#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static char WCFeedPlanKey, WCFeedStateKey, WCFeedRefreshKey, WCFeedRecoveringKey;
static __thread NSUInteger WCFeedHeightDepth;

@interface WCFeedPlan : NSObject
@property (atomic) CGFloat nativeHeight;
@property (atomic) CGFloat observedExtra;
@property (nonatomic) CGFloat predictedExtra;
@property (nonatomic, copy) NSString *signature;
@property (nonatomic, copy) NSString *tid;
@property (nonatomic, weak) UIViewController *controller;
@end
@implementation WCFeedPlan
@end

@interface WCFeedViewState : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic) CGRect frame;
@property (nonatomic) BOOL hidden;
@property (nonatomic) NSInteger lines;
@property (nonatomic) NSLineBreakMode lineBreak;
@end
@implementation WCFeedViewState
@end

@interface WCFeedState : NSObject
@property (nonatomic, strong) NSMutableArray<WCFeedViewState *> *views;
@property (nonatomic, strong) UIView *footer;
@property (nonatomic, strong) UIButton *like;
@property (nonatomic, strong) UIButton *comment;
@property (nonatomic, strong) UIButton *forward;
@property (nonatomic, weak) id item;
@property (nonatomic, weak) id model;
@property (nonatomic) BOOL actionsAvailable;
@property (nonatomic, copy) NSString *tid;
@property (nonatomic, copy) NSString *account;
@property (nonatomic) CFTimeInterval lastAction;
@property (nonatomic) BOOL updating;
@end
@implementation WCFeedState
@end

static NSHashTable *WCFeedControllers(void) {
    static NSHashTable *controllers; static dispatch_once_t once;
    dispatch_once(&once, ^{ controllers = [NSHashTable weakObjectsHashTable]; });
    return controllers;
}
static id WCFeedView(id cell, NSString *key) {
    id value = WCTweakSafeValue(cell, key);
    return [value isKindOfClass:UIView.class] ? value : nil;
}
static NSString *WCFeedText(id value) {
    if ([value isKindOfClass:NSAttributedString.class]) return [value string];
    return [value isKindOfClass:NSString.class] ? value : @"";
}
static NSString *WCFeedLocationText(id item, id model) {
    id owner = WCTweakSafeValue(model, @"dataItem");
    NSString *tid = WCFeedText(WCTweakSafeValue(item, @"tid"));
    if (!tid.length || ![tid isEqualToString:WCFeedText(WCTweakSafeValue(owner, @"tid"))] ||
        ![WCTweakSafeValue(model, @"canShowLoactionInfo") boolValue]) return @"";
    return WCFeedText(WCTweakSafeValue(model, @"locationDisplayText"));
}
static BOOL WCFeedTimeline(id controller) {
    Class cls = NSClassFromString(@"WCTimeLineViewController");
    return cls && [controller isKindOfClass:cls];
}
static BOOL WCFeedControllerSupported(id controller) {
    if (WCFeedTimeline(controller)) return YES;
    for (NSString *name in @[@"WCCommentDetailViewControllerFB", @"WCCommentDetailViewController"]) {
        Class cls = NSClassFromString(name);
        if (cls && [controller isKindOfClass:cls]) return YES;
    }
    return NO;
}
static NSMapTable *WCFeedControllerHints(void) {
    static NSMapTable *hints; static dispatch_once_t once;
    dispatch_once(&once, ^{ hints = [NSMapTable weakToWeakObjectsMapTable]; }); return hints;
}
static void WCFeedBindController(id context, id item, UIViewController *controller) {
    NSMapTable *hints = WCFeedControllerHints();
    @synchronized (hints) {
        if (context) [hints setObject:controller forKey:context];
        if (item) [hints setObject:controller forKey:item];
    }
}
static UIViewController *WCFeedResolveController(id context, id item) {
    NSMapTable *hints = WCFeedControllerHints();
    @synchronized (hints) {
        id bound = (context ? [hints objectForKey:context] : nil) ?: (item ? [hints objectForKey:item] : nil);
        if (WCFeedControllerSupported(bound)) return bound;
    }
    id root = WCTweakSafeValue(context, @"rootViewController");
    if (WCFeedControllerSupported(root)) return root;
    if (NSThread.isMainThread && [root isKindOfClass:UIViewController.class]) {
        for (UIViewController *parent = [root parentViewController]; parent; parent = parent.parentViewController)
            if (WCFeedControllerSupported(parent)) return parent;
        if ([root isKindOfClass:UINavigationController.class] && WCFeedControllerSupported([root topViewController]))
            return [root topViewController];
    }
    return nil;
}
static BOOL WCFeedPost(id item) {
    return item && WCFeedText(WCTweakSafeValue(item, @"tid")).length &&
        ![WCTweakSafeValue(item, @"isAd") boolValue];
}
static BOOL WCFeedEnabledForItem(id item, id controller) {
    return (WCFeedTimeline(controller) && WCGestureEnabled(WCGestureMomentsFeedEnabledKey)) ||
        WCGestureMomentsForwardCanForward(item);
}
static CGFloat WCFeedScale(void) { return MAX(.5, MIN(1.5, WCGestureLayoutScaleFactor())); }
static CGFloat WCFeedSpacing(void) {
    double value = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMomentsFeedSpacingKey];
    return (isfinite(value) ? MAX(0, MIN(48, value)) : 8) * WCFeedScale();
}
static CGFloat WCFeedHeight(NSString *text, UIFont *font, CGFloat width) {
    if (!text.length || width <= 0) return 0;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
        attributes:@{NSFontAttributeName:font} context:nil];
    return ceil(MAX(font.lineHeight, rect.size.height));
}
static CGFloat WCFeedExtra(WCFeedPlan *plan) { return MAX(plan.predictedExtra, plan.observedExtra); }
static BOOL WCFeedHas(id object, NSString *name, NSUInteger count) {
    SEL selector = NSSelectorFromString(name);
    if (![object respondsToSelector:selector]) return NO;
    return [object methodSignatureForSelector:selector].numberOfArguments == count + 2;
}
static BOOL WCFeedCanOperate(id item, id context) {
    Class cls = NSClassFromString(@"WCTimeLineCellView");
    NSString *name = @"canShowOperateButtonForDataItem:pageContext:";
    return WCFeedHas(cls, name, 2) && ((BOOL (*)(id, SEL, id, id))objc_msgSend)(cls, NSSelectorFromString(name), item, context);
}
static void WCFeedRegister(id controller) {
    if (!WCFeedControllerSupported(controller)) return;
    if (NSThread.isMainThread) [WCFeedControllers() addObject:controller];
    else dispatch_async(dispatch_get_main_queue(), ^{ [WCFeedControllers() addObject:controller]; });
}

static void WCFeedRefreshAttempt(UIViewController *controller, NSUInteger attempts) {
    if (!NSThread.isMainThread || !WCFeedControllerSupported(controller) ||
        [objc_getAssociatedObject(controller, &WCFeedRefreshKey) boolValue]) return;
    objc_setAssociatedObject(controller, &WCFeedRefreshKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *target = weakController;
        if (!target) return;
        id cache = WCTweakSafeValue(target, @"cellHeightCache");
        id view = WCTweakSafeValue(target, @"tableView");
        if (![view isKindOfClass:UITableView.class]) {
            objc_setAssociatedObject(target, &WCFeedRefreshKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
        }
        UITableView *table = view;
        if (table.hasUncommittedUpdates) {
            if (attempts) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIViewController *retry = weakController;
                if (!retry) return;
                objc_setAssociatedObject(retry, &WCFeedRefreshKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                WCFeedRefreshAttempt(retry, attempts - 1);
            });
            else objc_setAssociatedObject(target, &WCFeedRefreshKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        objc_setAssociatedObject(target, &WCFeedRefreshKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSIndexPath *anchor = table.indexPathsForVisibleRows.firstObject;
        CGFloat offset = anchor ? table.contentOffset.y - CGRectGetMinY([table rectForRowAtIndexPath:anchor]) : 0;
        if ([cache isKindOfClass:NSMutableDictionary.class]) [cache removeAllObjects];
        [UIView performWithoutAnimation:^{
            [table reloadData]; [table layoutIfNeeded];
            if (anchor && anchor.section < [table numberOfSections] && anchor.row < [table numberOfRowsInSection:anchor.section]) {
                CGFloat y = CGRectGetMinY([table rectForRowAtIndexPath:anchor]) + offset;
                CGFloat lower = -table.adjustedContentInset.top;
                CGFloat upper = MAX(lower, table.contentSize.height - table.bounds.size.height + table.adjustedContentInset.bottom);
                table.contentOffset = CGPointMake(table.contentOffset.x, MAX(lower, MIN(upper, y)));
            }
        }];
    });
}
static void WCFeedRefresh(UIViewController *controller) { WCFeedRefreshAttempt(controller, 5); }

static WCFeedPlan *WCFeedBuildPlan(double nativeHeight, id item, id context, id model, UIViewController *controller) {
    if (!isfinite(nativeHeight) || nativeHeight <= 0 || !WCFeedControllerSupported(controller)) return nil;
    WCFeedRegister(controller);
    if (!WCFeedEnabledForItem(item, controller) || !WCFeedPost(item)) return nil;
    BOOL feedEnabled = WCFeedTimeline(controller) && WCGestureEnabled(WCGestureMomentsFeedEnabledKey);
    BOOL forward = WCGestureMomentsForwardCanForward(item);
    id holder = model ?: item;
    id params = WCTweakSafeValue(model, @"params");
    CGFloat scale = WCFeedScale();
    CGFloat width = [WCTweakSafeValue(params, @"actionAreaWidth") doubleValue];
    if (!isfinite(width) || width < 80) width = 220 * scale;
    UIFont *font = WCTweakSafeValue(params, @"titleFont");
    if (![font isKindOfClass:UIFont.class]) font = [UIFont systemFontOfSize:13 * scale];
    BOOL fullLocation = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedLocationKey);
    NSString *location = fullLocation ? WCFeedLocationText(item, model) : @"";
    NSString *time = WCGestureMomentsTimeText(item) ?: WCFeedText(WCTweakSafeValue(model, @"timeLabelDisplayText"));
    BOOL actions = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedActionsKey) && WCFeedCanOperate(item, context);
    CGFloat timeExtra = feedEnabled ? MAX(0, WCFeedHeight(time, font, MAX(80, width - 80 * scale)) - ceil(font.lineHeight)) : 0;
    CGFloat extra = (feedEnabled ? WCFeedSpacing() : 0) + timeExtra + (location.length ? WCFeedHeight(location, font, width) + 6 * scale : 0)
        + ((actions || forward) ? 46 * scale : 0);
    if (!isfinite(extra) || extra > 4096) return nil;
    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%.2f|%@|%.2f|%.2f|%d|%d|%.2f|%d|%d",
        WCFeedText(WCTweakSafeValue(item, @"tid")), time, location, width, font.fontName, font.pointSize,
        scale, fullLocation, actions, WCFeedSpacing(), feedEnabled, forward];
    @synchronized (holder) {
        WCFeedPlan *plan = objc_getAssociatedObject(holder, &WCFeedPlanKey);
        if (plan.controller != controller || ![plan.signature isEqualToString:signature]) {
            plan = [WCFeedPlan new]; plan.signature = signature; plan.predictedExtra = extra;
            plan.controller = controller;
            plan.tid = WCFeedText(WCTweakSafeValue(item, @"tid"));
            objc_setAssociatedObject(holder, &WCFeedPlanKey, plan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        plan.nativeHeight = nativeHeight;
        if (holder != item) objc_setAssociatedObject(item, &WCFeedPlanKey, plan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return plan;
    }
}
void WCGestureMomentsFeedBeginHeight(void) { WCFeedHeightDepth++; }
double WCGestureMomentsFeedEndHeight(double nativeHeight, id item, id context, id model) {
    if (WCFeedHeightDepth) WCFeedHeightDepth--;
    if (WCFeedHeightDepth) return nativeHeight;
    UIViewController *controller = WCFeedResolveController(context, item);
    WCFeedPlan *plan = WCFeedBuildPlan(nativeHeight, item, context, model, controller);
    return plan ? nativeHeight + WCFeedExtra(plan) : nativeHeight;
}
static WCFeedPlan *WCFeedRecoverPlan(UIView *cell, id item, id context, id model, UIViewController *controller) {
    if ([objc_getAssociatedObject(cell, &WCFeedRecoveringKey) boolValue]) return nil;
    Class cls = NSClassFromString(@"WCTimeLineCellView");
    SEL selector = NSSelectorFromString(@"heightForDataItem:pageContext:actionAreaVM:");
    if (!WCFeedHas(cls, NSStringFromSelector(selector), 3)) return nil;
    double nativeHeight = 0;
    objc_setAssociatedObject(cell, &WCFeedRecoveringKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Ask WeChat to measure its native content. Suppress only our own added
    // height during this call, so recovery cannot accumulate an old extension.
    WCFeedHeightDepth++;
    @try {
        nativeHeight = ((double (*)(id, SEL, id, id, id))objc_msgSend)(cls, selector, item, context, model);
    } @catch (__unused NSException *exception) {
        nativeHeight = 0;
    } @finally {
        WCFeedHeightDepth--;
        objc_setAssociatedObject(cell, &WCFeedRecoveringKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return WCFeedBuildPlan(nativeHeight, item, context, model, controller);
}

static void WCFeedRestoreViews(UIView *cell, WCFeedState *state) {
    id item = WCTweakSafeValue(cell, @"m_dataItem");
    BOOL sameContent = item == state.item && state.model == WCTweakSafeValue(cell, @"actionAreaVM") &&
        [state.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))] &&
        [state.account isEqualToString:WCCurrentUserWXID() ?: @""];
    // If native code already rebound the cell, old snapshots belong to the old
    // post. Restoring them here would resurrect its location/visibility.
    for (WCFeedViewState *saved in (sameContent ? state.views : @[])) {
        UIView *view = saved.view;
        view.frame = saved.frame; view.hidden = saved.hidden;
        if ([view isKindOfClass:UILabel.class]) {
            ((UILabel *)view).numberOfLines = saved.lines;
            ((UILabel *)view).lineBreakMode = saved.lineBreak;
        }
    }
    [state.views removeAllObjects];
    state.footer.hidden = YES;
    state.actionsAvailable = NO;
}
void WCGestureMomentsFeedBeforeLayout(UIView *cell) {
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (state && !state.updating) WCFeedRestoreViews(cell, state);
}
void WCGestureMomentsFeedReset(UIView *cell) {
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (!state) return;
    WCFeedRestoreViews(cell, state); [state.footer removeFromSuperview];
    objc_setAssociatedObject(cell, &WCFeedStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void WCFeedSave(WCFeedState *state, UIView *view) {
    if (!view) return;
    for (WCFeedViewState *old in state.views) if (old.view == view) return;
    WCFeedViewState *saved = [WCFeedViewState new]; saved.view = view;
    saved.frame = view.frame; saved.hidden = view.hidden;
    if ([view isKindOfClass:UILabel.class]) {
        saved.lines = ((UILabel *)view).numberOfLines; saved.lineBreak = ((UILabel *)view).lineBreakMode;
    }
    [state.views addObject:saved];
}
static BOOL WCFeedCurrent(UIView *cell, WCFeedState *state) {
    id item = WCTweakSafeValue(cell, @"m_dataItem");
    UIViewController *controller = WCViewControllerForResponder(cell);
    if (!WCFeedControllerSupported(controller))
        controller = WCFeedResolveController(WCTweakSafeValue(cell, @"pageContext"), item);
    return cell.window && WCFeedEnabledForItem(item, controller) && WCFeedPost(item) &&
        WCFeedControllerSupported(controller) && item == state.item &&
        state.model == WCTweakSafeValue(cell, @"actionAreaVM") &&
        [WCFeedText(WCTweakSafeValue(item, @"tid")) isEqualToString:state.tid] &&
        [state.account isEqualToString:WCCurrentUserWXID() ?: @""];
}
static UIButton *WCFeedButton(NSString *title, NSString *symbol) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    if (symbol) [button setImage:[UIImage systemImageNamed:symbol withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:14 * WCFeedScale() weight:UIImageSymbolWeightRegular]]
        forState:UIControlStateNormal];
    button.tintColor = UIColor.labelColor;
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12 * WCFeedScale()];
    return button;
}
static WCFeedState *WCFeedCreateState(UIView *cell) {
    WCFeedState *state = [WCFeedState new]; state.views = [NSMutableArray array];
    state.footer = [UIView new]; state.footer.backgroundColor = UIColor.clearColor; state.footer.hidden = YES;
    state.like = WCFeedButton(@"点赞", @"heart"); state.comment = WCFeedButton(@"评论", @"text.bubble");
    state.forward = WCFeedButton(@"转发", @"arrow.turn.up.right");
    for (UIButton *button in @[state.like, state.comment, state.forward]) [state.footer addSubview:button];
    [cell addSubview:state.footer];
    __weak UIView *weakCell = cell; __weak WCFeedState *weakState = state;
    for (UIButton *button in @[state.like, state.comment, state.forward]) {
        [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
            UIView *target = weakCell; WCFeedState *current = weakState;
            if (!current || !WCFeedCurrent(target, current) || CACurrentMediaTime() - current.lastAction < .35) return;
            UIButton *sender = action.sender;
            if (sender == current.forward) {
                if (WCGestureMomentsForwardCanForward(current.item)) {
                    current.lastAction = CACurrentMediaTime();
                    UIViewController *presenter = WCViewControllerForResponder(target);
                    if (presenter) WCGestureMomentsForwardPresent(current.item, presenter);
                }
                return;
            }
            NSString *selector = sender == current.like ? @"onAccessibilityLike" : @"onAccessibilityComment";
            UIView *operate = WCFeedView(target, @"m_operateBtn");
            if (!WCGestureEnabled(WCGestureMomentsFeedActionsKey) || !WCFeedHas(target, selector, 0) ||
                !current.actionsAvailable || !operate || !operate.userInteractionEnabled ||
                ([operate isKindOfClass:UIControl.class] && !((UIControl *)operate).enabled) ||
                !WCFeedCanOperate(current.item, WCTweakSafeValue(target, @"pageContext"))) return;
            current.lastAction = CACurrentMediaTime();
            ((void (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(selector));
            [target setNeedsLayout];
        }] forControlEvents:UIControlEventTouchUpInside];
    }
    objc_setAssociatedObject(cell, &WCFeedStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return state;
}

void WCGestureMomentsFeedLayout(UIView *cell) {
    if (!NSThread.isMainThread) return;
    if ([objc_getAssociatedObject(cell, &WCFeedRecoveringKey) boolValue]) return;
    id item = WCTweakSafeValue(cell, @"m_dataItem"), model = WCTweakSafeValue(cell, @"actionAreaVM");
    id context = WCTweakSafeValue(cell, @"pageContext") ?: WCTweakSafeValue(model, @"pageContext");
    UIViewController *controller = WCViewControllerForResponder(cell);
    if (!WCFeedControllerSupported(controller)) controller = WCFeedResolveController(context, item);
    WCFeedRegister(controller);
    if (!cell.window || !WCFeedEnabledForItem(item, controller) || !WCFeedControllerSupported(controller) ||
        !WCFeedPost(item)) { WCGestureMomentsFeedReset(cell); return; }
    WCFeedBindController(context, item, controller);
    WCFeedPlan *plan = objc_getAssociatedObject(model ?: item, &WCFeedPlanKey);
    if (!plan) plan = objc_getAssociatedObject(item, &WCFeedPlanKey);
    if (!plan || plan.controller != controller || !plan.nativeHeight ||
        ![plan.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))]) {
        plan = WCFeedRecoverPlan(cell, item, context, model, controller);
        if (!plan) { WCGestureMomentsFeedReset(cell); return; }
        WCFeedRefresh(controller);
    }
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (state.updating) return;
    if (state.item && (state.item != item || state.model != model ||
        ![state.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))])) {
        WCGestureMomentsFeedReset(cell); state = nil;
    }
    if (!state) state = WCFeedCreateState(cell);
    WCFeedRestoreViews(cell, state);
    state.updating = YES;
    @try {
        state.item = item; state.model = model;
        state.tid = WCFeedText(WCTweakSafeValue(item, @"tid")); state.account = WCCurrentUserWXID() ?: @"";
        UILabel *time = WCFeedView(cell, @"m_timeLabel");
        UIView *operate = WCFeedView(cell, @"m_operateBtn");
        if (![time isKindOfClass:UILabel.class] || time.hidden || CGRectIsEmpty(time.frame)) return;
        CGFloat scale = WCFeedScale(), spacing = 6 * scale;
        BOOL feedEnabled = WCFeedTimeline(controller) && WCGestureEnabled(WCGestureMomentsFeedEnabledKey);
        BOOL forward = WCGestureMomentsForwardCanForward(item);
        CGFloat left = CGRectGetMinX(time.frame), right = CGRectGetWidth(cell.bounds) - 4 * scale;
        if (right - left < 80) return;
        BOOL fullLocation = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedLocationKey);
        BOOL actions = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedActionsKey) && operate && !operate.hidden &&
            operate.userInteractionEnabled && (![operate isKindOfClass:UIControl.class] || ((UIControl *)operate).enabled) &&
            WCFeedCanOperate(item, WCTweakSafeValue(cell, @"pageContext"));
        UIView *location = WCFeedView(cell, @"m_locationLabel"), *individual = WCFeedView(cell, @"m_individualLocationLabel");
        UILabel *wrappedLocation = nil;
        if (fullLocation && WCFeedLocationText(item, model).length)
            for (UIView *label in @[location ?: [UIView new], individual ?: [UIView new]])
                if (label.superview == cell && [label isKindOfClass:UILabel.class] &&
                    !label.hidden && ((UILabel *)label).text.length) {
                    wrappedLocation = (UILabel *)label; break;
                }
        // Some native paths bottom-align metadata using the extended height. Normalize
        // those views once before adding our own footer; never move the message body.
        for (UIView *view in @[time, operate ?: [UIView new], location ?: [UIView new], individual ?: [UIView new]]) {
            if (view.superview != cell) continue;
            if (CGRectGetMinY(view.frame) >= plan.nativeHeight && CGRectGetMaxY(view.frame) > plan.nativeHeight) {
                WCFeedSave(state, view); CGRect frame = view.frame; frame.origin.y -= WCFeedExtra(plan); view.frame = frame;
            }
        }
        CGRect originalTime = time.frame;
        CGFloat timeRight = right;
        for (UIView *view in cell.subviews) {
            if (view == state.footer || view == time || view.hidden || view.alpha < .01 || CGRectIsEmpty(view.frame) ||
                view == wrappedLocation || (actions && view == operate)) continue;
            if (CGRectGetMinX(view.frame) > left && CGRectGetMinY(view.frame) < CGRectGetMaxY(originalTime) &&
                CGRectGetMaxY(view.frame) > CGRectGetMinY(originalTime)) timeRight = MIN(timeRight, CGRectGetMinX(view.frame) - spacing);
        }
        CGFloat timeWidth = feedEnabled ? MAX(40, timeRight - left) : originalTime.size.width;
        CGFloat height = WCFeedHeight(time.text ?: @"", time.font, timeWidth);
        CGFloat timeExtra = feedEnabled ? MAX(0, height - CGRectGetHeight(originalTime)) : 0;
        if (feedEnabled) {
            WCFeedSave(state, time);
            time.numberOfLines = 0; time.lineBreakMode = NSLineBreakByWordWrapping;
            time.frame = CGRectMake(left, originalTime.origin.y, timeWidth, MAX(height, originalTime.size.height));
        }
        for (UIView *view in cell.subviews) {
            if (view == state.footer || view == time || view == wrappedLocation || (actions && view == operate)) continue;
            if (timeExtra > 0 && !view.hidden && CGRectGetMinY(view.frame) >= CGRectGetMaxY(originalTime) - .5) {
                WCFeedSave(state, view); CGRect frame = view.frame; frame.origin.y += timeExtra; view.frame = frame;
            }
        }
        CGFloat bottom = CGRectGetMaxY(time.frame);
        for (UIView *view in cell.subviews) {
            if (view == state.footer || view == wrappedLocation || (actions && view == operate) ||
                view.hidden || view.alpha < .01 || CGRectIsEmpty(view.frame)) continue;
            if (view.frame.origin.y >= 1 && CGRectGetMaxY(view.frame) < plan.nativeHeight + timeExtra + 40 * scale)
                bottom = MAX(bottom, CGRectGetMaxY(view.frame));
        }
        CGFloat width = right - left, cursor = 0;
        if (wrappedLocation) {
            // Keep WeChat's actual label, attributed text, color and gestures.
            // Only its layout changes; there is no second location view/text.
            WCFeedSave(state, wrappedLocation);
            wrappedLocation.numberOfLines = 0;
            wrappedLocation.lineBreakMode = NSLineBreakByWordWrapping;
            CGFloat locationHeight = ceil(MAX(wrappedLocation.font.lineHeight,
                [wrappedLocation sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height));
            wrappedLocation.frame = CGRectMake(left, bottom + spacing, width, locationHeight);
            bottom = CGRectGetMaxY(wrappedLocation.frame);
        }
        state.like.hidden = state.comment.hidden = !actions;
        state.forward.hidden = !forward;
        state.actionsAvailable = actions;
        if (actions || forward) {
            cursor += spacing;
            CGFloat rowHeight = 40 * scale;
            NSArray<UIButton *> *buttons = actions ? (forward ? @[state.like, state.comment, state.forward] : @[state.like, state.comment]) : @[state.forward];
            CGFloat buttonWidth = MIN(62 * scale, (width - spacing * (buttons.count - 1)) / buttons.count);
            CGFloat x = width - buttonWidth * buttons.count - spacing * (buttons.count - 1);
            for (UIButton *button in buttons) {
                button.frame = CGRectMake(x, cursor, buttonWidth, rowHeight);
                button.titleLabel.font = [UIFont systemFontOfSize:12 * scale];
                x += buttonWidth + spacing;
            }
            BOOL liked = [WCTweakSafeValue(item, @"likeFlag") boolValue];
            [state.like setTitle:liked ? @"已赞" : @"点赞" forState:UIControlStateNormal];
            UIImageSymbolConfiguration *icons = [UIImageSymbolConfiguration configurationWithPointSize:14 * scale weight:UIImageSymbolWeightRegular];
            [state.like setImage:[UIImage systemImageNamed:liked ? @"heart.fill" : @"heart" withConfiguration:icons] forState:UIControlStateNormal];
            [state.comment setImage:[UIImage systemImageNamed:@"text.bubble" withConfiguration:icons] forState:UIControlStateNormal];
            [state.forward setImage:[UIImage systemImageNamed:@"arrow.turn.up.right" withConfiguration:icons] forState:UIControlStateNormal];
            state.like.titleLabel.font = state.comment.titleLabel.font = [UIFont systemFontOfSize:12 * scale];
            state.like.accessibilityLabel = liked ? @"取消点赞" : @"点赞";
            if (actions) { WCFeedSave(state, operate); operate.hidden = YES; }
            cursor += rowHeight;
        }
        state.footer.frame = CGRectMake(left, bottom, width, cursor);
        state.footer.hidden = cursor <= 0;
        CGFloat needed = MAX(0, bottom + cursor + (feedEnabled ? WCFeedSpacing() : 0) - plan.nativeHeight);
        if (isfinite(needed) && needed <= 4096 && needed > WCFeedExtra(plan) + .5) {
            plan.observedExtra = needed; WCFeedRefresh(controller);
        }
    } @finally { state.updating = NO; }
}

BOOL WCGestureMomentsFeedIsActionPoint(UIView *cell, CGPoint point) {
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (!state || state.footer.hidden || !WCFeedCurrent(cell, state)) return NO;
    for (UIButton *button in @[state.like, state.comment, state.forward]) {
        if (button.hidden || !button.enabled) continue;
        if ([button pointInside:[cell convertPoint:point toView:button] withEvent:nil]) return YES;
    }
    return NO;
}
UIView *WCGestureMomentsFeedHitTest(UIView *cell, CGPoint point, UIEvent *event, UIView *original) {
    if (!CGRectContainsPoint(cell.bounds, point) || !WCGestureMomentsFeedIsActionPoint(cell, point)) return original;
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if ([original isKindOfClass:UIControl.class] && ![original isDescendantOfView:state.footer]) return original;
    return [state.footer hitTest:[cell convertPoint:point toView:state.footer] withEvent:event] ?: original;
}
void WCGestureMomentsFeedSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.moments.feed-layout."] &&
        ![key isEqualToString:WCGestureMomentsForwardEnabledKey] &&
        ![key hasPrefix:@"com.qiu7c.onewx.moments.precise-time."] &&
        ![key isEqualToString:WCGesturePageScaleEnabledKey] && ![key isEqualToString:WCGesturePageScalePercentKey] &&
        ![key isEqualToString:WCMomentsLayoutEnabledKey] && ![key isEqualToString:WCMomentsHeightScaleKey]) return;
    for (UIViewController *controller in WCFeedControllers().allObjects) WCFeedRefresh(controller);
}
