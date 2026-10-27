#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

static char WCForwardMenuKey;
@interface WCForwardMenuState : NSObject
@property (nonatomic, strong) id item;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, weak) UIView *container;
@property (nonatomic) CGRect baseFrame;
@property (nonatomic) CGRect baseContainerFrame;
@property (nonatomic) CGRect buttonFrame;
@property (nonatomic) CGFloat addedWidth;
@property (nonatomic, copy) NSArray<UIView *> *nativeViews;
@property (nonatomic, copy) NSArray<NSValue *> *nativeFrames;
@property (nonatomic, strong) CALayer *originalMask;
@property (nonatomic, strong) CAShapeLayer *expandedMask;
@property (nonatomic) BOOL captured;
@property (nonatomic) BOOL applying;
@end
@implementation WCForwardMenuState
@end
static NSHashTable *WCForwardMenus(void) {
    static NSHashTable *views; static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSHashTable weakObjectsHashTable]; }); return views;
}
static NSString *WCForwardMenuID(id item) {
    id value = WCTweakSafeValue(item, @"tid");
    return [value isKindOfClass:NSString.class] ? value : @"";
}
void WCGestureMomentsForwardMenuReset(UIView *view) {
    WCForwardMenuState *state = objc_getAssociatedObject(view, &WCForwardMenuKey);
    if (!state || state.applying) return;
    state.applying = YES;
    if (state.captured) {
        view.frame = state.baseFrame;
        if (state.container != view) state.container.frame = state.baseContainerFrame;
        for (NSUInteger i = 0; i < state.nativeViews.count; i++) state.nativeViews[i].frame = state.nativeFrames[i].CGRectValue;
        view.layer.mask = state.originalMask;
    }
    [state.button removeFromSuperview]; [state.separator removeFromSuperview];
    objc_setAssociatedObject(view, &WCForwardMenuKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void WCForwardMenuCapture(UIView *view, WCForwardMenuState *state, UIControl *anchor) {
    UIView *container = anchor.superview ?: view;
    CGFloat width = CGRectGetWidth(anchor.frame);
    if (width < 44) width = 72 * WCGestureLayoutScaleFactor();
    if (CGRectGetWidth(view.bounds) < 44 || CGRectGetWidth(container.bounds) < 44) return;
    state.baseFrame = view.frame; state.baseContainerFrame = container.frame;
    state.addedWidth = width; state.container = container; state.originalMask = view.layer.mask;
    NSMutableArray *views = [NSMutableArray array], *frames = [NSMutableArray array];
    // Include both levels: recent builds place the image background outside
    // m_clipView, while like/comment controls live inside it.
    NSArray *containers = container == view ? @[view] : @[view, container];
    for (UIView *parent in containers) for (UIView *child in parent.subviews) {
        if (child == state.button || child == state.separator || [views containsObject:child]) continue;
        [views addObject:child]; [frames addObject:[NSValue valueWithCGRect:child.frame]];
    }
    state.nativeViews = views; state.nativeFrames = frames;
    CGFloat height = MAX(24, CGRectGetHeight(anchor.frame));
    state.buttonFrame = CGRectMake(CGRectGetWidth(container.bounds), CGRectGetMinY(anchor.frame), width, height);
    state.expandedMask = [CAShapeLayer layer]; state.expandedMask.fillColor = UIColor.blackColor.CGColor;
    state.captured = YES;
}
void WCGestureMomentsForwardMenuLayout(UIView *view) {
    WCForwardMenuState *state = objc_getAssociatedObject(view, &WCForwardMenuKey);
    if (!state || state.applying) return;
    if (!WCGestureEnabled(WCGestureMomentsForwardEnabledKey)) {
        WCGestureMomentsForwardMenuReset(view); return;
    }
    // showWithItemData: can run before the menu enters its window. Keep the
    // item until native attachment/layout; hide itself owns final restoration.
    if (!view.window || view.hidden || [WCTweakSafeValue(view, @"isPerformHideAnimation") boolValue]) {
        state.button.hidden = YES; return;
    }
    id nativeItem = WCTweakSafeValue(view, @"m_item");
    if (nativeItem && nativeItem != state.item && ![WCForwardMenuID(nativeItem) isEqualToString:WCForwardMenuID(state.item)]) {
        WCGestureMomentsForwardMenuReset(view); return;
    }
    id candidate = WCTweakSafeValue(view, @"m_commentBtn") ?: WCTweakSafeValue(view, @"m_likeBtn");
    if (![candidate isKindOfClass:UIControl.class]) return;
    UIControl *anchor = candidate;
    state.applying = YES;
    @try {
        if (!state.captured) WCForwardMenuCapture(view, state, anchor);
        if (!state.captured || !state.container) return;
        state.button.hidden = NO;
        CGRect expanded = state.baseFrame; expanded.origin.x -= state.addedWidth; expanded.size.width += state.addedWidth;
        if (!CGRectEqualToRect(view.frame, expanded)) view.frame = expanded;
        if (state.container != view) {
            CGRect frame = state.baseContainerFrame; frame.size.width += state.addedWidth;
            state.container.frame = frame;
        }
        for (NSUInteger i = 0; i < state.nativeViews.count; i++) {
            UIView *child = state.nativeViews[i]; CGRect frame = state.nativeFrames[i].CGRectValue;
            CGFloat baseWidth = child.superview == view ? state.baseFrame.size.width : state.baseContainerFrame.size.width;
            if (child == state.container || (frame.origin.x <= 1 && frame.size.width >= baseWidth - 2))
                frame.size.width += state.addedWidth;
            if (!CGRectEqualToRect(child.frame, frame)) child.frame = frame;
        }
        UIButton *nativeButton = [anchor isKindOfClass:UIButton.class] ? (UIButton *)anchor : nil;
        UIColor *color = nativeButton.currentTitleColor ?: anchor.tintColor ?: UIColor.whiteColor;
        [state.button setTitleColor:color forState:UIControlStateNormal]; state.button.tintColor = color;
        state.button.titleLabel.font = [UIFont systemFontOfSize:12 * WCGestureLayoutScaleFactor()];
        [state.button setImage:[UIImage systemImageNamed:@"arrow.turn.up.right" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:14 * WCGestureLayoutScaleFactor() weight:UIImageSymbolWeightRegular]]
            forState:UIControlStateNormal];
        if (state.button.superview != state.container) {
            [state.container addSubview:state.separator]; [state.container addSubview:state.button];
        }
        state.button.frame = state.buttonFrame;
        state.separator.backgroundColor = [color colorWithAlphaComponent:.18];
        state.separator.frame = CGRectMake(state.buttonFrame.origin.x, state.buttonFrame.origin.y + 8,
            1 / UIScreen.mainScreen.scale, MAX(8, state.buttonFrame.size.height - 16));
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        state.expandedMask.frame = view.bounds;
        state.expandedMask.path = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
        view.layer.mask = state.expandedMask;
        [CATransaction commit];
        if (state.container.subviews.lastObject != state.button) [state.container bringSubviewToFront:state.button];
    } @finally { state.applying = NO; }
}
void WCGestureMomentsForwardMenuPrepare(UIView *view, id item) {
    if (!NSThread.isMainThread || !view || !item) return;
    [WCForwardMenus() addObject:view];
    WCGestureMomentsForwardMenuReset(view);
    if (!WCGestureEnabled(WCGestureMomentsForwardEnabledKey) || [WCTweakSafeValue(item, @"isAd") boolValue]) return;
    WCForwardMenuState *state = [WCForwardMenuState new]; state.item = item;
    WCRefreshCachedCurrentUser(); state.account = WCCurrentUserWXID() ?: @"";
    state.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [state.button setTitle:@"转发" forState:UIControlStateNormal]; state.button.accessibilityLabel = @"转发朋友圈";
    state.button.accessibilityIdentifier = @"onewx_moments_forward";
    state.separator = [UIView new]; state.separator.userInteractionEnabled = NO;
    __weak UIView *weakView = view; __weak WCForwardMenuState *weakState = state;
    [state.button addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        UIView *menu = weakView; WCForwardMenuState *current = weakState;
        if (!menu || !current || objc_getAssociatedObject(menu, &WCForwardMenuKey) != current ||
            !WCGestureEnabled(WCGestureMomentsForwardEnabledKey)) return;
        if (!WCRefreshCachedCurrentUser() || ![current.account isEqualToString:WCCurrentUserWXID() ?: @""]) return;
        id itemToForward = current.item;
        UIViewController *presenter = WCViewControllerForResponder(menu);
        id navigation = WCTweakSafeValue(menu, @"navigationController");
        if ([navigation isKindOfClass:UINavigationController.class]) presenter = [navigation visibleViewController] ?: presenter;
        if ([menu respondsToSelector:NSSelectorFromString(@"hide")])
            ((void (*)(id, SEL))objc_msgSend)(menu, NSSelectorFromString(@"hide"));
        if (!WCGestureMomentsForwardCanForward(itemToForward)) { WCShowToast(@"当前朋友圈类型暂不支持转发"); return; }
        if (presenter) WCGestureMomentsForwardPresent(itemToForward, presenter);
        else WCShowToast(@"当前页面无法打开朋友圈发布页");
    }] forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(view, &WCForwardMenuKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCGestureMomentsForwardMenuLayout(view);
}
void WCGestureMomentsForwardMenuSettingsChanged(void) {
    for (UIView *view in WCForwardMenus().allObjects) {
        id item = WCTweakSafeValue(view, @"m_item");
        WCGestureMomentsForwardMenuReset(view);
        if (view.window && !view.hidden && item) WCGestureMomentsForwardMenuPrepare(view, item);
    }
}
