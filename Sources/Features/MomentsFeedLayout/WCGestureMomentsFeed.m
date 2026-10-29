#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static char WCFeedPlanKey, WCFeedStateKey, WCFeedRefreshKey, WCFeedRecoveringKey, WCFeedRowsKey, WCFeedRemeasureKey, WCFeedButtonStyleKey, WCFeedNeedsRefreshKey;
static __thread NSUInteger WCFeedHeightDepth;

@interface WCFeedPlan : NSObject
@property (atomic) CGFloat nativeHeight;
@property (atomic) CGFloat observedExtra;
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic) CGFloat rowWidth;
@property (nonatomic, weak) id item;
@property (nonatomic, weak) id model;
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, weak) UITableViewCell *wrapper;
@property (nonatomic, copy) NSString *account;
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
@property (nonatomic) BOOL resizedContent;
@property (nonatomic) CGFloat originalContentHeight;
@property (nonatomic) CGFloat appliedContentHeight;
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
static CGFloat WCFeedButtonScale(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    double percent = [defaults objectForKey:WCGestureMomentsFeedButtonSizeKey] ? [defaults doubleForKey:WCGestureMomentsFeedButtonSizeKey] : 100;
    return WCFeedScale() * (isfinite(percent) ? MAX(60, MIN(180, percent)) : 100) / 100;
}
WCGestureMomentsFeedActionMetrics WCGestureMomentsFeedResolveActionMetrics(CGFloat width, NSUInteger count, BOOL hideText) {
    CGFloat scale = WCFeedScale(), buttonScale = WCFeedButtonScale(), spacing = 6 * scale;
    if (count && width < count * 54 * buttonScale + count * spacing + 80 * scale) hideText = YES;
    CGFloat buttonWidth = (hideText ? 30 : 54) * buttonScale;
    if (count) buttonWidth = MIN(buttonWidth, MAX(16 * scale, (width - 40 * scale - spacing * count) / count));
    return (WCGestureMomentsFeedActionMetrics){buttonWidth, 32 * buttonScale,
        count ? count * buttonWidth + (count - 1) * spacing : 0, spacing, hideText};
}
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
static BOOL WCFeedOwnPost(id item) {
    NSString *account = WCCurrentUserWXID();
    return account.length && [WCFeedText(WCTweakSafeValue(item, @"username")) isEqualToString:account];
}
static BOOL WCFeedActionsAvailable(UIView *cell, id item, id context) {
    if (!WCFeedPost(item) || !WCFeedHas(cell, @"onAccessibilityLike", 0) || !WCFeedHas(cell, @"onAccessibilityComment", 0)) return NO;
    if (WCFeedCanOperate(item, context)) return YES;
    // Owner-only native controls can occupy the native More slot. Keep native
    // action handlers available for a published own post, independently of More.hidden.
    UIView *deleteButton = WCFeedView(cell, @"m_deleteButton");
    return WCFeedOwnPost(item) && [WCTweakSafeValue(WCTweakSafeValue(cell, @"actionAreaVM"), @"canShowDeleteButton") boolValue] &&
        deleteButton.superview == cell && !deleteButton.hidden && deleteButton.alpha >= .01;
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
        if (!table.window) {
            if ([cache isKindOfClass:NSMutableDictionary.class]) [cache removeAllObjects];
            objc_setAssociatedObject(target, &WCFeedNeedsRefreshKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(target, &WCFeedRefreshKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
        }
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

// A layout measurement must not reload/rebind the cells that own its row records.
static void WCFeedRemeasureAttempt(UIViewController *controller, NSUInteger attempts) {
    if (!NSThread.isMainThread || !WCFeedControllerSupported(controller) ||
        [objc_getAssociatedObject(controller, &WCFeedRemeasureKey) boolValue]) return;
    objc_setAssociatedObject(controller, &WCFeedRemeasureKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *target = weakController;
        if (!target) return;
        id value = WCTweakSafeValue(target, @"tableView");
        if (![value isKindOfClass:UITableView.class]) {
            objc_setAssociatedObject(target, &WCFeedRemeasureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
        }
        UITableView *table = value;
        if (!table.window) {
            objc_setAssociatedObject(target, &WCFeedRemeasureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return;
        }
        if (table.dragging || table.decelerating || table.tracking) {
            // One pending request per controller; do not invalidate row geometry mid-fling.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIViewController *retry = weakController;
                if (!retry) return;
                objc_setAssociatedObject(retry, &WCFeedRemeasureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                WCFeedRemeasureAttempt(retry, attempts);
            });
            return;
        }
        if (table.hasUncommittedUpdates) {
            if (attempts) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIViewController *retry = weakController;
                if (!retry) return;
                objc_setAssociatedObject(retry, &WCFeedRemeasureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                WCFeedRemeasureAttempt(retry, attempts - 1);
            });
            else objc_setAssociatedObject(target, &WCFeedRemeasureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        id cache = WCTweakSafeValue(target, @"cellHeightCache");
        if ([cache isKindOfClass:NSMutableDictionary.class]) [cache removeAllObjects];
        [UIView performWithoutAnimation:^{
            [table beginUpdates]; [table endUpdates]; [table layoutIfNeeded];
        }];
        objc_setAssociatedObject(target, &WCFeedRemeasureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UITableViewCell *wrapper in table.visibleCells) {
            for (UIView *view in wrapper.contentView.subviews) {
                Class cls = NSClassFromString(@"WCTimeLineCellView");
                if (cls && [view isKindOfClass:cls]) [view setNeedsLayout];
            }
        }
    });
}
static void WCFeedRemeasure(UIViewController *controller) { WCFeedRemeasureAttempt(controller, 5); }

static NSMutableDictionary<NSIndexPath *, WCFeedPlan *> *WCFeedRows(UIViewController *controller) {
    NSMutableDictionary *rows = objc_getAssociatedObject(controller, &WCFeedRowsKey);
    if (!rows) {
        rows = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(controller, &WCFeedRowsKey, rows, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return rows;
}
static NSIndexPath *WCFeedItemIndexPath(UIViewController *controller, id item) {
    if (!WCFeedHas(controller, @"indexPathOfDataItem:", 1)) return nil;
    id path = ((id (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"indexPathOfDataItem:"), item);
    return [path isKindOfClass:NSIndexPath.class] ? path : nil;
}
static void WCFeedSetContentHeight(UIView *cell, CGFloat height) {
    // Extending the hit-test bounds must not move native labels/media through
    // flexible-top autoresizing masks after we have placed the metadata.
    [UIView performWithoutAnimation:^{
        BOOL autoresizes = cell.autoresizesSubviews;
        cell.autoresizesSubviews = NO;
        CGRect frame = cell.frame; frame.size.height = height; cell.frame = frame;
        cell.autoresizesSubviews = autoresizes;
    }];
}
double WCGestureMomentsFeedRowHeight(UIViewController *controller, UITableView *table, NSIndexPath *path, double original) {
    if (!NSThread.isMainThread || !WCFeedControllerSupported(controller) || !isfinite(original) || original <= 0 ||
        ![table isKindOfClass:UITableView.class] || ![path isKindOfClass:NSIndexPath.class] ||
        WCTweakSafeValue(controller, @"tableView") != table) return original;
    WCFeedPlan *plan = [objc_getAssociatedObject(controller, &WCFeedRowsKey) objectForKey:path];
    id item = plan.item;
    if (!item || !WCFeedEnabledForItem(item, controller) || !WCFeedPost(item) ||
        ![plan.account isEqualToString:WCCurrentUserWXID() ?: @""] ||
        ![plan.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))] ||
        fabs(plan.rowWidth - table.bounds.size.width) > .5) return original;
    // Prefer the real visible wrapper binding. An item-index lookup can be unavailable
    // while native caches are being updated even though this cell still owns the post.
    NSIndexPath *current = nil;
    if (plan.contentView.window && plan.wrapper &&
        WCTweakSafeValue(plan.contentView, @"m_dataItem") == item &&
        [plan.contentView isDescendantOfView:plan.wrapper.contentView]) current = [table indexPathForCell:plan.wrapper];
    if (!current) current = WCFeedItemIndexPath(controller, item);
    if (!current) {
        // Detail pages have a single data item; validate it rather than assuming row zero.
        id detailItem = WCTweakSafeValue(controller, @"m_dataItem") ?: WCTweakSafeValue(controller, @"dataItem");
        if (WCFeedTimeline(controller) || detailItem != item) return original;
    } else if (![current isEqual:path]) return original;
    return MAX(original, plan.rowHeight);
}
id WCGestureMomentsFeedCachedHeight(UIViewController *controller, id item, id original) {
    if (WCFeedHeightDepth || !NSThread.isMainThread || !WCFeedControllerSupported(controller) ||
        ![original isKindOfClass:NSNumber.class] || !WCFeedPost(item) || !WCFeedEnabledForItem(item, controller)) return original;
    double height = [original doubleValue];
    if (!isfinite(height) || height <= 0) return original;
    id table = WCTweakSafeValue(controller, @"tableView");
    if (![table isKindOfClass:UITableView.class]) return original;
    NSDictionary *rows = objc_getAssociatedObject(controller, &WCFeedRowsKey);
    NSString *tid = WCFeedText(WCTweakSafeValue(item, @"tid"));
    NSString *account = WCCurrentUserWXID() ?: @"";
    CGFloat width = ((UITableView *)table).bounds.size.width;
    for (NSIndexPath *path in rows) {
        WCFeedPlan *plan = rows[path];
        if (plan.item && [plan.tid isEqualToString:WCFeedText(WCTweakSafeValue(plan.item, @"tid"))] &&
            [plan.tid isEqualToString:tid] && [plan.account isEqualToString:account] &&
            fabs(plan.rowWidth - width) <= .5 && plan.rowHeight > height)
            height = plan.rowHeight;
    }
    return height > [original doubleValue] ? @(height) : original;
}
static void WCFeedUpdateRowHeight(UIView *cell, UIViewController *controller, id item, id model, WCFeedPlan *plan, CGFloat bottom) {
    UITableViewCell *wrapper = nil;
    for (UIView *view = cell.superview; view; view = view.superview)
        if ([view isKindOfClass:UITableViewCell.class]) { wrapper = (UITableViewCell *)view; break; }
    id value = WCTweakSafeValue(controller, @"tableView");
    if (!wrapper || ![value isKindOfClass:UITableView.class]) return;
    UITableView *table = value;
    NSIndexPath *path = [table indexPathForCell:wrapper] ?: WCFeedItemIndexPath(controller, item);
    if (!path) return;
    CGFloat required = [cell convertPoint:CGPointMake(0, bottom) toView:wrapper.contentView].y;
    if (!isfinite(required) || required <= 0 || required > 10000) return;
    NSMutableDictionary *rows = WCFeedRows(controller);
    BOOL changed = rows[path] != plan || fabs(plan.rowHeight - required) > .5 || fabs(plan.rowWidth - table.bounds.size.width) > .5;
    plan.item = item; plan.model = model; plan.contentView = cell; plan.wrapper = wrapper;
    plan.account = WCCurrentUserWXID() ?: @"";
    plan.rowHeight = required; plan.rowWidth = table.bounds.size.width; rows[path] = plan;
    BOOL exceedsRow = required > wrapper.contentView.bounds.size.height + .5;
    if (changed && exceedsRow) WCFeedRemeasure(controller);
    WCFeedState *state = objc_getAssociatedObject(cell, &WCFeedStateKey);
    if (!exceedsRow && CGAffineTransformIsIdentity(cell.transform)) {
        CGFloat current = cell.frame.size.height;
        if (state.resizedContent && fabs(current - state.appliedContentHeight) > .5) state.resizedContent = NO;
        if (!state.resizedContent && bottom > current + .5) {
            state.originalContentHeight = current; state.resizedContent = YES;
        }
        if (state.resizedContent) {
            CGFloat height = MAX(state.originalContentHeight, ceil(bottom));
            state.appliedContentHeight = height;
            if (fabs(current - height) > .5) WCFeedSetContentHeight(cell, height);
        }
    }
    if (exceedsRow || bottom > cell.bounds.size.height + .5) {
        // Never draw custom metadata over the next comment/post while the table remeasures.
        for (WCFeedViewState *saved in state.views) {
            UIView *view = saved.view; view.frame = saved.frame; view.hidden = saved.hidden;
            if ([view isKindOfClass:UILabel.class]) {
                ((UILabel *)view).numberOfLines = saved.lines; ((UILabel *)view).lineBreakMode = saved.lineBreak;
            }
        }
        [state.views removeAllObjects]; state.footer.hidden = YES; state.actionsAvailable = NO;
    }
}

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
    BOOL actions = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedActionsKey) && (WCFeedCanOperate(item, context) ||
        (WCFeedOwnPost(item) && [WCTweakSafeValue(model, @"canShowDeleteButton") boolValue]));
    BOOL hideText = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedHideActionTextKey);
    NSUInteger count = (actions ? 2 : 0) + (forward ? 1 : 0);
    WCGestureMomentsFeedActionMetrics metrics = WCGestureMomentsFeedResolveActionMetrics(width, count, hideText);
    hideText = metrics.hidesText;
    CGFloat controlsWidth = metrics.totalWidth > 0 ? metrics.totalWidth + metrics.spacing : 0;
    CGFloat timeExtra = feedEnabled ? MAX(0, MAX(count ? metrics.buttonHeight : 0,
        WCFeedHeight(time, font, MAX(40 * scale, width - controlsWidth))) - ceil(font.lineHeight)) : 0;
    BOOL ownControls = feedEnabled && [WCTweakSafeValue(model, @"canShowDeleteButton") boolValue];
    CGFloat extra = (feedEnabled ? MAX(12 * scale, WCFeedSpacing()) + 15 * scale : 0) + timeExtra +
        (location.length ? MAX(0, WCFeedHeight(location, font, width) - ceil(font.lineHeight)) + 6 * scale : 0) +
        (ownControls ? 24 * scale : 0) + (!feedEnabled && forward ? metrics.buttonHeight + 6 * scale : 0);
    if (!isfinite(extra) || extra > 4096) return nil;
    NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%.2f|%@|%.2f|%.2f|%d|%d|%.2f|%d|%d|%d|%d|%.3f",
        WCFeedText(WCTweakSafeValue(item, @"tid")), time, location, width, font.fontName, font.pointSize,
        scale, fullLocation, actions, WCFeedSpacing(), feedEnabled, forward, hideText, ownControls, WCFeedButtonScale()];
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
    BOOL sameItem = item == state.item &&
        [state.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))] &&
        [state.account isEqualToString:WCCurrentUserWXID() ?: @""];
    BOOL sameContent = sameItem && state.model == WCTweakSafeValue(cell, @"actionAreaVM");
    // If native code already rebound the cell, old snapshots belong to the old
    // post. Restoring them here would resurrect its location/visibility.
    [UIView performWithoutAnimation:^{
    for (WCFeedViewState *saved in (sameContent ? state.views : @[])) {
        UIView *view = saved.view;
        if (!CGRectEqualToRect(view.frame, saved.frame)) view.frame = saved.frame;
        if (view.hidden != saved.hidden) view.hidden = saved.hidden;
        if ([view isKindOfClass:UILabel.class]) {
            if (((UILabel *)view).numberOfLines != saved.lines) ((UILabel *)view).numberOfLines = saved.lines;
            if (((UILabel *)view).lineBreakMode != saved.lineBreak) ((UILabel *)view).lineBreakMode = saved.lineBreak;
        }
    }
    [state.views removeAllObjects];
    state.footer.hidden = YES;
    state.actionsAvailable = NO;
    // Native layout must start with native bounds, not our previous extension.
    if (sameItem && state.resizedContent && CGAffineTransformIsIdentity(cell.transform) &&
        fabs(cell.frame.size.height - state.appliedContentHeight) < .5)
        WCFeedSetContentHeight(cell, state.originalContentHeight);
    state.resizedContent = NO;
    }];
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
@interface WCFeedActionButton : UIButton
@end
@implementation WCFeedActionButton
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat scale = WCFeedScale();
    BOOL hasText = self.currentTitle.length > 0;
    CGFloat buttonScale = WCFeedButtonScale();
    CGFloat iconBox = MIN(16 * buttonScale, MAX(0, self.bounds.size.width - 4 * scale)), gap = hasText ? 4 * buttonScale : 0;
    CGFloat textWidth = hasText ? ceil([self.currentTitle sizeWithAttributes:@{NSFontAttributeName:self.titleLabel.font}].width) : 0;
    textWidth = MIN(textWidth, MAX(0, self.bounds.size.width - iconBox - gap - 4 * scale));
    CGFloat groupWidth = iconBox + gap + textWidth;
    CGFloat x = MAX(0, (self.bounds.size.width - groupWidth) / 2);
    CGSize size = self.currentImage.size;
    CGFloat factor = size.width > 0 && size.height > 0 ? MIN(iconBox / size.height, iconBox / size.width) : 0;
    CGSize imageSize = CGSizeMake(size.width * factor, size.height * factor);
    self.imageView.frame = CGRectMake(x + (iconBox - imageSize.width) / 2,
        (self.bounds.size.height - imageSize.height) / 2, imageSize.width, imageSize.height);
    self.titleLabel.hidden = !hasText; self.titleLabel.textAlignment = NSTextAlignmentLeft;
    CGFloat labelHeight = hasText ? ceil(self.titleLabel.font.lineHeight) : 0;
    self.titleLabel.frame = CGRectMake(x + iconBox + gap, (self.bounds.size.height - labelHeight) / 2, textWidth, labelHeight);
}
@end
void WCGestureConfigureMomentsFeedButton(UIButton *button, NSString *title, NSString *symbol, BOOL hideText) {
    CGFloat scale = WCFeedButtonScale();
    UIUserInterfaceStyle style = button.traitCollection.userInterfaceStyle;
    UIAccessibilityContrast contrast = button.traitCollection.accessibilityContrast;
    NSDictionary *old = objc_getAssociatedObject(button, &WCFeedButtonStyleKey);
    if ([old[@"title"] isEqualToString:title] && [old[@"symbol"] isEqualToString:symbol] &&
        [old[@"hidden"] boolValue] == hideText && fabs([old[@"scale"] doubleValue] - scale) < .0001 &&
        [old[@"style"] integerValue] == style && [old[@"contrast"] integerValue] == contrast) return;
    objc_setAssociatedObject(button, &WCFeedButtonStyleKey, @{@"title":title,@"symbol":symbol,@"hidden":@(hideText),
        @"scale":@(scale),@"style":@(style),@"contrast":@(contrast)}, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIColor *color = [UIColor.labelColor resolvedColorWithTraitCollection:button.traitCollection];
    UIImage *icon = [UIImage systemImageNamed:symbol withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:16 * WCFeedButtonScale() weight:UIImageSymbolWeightRegular]];
    icon = [icon imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    for (NSNumber *value in @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateSelected), @(UIControlStateDisabled)]) {
        UIControlState state = value.unsignedIntegerValue;
        [button setTitle:hideText ? nil : title forState:state]; [button setTitleColor:color forState:state];
        [button setImage:icon forState:state];
    }
    button.tintColor = color; button.titleLabel.font = [UIFont systemFontOfSize:13 * WCFeedButtonScale()];
    button.accessibilityLabel = title; [button setNeedsLayout];
}
UIButton *WCGestureCreateMomentsFeedButton(NSString *title, NSString *symbol) {
    UIButton *button = [[WCFeedActionButton alloc] initWithFrame:CGRectZero];
    WCGestureConfigureMomentsFeedButton(button, title, symbol, NO); return button;
}
static WCFeedState *WCFeedCreateState(UIView *cell) {
    WCFeedState *state = [WCFeedState new]; state.views = [NSMutableArray array];
    state.footer = [UIView new]; state.footer.backgroundColor = UIColor.clearColor; state.footer.hidden = YES;
    state.like = WCGestureCreateMomentsFeedButton(@"点赞", @"heart"); state.comment = WCGestureCreateMomentsFeedButton(@"评论", @"text.bubble");
    state.forward = WCGestureCreateMomentsFeedButton(@"转发", @"arrow.turn.up.right");
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
            if (!WCGestureEnabled(WCGestureMomentsFeedActionsKey) || !WCFeedHas(target, selector, 0) ||
                !current.actionsAvailable || !WCFeedActionsAvailable(target, current.item, WCTweakSafeValue(target, @"pageContext"))) return;
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
    if (cell.window && [objc_getAssociatedObject(controller, &WCFeedNeedsRefreshKey) boolValue]) {
        objc_setAssociatedObject(controller, &WCFeedNeedsRefreshKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCFeedRefresh(controller);
    }
    if (!cell.window || !WCFeedEnabledForItem(item, controller) || !WCFeedControllerSupported(controller) ||
        !WCFeedPost(item)) { WCGestureMomentsFeedReset(cell); return; }
    WCFeedBindController(context, item, controller);
    WCFeedPlan *plan = objc_getAssociatedObject(model ?: item, &WCFeedPlanKey);
    if (!plan) plan = objc_getAssociatedObject(item, &WCFeedPlanKey);
    if (!plan || plan.controller != controller || !plan.nativeHeight ||
        ![plan.tid isEqualToString:WCFeedText(WCTweakSafeValue(item, @"tid"))]) {
        plan = WCFeedRecoverPlan(cell, item, context, model, controller);
        if (!plan) { WCGestureMomentsFeedReset(cell); return; }
        WCFeedRemeasure(controller);
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
    [UIView performWithoutAnimation:^{
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
        BOOL actions = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedActionsKey) && WCFeedActionsAvailable(cell, item, context);
        UIView *location = WCFeedView(cell, @"m_locationLabel"), *individual = WCFeedView(cell, @"m_individualLocationLabel");
        UILabel *wrappedLocation = nil;
        if (fullLocation && WCFeedLocationText(item, model).length)
            for (UIView *label in @[location ?: [UIView new], individual ?: [UIView new]])
                if (label.superview == cell && [label isKindOfClass:UILabel.class] &&
                    !label.hidden && ((UILabel *)label).text.length) {
                    wrappedLocation = (UILabel *)label; break;
                }
        CGFloat width = right - left;
        BOOL hideText = feedEnabled && WCGestureEnabled(WCGestureMomentsFeedHideActionTextKey);
        state.like.hidden = state.comment.hidden = !actions; state.forward.hidden = !forward;
        state.actionsAvailable = actions;
        NSArray<UIButton *> *buttons = actions ? (forward ? @[state.like, state.comment, state.forward] : @[state.like, state.comment]) : (forward ? @[state.forward] : @[]);
        CGFloat actionRight = right;
        if (feedEnabled && !actions && operate.superview == cell && !operate.hidden)
            actionRight = MIN(right, CGRectGetMinX(operate.frame) - spacing);
        CGFloat actionWidth = MAX(40 * scale, actionRight - left);
        WCGestureMomentsFeedActionMetrics metrics = WCGestureMomentsFeedResolveActionMetrics(actionWidth, buttons.count, hideText);
        hideText = metrics.hidesText;
        BOOL liked = [WCTweakSafeValue(item, @"likeFlag") boolValue];
        WCGestureConfigureMomentsFeedButton(state.like, liked ? @"已赞" : @"点赞", liked ? @"heart.fill" : @"heart", hideText);
        WCGestureConfigureMomentsFeedButton(state.comment, @"评论", @"text.bubble", hideText);
        WCGestureConfigureMomentsFeedButton(state.forward, @"转发", @"arrow.turn.up.right", hideText);
        state.like.accessibilityLabel = liked ? @"取消点赞" : @"点赞";
        CGFloat buttonWidth = metrics.buttonWidth, buttonHeight = metrics.buttonHeight, buttonsWidth = metrics.totalWidth;
        UIView *privacy = WCFeedView(cell, @"m_privacyButton"), *delete = WCFeedView(cell, @"m_deleteButton");
        NSMutableArray<UIView *> *ownButtons = [NSMutableArray array];
        if (feedEnabled) for (UIView *view in @[privacy ?: [UIView new], delete ?: [UIView new]])
            if (view.superview == cell && !view.hidden && view.alpha >= .01 && !CGRectIsEmpty(view.frame)) [ownButtons addObject:view];

        CGFloat bottom = CGRectGetMaxY(time.frame);
        if (feedEnabled) {
            // Keep the metadata attached to the real body, independently of an inflated child frame.
            CGFloat bodyBottom = 0;
            for (NSString *key in @[@"m_headImage", @"m_nickLabel", @"contentDescView", @"m_contentDescView", @"m_mediaView",
                @"m_showFullTextView", @"translateView", @"m_translateView", @"m_translateLineView", @"m_translateStatusView", @"m_openIMDescLabel"] ) {
                UIView *view = WCFeedView(cell, key);
                if (view.superview == cell && !view.hidden && view.alpha >= .01 && !CGRectIsEmpty(view.frame)) bodyBottom = MAX(bodyBottom, CGRectGetMaxY(view.frame));
            }
            CGFloat cursor = bodyBottom > 0 ? bodyBottom + 22 * scale : time.frame.origin.y + 15 * scale;
            // Preserve native source/music/app/location views and their actions, arranged above the time row.
            NSMutableArray<UIView *> *metadata = [NSMutableArray array];
            for (NSString *key in @[@"m_sourceLabel", @"m_individualSourceLabel", @"m_weAppView", @"m_individualWeAppView",
                @"m_actionLabel", @"m_musicLabel", @"m_locationLabel", @"m_individualLocationLabel", @"ecsView", @"m_errTipsView"]) {
                UIView *view = WCFeedView(cell, key);
                if (view.superview == cell && !view.hidden && view.alpha >= .01 && !CGRectIsEmpty(view.frame) && ![metadata containsObject:view]) [metadata addObject:view];
            }
            [metadata sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
                if (fabs(a.frame.origin.y - b.frame.origin.y) > .5) return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
                if (fabs(a.frame.origin.x - b.frame.origin.x) < .5) return NSOrderedSame;
                return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
            }];
            for (UIView *view in metadata) {
                WCFeedSave(state, view); CGFloat height = view.bounds.size.height;
                if (view == wrappedLocation) {
                    wrappedLocation.numberOfLines = 0; wrappedLocation.lineBreakMode = NSLineBreakByWordWrapping;
                    height = ceil(MAX(wrappedLocation.font.lineHeight, [wrappedLocation sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height));
                }
                CGFloat viewWidth = view == wrappedLocation ? width : MIN(width, view.bounds.size.width);
                view.frame = CGRectMake(left, cursor, viewWidth, height); cursor = CGRectGetMaxY(view.frame) + spacing;
            }
            if (ownButtons.count) {
                CGFloat x = left, ownHeight = 0;
                for (UIView *view in ownButtons) {
                    WCFeedSave(state, view); CGRect frame = view.frame;
                    frame.origin = CGPointMake(x, cursor); view.frame = frame;
                    x += frame.size.width + 12 * scale; ownHeight = MAX(ownHeight, frame.size.height);
                }
                cursor += ownHeight + spacing;
            }
            CGFloat top = cursor;
            CGFloat available = actionWidth - (buttonsWidth > 0 ? buttonsWidth + spacing : 0);
            if (available < 40 * scale) return;
            CGFloat timeHeight = MAX(time.font.lineHeight, WCFeedHeight(time.text ?: @"", time.font, available));
            CGFloat iconCenter = buttonHeight / 2;
            CGFloat anchor = buttons.count ? MAX(timeHeight / 2, iconCenter) : timeHeight / 2;
            WCFeedSave(state, time); time.numberOfLines = 0; time.lineBreakMode = NSLineBreakByWordWrapping;
            time.frame = CGRectMake(left, top + anchor - timeHeight / 2, available, timeHeight);
            state.footer.frame = CGRectMake(actionRight - buttonsWidth, top + anchor - iconCenter, buttonsWidth, buttonHeight);
            if (!actions && operate.superview == cell && !operate.hidden) {
                WCFeedSave(state, operate); CGRect frame = operate.frame;
                frame.origin.y = top + anchor - frame.size.height / 2; operate.frame = frame;
            }
            bottom = MAX(CGRectGetMaxY(time.frame), buttons.count ? CGRectGetMaxY(state.footer.frame) : 0);
        } else {
            // Forwarding can also be enabled without timeline restyling (including the detail page).
            for (UIView *view in cell.subviews) if (view != state.footer && !view.hidden && view.alpha >= .01 && !CGRectIsEmpty(view.frame))
                bottom = MAX(bottom, CGRectGetMaxY(view.frame));
            state.footer.frame = CGRectMake(right - buttonsWidth, bottom + spacing, buttonsWidth, buttonHeight);
            bottom += buttons.count ? spacing + buttonHeight : 0;
        }
        CGFloat x = 0;
        for (UIButton *button in buttons) { button.frame = CGRectMake(x, 0, buttonWidth, buttonHeight); x += buttonWidth + spacing; }
        state.footer.hidden = buttons.count == 0;
        if (actions) { WCFeedSave(state, operate); operate.hidden = YES; }
        CGFloat padding = feedEnabled ? MAX(12 * scale, WCFeedSpacing()) : 6 * scale;
        CGFloat requiredBottom = bottom + padding;
        CGFloat needed = MAX(0, requiredBottom - plan.nativeHeight);
        if (isfinite(needed) && needed <= 4096 && needed > WCFeedExtra(plan) + .5) {
            // Retain the estimate for future native measurements. Only an actual
            // row-size deficit below should request a new table measurement.
            plan.observedExtra = needed;
        }
        WCFeedUpdateRowHeight(cell, controller, item, model, plan, requiredBottom);
    } @finally { state.updating = NO; }
    }];
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
    for (UIViewController *controller in WCFeedControllers().allObjects) {
        objc_setAssociatedObject(controller, &WCFeedRowsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCFeedRefresh(controller);
    }
}
