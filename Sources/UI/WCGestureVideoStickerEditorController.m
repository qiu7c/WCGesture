#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCVideoStickerEditorController : UIViewController <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImage *source;
@property (nonatomic, strong) UIImageView *sticker;
@property (nonatomic, strong) UIStackView *toolbar;
@property (nonatomic, strong) UILabel *gestureHint;
@property (nonatomic) CGPoint unitCenter;
@property (nonatomic) CGFloat relativeWidth;
@property (nonatomic) CGFloat angle;
@property (nonatomic) BOOL finished;
@property (nonatomic, copy) void (^completion)(UIImage *, NSDictionary *);
- (void)cancel;
@end
@implementation WCVideoStickerEditorController
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.clearColor;
    self.modalInPresentation = YES;
    self.sticker = [[UIImageView alloc] initWithImage:self.source];
    self.sticker.contentMode = UIViewContentModeScaleAspectFit;
    self.sticker.layer.borderWidth = 1; self.sticker.layer.borderColor = UIColor.systemBlueColor.CGColor;
    [self.view addSubview:self.sticker];
    self.gestureHint = [UILabel new]; self.gestureHint.text = @"拖动移动 · 双指缩放、旋转";
    self.gestureHint.font = [UIFont systemFontOfSize:14]; self.gestureHint.textColor = UIColor.whiteColor;
    self.gestureHint.textAlignment = NSTextAlignmentCenter;
    self.gestureHint.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:.45];
    self.gestureHint.layer.cornerRadius = 12; self.gestureHint.layer.masksToBounds = YES;
    [self.view addSubview:self.gestureHint];
    self.toolbar = [[UIStackView alloc] init]; self.toolbar.spacing = 12;
    self.toolbar.distribution = UIStackViewDistributionFillEqually;
    self.toolbar.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:.92];
    self.toolbar.layer.cornerRadius = 14;
    for (NSString *title in @[@"取消", @"居中", @"完成"]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem]; [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:15];
        SEL action = [title isEqualToString:@"取消"] ? @selector(cancel) : ([title isEqualToString:@"居中"] ? @selector(centerSticker) : @selector(confirm));
        [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; [self.toolbar addArrangedSubview:button];
    }
    [self.view addSubview:self.toolbar];
    NSArray *gestures = @[[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveSticker:)],
        [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(scaleSticker:)],
        [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotateSticker:)]];
    for (UIGestureRecognizer *gesture in gestures) { gesture.delegate = self; [self.view addGestureRecognizer:gesture]; }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(enteredBackground:)
        name:UIApplicationDidEnterBackgroundNotification object:nil];
    self.view.accessibilityLabel = @"移动贴纸，单指拖动，双指缩放和旋转";
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = MIN(300, self.view.bounds.size.width - 32);
    self.gestureHint.frame = CGRectMake((self.view.bounds.size.width - width) / 2,
        self.view.safeAreaInsets.top + 12, width, 32);
    self.toolbar.frame = CGRectMake((self.view.bounds.size.width - width) / 2,
        self.view.bounds.size.height - self.view.safeAreaInsets.bottom - 62, width, 46);
    [self layoutSticker];
}
- (void)layoutSticker {
    CGSize size = self.view.bounds.size;
    CGFloat width = MAX(1, size.width * self.relativeWidth);
    self.sticker.bounds = CGRectMake(0, 0, width, width * self.source.size.height / MAX(1, self.source.size.width));
    self.sticker.center = CGPointMake(size.width * self.unitCenter.x, size.height * self.unitCenter.y);
    self.sticker.transform = CGAffineTransformMakeRotation(self.angle);
}
- (BOOL)gestureRecognizer:(__unused UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view && view != self.view; view = view.superview)
        if ([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (BOOL)gestureRecognizer:(__unused UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(__unused UIGestureRecognizer *)other { return YES; }
- (void)moveSticker:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self.view]; CGSize size = self.view.bounds.size;
    self.unitCenter = CGPointMake(MAX(0, MIN(1, self.unitCenter.x + delta.x / MAX(1, size.width))),
        MAX(0, MIN(1, self.unitCenter.y + delta.y / MAX(1, size.height))));
    [gesture setTranslation:CGPointZero inView:self.view]; [self layoutSticker];
}
- (void)scaleSticker:(UIPinchGestureRecognizer *)gesture {
    self.relativeWidth = MAX(.05, MIN(1.5, self.relativeWidth * gesture.scale));
    gesture.scale = 1; [self layoutSticker];
}
- (void)rotateSticker:(UIRotationGestureRecognizer *)gesture {
    self.angle += gesture.rotation; gesture.rotation = 0; [self layoutSticker];
}
- (void)centerSticker { self.unitCenter = CGPointMake(.5, .5); [self layoutSticker]; }
- (void)finish:(UIImage *)canvas placement:(NSDictionary *)placement {
    if (self.finished) return; self.finished = YES;
    void (^completion)(UIImage *, NSDictionary *) = self.completion; self.completion = nil;
    if (completion) completion(canvas, placement);
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)cancel { [self finish:nil placement:nil]; }
- (void)enteredBackground:(__unused NSNotification *)note { [self cancel]; }
- (void)confirm {
    CGSize size = self.view.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;
    CGFloat scale = MIN(1, 1536 / MAX(size.width, size.height));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = 1; format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:
        CGSizeMake(ceil(size.width * scale), ceil(size.height * scale)) format:format];
    CGFloat width = size.width * self.relativeWidth, height = width * self.source.size.height / MAX(1, self.source.size.width);
    UIImage *canvas = [renderer imageWithActions:^(UIGraphicsImageRendererContext *drawing) {
        CGContextRef cg = drawing.CGContext; CGContextScaleCTM(cg, scale, scale);
        CGContextTranslateCTM(cg, size.width * self.unitCenter.x, size.height * self.unitCenter.y);
        CGContextRotateCTM(cg, self.angle);
        [self.source drawInRect:CGRectMake(-width / 2, -height / 2, width, height)];
    }];
    [self finish:canvas placement:@{@"x":@(self.unitCenter.x), @"y":@(self.unitCenter.y),
        @"width":@(self.relativeWidth), @"angle":@(self.angle)}];
}
@end

UIViewController *WCGestureCreateVideoStickerEditor(UIImage *image, NSDictionary *placement,
    void (^completion)(UIImage *, NSDictionary *)) {
    WCVideoStickerEditorController *controller = [WCVideoStickerEditorController new];
    controller.source = image; controller.completion = completion;
    double x = placement ? [placement[@"x"] doubleValue] : .5, y = placement ? [placement[@"y"] doubleValue] : .5;
    double width = placement ? [placement[@"width"] doubleValue] : .3;
    double angle = [placement[@"angle"] doubleValue];
    controller.unitCenter = CGPointMake(isfinite(x) ? MAX(0, MIN(1, x)) : .5, isfinite(y) ? MAX(0, MIN(1, y)) : .5);
    controller.relativeWidth = isfinite(width) ? MAX(.05, MIN(1.5, width)) : .3;
    controller.angle = isfinite(angle) ? angle : 0;
    controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return controller;
}
BOOL WCGestureVideoStickerEditorCancel(UIViewController *controller) {
    if (![controller isKindOfClass:WCVideoStickerEditorController.class]) return NO;
    [(WCVideoStickerEditorController *)controller cancel]; return YES;
}
