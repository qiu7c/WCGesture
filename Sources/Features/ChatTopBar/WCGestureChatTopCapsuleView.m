#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static CGFloat WCTopValue(NSString *key, CGFloat fallback, CGFloat low, CGFloat high) {
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:key];
    double value = [stored respondsToSelector:@selector(doubleValue)] ? [stored doubleValue] : fallback;
    return isfinite(value) ? MIN(high, MAX(low, value)) : fallback;
}

@interface WCGestureChatTopCapsuleView ()
@property (nonatomic, assign) BOOL profile;
@property (nonatomic, strong) UIView *glass;
@property (nonatomic, strong) UIView *avatar;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *typingLabel;
@property (nonatomic, strong) UIButton *firstButton;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, assign) CGFloat avatarSize;
@property (nonatomic, assign) CGSize preferredSize;
@property (nonatomic, copy) NSArray *configuration;
@end

@implementation WCGestureChatTopCapsuleView
- (instancetype)initWithProfile:(BOOL)profile {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _profile = profile;
    _glass = WCGestureCreateChatGlassView();
    _glass.translatesAutoresizingMaskIntoConstraints = YES;
    [self addSubview:_glass];
    UIView *content = WCGestureChatGlassContent(_glass);
    _firstButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _firstButton.tintColor = UIColor.labelColor;
    [_firstButton setImage:[UIImage systemImageNamed:profile ? @"chevron.left" : @"magnifyingglass"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:profile ? 17 : 18 weight:UIImageSymbolWeightRegular]] forState:UIControlStateNormal];
    _firstButton.accessibilityLabel = profile ? @"返回" : @"搜索聊天记录";
    [_firstButton addTarget:self action:@selector(first) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_firstButton];
    if (profile) {
        _nameLabel = [UILabel new]; _nameLabel.textColor = UIColor.labelColor;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.adjustsFontForContentSizeCategory = YES;
        [content addSubview:_nameLabel];
        _typingLabel = [UILabel new]; _typingLabel.text = @"•••";
        _typingLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        _typingLabel.textColor = UIColor.systemGreenColor;
        _typingLabel.accessibilityLabel = @"对方正在输入";
        _typingLabel.isAccessibilityElement = YES;
        [content addSubview:_typingLabel];
    } else {
        _moreButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _moreButton.tintColor = UIColor.labelColor; _moreButton.accessibilityLabel = @"更多";
        [_moreButton addTarget:self action:@selector(more) forControlEvents:UIControlEventTouchUpInside];
        [content addSubview:_moreButton];
    }
    return self;
}
- (void)first {
    if (self.profile) { if (self.backAction) self.backAction(); }
    else if (self.searchAction) self.searchAction();
}
- (void)more { if (self.moreAction) self.moreAction(); }
- (void)setAvatarView:(UIView *)avatar {
    if (self.avatar == avatar) return;
    id imageView = [avatar isKindOfClass:UIImageView.class] ? avatar
        : WCTweakValueForSelectorNames(avatar, @[@"headImageView", @"imageView"]);
    if ([imageView isKindOfClass:UIImageView.class] && ((UIImageView *)imageView).image) {
        // A loaded image needs one circular viewport, avoiding the native host's extra crop.
        UIImageView *plain = [[UIImageView alloc] initWithImage:((UIImageView *)imageView).image];
        plain.contentMode = UIViewContentModeScaleAspectFit;
        avatar = plain;
    }
    [self.avatar removeFromSuperview];
    self.avatar = avatar;
    avatar.userInteractionEnabled = NO;
    avatar.translatesAutoresizingMaskIntoConstraints = YES;
    WCGestureExcludeHeadViewFromGlobalAvatarRounding(avatar);
    [WCGestureChatGlassContent(self.glass) addSubview:avatar];
    [self setNeedsLayout];
}
- (CGSize)configureWithName:(NSString *)name typing:(BOOL)typing search:(BOOL)search
                 moreImage:(UIImage *)image menu:(UIMenu *)menu maximumWidth:(CGFloat)width {
    WCGestureConfigureChatGlass(self.glass);
    NSArray *configuration = @[name, @(typing), @(search), @(width),
        @([NSUserDefaults.standardUserDefaults doubleForKey:WCGestureChatTopBarAvatarSizeKey]),
        @([NSUserDefaults.standardUserDefaults doubleForKey:WCGestureChatTopBarNicknameSizeKey]),
        self.traitCollection.preferredContentSizeCategory, image ?: NSNull.null, menu ?: NSNull.null];
    if ([self.configuration isEqualToArray:configuration]) return self.preferredSize;
    self.configuration = configuration;
    self.avatarSize = WCTopValue(WCGestureChatTopBarAvatarSizeKey, 30, 24, 34);
    CGFloat fontSize = WCTopValue(WCGestureChatTopBarNicknameSizeKey, 15, 12, 18);
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:
        [UIFont systemFontOfSize:fontSize] maximumPointSize:22];
    self.nameLabel.font = font;
    if (![self.nameLabel.text isEqualToString:name]) self.nameLabel.text = name;
    self.typingLabel.hidden = !typing;
    self.firstButton.hidden = !self.profile && !search;
    UIImage *moreImage = image ?: [UIImage systemImageNamed:@"ellipsis"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightRegular]];
    if (moreImage.size.width > 22 || moreImage.size.height > 22) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20, 20)];
        UIImage *source = moreImage;
        moreImage = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
            [source drawInRect:CGRectMake(0, 0, 20, 20)];
        }];
    }
    [self.moreButton setImage:[moreImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    self.moreButton.menu = menu;
    self.moreButton.showsMenuAsPrimaryAction = menu != nil;
    CGFloat measured = ceil([name sizeWithAttributes:@{NSFontAttributeName:font}].width);
    CGFloat desired = self.profile ? 44 + self.avatarSize + 8 + measured + (typing ? 22 : 0) + 12 : (search ? 88 : 44);
    CGSize nextSize = CGSizeMake(MIN(MAX(0, width), desired), 44);
    if (!CGSizeEqualToSize(self.preferredSize, nextSize)) {
        self.preferredSize = nextSize;
        [self invalidateIntrinsicContentSize];
    }
    [self setNeedsLayout];
    return self.preferredSize;
}
- (CGSize)intrinsicContentSize { return self.preferredSize; }
- (CGSize)sizeThatFits:(CGSize)size { return self.preferredSize; }
- (void)layoutSubviews {
    [super layoutSubviews];
    // All controls retain a 44pt touch target.
    self.glass.frame = self.bounds;
    CGFloat height = CGRectGetHeight(self.bounds), width = CGRectGetWidth(self.bounds);
    self.firstButton.frame = CGRectMake(0, 0, 44, height);
    if (self.profile) {
        self.avatar.frame = CGRectMake(44, (height - self.avatarSize) / 2, self.avatarSize, self.avatarSize);
        self.avatar.clipsToBounds = YES;
        self.avatar.layer.cornerRadius = self.avatarSize / 2;
        self.avatar.layer.cornerCurve = kCACornerCurveContinuous;
        CGFloat x = CGRectGetMaxX(self.avatar.frame) + 8;
        CGFloat typingWidth = self.typingLabel.hidden ? 0 : 22;
        self.nameLabel.frame = CGRectMake(x, 0, MAX(0, width - x - 12 - typingWidth), height);
        self.typingLabel.frame = CGRectMake(width - 30, 0, 20, height);
    } else {
        self.moreButton.frame = CGRectMake(MAX(0, width - 44), 0, 44, height);
    }
}
@end
