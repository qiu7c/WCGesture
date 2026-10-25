#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCGlobalAvatarOriginalCornerRadiusKey;
static char WCGlobalAvatarOriginalMasksToBoundsKey;
static char WCGlobalAvatarOriginalCornerCurveKey;
static char WCGlobalAvatarStateSavedKey;
static char WCGlobalAvatarTargetViewKey;
static char WCGlobalAvatarExcludedKey;
static BOOL WCGlobalAvatarConfigurationEnabled = NO;
static CGFloat WCGlobalAvatarConfigurationRatio = 1.0;

static NSHashTable<UIView *> *WCTrackedGlobalAvatarViews(void) {
    static NSHashTable<UIView *> *views;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}

static void WCReloadGlobalAvatarConfiguration(void) {
    WCGlobalAvatarConfigurationEnabled = WCGestureEnabled(WCGestureGlobalAvatarRoundingEnabledKey);
    CGFloat percent = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureGlobalAvatarCornerPercentKey];
    WCGlobalAvatarConfigurationRatio = (isfinite(percent) ? MIN(100.0, MAX(0.0, percent)) : 100.0) / 100.0;
}

static void WCEnsureGlobalAvatarConfiguration(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ WCReloadGlobalAvatarConfiguration(); });
}

static CGFloat WCGlobalAvatarCornerRatio(void) {
    WCEnsureGlobalAvatarConfiguration();
    return WCGlobalAvatarConfigurationRatio;
}

static UIView *WCGlobalAvatarTargetView(UIView *headView) {
    SEL selector = NSSelectorFromString(@"headImageView");
    if ([headView respondsToSelector:selector]) {
        id target = ((id (*)(id, SEL))objc_msgSend)(headView, selector);
        if ([target isKindOfClass:UIView.class]) return target;
    }
    return headView;
}

static void WCRestoreGlobalAvatarRounding(UIView *headView) {
    UIView *target = objc_getAssociatedObject(headView, &WCGlobalAvatarTargetViewKey);
    if (!target) target = headView;
    if (![objc_getAssociatedObject(headView, &WCGlobalAvatarStateSavedKey) boolValue]) return;
    target.layer.cornerRadius = [objc_getAssociatedObject(headView, &WCGlobalAvatarOriginalCornerRadiusKey) doubleValue];
    target.layer.masksToBounds = [objc_getAssociatedObject(headView, &WCGlobalAvatarOriginalMasksToBoundsKey) boolValue];
    NSString *curve = objc_getAssociatedObject(headView, &WCGlobalAvatarOriginalCornerCurveKey);
    if (curve.length > 0) target.layer.cornerCurve = curve;
    objc_setAssociatedObject(headView, &WCGlobalAvatarStateSavedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCGlobalAvatarTargetViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCGlobalAvatarOriginalCornerRadiusKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCGlobalAvatarOriginalMasksToBoundsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(headView, &WCGlobalAvatarOriginalCornerCurveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL WCGestureHeadViewIsExcludedFromGlobalAvatarRounding(UIView *headView) {
    return [objc_getAssociatedObject(headView, &WCGlobalAvatarExcludedKey) boolValue];
}

void WCGestureExcludeHeadViewFromGlobalAvatarRounding(UIView *headView) {
    if (!headView) return;
    objc_setAssociatedObject(headView, &WCGlobalAvatarExcludedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCRestoreGlobalAvatarRounding(headView);
    [WCTrackedGlobalAvatarViews() removeObject:headView];
}

void WCGestureApplyGlobalAvatarRoundingToHeadView(UIView *headView) {
    if (!headView) return;
    WCEnsureGlobalAvatarConfiguration();
    if (WCGestureHeadViewIsExcludedFromGlobalAvatarRounding(headView)) {
        WCRestoreGlobalAvatarRounding(headView);
        [WCTrackedGlobalAvatarViews() removeObject:headView];
        return;
    }
    [WCTrackedGlobalAvatarViews() addObject:headView];
    NSNumber *saved = objc_getAssociatedObject(headView, &WCGlobalAvatarStateSavedKey);
    if (!WCGlobalAvatarConfigurationEnabled) {
        if (!saved.boolValue) return;
        WCRestoreGlobalAvatarRounding(headView);
        return;
    }
    UIView *target = WCGlobalAvatarTargetView(headView);
    UIView *savedTarget = objc_getAssociatedObject(headView, &WCGlobalAvatarTargetViewKey) ?: headView;
    if (saved.boolValue && savedTarget != target) {
        WCRestoreGlobalAvatarRounding(headView);
        saved = nil;
    }
    if (!saved.boolValue) {
        objc_setAssociatedObject(headView, &WCGlobalAvatarTargetViewKey,
                                 target == headView ? nil : target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(headView, &WCGlobalAvatarOriginalCornerRadiusKey,
                                 @(target.layer.cornerRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(headView, &WCGlobalAvatarOriginalMasksToBoundsKey,
                                 @(target.layer.masksToBounds), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(headView, &WCGlobalAvatarOriginalCornerCurveKey,
                                 target.layer.cornerCurve ?: kCACornerCurveCircular,
                                 OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(headView, &WCGlobalAvatarStateSavedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat width = CGRectGetWidth(target.bounds);
    CGFloat height = CGRectGetHeight(target.bounds);
    if (width <= 0.0 || height <= 0.0) return;
    CGFloat radius = MIN(width, height) * 0.5 * WCGlobalAvatarCornerRatio();
    if (fabs(target.layer.cornerRadius - radius) > 0.01) target.layer.cornerRadius = radius;
    if (![target.layer.cornerCurve isEqualToString:kCACornerCurveContinuous]) {
        target.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (!target.layer.masksToBounds) target.layer.masksToBounds = YES;
}

void WCGestureRefreshTrackedGlobalAvatarViews(void) {
    WCReloadGlobalAvatarConfiguration();
    for (UIView *headView in WCTrackedGlobalAvatarViews().allObjects) {
        WCGestureApplyGlobalAvatarRoundingToHeadView(headView);
    }
}

unsigned int WCGestureGlobalAvatarScaledCornerSize(unsigned int originalSize) {
    WCEnsureGlobalAvatarConfiguration();
    if (!WCGlobalAvatarConfigurationEnabled) return originalSize;
    return (unsigned int)lrint((double)originalSize * WCGlobalAvatarCornerRatio());
}
