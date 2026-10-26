#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/message.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

static void WCGlassApplyTransparency(UIView *glass);

static UIBlurEffect *WCGlassRadiusEffect(double radius) {
    // Verified against the supplied UIKit header: +effectWithBlurRadius:(double).
    // Check the runtime ABI as this is an optional system implementation detail.
    SEL selector = NSSelectorFromString(@"effectWithBlurRadius:");
    NSMethodSignature *signature = [UIBlurEffect methodSignatureForSelector:selector];
    if (![UIBlurEffect respondsToSelector:selector] || signature.numberOfArguments != 3
        || signature.methodReturnType[0] != '@'
        || strcmp([signature getArgumentTypeAtIndex:2], @encode(double)) != 0) return nil;
    @try {
        id effect = ((id (*)(id,SEL,double))objc_msgSend)(UIBlurEffect.class,selector,radius);
        return [effect isKindOfClass:UIBlurEffect.class] ? effect : nil;
    } @catch (__unused NSException *exception) { return nil; }
}

@interface WCGestureGlassCapsuleView : UIView
@property (nonatomic, strong) UIVisualEffectView *effectView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIViewPropertyAnimator *blurAnimator;
@property (nonatomic, strong) CAShapeLayer *surfaceMask;
@property (nonatomic, assign) CGFloat capsuleCornerRadius;
@property (nonatomic, assign) CGFloat appliedBlurIntensity;
@property (nonatomic, assign) BOOL blurRebuildPending;
- (void)configureFrostedGlassWithBlurIntensity:(CGFloat)intensity;
@end

@implementation WCGestureGlassCapsuleView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.appliedBlurIntensity = -1;
    self.surfaceMask = [CAShapeLayer layer]; self.surfaceMask.fillColor = UIColor.blackColor.CGColor;
    self.layer.mask = self.surfaceMask;
    self.effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
    self.effectView.userInteractionEnabled = NO;
    self.effectView.clipsToBounds = YES;
    self.effectView.layer.borderWidth = 0.5;
    [self addSubview:self.effectView];
    self.contentView = [UIView new]; self.contentView.backgroundColor = UIColor.clearColor;
    [self addSubview:self.contentView];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshBackdropAfterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshBackdropAfterForeground) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [self applyTraitColors];
    return self;
}
- (void)invalidateBlurAnimator {
    if (self.blurAnimator.state == UIViewAnimatingStateActive) [self.blurAnimator stopAnimation:YES];
    self.blurAnimator = nil;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self invalidateBlurAnimator];
}
- (void)scheduleBlurRebuild {
    if (self.blurRebuildPending) return;
    self.blurRebuildPending = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.blurRebuildPending = NO;
        [weakSelf rebuildBlurEffect];
    });
}
- (void)rebuildBlurEffect {
    // The visual-effect host must already have its final bounds and a window.
    if (!self.window || CGRectIsEmpty(self.effectView.bounds)) return;
    [self invalidateBlurAnimator];
    self.effectView.alpha = 1;
    self.effectView.backgroundColor = UIColor.clearColor;
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        self.effectView.effect = nil;
        self.effectView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        return;
    }
    CGFloat intensity = MAX(0, MIN(1, self.appliedBlurIntensity));
    if (intensity == 0) { self.effectView.effect = nil; return; }
    // This changes the blur kernel radius, not the material animation's alpha.
    UIBlurEffect *radiusEffect = WCGlassRadiusEffect(40.0 * intensity);
    if (radiusEffect) {
        [UIView performWithoutAnimation:^{ self.effectView.effect = radiusEffect; }];
        return;
    }
    // Compatibility fallback only; never construct its animator while native
    // navigation/pinned layout has disabled animations.
    if (!UIView.areAnimationsEnabled || [CATransaction disableActions]) { [self scheduleBlurRebuild]; return; }
    self.effectView.effect = nil;
    [self.effectView layoutIfNeeded];
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    __weak UIVisualEffectView *weakEffect = self.effectView;
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:1 curve:UIViewAnimationCurveLinear animations:^{ weakEffect.effect = effect; }];
    animator.pausesOnCompletion = YES; animator.scrubsLinearly = YES;
    self.blurAnimator = animator;
    animator.fractionComplete = intensity;
}
- (void)configureFrostedGlassWithBlurIntensity:(CGFloat)intensity {
    CGFloat resolved = isfinite(intensity) ? MIN(1,MAX(0,intensity)) : 0.2;
    if (fabs(self.appliedBlurIntensity - resolved) < 0.001) return;
    self.appliedBlurIntensity = resolved;
    [self rebuildBlurEffect];
}
- (void)applyTraitColors {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.effectView.layer.borderColor = (dark ? [UIColor.whiteColor colorWithAlphaComponent:0.14] : [UIColor.blackColor colorWithAlphaComponent:0.10]).CGColor;
}
- (void)refreshBackdropAfterForeground {
    if (self.appliedBlurIntensity < 0 || !self.window) return;
    WCGlassApplyTransparency(self);
    [self rebuildBlurEffect];
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self refreshBackdropAfterForeground];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL sizeChanged = !CGSizeEqualToSize(self.effectView.bounds.size, self.bounds.size);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.surfaceMask.frame = self.bounds;
    self.surfaceMask.path = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
    self.effectView.frame = self.bounds; self.contentView.frame = self.bounds;
    self.effectView.layer.cornerRadius = self.capsuleCornerRadius > 0 ? self.capsuleCornerRadius : CGRectGetHeight(self.bounds) / 2;
    self.effectView.layer.cornerCurve = kCACornerCurveContinuous;
    [CATransaction commit];
    if (sizeChanged && self.appliedBlurIntensity >= 0 && self.window) [self scheduleBlurRebuild];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (previous.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self applyTraitColors]; [self refreshBackdropAfterForeground];
    }
}
@end

UIView *WCGestureCreateChatGlassView(void) {
    WCGestureGlassCapsuleView *view = [WCGestureGlassCapsuleView new];
    WCGestureConfigureChatGlass(view); return view;
}
UIView *WCGestureChatGlassContent(UIView *glass) { return ((WCGestureGlassCapsuleView *)glass).contentView; }
static CGFloat WCGlassNumber(NSString *key, CGFloat fallback, CGFloat low, CGFloat high) {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:key];
    double number = [stored respondsToSelector:@selector(doubleValue)] ? [stored doubleValue] : fallback;
    return isfinite(number) ? MIN(high, MAX(low, number)) : fallback;
}
static void WCGlassApplyTransparency(UIView *glass) {
    CGFloat transparency = WCGlassNumber(WCGestureChatGlassTransparencyKey, 50, 0, 100) / 100.0;
    // Keep the visual-effect view and its UIView ancestors at alpha=1.
    // A compositing mask fades only the completed glass surface, independently
    // of the blur radius; sibling text/icons retain their original opacity.
    glass.alpha = 1;
    WCGestureGlassCapsuleView *view = (WCGestureGlassCapsuleView *)glass;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    view.surfaceMask.opacity = 1 - transparency;
    [CATransaction commit];
}
CGFloat WCGestureChatTopBarShellFactor(void) { return WCGlassNumber(WCGestureChatTopBarShellScaleKey, 100, 80, 140) / 100.0; }
CGFloat WCGestureChatTopBarActionsWidth(BOOL search) {
    CGFloat scale = WCGestureChatTopBarScale(), shell = WCGestureChatTopBarShellFactor();
    CGFloat icon = WCGlassNumber(WCGestureChatTopBarIconSizeKey, 18, 12, 26);
    return MAX((search ? 76 : 40) * shell, (search ? 2 : 1) * (20 * icon / 18 + 8)) * scale;
}
void WCGestureConfigureChatGlass(UIView *glass) {
    WCGlassApplyTransparency(glass);
    double intensity = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureChatGlassBlurIntensityKey];
    if (!isfinite(intensity)) intensity = 20;
    WCGestureGlassCapsuleView *view = (WCGestureGlassCapsuleView *)glass;
    [view configureFrostedGlassWithBlurIntensity:intensity / 100.0];
}

CGFloat WCGestureChatTopBarScale(void) {
    return WCGestureLayoutScaleFactor();
}
void WCGestureConfigureChatPinnedGlass(UIView *glass) {
    WCGlassApplyTransparency(glass);
    double intensity = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureChatGlassBlurIntensityKey];
    if (!isfinite(intensity)) intensity = 20;
    [(WCGestureGlassCapsuleView *)glass configureFrostedGlassWithBlurIntensity:intensity / 100.0];
}
