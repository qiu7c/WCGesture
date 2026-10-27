#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static char WCFeedPlanKey, WCFeedStateKey, WCFeedRefreshKey;
static __thread NSUInteger WCFeedHeightDepth;

@interface WCFeedPlan : NSObject
@property (atomic) CGFloat nativeHeight;
@property (atomic) CGFloat observedExtra;
@property (nonatomic) CGFloat predictedExtra;
@property (nonatomic, copy) NSString *signature;
@property (nonatomic, copy) NSString *tid;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, strong) UIFont *font;
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
@property (nonatomic, strong) UIButton *location;
@property (nonatomic, strong) UIButton *like;
@property (nonatomic, strong) UIButton *comment;
@property (nonatomic, weak) UIView *locationTarget;
@property (nonatomic, weak) id item;
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
static BOOL WCFeedTimeline(id controller) {
    Class cls = NSClassFromString(@"WCTimeLineViewController");
    return cls && [controller isKindOfClass:cls];
}
static BOOL WCFeedPost(id item) {
    return item && WCFeedText(WCTweakSafeValue(item, @"tid")).length &&
        ![WCTweakSafeValue(item, @"isAd") boolValue];
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
    if (!WCFeedTimeline(controller)) return;
    if (NSThread.isMainThread) [WCFeedControllers() addObject:controller];
    else dispatch_async(dispatch_get_main_queue(), ^{ [WCFeedControllers() addObject:controller]; });
}

static void WCFeedRefreshAttempt(UIViewController *controller, NSUInteger attempts) {
    if (!NSThread.isMainThread || !WCFeedTimeline(controller) ||
        [objc_getAssociatedObject(controller, &WCFeedRefreshKey) boolValue]) return;
    objc_setAssociatedObject(controller, &WCFeedRefreshKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *target = weakController;
        if (!target) return;
        id cache = WCTweakSafeValue(target, @"cellHeightCache");
        id view = WCTweakSafeValue(target, @"tableView");
        if (![cache isKindOfClass:NSMutableDictionary.class] || ![view isKindOfClass:UITableView.class]) {
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
        [cache removeAllObjects];
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

void WCGestureMomentsFeedBeginHeight(void) { WCFeedHeightDepth++; }
double WCGestureMomentsFeedEndHeight(double nativeHeight, id item, id context, id model) {
    if (WCFeedHeightDepth) WCFeedHeightDepth--;
    if (WCFeedHeightDepth || !isfinite(nativeHeight) || nativeHeight <= 0) return nativeHeight;
    id controller = WCTweakSafeValue(context, @"rootViewController");
    if (!WCFeedTimeline(controller)) return nativeHeight;
    WCFeedRegister(controller);
    if (!WCGestureEnabled(WCGestureMomentsFeedEnabledKey) || !WCFeedPost(item)) return nativeHeight;
    id holder = model ?: item;
    id params = WCTweakSafeValue(model, @"params");
    CGFloat scale = WCFeedScale();
    CGFloat width = [WCTweakSafeValue(params, @"actionAreaWidth") doubleValue];
    if (!isfinite(width) || width < 80) width = 220 * scale;
    UIFont *font = WCTweakSafeValue(params, @"titleFont");
    if (![font isKindOfClass:UIFont.class]) font = [UIFont systemFontOfSize:13 * scale];
    BOOL fullLocation = WCGestureEnabled(WCGestureMomentsFeedLocationKey);
    NSString *location = fullLocation && [WCTweakSafeValue(model, @"canShowLoactionInfo") boolValue]
        ? WCFeedText(WCTweakSafeValue(model, @"locationDisplayText")) : @"";
    NSString *time = WCGestureMomentsTimeText(item) ?: WCFeedText(WCTweakSafeValue(model, @"timeLabelDisplayText"));
    BOOL actions = WCGestureEnabled(WCGestureMomentsFeedActionsKey) && WCFeedCanOperate(item, context);
    CGFloat timeExtra = MAX(0, WCFeedHeight(time, font, MAX(80, width - 80 * scale)) - ceil(font.lineHeight));
    CGFloat extra = WCFeedSpacing() + timeExtra + (location.length ? WCFeedHeight(location, font, width) + 6 * scale : 0)
        + (actions ? 50 * scale : 0);
    if (!isfinite(extra) || extra > 4096) return nativeHeight;
    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%.2f|%@|%.2f|%.2f|%d|%d|%.2f",
        WCFeedText(WCTweakSafeValue(item, @"tid")), time, location, width, font.fontName, font.pointSize,
        scale, fullLocation, actions, WCFeedSpacing()];
    @synchronized (holder) {
        WCFeedPlan *plan = objc_getAssociatedObject(holder, &WCFeedPlanKey);
        if (![plan.signature isEqualToString:signature]) {
            plan = [WCFeedPlan new]; plan.signature = signature; plan.predictedExtra = extra;
            plan.tid = WCFeedText(WCTweakSafeValue(item, @"tid"));
            plan.location = location; plan.font = font;
            objc_setAssociatedObject(holder, &WCFeedPlanKey, plan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        plan.nativeHeight = nativeHeight;
        if (holder != item) objc_setAssociatedObject(item, &WCFeedPlanKey, plan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return nativeHeight + WCFeedExtra(plan);
    }
}

static void WCFeedRestoreViews(WCFeedState *state) {
    for (WCFeedViewState *saved in state.views) {
        UIView *view = saved.view;
        view.frame = saved.frame; view.hidden = saved.hidden;
        if ([view isKindOfClass:UILabel.class]) {
            ((UILabel *)view).numberOfLines = saved.lines;
            ((UILabel *)view).lineBreakMode = saved.lineBreak;
        }
    }
    [state.views removeAllObjects];
    state.footer.hidden = YES;
}
void WCGestureMomentsFeedBeforeLayout(UIView *cell) {
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (state && !state.updating) WCFeedRestoreViews(state);
}
void WCGestureMomentsFeedReset(UIView *cell) {
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (!state) return;
    WCFeedRestoreViews(state); [state.footer removeFromSuperview];
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
    return cell.window && WCGestureEnabled(WCGestureMomentsFeedEnabledKey) && WCFeedPost(item) &&
        WCFeedTimeline(WCViewControllerForResponder(cell)) && item == state.item &&
        [WCFeedText(WCTweakSafeValue(item, @"tid")) isEqualToString:state.tid] &&
        [state.account isEqualToString:WCCurrentUserWXID() ?: @""];
}
static UIButton *WCFeedButton(NSString *title, NSString *symbol) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    if (symbol) [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.tintColor = UIColor.systemBlueColor;
    button.titleLabel.font = [UIFont systemFontOfSize:13 * WCFeedScale()];
    return button;
}
static WCFeedState *WCFeedCreateState(UIView *cell) {
    WCFeedState *state = [WCFeedState new]; state.views = [NSMutableArray array];
    state.footer = [UIView new]; state.footer.backgroundColor = UIColor.clearColor;
    state.location = WCFeedButton(@"", nil); state.location.titleLabel.numberOfLines = 0;
    state.location.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    state.location.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [state.location setTitleColor:UIColor.systemBlueColor forState:UIControlStateDisabled];
    state.like = WCFeedButton(@"点赞", @"heart"); state.comment = WCFeedButton(@"评论", @"text.bubble");
    for (UIButton *button in @[state.location, state.like, state.comment]) [state.footer addSubview:button];
    [cell addSubview:state.footer];
    __weak UIView *weakCell = cell; __weak WCFeedState *weakState = state;
    for (UIButton *button in @[state.like, state.comment, state.location]) {
        [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
            UIView *target = weakCell; WCFeedState *current = weakState;
            if (!current || !WCFeedCurrent(target, current) || CACurrentMediaTime() - current.lastAction < .35) return;
            UIButton *sender = action.sender;
            NSString *selector = sender == current.like ? @"onAccessibilityLike" : @"onAccessibilityComment";
            if (sender == current.location) {
                if (!WCGestureEnabled(WCGestureMomentsFeedLocationKey)) return;
                id native = current.locationTarget;
                if (native && WCFeedHas(target, @"onActionLocation:", 1))
                    ((void (*)(id, SEL, id))objc_msgSend)(target, NSSelectorFromString(@"onActionLocation:"), native);
                return;
            }
            UIView *operate = WCFeedView(target, @"m_operateBtn");
            if (!WCGestureEnabled(WCGestureMomentsFeedActionsKey) || !WCFeedHas(target, selector, 0) ||
                !operate || operate.hidden || !operate.userInteractionEnabled ||
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
    UIViewController *controller = WCViewControllerForResponder(cell);
    WCFeedRegister(controller);
    id item = WCTweakSafeValue(cell, @"m_dataItem"), model = WCTweakSafeValue(cell, @"actionAreaVM");
    if (!WCGestureEnabled(WCGestureMomentsFeedEnabledKey) || !WCFeedTimeline(controller) ||
        !WCFeedPost(item)) { WCGestureMomentsFeedReset(cell); return; }
    WCFeedPlan *plan = objc_getAssociatedObject(model ?: item, &WCFeedPlanKey);
    if (!plan) plan = objc_getAssociatedObject(item, &WCFeedPlanKey);
    if (!plan || !plan.nativeHeight || ![plan.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))]) {
        WCGestureMomentsFeedReset(cell); return;
    }
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (state.updating) return;
    if (state.item && state.item != item) { WCGestureMomentsFeedReset(cell); state = nil; }
    if (!state) state = WCFeedCreateState(cell);
    if (state.views.count) WCFeedRestoreViews(state);
    state.updating = YES;
    @try {
        state.item = item; state.tid = WCFeedText(WCTweakSafeValue(item, @"tid")); state.account = WCCurrentUserWXID() ?: @"";
        UILabel *time = WCFeedView(cell, @"m_timeLabel");
        UIView *operate = WCFeedView(cell, @"m_operateBtn");
        if (![time isKindOfClass:UILabel.class] || time.hidden || CGRectIsEmpty(time.frame)) return;
        CGFloat scale = WCFeedScale(), spacing = 6 * scale;
        CGFloat left = CGRectGetMinX(time.frame), right = CGRectGetWidth(cell.bounds) - 4 * scale;
        if (right - left < 80) return;
        BOOL fullLocation = WCGestureEnabled(WCGestureMomentsFeedLocationKey);
        BOOL actions = WCGestureEnabled(WCGestureMomentsFeedActionsKey) && operate && !operate.hidden &&
            operate.userInteractionEnabled && (![operate isKindOfClass:UIControl.class] || ((UIControl *)operate).enabled) &&
            WCFeedCanOperate(item, WCTweakSafeValue(cell, @"pageContext"));
        UIView *location = WCFeedView(cell, @"m_locationLabel"), *individual = WCFeedView(cell, @"m_individualLocationLabel");
        NSString *nativeLocation = @"";
        state.locationTarget = nil;
        for (UIView *label in @[location ?: [UIView new], individual ?: [UIView new]])
            if ([label isKindOfClass:UILabel.class] && !label.hidden && ((UILabel *)label).text.length) {
                nativeLocation = ((UILabel *)label).text;
                state.locationTarget = label;
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
                (fullLocation && (view == location || view == individual)) || (actions && view == operate)) continue;
            if (CGRectGetMinX(view.frame) > left && CGRectGetMinY(view.frame) < CGRectGetMaxY(originalTime) &&
                CGRectGetMaxY(view.frame) > CGRectGetMinY(originalTime)) timeRight = MIN(timeRight, CGRectGetMinX(view.frame) - spacing);
        }
        CGFloat timeWidth = MAX(40, timeRight - left);
        CGFloat height = WCFeedHeight(time.text ?: @"", time.font, timeWidth);
        CGFloat timeExtra = MAX(0, height - CGRectGetHeight(originalTime));
        WCFeedSave(state, time);
        time.numberOfLines = 0; time.lineBreakMode = NSLineBreakByWordWrapping;
        time.frame = CGRectMake(left, originalTime.origin.y, timeWidth, MAX(height, originalTime.size.height));
        for (UIView *view in cell.subviews) {
            if (view == state.footer || view == time || view == location || view == individual || (actions && view == operate)) continue;
            if (timeExtra > 0 && !view.hidden && CGRectGetMinY(view.frame) >= CGRectGetMaxY(originalTime) - .5) {
                WCFeedSave(state, view); CGRect frame = view.frame; frame.origin.y += timeExtra; view.frame = frame;
            }
        }
        if (fullLocation) for (UIView *view in @[location ?: [UIView new], individual ?: [UIView new]])
            if (view.superview == cell) { WCFeedSave(state, view); view.hidden = YES; }
        CGFloat bottom = CGRectGetMaxY(time.frame);
        for (UIView *view in cell.subviews) {
            if (view == state.footer || (actions && view == operate) || view.hidden || view.alpha < .01 || CGRectIsEmpty(view.frame)) continue;
            if (view.frame.origin.y >= 1 && CGRectGetMaxY(view.frame) < plan.nativeHeight + timeExtra + 40 * scale)
                bottom = MAX(bottom, CGRectGetMaxY(view.frame));
        }
        CGFloat width = right - left, cursor = 0;
        NSString *locationText = fullLocation ? (plan.location.length ? plan.location : nativeLocation) : @"";
        state.location.hidden = !locationText.length;
        if (locationText.length) {
            UIFont *font = [location isKindOfClass:UILabel.class] ? ((UILabel *)location).font : plan.font;
            state.location.titleLabel.font = font;
            [state.location setTitle:locationText forState:UIControlStateNormal];
            CGFloat locationHeight = WCFeedHeight(locationText, font, width);
            state.location.frame = CGRectMake(0, spacing, width, locationHeight);
            state.location.enabled = state.locationTarget && WCFeedHas(cell, @"onActionLocation:", 1);
            cursor = spacing + locationHeight;
        }
        state.like.hidden = state.comment.hidden = !actions;
        if (actions) {
            cursor += spacing;
            CGFloat rowHeight = 44 * scale;
            CGFloat moreWidth = MAX(32 * scale, operate.frame.size.width);
            CGFloat buttonWidth = MIN(94 * scale, MAX(44 * scale, (width - moreWidth - 2 * spacing) / 2));
            state.like.frame = CGRectMake(0, cursor, buttonWidth, rowHeight);
            state.comment.frame = CGRectMake(buttonWidth + spacing, cursor, buttonWidth, rowHeight);
            BOOL liked = [WCTweakSafeValue(item, @"likeFlag") boolValue];
            [state.like setTitle:liked ? @"已赞" : @"点赞" forState:UIControlStateNormal];
            [state.like setImage:[UIImage systemImageNamed:liked ? @"heart.fill" : @"heart"] forState:UIControlStateNormal];
            state.like.accessibilityLabel = liked ? @"取消点赞" : @"点赞";
            WCFeedSave(state, operate);
            CGRect frame = operate.frame; frame.origin.x = right - frame.size.width;
            frame.origin.y = bottom + cursor + (rowHeight - frame.size.height) / 2; operate.frame = frame;
            cursor += rowHeight;
        }
        state.footer.frame = CGRectMake(left, bottom, width, cursor);
        state.footer.hidden = cursor <= 0;
        CGFloat needed = MAX(0, bottom + cursor + WCFeedSpacing() - plan.nativeHeight);
        if (isfinite(needed) && needed <= 4096 && needed > WCFeedExtra(plan) + .5) {
            plan.observedExtra = needed; WCFeedRefresh(controller);
        }
    } @finally { state.updating = NO; }
}

BOOL WCGestureMomentsFeedIsActionPoint(UIView *cell, CGPoint point) {
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (!state || state.footer.hidden || !WCFeedCurrent(cell, state)) return NO;
    for (UIButton *button in @[state.location, state.like, state.comment]) {
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
        ![key hasPrefix:@"com.qiu7c.onewx.moments.precise-time."] &&
        ![key isEqualToString:WCGesturePageScaleEnabledKey] && ![key isEqualToString:WCGesturePageScalePercentKey] &&
        ![key isEqualToString:WCMomentsLayoutEnabledKey] && ![key isEqualToString:WCMomentsHeightScaleKey]) return;
    for (UIViewController *controller in WCFeedControllers().allObjects) WCFeedRefresh(controller);
}
