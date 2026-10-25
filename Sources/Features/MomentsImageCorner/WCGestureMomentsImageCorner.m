#import <math.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

static char WCMomentsCornerStateKey, WCMomentsCornerTargetsKey, WCMomentsCornerBusyKey;
static CGFloat WCMomentsCornerResolvedRadius(CGSize size, double requested) {
    CGFloat side = MIN(size.width, size.height);
    if (!isfinite(side) || side <= 0) return 0;
    CGFloat radius = isfinite(requested) ? MIN(40, MAX(0, requested)) : 8;
    return MIN(radius, side * 0.5);
}

static NSHashTable<UIView *> *WCMomentsCornerRoots(void) {
    static NSHashTable *roots; static dispatch_once_t once;
    dispatch_once(&once, ^{ roots = [NSHashTable weakObjectsHashTable]; }); return roots;
}

static void WCMomentsCornerRestore(UIView *view) {
    NSDictionary *state = objc_getAssociatedObject(view, &WCMomentsCornerStateKey);
    if (!state) return;
    view.layer.cornerRadius = [state[@"radius"] doubleValue];
    view.layer.masksToBounds = [state[@"clips"] boolValue];
    view.layer.cornerCurve = state[@"curve"];
    objc_setAssociatedObject(view, &WCMomentsCornerStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void WCGestureMomentsImageCornerReset(UIView *root) {
    NSHashTable *previous = objc_getAssociatedObject(root, &WCMomentsCornerTargetsKey);
    for (UIView *target in previous.allObjects) WCMomentsCornerRestore(target);
    objc_setAssociatedObject(root, &WCMomentsCornerTargetsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL WCMomentsCornerIsPicture(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    // Scope matching to known picture classes under a Moments root, not all
    // UIImageViews. In particular, avatars, badges and text blocks are excluded.
    return [name isEqualToString:@"WCImageView"] || [name isEqualToString:@"MMWebImageView"] ||
           [name isEqualToString:@"WCPuzzleImageView"];
}

static BOOL WCMomentsCornerSkipBranch(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    return [name containsString:@"HeadImage"] || [name containsString:@"Avatar"] ||
           [view isKindOfClass:UILabel.class] || [view isKindOfClass:UIButton.class];
}

static void WCMomentsCornerWalk(UIView *view, CGFloat radius, NSUInteger depth, NSUInteger *remaining, NSHashTable *targets) {
    if (depth > 10 || !*remaining || WCMomentsCornerSkipBranch(view)) return;
    (*remaining)--;
    if (WCMomentsCornerIsPicture(view)) {
        CGFloat side = MIN(CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds));
        if (side <= 0 || !isfinite(side)) return;
        if (!objc_getAssociatedObject(view, &WCMomentsCornerStateKey)) {
            NSDictionary *state = @{ @"radius": @(view.layer.cornerRadius), @"clips": @(view.layer.masksToBounds),
                                     @"curve": view.layer.cornerCurve ?: kCACornerCurveCircular };
            objc_setAssociatedObject(view, &WCMomentsCornerStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGFloat resolved = WCMomentsCornerResolvedRadius(view.bounds.size, radius);
        if (fabs(view.layer.cornerRadius - resolved) > 0.01) view.layer.cornerRadius = resolved;
        if (![view.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) view.layer.cornerCurve = kCACornerCurveContinuous;
        if (!view.layer.masksToBounds) view.layer.masksToBounds = YES;
        [targets addObject:view];
        // Clip a puzzle as one image; never round its internal tiles separately.
        return;
    }
    for (UIView *child in view.subviews) WCMomentsCornerWalk(child, radius, depth + 1, remaining, targets);
}

void WCGestureMomentsImageCornerLayout(UIView *root) {
    if ([objc_getAssociatedObject(root, &WCMomentsCornerBusyKey) boolValue]) return;
    [WCMomentsCornerRoots() addObject:root];
    if (!WCGestureEnabled(WCGestureMomentsImageCornerEnabledKey)) { WCGestureMomentsImageCornerReset(root); return; }
    objc_setAssociatedObject(root, &WCMomentsCornerBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        double value = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMomentsImageCornerRadiusKey];
        CGFloat radius = isfinite(value) ? MIN(40, MAX(0, value)) : 8;
        NSHashTable *targets = [NSHashTable weakObjectsHashTable];
        NSUInteger remaining = 400;
        WCMomentsCornerWalk(root, radius, 0, &remaining, targets);
        NSHashTable *previous = objc_getAssociatedObject(root, &WCMomentsCornerTargetsKey);
        for (UIView *old in previous.allObjects) if (![targets containsObject:old]) WCMomentsCornerRestore(old);
        objc_setAssociatedObject(root, &WCMomentsCornerTargetsKey, targets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally {
        objc_setAssociatedObject(root, &WCMomentsCornerBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void WCGestureMomentsImageCornerSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.moments.image-corner."]) return;
    for (UIView *root in WCMomentsCornerRoots().allObjects) {
        WCGestureMomentsImageCornerReset(root);
        if (root.window) { [root setNeedsLayout]; WCGestureMomentsImageCornerLayout(root); }
    }
}
