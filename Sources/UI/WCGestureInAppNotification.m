#import "Sources/API/WCGestureInternal.h"
#import <UIKit/UIKit.h>
static const NSTimeInterval WCGestureInAppNotificationDuration = 4.0;
static const NSTimeInterval WCGestureInAppNotificationDuplicateInterval = 5.0;
static UIWindow *WCGestureInAppActiveWindow(void) { return WCActiveWindow(); }
static CGFloat WCGestureInAppNotificationPreferredHeight(void) { return 60.0; }
static CGFloat WCGestureInAppNotificationBlurIntensity(void) { return 0.85; }
static NSString *WCGestureInAppNotificationResolvedSymbolName(NSString *symbol) { return symbol.length ? symbol : @"bell.fill"; }
@interface WCGestureInAppNotificationRequest : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy, nullable) dispatch_block_t action;
@end

@implementation WCGestureInAppNotificationRequest
@end

@interface WCGestureInAppBannerView : UIControl
@property (nonatomic, strong) UIImageView *symbolView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
- (instancetype)initWithRequest:(WCGestureInAppNotificationRequest *)request;
@end

@implementation WCGestureInAppBannerView

- (instancetype)initWithRequest:(WCGestureInAppNotificationRequest *)request {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 14.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.16;
    self.layer.shadowRadius = 12.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@，%@", request.title, request.body];

    UIVisualEffectView *background = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    background.translatesAutoresizingMaskIntoConstraints = NO;
    background.userInteractionEnabled = NO;
    background.layer.cornerRadius = 14.0;
    background.layer.cornerCurve = kCACornerCurveContinuous;
    background.clipsToBounds = YES;
    [self addSubview:background];

    CGFloat blurIntensity = WCGestureInAppNotificationBlurIntensity();
    background.contentView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.10 + (1.0 - blurIntensity) * 0.45];

    UIView *iconBackground = [UIView new];
    iconBackground.translatesAutoresizingMaskIntoConstraints = NO;
    iconBackground.backgroundColor = [UIColor colorWithRed:0.12 green:0.72 blue:0.32 alpha:1.0];
    iconBackground.layer.cornerRadius = 10.0;
    iconBackground.layer.cornerCurve = kCACornerCurveContinuous;
    [background.contentView addSubview:iconBackground];

    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:19.0 weight:UIImageSymbolWeightSemibold];
    NSString *resolvedSymbolName = WCGestureInAppNotificationResolvedSymbolName(request.symbolName);
    UIImage *symbol = [UIImage systemImageNamed:resolvedSymbolName withConfiguration:configuration] ?:
                      [UIImage systemImageNamed:@"bell.fill" withConfiguration:configuration];
    self.symbolView = [[UIImageView alloc] initWithImage:symbol];
    self.symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    self.symbolView.contentMode = UIViewContentModeScaleAspectFit;
    self.symbolView.tintColor = UIColor.whiteColor;
    [iconBackground addSubview:self.symbolView];

    self.titleLabel = [UILabel new];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = request.title;
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [background.contentView addSubview:self.titleLabel];

    self.bodyLabel = [UILabel new];
    self.bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bodyLabel.text = request.body;
    self.bodyLabel.textColor = UIColor.secondaryLabelColor;
    self.bodyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.bodyLabel.adjustsFontForContentSizeCategory = YES;
    self.bodyLabel.numberOfLines = 2;
    self.bodyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [background.contentView addSubview:self.bodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [iconBackground.leadingAnchor constraintEqualToAnchor:background.contentView.leadingAnchor constant:12.0],
        [iconBackground.centerYAnchor constraintEqualToAnchor:background.contentView.centerYAnchor],
        [iconBackground.widthAnchor constraintEqualToConstant:38.0],
        [iconBackground.heightAnchor constraintEqualToConstant:38.0],
        [self.symbolView.centerXAnchor constraintEqualToAnchor:iconBackground.centerXAnchor],
        [self.symbolView.centerYAnchor constraintEqualToAnchor:iconBackground.centerYAnchor],
        [self.symbolView.widthAnchor constraintEqualToConstant:21.0],
        [self.symbolView.heightAnchor constraintEqualToConstant:21.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:iconBackground.trailingAnchor constant:10.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:background.contentView.trailingAnchor constant:-12.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:background.contentView.topAnchor constant:9.0],
        [self.bodyLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.bodyLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.bodyLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:1.0],
        [self.bodyLabel.bottomAnchor constraintEqualToAnchor:background.contentView.bottomAnchor constant:-9.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:WCGestureInAppNotificationPreferredHeight()],
    ]];
    return self;
}

@end

@interface WCGestureInAppNotificationCenter : NSObject
@property (nonatomic, strong) NSMutableArray<WCGestureInAppNotificationRequest *> *queue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *recentIdentifiers;
@property (nonatomic, strong, nullable) WCGestureInAppNotificationRequest *currentRequest;
@property (nonatomic, strong, nullable) WCGestureInAppBannerView *currentBanner;
@property (nonatomic, assign) NSUInteger presentationToken;
@property (nonatomic, assign) BOOL dismissing;
+ (instancetype)sharedCenter;
- (void)enqueueRequest:(WCGestureInAppNotificationRequest *)request;
- (void)showNextIfPossible;
- (void)dismissCurrentAnimated:(BOOL)animated completion:(dispatch_block_t _Nullable)completion;
- (void)dismissAll;
@end

@implementation WCGestureInAppNotificationCenter

+ (instancetype)sharedCenter {
    static WCGestureInAppNotificationCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [WCGestureInAppNotificationCenter new];
        center.queue = [NSMutableArray array];
        center.recentIdentifiers = [NSMutableDictionary dictionary];
        [NSNotificationCenter.defaultCenter addObserver:center
                                               selector:@selector(applicationDidEnterBackground:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    });
    return center;
}

- (UIWindow *)activeWindow {
    return WCGestureInAppActiveWindow();
}

- (void)enqueueRequest:(WCGestureInAppNotificationRequest *)request {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self enqueueRequest:request]; });
        return;
    }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;

    NSDate *now = NSDate.date;
    for (NSString *identifier in self.recentIdentifiers.allKeys.copy) {
        if ([now timeIntervalSinceDate:self.recentIdentifiers[identifier]] >
            WCGestureInAppNotificationDuplicateInterval) {
            [self.recentIdentifiers removeObjectForKey:identifier];
        }
    }
    NSDate *lastShown = self.recentIdentifiers[request.identifier];
    if (lastShown && [now timeIntervalSinceDate:lastShown] <= WCGestureInAppNotificationDuplicateInterval) return;
    self.recentIdentifiers[request.identifier] = now;

    [self.queue addObject:request];
    if (self.queue.count > 8) [self.queue removeObjectAtIndex:0];
    [self showNextIfPossible];
}

- (void)showNextIfPossible {
    if (self.currentRequest || self.dismissing || self.queue.count == 0) return;
    UIWindow *window = [self activeWindow];
    if (!window) {
        NSLog(@"[One Wx] 应用内提醒未显示：没有可用的前台窗口");
        [self.queue removeAllObjects];
        return;
    }

    WCGestureInAppNotificationRequest *request = self.queue.firstObject;
    [self.queue removeObjectAtIndex:0];
    self.currentRequest = request;
    WCGestureInAppBannerView *banner = [[WCGestureInAppBannerView alloc] initWithRequest:request];
    self.currentBanner = banner;
    [banner addTarget:self action:@selector(bannerTapped:) forControlEvents:UIControlEventTouchUpInside];
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(bannerSwiped:)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp;
    [banner addGestureRecognizer:swipe];
    [window addSubview:banner];
    [NSLayoutConstraint activateConstraints:@[
        [banner.leadingAnchor constraintEqualToAnchor:window.leadingAnchor constant:12.0],
        [banner.trailingAnchor constraintEqualToAnchor:window.trailingAnchor constant:-12.0],
        [banner.topAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:8.0],
    ]];
    [window layoutIfNeeded];

    banner.transform = CGAffineTransformMakeTranslation(0.0, -CGRectGetMaxY(banner.frame) - 20.0);
    banner.alpha = 0.35;
    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        banner.transform = CGAffineTransformIdentity;
        banner.alpha = 1.0;
    } completion:nil];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    NSUInteger token = ++self.presentationToken;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(WCGestureInAppNotificationDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.presentationToken != token || strongSelf.currentRequest != request) return;
        [strongSelf dismissCurrentAnimated:YES completion:nil];
    });
}

- (void)bannerTapped:(__unused WCGestureInAppBannerView *)sender {
    dispatch_block_t action = self.currentRequest.action;
    [self dismissCurrentAnimated:YES completion:action];
}

- (void)bannerSwiped:(__unused UISwipeGestureRecognizer *)recognizer {
    [self dismissCurrentAnimated:YES completion:nil];
}

- (void)dismissCurrentAnimated:(BOOL)animated completion:(dispatch_block_t)completion {
    WCGestureInAppBannerView *banner = self.currentBanner;
    if (!self.currentRequest || !banner) {
        if (completion) completion();
        return;
    }
    self.presentationToken++;
    self.dismissing = YES;
    self.currentRequest = nil;
    void (^finished)(void) = ^{
        [banner removeFromSuperview];
        self.currentBanner = nil;
        self.dismissing = NO;
        if (completion) completion();
        [self showNextIfPossible];
    };
    if (!animated) {
        finished();
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                     animations:^{
        banner.transform = CGAffineTransformMakeTranslation(0.0, -CGRectGetMaxY(banner.frame) - 20.0);
        banner.alpha = 0.0;
    } completion:^(__unused BOOL didFinish) { finished(); }];
}

- (void)applicationDidEnterBackground:(__unused NSNotification *)notification {
    [self dismissAll];
}

- (void)dismissAll {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self dismissAll]; });
        return;
    }
    [self.queue removeAllObjects];
    [self dismissCurrentAnimated:NO completion:nil];
}

@end

void WCGestureShowInAppNotification(NSString *title,
                                NSString *body,
                                NSString *identifier,
                                NSString *symbolName,
                                dispatch_block_t action) {
    if (title.length == 0 || body.length == 0) return;
    WCGestureInAppNotificationRequest *request = [WCGestureInAppNotificationRequest new];
    request.title = title;
    request.body = body;
    request.identifier = identifier.length > 0 ? identifier : NSUUID.UUID.UUIDString;
    request.symbolName = symbolName.length > 0 ? symbolName : @"bell.fill";
    request.action = action;
    [[WCGestureInAppNotificationCenter sharedCenter] enqueueRequest:request];
}


void WCGestureDismissInAppNotifications(void) {
    [[WCGestureInAppNotificationCenter sharedCenter] dismissAll];
}
