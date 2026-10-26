#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCMediaCornerState : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) BOOL clips;
@property (nonatomic, copy) CALayerCornerCurve curve;
@property (nonatomic, assign) CACornerMask corners;
@end
@implementation WCMediaCornerState
@end
static char WCMediaCornerStateKey, WCMediaCornerPendingKey;
static NSHashTable<UIView *> *WCMediaCornerViews(void) {
    static NSHashTable *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}
void WCGestureMediaCornerApply(UIView *view, NSString *enabledKey, NSString *radiusKey, BOOL eligible) {
    if (eligible) [WCMediaCornerViews() addObject:view];
    WCMediaCornerState *state = objc_getAssociatedObject(view, &WCMediaCornerStateKey);
    if (!eligible || !view.window || !WCGestureEnabled(enabledKey)) {
        if (!state || ![state.key isEqualToString:enabledKey]) return;
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        view.layer.cornerRadius = state.radius; view.layer.masksToBounds = state.clips;
        view.layer.cornerCurve = state.curve; view.layer.maskedCorners = state.corners;
        [CATransaction commit];
        objc_setAssociatedObject(view, &WCMediaCornerStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    CGFloat side = MIN(CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds));
    if (!isfinite(side) || side <= 0) return;
    if (!state) {
        state = [WCMediaCornerState new]; state.radius = view.layer.cornerRadius;
        state.clips = view.layer.masksToBounds; state.curve = view.layer.cornerCurve;
        state.corners = view.layer.maskedCorners;
        objc_setAssociatedObject(view, &WCMediaCornerStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    state.key = enabledKey; [WCMediaCornerViews() addObject:view];
    double requested = [NSUserDefaults.standardUserDefaults doubleForKey:radiusKey];
    CGFloat radius = MIN(side / 2, isfinite(requested) ? MIN(40, MAX(0, requested)) : 8);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (fabs(view.layer.cornerRadius - radius) > 0.01) view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous; view.layer.masksToBounds = YES;
    view.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [CATransaction commit];
}
static void WCMediaCornerRefresh(UIView *view) {
    WCGestureEmoticonCornerLayout(view);
    WCGestureChatImageCornerLayout(view);
}
void WCGestureMediaCornerReset(UIView *root) {
    for (UIView *view in WCMediaCornerViews().allObjects) {
        if (view != root && ![view isDescendantOfView:root]) continue;
        WCMediaCornerState *state = objc_getAssociatedObject(view, &WCMediaCornerStateKey);
        if (state) WCGestureMediaCornerApply(view, state.key, @"", NO);
    }
}
void WCGestureMediaCornerViewDidLayout(UIView *view) {
    if (!objc_getAssociatedObject(view, &WCMediaCornerStateKey) || objc_getAssociatedObject(view, &WCMediaCornerPendingKey)) return;
    objc_setAssociatedObject(view, &WCMediaCornerPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakView = view;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *target = weakView;
        if (!target) return;
        objc_setAssociatedObject(target, &WCMediaCornerPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCMediaCornerRefresh(target);
    });
}
void WCGestureMediaCornerSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key containsString:@".emoticon-corner."] && ![key containsString:@".chat-image-corner."]) return;
    for (UIView *view in WCMediaCornerViews().allObjects) WCMediaCornerRefresh(view);
}
