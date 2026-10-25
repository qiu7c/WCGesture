#import <math.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

static char WCMomentsCornerStateKey, WCMomentsCornerTargetsKey, WCMomentsCornerBusyKey;
static char WCMomentsCornerProfileKey, WCMomentsCornerRegisteredKey, WCMomentsCornerPendingKey;

@interface WCMomentsCornerState : NSObject
@property (nonatomic, weak) UIView *owner;
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL clips;
@property (nonatomic, copy) CALayerCornerCurve curve;
@property (nonatomic) CACornerMask corners;
@end
@implementation WCMomentsCornerState
@end

static CGFloat WCMomentsCornerResolvedRadius(CGSize size, double requested) {
    CGFloat side = MIN(size.width, size.height);
    if (!isfinite(side) || side <= 0) return 0;
    CGFloat radius = isfinite(requested) ? MIN(40, MAX(0, requested)) : 8;
    return MIN(radius, side * 0.5);
}

static NSHashTable<UIView *> *WCMomentsCornerRoots(void) {
    static NSHashTable *roots;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ roots = [NSHashTable weakObjectsHashTable]; });
    return roots;
}

static BOOL WCMomentsCornerClass(UIView *view, NSString *name) {
    Class cls = NSClassFromString(name);
    return cls && [view isKindOfClass:cls];
}

static UIView *WCMomentsCornerRootForView(UIView *view) {
    UIView *grid = nil;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if (WCMomentsCornerClass(ancestor, @"WCTimeLineCellView")
            || WCMomentsCornerClass(ancestor, @"WCListBaseCellView")
            || [objc_getAssociatedObject(ancestor, &WCMomentsCornerProfileKey) boolValue]) return ancestor;
        if (!grid && WCMomentsCornerClass(ancestor, @"WCContentItemViewTemplateGrid")) grid = ancestor;
    }
    return grid;
}

static void WCMomentsCornerRestore(UIView *view, UIView *owner) {
    WCMomentsCornerState *state = objc_getAssociatedObject(view, &WCMomentsCornerStateKey);
    if (!state || (owner && state.owner != owner)) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.cornerRadius = state.radius;
    view.layer.masksToBounds = state.clips;
    view.layer.cornerCurve = state.curve;
    view.layer.maskedCorners = state.corners;
    [CATransaction commit];
    objc_setAssociatedObject(view, &WCMomentsCornerStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void WCGestureMomentsImageCornerReset(UIView *root) {
    NSHashTable *previous = objc_getAssociatedObject(root, &WCMomentsCornerTargetsKey);
    for (UIView *target in previous.allObjects) WCMomentsCornerRestore(target, root);
    objc_setAssociatedObject(root, &WCMomentsCornerTargetsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCMomentsCornerApply(UIView *view, UIView *root, CGFloat radius, NSHashTable *targets) {
    CGFloat side = MIN(CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds));
    if (!isfinite(side) || side <= 0) return;
    WCMomentsCornerState *state = objc_getAssociatedObject(view, &WCMomentsCornerStateKey);
    if (!state) {
        state = [WCMomentsCornerState new];
        state.radius = view.layer.cornerRadius;
        state.clips = view.layer.masksToBounds;
        state.curve = view.layer.cornerCurve ?: kCACornerCurveCircular;
        state.corners = view.layer.maskedCorners;
        objc_setAssociatedObject(view, &WCMomentsCornerStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // A nested grid and its enclosing cell must never restore each other's targets.
    if (state.owner && state.owner != root) {
        NSHashTable *oldTargets = objc_getAssociatedObject(state.owner, &WCMomentsCornerTargetsKey);
        [oldTargets removeObject:view];
    }
    state.owner = root;
    CGFloat resolved = WCMomentsCornerResolvedRadius(view.bounds.size, radius);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (fabs(view.layer.cornerRadius - resolved) > 0.01) view.layer.cornerRadius = resolved;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    view.layer.masksToBounds = YES;
    [CATransaction commit];
    [targets addObject:view];
}

static BOOL WCMomentsCornerSkipBranch(UIView *view) {
    NSString *name = NSStringFromClass(view.class);
    return [name containsString:@"HeadImage"] || [name containsString:@"Avatar"]
        || [view isKindOfClass:UILabel.class] || [view isKindOfClass:UIButton.class];
}

static void WCMomentsCornerWalk(UIView *view, UIView *root, CGFloat radius, NSUInteger depth,
                               NSUInteger *remaining, NSHashTable *targets, BOOL nativeTile) {
    if (depth > 14 || !*remaining) return;
    (*remaining)--;
    // Native grid items are explicit media tiles, including UIButton-backed thumbnails.
    if (nativeTile) { WCMomentsCornerApply(view, root, radius, targets); return; }
    if (view != root && WCMomentsCornerSkipBranch(view)) return;
    if (WCMomentsCornerClass(view, @"WCSNSNodeVideoView")
        || WCMomentsCornerClass(view, @"WCPuzzleImageView")
        || WCMomentsCornerClass(view, @"WCImageView")
        || WCMomentsCornerClass(view, @"MMWebImageView")) {
        WCMomentsCornerApply(view, root, radius, targets);
        return;
    }
    if (WCMomentsCornerClass(view, @"MMImageGridView")) {
        id tiles = WCTweakSafeValue(view, @"m_arrOfViews");
        if ([tiles isKindOfClass:NSArray.class]) {
            for (id tile in tiles) {
                if (!*remaining) break;
                if ([tile isKindOfClass:UIView.class] && [(UIView *)tile isDescendantOfView:view]) {
                    WCMomentsCornerWalk(tile, root, radius, depth + 1, remaining, targets, YES);
                }
            }
            return;
        }
    }
    // getAlbumView is the dedicated thumbnail strip, not the whole contact/profile cell.
    BOOL profileStrip = view == root && [objc_getAssociatedObject(root, &WCMomentsCornerProfileKey) boolValue];
    for (UIView *child in view.subviews) {
        BOOL previewImage = profileStrip && [child isKindOfClass:UIImageView.class];
        WCMomentsCornerWalk(child, root, radius, depth + 1, remaining, targets, previewImage);
    }
}

void WCGestureMomentsImageCornerLayout(UIView *view) {
    UIView *root = WCMomentsCornerRootForView(view);
    if (!root) {
        // A formerly rounded media view may have moved to a fullscreen or unrelated host.
        WCMomentsCornerRestore(view, nil);
        return;
    }
    if (root != view && objc_getAssociatedObject(view, &WCMomentsCornerTargetsKey)) {
        WCGestureMomentsImageCornerReset(view);
    }
    if ([objc_getAssociatedObject(root, &WCMomentsCornerBusyKey) boolValue]) return;
    [WCMomentsCornerRoots() addObject:root];
    objc_setAssociatedObject(root, &WCMomentsCornerRegisteredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!WCGestureEnabled(WCGestureMomentsImageCornerEnabledKey)) { WCGestureMomentsImageCornerReset(root); return; }
    objc_setAssociatedObject(root, &WCMomentsCornerBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        double value = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMomentsImageCornerRadiusKey];
        CGFloat radius = isfinite(value) ? MIN(40, MAX(0, value)) : 8;
        NSHashTable *targets = [NSHashTable weakObjectsHashTable];
        NSUInteger remaining = 500;
        WCMomentsCornerWalk(root, root, radius, 0, &remaining, targets, NO);
        NSHashTable *previous = objc_getAssociatedObject(root, &WCMomentsCornerTargetsKey);
        for (UIView *old in previous.allObjects) if (![targets containsObject:old]) WCMomentsCornerRestore(old, root);
        objc_setAssociatedObject(root, &WCMomentsCornerTargetsKey, targets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally {
        objc_setAssociatedObject(root, &WCMomentsCornerBusyKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void WCGestureMomentsImageCornerViewDidLayout(UIView *view) {
    WCMomentsCornerState *state = objc_getAssociatedObject(view, &WCMomentsCornerStateKey);
    BOOL registered = [objc_getAssociatedObject(view, &WCMomentsCornerRegisteredKey) boolValue];
    if (!state && !registered) return;
    if (!WCGestureEnabled(WCGestureMomentsImageCornerEnabledKey)) {
        if (state) WCMomentsCornerRestore(view, nil);
        return;
    }
    UIView *root = WCMomentsCornerRootForView(view);
    if (!root) { WCMomentsCornerRestore(view, nil); return; }
    if ([objc_getAssociatedObject(root, &WCMomentsCornerPendingKey) boolValue]) return;
    objc_setAssociatedObject(root, &WCMomentsCornerPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakRoot = root;
    // Run after private subclasses finish layout and overwrite their own layers.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *target = weakRoot;
        if (!target) return;
        objc_setAssociatedObject(target, &WCMomentsCornerPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        WCGestureMomentsImageCornerLayout(target);
    });
}

void WCGestureMomentsImageCornerRegisterProfile(UIView *view) {
    if (![view isKindOfClass:UIView.class]) return;
    objc_setAssociatedObject(view, &WCMomentsCornerProfileKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCGestureMomentsImageCornerLayout(view);
    WCGestureMomentsImageCornerViewDidLayout(view);
}

void WCGestureMomentsImageCornerSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.moments.image-corner."]) return;
    // Do not reset/re-capture baselines when only the requested radius changes.
    for (UIView *root in WCMomentsCornerRoots().allObjects) WCGestureMomentsImageCornerLayout(root);
}
