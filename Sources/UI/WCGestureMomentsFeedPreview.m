#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

static UILabel *WCMomentsPreviewLabel(NSString *text, CGFloat size, UIColor *color) {
    UILabel *label = [UILabel new]; label.text = text; label.font = [UIFont systemFontOfSize:size];
    label.textColor = color; label.numberOfLines = 0; return label;
}
static UIImage *WCMomentsPreviewLandscape(NSUInteger index) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(240, 180)];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
        NSArray *skies = @[[UIColor colorWithRed:.66 green:.84 blue:.94 alpha:1],
            [UIColor colorWithRed:.96 green:.80 blue:.65 alpha:1], [UIColor colorWithRed:.75 green:.85 blue:.76 alpha:1]];
        [skies[index % skies.count] setFill]; UIRectFill(CGRectMake(0, 0, 240, 180));
        [[UIColor colorWithWhite:1 alpha:.8] setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(158, 28, 32, 32)] fill];
        [[UIColor colorWithRed:.33 green:.59 blue:.54 alpha:1] setFill];
        UIBezierPath *mountain = [UIBezierPath bezierPath]; [mountain moveToPoint:CGPointMake(0, 134)];
        [mountain addLineToPoint:CGPointMake(82, 66 + index % 3 * 12)]; [mountain addLineToPoint:CGPointMake(170, 138)];
        [mountain addLineToPoint:CGPointMake(240, 85)]; [mountain addLineToPoint:CGPointMake(240, 180)];
        [mountain addLineToPoint:CGPointMake(0, 180)]; [mountain closePath]; [mountain fill];
        [[UIColor colorWithRed:.23 green:.52 blue:.66 alpha:1] setFill]; UIRectFill(CGRectMake(0, 143, 240, 37));
    }];
}

@interface WCMomentsPreviewPost : UIView
@property (nonatomic) BOOL video;
@property (nonatomic, strong) UIView *avatar;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UIView *media;
@property (nonatomic, strong) NSArray<UIImageView *> *photos;
@property (nonatomic, strong) UIImageView *playIcon;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *locationLabel;
@property (nonatomic, strong) NSArray<UIButton *> *buttons;
@property (nonatomic, strong) NSArray<UIButton *> *ownerButtons;
@property (nonatomic, strong) UIButton *more;
@property (nonatomic, strong) UILabel *comments;
@property (nonatomic, strong) UIView *line;
@property (nonatomic) NSTimeInterval timestamp;
- (instancetype)initWithVideo:(BOOL)video;
- (CGFloat)layoutForWidth:(CGFloat)width;
@end
@implementation WCMomentsPreviewPost
- (instancetype)initWithVideo:(BOOL)video {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    self.video = video; self.timestamp = NSDate.date.timeIntervalSince1970 - (video ? 600 : 120);
    self.avatar = WCGestureCurrentUserAvatarView();
    self.nameLabel = WCMomentsPreviewLabel(video ? @"好友" : @"我", 16, UIColor.labelColor);
    self.bodyLabel = WCMomentsPreviewLabel(video ? @"沿着海边走走，风景正好。" : @"记录今天的片刻，留下值得回看的风景。", 16, UIColor.labelColor);
    self.media = [UIView new]; self.media.clipsToBounds = YES;
    NSMutableArray *photos = [NSMutableArray array];
    for (NSUInteger index = 0; index < (video ? 1 : 6); index++) {
        UIImageView *photo = [[UIImageView alloc] initWithImage:WCMomentsPreviewLandscape(index)];
        photo.contentMode = UIViewContentModeScaleAspectFill; photo.clipsToBounds = YES;
        [self.media addSubview:photo]; [photos addObject:photo];
    }
    self.photos = photos;
    self.playIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
    self.playIcon.tintColor = UIColor.whiteColor; self.playIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.playIcon.hidden = !video; [self.media addSubview:self.playIcon];
    self.timeLabel = WCMomentsPreviewLabel(@"2分钟前", 12, UIColor.secondaryLabelColor);
    self.locationLabel = WCMomentsPreviewLabel(@"广州市 · 粤·向群饭店(信达金茂店) · 36年广州粤菜老字号", 12, UIColor.secondaryLabelColor);
    self.buttons = @[WCGestureCreateMomentsFeedButton(@"点赞", @"heart"), WCGestureCreateMomentsFeedButton(@"评论", @"text.bubble"), WCGestureCreateMomentsFeedButton(@"转发", @"arrow.turn.up.right")];
    NSMutableArray *owner = [NSMutableArray array];
    for (NSString *symbol in @[@"lock", @"trash"]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom]; [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
        button.tintColor = UIColor.secondaryLabelColor; button.userInteractionEnabled = NO;
        [self addSubview:button]; [owner addObject:button];
    }
    self.ownerButtons = owner;
    self.more = [UIButton buttonWithType:UIButtonTypeCustom]; [self.more setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    self.more.tintColor = UIColor.secondaryLabelColor; self.more.userInteractionEnabled = NO;
    self.comments = WCMomentsPreviewLabel(@"好友：这个角度真好看\n我：下次一起去", 13, UIColor.labelColor);
    self.comments.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.line = [UIView new]; self.line.backgroundColor = UIColor.separatorColor;
    for (UIView *view in @[self.avatar, self.nameLabel, self.bodyLabel, self.media, self.timeLabel, self.locationLabel, self.more, self.comments, self.line]) [self addSubview:view];
    for (UIButton *button in self.buttons) { button.userInteractionEnabled = NO; [self addSubview:button]; }
    return self;
}
- (CGFloat)layoutForWidth:(CGFloat)width {
    CGFloat scale = MAX(.5, MIN(1.5, WCGestureLayoutScaleFactor()));
    CGFloat left = 72 * scale, right = width - 18 * scale, availableWidth = MAX(80, right - left);
    CGFloat spacing = 6 * scale;
    BOOL feed = WCGestureEnabled(WCGestureMomentsFeedEnabledKey);
    BOOL actions = feed && WCGestureEnabled(WCGestureMomentsFeedActionsKey);
    BOOL forward = WCGestureEnabled(WCGestureMomentsForwardEnabledKey);
    self.backgroundColor = UIColor.systemBackgroundColor;
    self.avatar.frame = CGRectMake(20 * scale, 14 * scale, 42 * scale, 42 * scale);
    WCGestureApplyGlobalAvatarRoundingToHeadView(self.avatar);
    self.nameLabel.font = [UIFont systemFontOfSize:16 * scale]; self.nameLabel.frame = CGRectMake(left, 14 * scale, availableWidth, 20 * scale);
    self.bodyLabel.font = [UIFont systemFontOfSize:16 * scale];
    CGFloat bodyHeight = ceil([self.bodyLabel sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)].height);
    self.bodyLabel.frame = CGRectMake(left, 39 * scale, availableWidth, bodyHeight);
    CGFloat mediaWidth = MIN(210 * scale, availableWidth), mediaHeight = self.video ? mediaWidth * 1.1 : (mediaWidth - 6 * scale) * 2 / 3 + 3 * scale;
    self.media.frame = CGRectMake(left, CGRectGetMaxY(self.bodyLabel.frame) + spacing, mediaWidth, mediaHeight);
    for (NSUInteger index = 0; index < self.photos.count; index++) {
        CGFloat tile = (mediaWidth - 6 * scale) / 3;
        self.photos[index].frame = self.video ? self.media.bounds : CGRectMake((index % 3) * (tile + 3 * scale), (index / 3) * (tile + 3 * scale), tile, tile);
    }
    self.playIcon.frame = CGRectMake((mediaWidth - 42 * scale) / 2, (mediaHeight - 42 * scale) / 2, 42 * scale, 42 * scale);
    double radius = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMomentsImageCornerRadiusKey];
    self.media.layer.cornerRadius = WCGestureEnabled(WCGestureMomentsImageCornerEnabledKey) ? WCGestureMomentsImageCornerResolvedRadius(self.media.bounds.size, radius) : 0;
    self.media.layer.cornerCurve = kCACornerCurveContinuous;
    NSArray<UIButton *> *visible = actions ? (forward ? self.buttons : [self.buttons subarrayWithRange:NSMakeRange(0, 2)]) : (forward ? @[self.buttons[2]] : @[]);
    CGFloat actionRight = right - (feed && !actions ? 44 * scale : 0);
    CGFloat actionWidth = MAX(40 * scale, actionRight - left);
    WCGestureMomentsFeedActionMetrics metrics = WCGestureMomentsFeedResolveActionMetrics(actionWidth, visible.count,
        feed && WCGestureEnabled(WCGestureMomentsFeedHideActionTextKey));
    NSArray *titles = @[@"点赞", @"评论", @"转发"], *symbols = @[@"heart", @"text.bubble", @"arrow.turn.up.right"];
    for (NSUInteger index = 0; index < self.buttons.count; index++) {
        UIButton *button = self.buttons[index]; button.hidden = ![visible containsObject:button];
        WCGestureConfigureMomentsFeedButton(button, titles[index], symbols[index], metrics.hidesText);
    }
    self.timeLabel.text = WCGestureMomentsTimeText(@{@"createtime":@(self.timestamp)}) ?: (self.video ? @"10分钟前" : @"2分钟前");
    self.timeLabel.font = [UIFont systemFontOfSize:12 * scale]; self.timeLabel.numberOfLines = feed ? 0 : 1;
    CGFloat top = CGRectGetMaxY(self.media.frame) + (feed ? 22 : 7) * scale;
    self.locationLabel.font = [UIFont systemFontOfSize:12 * scale];
    self.locationLabel.numberOfLines = feed && WCGestureEnabled(WCGestureMomentsFeedLocationKey) ? 0 : 1;
    CGFloat locationHeight = ceil([self.locationLabel sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)].height);
    for (UIButton *button in self.ownerButtons) button.hidden = self.video;
    if (feed) {
        self.locationLabel.frame = CGRectMake(left, top, availableWidth, locationHeight);
        top = CGRectGetMaxY(self.locationLabel.frame) + spacing;
        if (!self.video) {
            for (NSUInteger index = 0; index < self.ownerButtons.count; index++)
                self.ownerButtons[index].frame = CGRectMake(left + index * 25 * scale, top, 13 * scale, 13 * scale);
            top += 13 * scale + spacing;
        }
    }
    CGFloat timeWidth = feed ? actionWidth - (visible.count ? metrics.totalWidth + spacing : 0) : availableWidth - (self.video ? 40 : 88) * scale;
    timeWidth = MAX(40 * scale, timeWidth);
    CGFloat timeHeight = feed ? ceil([self.timeLabel sizeThatFits:CGSizeMake(timeWidth, CGFLOAT_MAX)].height) : self.timeLabel.font.lineHeight;
    CGFloat anchor = feed && visible.count ? MAX(timeHeight, metrics.buttonHeight) / 2 : timeHeight / 2;
    self.timeLabel.frame = CGRectMake(left, top + anchor - timeHeight / 2, timeWidth, timeHeight);
    CGFloat buttonY = top + anchor - metrics.buttonHeight / 2;
    CGFloat bottom = CGRectGetMaxY(self.timeLabel.frame);
    if (feed && visible.count) bottom = MAX(bottom, buttonY + metrics.buttonHeight);
    self.more.hidden = actions;
    self.more.frame = CGRectMake(right - 38 * scale, top + anchor - 12 * scale, 38 * scale, 24 * scale);
    if (!feed) {
        self.locationLabel.frame = CGRectMake(left, bottom + spacing, availableWidth, locationHeight);
        bottom = CGRectGetMaxY(self.locationLabel.frame);
        for (NSUInteger index = 0; index < self.ownerButtons.count; index++)
            self.ownerButtons[index].frame = CGRectMake(CGRectGetMaxX(self.timeLabel.frame) + (6 + index * 22) * scale,
                top + anchor - 6.5 * scale, 13 * scale, 13 * scale);
        if (visible.count) { buttonY = bottom + spacing; bottom = buttonY + metrics.buttonHeight; }
    }
    for (NSUInteger index = 0; index < visible.count; index++)
        visible[index].frame = CGRectMake((feed ? actionRight : right) - metrics.totalWidth + index * (metrics.buttonWidth + metrics.spacing), buttonY, metrics.buttonWidth, metrics.buttonHeight);
    double extra = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMomentsFeedSpacingKey];
    CGFloat padding = feed ? MAX(12 * scale, (isfinite(extra) ? MAX(0, MIN(48, extra)) : 8) * scale) : 4 * scale;
    self.comments.font = [UIFont systemFontOfSize:13 * scale];
    CGFloat commentsHeight = ceil([self.comments sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)].height) + 12 * scale;
    self.comments.frame = CGRectMake(left, bottom + padding, availableWidth, commentsHeight);
    CGFloat height = CGRectGetMaxY(self.comments.frame) + 18 * scale;
    self.line.frame = CGRectMake(20 * scale, height - 1, width - 40 * scale, .5);
    return height;
}
@end

@interface WCMomentsFeedPreview : UIScrollView
@property (nonatomic, strong) NSArray<WCMomentsPreviewPost *> *posts;
@property (nonatomic) NSUInteger revision;
@property (nonatomic) NSUInteger laidOutRevision;
@property (nonatomic) CGFloat lastWidth;
@property (nonatomic) UIUserInterfaceStyle lastStyle;
@property (nonatomic) UIAccessibilityContrast lastContrast;
@end
@implementation WCMomentsFeedPreview
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.revision = 1;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:WCGestureDidChangeNotification object:nil];
    self.alwaysBounceVertical = YES; self.backgroundColor = UIColor.systemBackgroundColor;
    self.posts = @[[[WCMomentsPreviewPost alloc] initWithVideo:NO], [[WCMomentsPreviewPost alloc] initWithVideo:YES]];
    for (UIView *post in self.posts) [self addSubview:post]; return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)changed:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf changed:notification]; }); return;
    }
    self.revision++; [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat y = 0, width = self.bounds.size.width;
    if (width <= 0) return;
    if (fabs(width - self.lastWidth) < .5 && self.revision == self.laidOutRevision &&
        self.lastStyle == self.traitCollection.userInterfaceStyle && self.lastContrast == self.traitCollection.accessibilityContrast) return;
    self.lastWidth = width; self.laidOutRevision = self.revision;
    self.lastStyle = self.traitCollection.userInterfaceStyle; self.lastContrast = self.traitCollection.accessibilityContrast;
    for (WCMomentsPreviewPost *post in self.posts) {
        CGFloat height = [post layoutForWidth:width]; post.frame = CGRectMake(0, y, width, height); y += height;
    }
    CGSize size = CGSizeMake(width, y + 16);
    if (!CGSizeEqualToSize(self.contentSize, size)) self.contentSize = size;
}
@end

static NSDictionary *WCMomentsPreviewNumber(NSString *title, NSString *key, double minimum, double maximum, double reset) {
    return @{@"title":title,@"key":key,@"minimum":@(minimum),@"maximum":@(maximum),@"reset":@(reset)};
}
static NSDictionary *WCMomentsPreviewSwitch(NSString *title, NSString *key) {
    return @{@"option":@{@"title":title,@"type":@"bool",@"key":key}};
}
UIViewController *WCGestureCreateMomentsFeedPreviewController(void) {
    NSArray *parameters = @[
        @{@"title":@"预览外观",@"themes":@[@"系统",@"浅色",@"深色"]},
        WCMomentsPreviewSwitch(@"朋友圈排版", WCGestureMomentsFeedEnabledKey),
        WCMomentsPreviewNumber(@"按钮大小 (%)", WCGestureMomentsFeedButtonSizeKey, 60, 180, 100),
        WCMomentsPreviewSwitch(@"独立点赞评论", WCGestureMomentsFeedActionsKey),
        WCMomentsPreviewSwitch(@"隐藏按钮文字", WCGestureMomentsFeedHideActionTextKey),
        WCMomentsPreviewSwitch(@"朋友圈转发", WCGestureMomentsForwardEnabledKey),
        WCMomentsPreviewSwitch(@"朋友圈圆角", WCGestureMomentsImageCornerEnabledKey),
        WCMomentsPreviewNumber(@"圆角程度", WCGestureMomentsImageCornerRadiusKey, 0, 40, 8),
        WCMomentsPreviewSwitch(@"完整显示定位", WCGestureMomentsFeedLocationKey),
        WCMomentsPreviewNumber(@"额外留白", WCGestureMomentsFeedSpacingKey, 0, 48, 8)
    ];
    UIViewController *controller = WCGestureCreateAdjustmentEditor(@"朋友圈预览", [WCMomentsFeedPreview new], parameters);
    controller.hidesBottomBarWhenPushed = YES; return controller;
}
