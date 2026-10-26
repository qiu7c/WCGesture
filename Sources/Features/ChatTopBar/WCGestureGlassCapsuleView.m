#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static void WCGlassApplyTransparency(UIView *glass);

@interface WCGestureGlassCapsuleView : UIView
@property (nonatomic, strong) UIVisualEffectView *effectView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIViewPropertyAnimator *blurAnimator;
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
- (void)rebuildBlurEffect {
    // Navigation preparation and pinned-header layout disable animations. Do
    // not create an effect interpolator inside those scopes: it may complete
    // immediately, leaving every slider value with the same full blur.
    if (!UIView.areAnimationsEnabled || [CATransaction disableActions]) {
        if (self.blurRebuildPending) return;
        self.blurRebuildPending = YES;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.blurRebuildPending = NO;
            [weakSelf rebuildBlurEffect];
        });
        return;
    }
    [self invalidateBlurAnimator];
    self.effectView.effect = nil;
    self.effectView.alpha = 1;
    self.effectView.backgroundColor = UIColor.clearColor;
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        self.effectView.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        return;
    }
    CGFloat intensity = MAX(0, MIN(1, self.appliedBlurIntensity));
    if (intensity == 0) return;
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    __weak UIVisualEffectView *weakEffect = self.effectView;
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:1 curve:UIViewAnimationCurveLinear animations:^{ weakEffect.effect = effect; }];
    animator.pausesOnCompletion = YES;
    animator.scrubsLinearly = YES;
    self.blurAnimator = animator;
    // Setting the fraction starts a paused interactive animation. Do not start
    // a time-driven animation that can run to the same final material.
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
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.effectView.frame = self.bounds; self.contentView.frame = self.bounds;
    self.effectView.layer.cornerRadius = self.capsuleCornerRadius > 0 ? self.capsuleCornerRadius : CGRectGetHeight(self.bounds) / 2;
    self.effectView.layer.cornerCurve = kCACornerCurveContinuous;
    [CATransaction commit];
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
    glass.alpha = 1 - transparency;
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
