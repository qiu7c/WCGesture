#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCPinnedGlassState : NSObject
@property (nonatomic, strong) UIView *glass;
@property (nonatomic, strong) NSMapTable<UIView *, id> *colors;
@property (nonatomic, copy) NSArray *layerValues;
@end
@implementation WCPinnedGlassState
@end
static char WCPinnedGlassKey, WCPinnedPendingKey;

static NSHashTable<UIView *> *WCPinnedViews(void) {
    static NSHashTable *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}
static void WCPinnedRestoreColors(UIView *view, WCPinnedGlassState *state, NSUInteger depth) {
    if (view == state.glass || depth > 10) return;
    id color = [state.colors objectForKey:view];
    if (color) { view.backgroundColor = color == NSNull.null ? nil : color; [state.colors removeObjectForKey:view]; }
    for (UIView *child in view.subviews) WCPinnedRestoreColors(child, state, depth + 1);
}
static void WCPinnedClearHeader(UIView *view, UIView *root, WCPinnedGlassState *state, CGFloat height, NSUInteger depth) {
    if (view == state.glass || [view isDescendantOfView:state.glass] || depth > 10) return;
    CGRect frame = [view convertRect:view.bounds toView:root];
    if (view != root && CGRectGetMinY(frame) >= CGRectGetMinY(root.bounds) + height) {
        WCPinnedRestoreColors(view, state, 0);
        return;
    }
    if (![state.colors objectForKey:view]) [state.colors setObject:view.backgroundColor ?: NSNull.null forKey:view];
    view.backgroundColor = UIColor.clearColor;
    for (UIView *child in view.subviews) WCPinnedClearHeader(child, root, state, height, depth + 1);
}
void WCGestureChatPinnedGlassApply(UIView *tips, BOOL enabled) {
    WCPinnedGlassState *state = objc_getAssociatedObject(tips, &WCPinnedGlassKey);
    if (!enabled) {
        if (!state) return;
        for (UIView *view in state.colors.keyEnumerator) {
            id color = [state.colors objectForKey:view]; view.backgroundColor = color == NSNull.null ? nil : color;
        }
        NSArray *saved = state.layerValues;
        tips.layer.shadowOpacity = [saved[0] floatValue]; tips.layer.shadowRadius = [saved[1] doubleValue];
        tips.layer.shadowOffset = [saved[2] CGSizeValue];
        tips.layer.shadowColor = saved[3] == NSNull.null ? nil : (__bridge CGColorRef)saved[3];
        tips.layer.borderWidth = [saved[4] doubleValue];
        tips.layer.borderColor = saved[5] == NSNull.null ? nil : (__bridge CGColorRef)saved[5];
        [state.glass removeFromSuperview];
        objc_setAssociatedObject(tips, &WCPinnedGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (CGRectIsEmpty(tips.bounds)) return;
    if (!state) {
        state = [WCPinnedGlassState new]; state.colors = [NSMapTable weakToStrongObjectsMapTable];
        state.layerValues = @[@(tips.layer.shadowOpacity), @(tips.layer.shadowRadius), [NSValue valueWithCGSize:tips.layer.shadowOffset],
            tips.layer.shadowColor ? (__bridge id)tips.layer.shadowColor : NSNull.null, @(tips.layer.borderWidth),
            tips.layer.borderColor ? (__bridge id)tips.layer.borderColor : NSNull.null];
        state.glass = WCGestureCreateChatGlassView();
        state.glass.translatesAutoresizingMaskIntoConstraints = YES; state.glass.userInteractionEnabled = NO;
        state.glass.clipsToBounds = YES;
        objc_setAssociatedObject(tips, &WCPinnedGlassKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    tips.layer.shadowOpacity = 0; tips.layer.shadowRadius = 0; tips.layer.shadowOffset = CGSizeZero;
    tips.layer.shadowColor = UIColor.clearColor.CGColor; tips.layer.borderWidth = 0; tips.layer.borderColor = UIColor.clearColor.CGColor;
    CGFloat scale = WCGestureChatTopBarScale();
    CGFloat height = MIN(CGRectGetHeight(tips.bounds), 40.0);
    // Match WCAtlas: frost only the fixed header, not the expanding pinned list.
    WCGestureConfigureChatPinnedGlass(state.glass);
    state.glass.frame = CGRectMake(CGRectGetMinX(tips.bounds) + 8 * scale, CGRectGetMinY(tips.bounds),
        MAX(0, CGRectGetWidth(tips.bounds) - 16 * scale), height);
    if (state.glass.superview != tips) [tips insertSubview:state.glass atIndex:0];
    else if (tips.subviews.firstObject != state.glass) [tips sendSubviewToBack:state.glass];
    WCPinnedClearHeader(tips, tips, state, height, 0);
    [CATransaction commit];
}
static BOOL WCPinnedEnabled(UIView *tips) {
    if (!tips.window || !WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey)) return NO;
    UIViewController *controller = WCViewControllerForResponder(tips);
    Class chatClass = NSClassFromString(@"BaseMsgContentViewController");
    for (; controller; controller = controller.parentViewController) {
        if (chatClass && [controller isKindOfClass:chatClass])
            return !WCGestureChatSearchIsActive(controller) && ![WCTweakSafeValue(controller, @"isMultiSelectMode") boolValue];
    }
    return NO;
}
void WCGestureChatPinnedLayout(UIView *tips) {
    [WCPinnedViews() addObject:tips];
    WCGestureChatPinnedGlassApply(tips, WCPinnedEnabled(tips));
    if (!tips.window || [objc_getAssociatedObject(tips, &WCPinnedPendingKey) boolValue]) return;
    objc_setAssociatedObject(tips, &WCPinnedPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakTips = tips;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *target = weakTips;
        if (!target) return;
        objc_setAssociatedObject(target, &WCPinnedPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCGestureChatPinnedGlassApply(target, WCPinnedEnabled(target));
    });
}
void WCGestureChatPinnedRefresh(void) {
    for (UIView *view in WCPinnedViews().allObjects) WCGestureChatPinnedLayout(view);
}
