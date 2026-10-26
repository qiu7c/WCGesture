#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import "Sources/API/WCGestureInternal.h"

// Measured from the supplied 393pt WeChat view tree: a short message row is
// 53pt, its avatar is (9,2,42,42), and its content starts at (60,5).
// Metadata is laid out inside each row, never in the whole preview's bounds.
@interface WCPreviewMessageRow : UIView
@property (nonatomic, assign) BOOL sender;
@property (nonatomic, assign) BOOL revoked;
@property (nonatomic, assign) BOOL editing;
@property (nonatomic, assign) WCGesturePreviewKind kind;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) UIView *avatar;
@property (nonatomic, strong) UIView *bubble;
@property (nonatomic, strong) CAShapeLayer *bubbleShape;
@property (nonatomic, strong) UILabel *body;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *revokeLabel;
@property (nonatomic, strong) UIPanGestureRecognizer *timePan;
@property (nonatomic, strong) UIPanGestureRecognizer *revokePan;
@property (nonatomic, assign) CGPoint panStart;
- (CGFloat)heightForWidth:(CGFloat)width;
@end

@implementation WCPreviewMessageRow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _avatar = WCGestureCurrentUserAvatarView();
        _bubble = [UIView new];
        _bubbleShape = [CAShapeLayer layer]; [_bubble.layer addSublayer:_bubbleShape];
        _body = [UILabel new]; _body.numberOfLines = 0; _body.textColor = UIColor.labelColor;
        [_bubble addSubview:_body];
        _timeLabel = [UILabel new]; _revokeLabel = [UILabel new];
        _timePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)];
        _revokePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)];
        [_timeLabel addGestureRecognizer:_timePan]; [_revokeLabel addGestureRecognizer:_revokePan];
        for (UIView *view in @[_avatar, _bubble, _timeLabel, _revokeLabel]) [self addSubview:view];
    }
    return self;
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && [self.avatar.accessibilityIdentifier isEqualToString:@"com.qiu7c.onewx.preview.avatar-unavailable"]) {
        [self.avatar removeFromSuperview];
        self.avatar = WCGestureCurrentUserAvatarView();
        [self insertSubview:self.avatar atIndex:0];
        [self setNeedsLayout];
    }
}
- (CGSize)textSizeForWidth:(CGFloat)width {
    self.body.font = [UIFont systemFontOfSize:12]; self.body.text = self.text;
    return [self.body sizeThatFits:CGSizeMake(MAX(24, width - 144), CGFLOAT_MAX)];
}
- (CGFloat)heightForWidth:(CGFloat)width {
    CGSize text = [self textSizeForWidth:width];
    return MAX(53, ceil(text.height) + 20 + 12);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    // 42pt avatars are native control geometry, not the text-size percentage.
    self.avatar.frame = CGRectMake(self.sender ? width - 51 : 9, 2, 42, 42);
    [self.avatar layoutIfNeeded];
    WCGestureApplyGlobalAvatarRoundingToHeadView(self.avatar);
    CGSize text = [self textSizeForWidth:width];
    CGFloat bubbleWidth = MAX(45, ceil(text.width) + 24);
    CGFloat bubbleHeight = MAX(36, ceil(text.height) + 20);
    self.bubble.frame = CGRectMake(self.sender ? width - 60 - bubbleWidth : 60, 5, bubbleWidth, bubbleHeight);
    self.body.frame = CGRectMake(12, 10, bubbleWidth - 24, MAX(16, bubbleHeight - 20));
    UIColor *fill = self.sender ? [UIColor colorWithRed:0.58 green:0.91 blue:0.43 alpha:1] : UIColor.secondarySystemGroupedBackgroundColor;
    if (self.sender) self.body.textColor = UIColor.blackColor; else self.body.textColor = UIColor.labelColor;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bubble.bounds cornerRadius:5];
    CGFloat tailX = self.sender ? bubbleWidth : 0;
    [path moveToPoint:CGPointMake(tailX, 10)];
    [path addLineToPoint:CGPointMake(tailX + (self.sender ? 5 : -5), 15)];
    [path addLineToPoint:CGPointMake(tailX, 20)]; [path closePath];
    self.bubbleShape.frame = self.bubble.bounds; self.bubbleShape.path = path.CGPath;
    self.bubbleShape.fillColor = [fill resolvedColorWithTraitCollection:self.traitCollection].CGColor;

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL side = [defaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    WCGestureMessageTimeStyleLabel(self.timeLabel, self.date);
    CGSize size = [self.timeLabel sizeThatFits:CGSizeMake(160, 26)];
    size.width = MIN(118, MAX(50, ceil(size.width) + 4));
    size.height = MAX(12, ceil(self.timeLabel.font.pointSize * 1.5));
    self.timeLabel.frame = side ? WCGestureMessageTimeSideFrame(self.bounds, self.bubble.frame, self.sender, size)
        : WCGestureMessageTimeAvatarFrame(self.bounds, self.avatar.frame, size);
    self.timeLabel.hidden = (self.kind != WCGesturePreviewMessageTime && !WCGestureEnabled(WCGestureMessageTimeEnabledKey)) || CGRectIsEmpty(self.timeLabel.frame);
    self.timeLabel.userInteractionEnabled = self.editing && self.kind == WCGesturePreviewMessageTime && !self.timeLabel.hidden;
    self.timePan.enabled = self.timeLabel.userInteractionEnabled;

    BOOL prompt = self.revoked && (self.kind == WCGesturePreviewAntiRevoke || WCGestureEnabled(WCGestureAntiRevokeEnabledKey));
    WCGestureAntiRevokeStyleLabel(self.revokeLabel);
    CGRect proposed = WCGestureAntiRevokeSideFrame(self.bounds, self.bubble.frame, self.sender,
        [self.revokeLabel sizeThatFits:CGSizeMake(160, 18)]);
    if (!self.timeLabel.hidden && !CGRectIsEmpty(proposed) && CGRectIntersectsRect(CGRectInset(proposed, -2, -2), self.timeLabel.frame)) {
        CGFloat below = CGRectGetMaxY(self.timeLabel.frame) + 2;
        CGFloat above = CGRectGetMinY(self.timeLabel.frame) - proposed.size.height - 2;
        if (below + proposed.size.height <= CGRectGetHeight(self.bounds)) proposed.origin.y = below;
        else if (above >= 0) proposed.origin.y = above;
        else proposed = CGRectZero;
    }
    self.revokeLabel.frame = proposed;
    self.revokeLabel.hidden = !prompt || [defaults integerForKey:WCGestureAntiRevokePromptStyleKey] != 1 || CGRectIsEmpty(proposed);
    self.revokeLabel.userInteractionEnabled = self.editing && self.kind == WCGesturePreviewAntiRevoke && !self.revokeLabel.hidden;
    self.revokePan.enabled = self.revokeLabel.userInteractionEnabled;
}
- (void)dragged:(UIPanGestureRecognizer *)gesture {
    BOOL revoke = gesture == self.revokePan;
    BOOL avatar = !revoke && ![NSUserDefaults.standardUserDefaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    NSString *xKey = revoke ? WCGestureAntiRevokeSideOffsetXKey : WCGestureMessageTimeOffsetXKey;
    NSString *yKey = revoke ? WCGestureAntiRevokeSideOffsetYKey : (avatar ? WCGestureMessageTimeAvatarSpacingKey : WCGestureMessageTimeOffsetYKey);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (gesture.state == UIGestureRecognizerStateBegan) self.panStart = CGPointMake([defaults doubleForKey:xKey], [defaults doubleForKey:yKey]);
    CGPoint translation = [gesture translationInView:self];
    if (!avatar) [defaults setDouble:MIN(80, MAX(-80, self.panStart.x + translation.x * (self.sender ? 1 : -1))) forKey:xKey];
    [defaults setDouble:MIN(avatar ? 8 : 80, MAX(avatar ? -6 : -80, self.panStart.y + translation.y)) forKey:yKey];
    [self setNeedsLayout]; WCGestureSettingsPostChange(yKey);
}
@end

@interface WCChatPreview : UIView
@property (nonatomic, assign) WCGesturePreviewKind kind;
@property (nonatomic, assign) BOOL editing;
@property (nonatomic, assign) NSUInteger inputLines;
@property (nonatomic, copy) void (^backHandler)(void);
@property (nonatomic, copy) void (^controlsHandler)(void);
@property (nonatomic, strong) UIView *navigation;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) WCGestureChatTopCapsuleView *topProfile;
@property (nonatomic, strong) WCGestureChatTopCapsuleView *topActions;
@property (nonatomic, strong) UIView *pinnedHeader;
@property (nonatomic, strong) UILabel *pinnedLabel;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *controlsButton;
@property (nonatomic, strong) UIScrollView *messages;
@property (nonatomic, strong) UILabel *separatorTime;
@property (nonatomic, strong) UILabel *localPrompt;
@property (nonatomic, strong) NSArray<WCPreviewMessageRow *> *rows;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UIView *inputField;
@property (nonatomic, strong) UILabel *placeholder;
@property (nonatomic, strong) NSArray<UIImageView *> *inputIcons;
@property (nonatomic, assign) CGSize lastViewport;
@property (nonatomic, assign) CGFloat lastContentHeight;
@end

@implementation WCChatPreview
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _inputLines = 1;
        _navigation = [UIView new]; _navigation.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        _heading = [UILabel new]; _heading.textAlignment = NSTextAlignmentCenter;
        _heading.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _heading.textColor = UIColor.labelColor;
        _heading.adjustsFontSizeToFitWidth = YES; _heading.minimumScaleFactor = 0.8;
        _backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_backButton setImage:WCGestureSettingsBackImage() forState:UIControlStateNormal];
        [_backButton addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
        _backButton.accessibilityLabel = @"返回设置";
        _controlsButton = [UIButton buttonWithType:UIButtonTypeSystem]; [_controlsButton setTitle:@"调节" forState:UIControlStateNormal];
        [_controlsButton addTarget:self action:@selector(controls) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *view in @[_heading, _backButton, _controlsButton]) [_navigation addSubview:view];
        _messages = [UIScrollView new]; _messages.alwaysBounceVertical = YES;
        _messages.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _separatorTime = [UILabel new]; _separatorTime.text = @"16:32";
        _separatorTime.font = [UIFont systemFontOfSize:12]; _separatorTime.textColor = UIColor.secondaryLabelColor;
        _separatorTime.textAlignment = NSTextAlignmentCenter; [_messages addSubview:_separatorTime];
        _localPrompt = [UILabel new]; _localPrompt.numberOfLines = 0; _localPrompt.textAlignment = NSTextAlignmentCenter;
        _localPrompt.font = [UIFont systemFontOfSize:12]; [_messages addSubview:_localPrompt];
        NSArray *samples = @[@{ @"text": @"你好", @"sender": @YES }, @{ @"text": @"收到", @"sender": @NO },
            @{ @"text": @"看一下时间", @"sender": @YES }, @{ @"text": @"这是一条消息", @"sender": @NO, @"revoked": @YES },
            @{ @"text": @"长消息也使用独立的消息行。调节时间的位置时，可以一起检查头像下方和消息旁的显示效果。", @"sender": @YES },
            @{ @"text": @"预览不会发送消息", @"sender": @NO }];
        NSMutableArray *rows = [NSMutableArray array];
        NSDate *baseDate = [NSCalendar.currentCalendar dateBySettingHour:16 minute:32 second:45 ofDate:NSDate.date options:0];
        for (NSUInteger i = 0; i < samples.count; i++) {
            WCPreviewMessageRow *row = [WCPreviewMessageRow new]; row.text = samples[i][@"text"];
            row.sender = [samples[i][@"sender"] boolValue]; row.revoked = [samples[i][@"revoked"] boolValue];
            row.date = [baseDate dateByAddingTimeInterval:i * 10];
            [_messages addSubview:row]; [rows addObject:row];
            [_messages.panGestureRecognizer requireGestureRecognizerToFail:row.timePan];
            [_messages.panGestureRecognizer requireGestureRecognizerToFail:row.revokePan];
        }
        _rows = rows;
        _inputBar = [UIView new]; _inputBar.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        _inputField = [UIView new]; _inputField.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
        _inputField.layer.cornerRadius = 5; [_inputBar addSubview:_inputField];
        _placeholder = [UILabel new]; _placeholder.text = @"示例聊天 · 右上角调节";
        _placeholder.font = [UIFont systemFontOfSize:13]; _placeholder.textColor = UIColor.tertiaryLabelColor; [_inputField addSubview:_placeholder];
        NSMutableArray *icons = [NSMutableArray array];
        for (NSString *name in @[@"waveform.circle", @"face.smiling", @"plus.circle"]) {
            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:name]];
            icon.tintColor = UIColor.labelColor; icon.contentMode = UIViewContentModeScaleAspectFit;
            [_inputBar addSubview:icon]; [icons addObject:icon];
        }
        _inputIcons = icons;
        for (UIView *view in @[_messages, _navigation, _inputBar]) [self addSubview:view];
    }
    return self;
}
- (void)ensureTopCapsules {
    if (self.topProfile) return;
    _topProfile = [[WCGestureChatTopCapsuleView alloc] initWithProfile:YES];
    _topActions = [[WCGestureChatTopCapsuleView alloc] initWithProfile:NO];
    [_topProfile setAvatarView:WCGestureCurrentUserAvatarView()];
    __weak typeof(self) weakSelf = self;
    _topProfile.backAction = ^{ [weakSelf back]; };
    _topActions.moreAction = ^{ [weakSelf controls]; };
    _topActions.searchAction = ^{ [weakSelf controls]; };
        [_navigation addSubview:_topProfile]; [_navigation addSubview:_topActions];
    _pinnedHeader = [UIView new]; _pinnedLabel = [UILabel new];
    _pinnedLabel.text = @"置顶消息  ·  你好"; _pinnedLabel.textColor = UIColor.labelColor;
    [_pinnedHeader addSubview:_pinnedLabel]; [_navigation addSubview:_pinnedHeader];
}
- (void)back { if (self.backHandler) self.backHandler(); }
- (void)controls { if (self.controlsHandler) self.controlsHandler(); }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    if (width < 1 || height < 1) return;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.08 alpha:1] : [UIColor colorWithWhite:0.93 alpha:1];
    }];
    self.navigation.backgroundColor = self.backgroundColor;
    self.inputBar.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return [UIColor colorWithWhite:traits.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.97 alpha:1];
    }];
    self.inputField.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    CGFloat top = self.safeAreaInsets.top;
    CGFloat navigationHeight = top + 44;
    self.navigation.frame = CGRectMake(0, 0, width, navigationHeight);
    self.backButton.frame = CGRectMake(4, top, 44, 44);
    self.controlsButton.frame = CGRectMake(width - 60, top, 56, 44);
    self.heading.frame = CGRectMake(52, top, MAX(0, width - 116), 44);
    self.heading.text = @[@"聊天预览 · 消息时间", @"聊天预览 · 防撤回", @"聊天预览 · 输入圆角", @"聊天预览 · 胶囊顶栏"][self.kind];
    BOOL capsule = self.kind == WCGesturePreviewChatTopBar || WCGestureEnabled(WCGestureChatTopBarCapsuleEnabledKey);
    self.heading.hidden = capsule; self.backButton.hidden = capsule; self.controlsButton.hidden = capsule;
    self.topProfile.hidden = !capsule; self.topActions.hidden = !capsule;
    self.pinnedHeader.hidden = !capsule;
    if (capsule) {
        [self ensureTopCapsules];
        self.topProfile.hidden = NO; self.topActions.hidden = NO; self.pinnedHeader.hidden = NO;
        self.navigation.backgroundColor = UIColor.clearColor;
        BOOL search = WCGestureEnabled(WCGestureChatSearchEnabledKey);
        NSString *userName = WCCurrentUserWXID();
        NSString *name = WCGesturePrivateContactDisplayName(userName.length ? WCPrivateContact(userName) : nil, @"我");
        CGSize leftSize = [self.topProfile configureWithName:name typing:NO search:NO moreImage:nil menu:nil maximumWidth:MAX(90 * WCGestureChatTopBarScale(), MIN(205 * WCGestureChatTopBarScale(), width - (search ? 76 : 40) * WCGestureChatTopBarScale() - 48))];
        CGSize rightSize = [self.topActions configureWithName:@"" typing:NO search:search moreImage:nil menu:nil maximumWidth:76 * WCGestureChatTopBarScale()];
        self.topProfile.frame = (CGRect){CGPointMake(16, top), leftSize};
        self.topActions.frame = (CGRect){CGPointMake(width - 16 - rightSize.width, top), rightSize};
        CGFloat scale = WCGestureChatTopBarScale();
        self.pinnedHeader.frame = CGRectMake(0, navigationHeight + 4 * scale, width, 40 * scale);
        self.pinnedLabel.font = [UIFont systemFontOfSize:13 * scale];
        self.pinnedLabel.frame = CGRectInset(self.pinnedHeader.bounds, 20 * scale, 0);
        WCGestureChatPinnedGlassApply(self.pinnedHeader, YES);
        navigationHeight += 44 * scale;
        self.navigation.frame = CGRectMake(0, 0, width, navigationHeight);
    }
    BOOL rounding = self.kind == WCGesturePreviewInputRounding;
    CGFloat fieldHeight = 33 + 18 * (MAX(1, self.inputLines) - 1);
    CGFloat inputHeight = fieldHeight + 12 + self.safeAreaInsets.bottom;
    CGFloat inputBottom = height;
    self.inputBar.frame = CGRectMake(0, inputBottom - inputHeight, width, inputHeight);
    CGFloat iconY = fieldHeight - 26.5;
    self.inputIcons[0].frame = CGRectMake(8, iconY, 32, 32);
    self.inputIcons[1].frame = CGRectMake(width - 80, iconY, 32, 32);
    self.inputIcons[2].frame = CGRectMake(width - 40, iconY, 32, 32);
    self.inputField.frame = CGRectMake(48, 6, MAX(0, width - 136), fieldHeight);
    self.placeholder.numberOfLines = self.inputLines;
    self.placeholder.text = self.inputLines > 1 ? @"多行输入预览\n观察圆角随高度变化\n不会发送消息" : @"示例聊天 · 右上角调节";
    self.placeholder.frame = CGRectInset(self.inputField.bounds, 8, 0);
    WCGestureChatInputRoundingApplyToViews(self.inputField, self.inputBar, rounding);
    CGFloat messagesTop = capsule ? 0 : navigationHeight;
    self.messages.frame = CGRectMake(0, messagesTop, width, MAX(0, CGRectGetMinY(self.inputBar.frame) - messagesTop));
    self.separatorTime.frame = CGRectMake(0, 0, width, 41);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL local = [defaults integerForKey:WCGestureAntiRevokePromptStyleKey] == 0 &&
        (self.kind == WCGesturePreviewAntiRevoke || WCGestureEnabled(WCGestureAntiRevokeEnabledKey));
    CGFloat y = 41;
    self.localPrompt.hidden = !local;
    for (WCPreviewMessageRow *row in self.rows) {
        row.kind = self.kind; row.editing = self.editing;
        row.frame = CGRectMake(0, y, width, [row heightForWidth:width]); [row setNeedsLayout];
        y += CGRectGetHeight(row.frame);
        if (local && row.revoked) {
            NSString *templateText = [defaults stringForKey:WCGestureAntiRevokeLocalTemplateKey];
            if (!templateText.length) templateText = WCGestureAntiRevokeDefaultTemplate(NO);
            self.localPrompt.text = WCGestureAntiRevokeFormatPrompt(templateText, @"预览好友", row.text, row.date);
            self.localPrompt.textColor = WCGestureDynamicColorForDefaultsKeys(WCGestureAntiRevokeLocalLightTextColorKey,
                WCGestureAntiRevokeLocalDarkTextColorKey, WCGestureAntiRevokeLocalTextColorKey, UIColor.secondaryLabelColor, UIColor.secondaryLabelColor);
            CGFloat promptHeight = [self.localPrompt sizeThatFits:CGSizeMake(MAX(0, width - 40), CGFLOAT_MAX)].height + 16;
            self.localPrompt.frame = CGRectMake(20, y, MAX(0, width - 40), promptHeight); y += promptHeight;
        }
    }
    CGFloat visibleHeight = CGRectGetHeight(self.messages.bounds);
    self.messages.contentSize = CGSizeMake(width, y + 12);
    self.messages.contentInset = UIEdgeInsetsMake(MAX(capsule ? navigationHeight : 0, visibleHeight - y - 12), 0, 0, 0);
    self.messages.scrollIndicatorInsets = UIEdgeInsetsZero;
    if ((!CGSizeEqualToSize(self.lastViewport, self.messages.bounds.size) || self.lastContentHeight != y) && !self.messages.dragging) {
        self.messages.contentOffset = CGPointMake(0, MAX(-self.messages.contentInset.top, y + 12 - CGRectGetHeight(self.messages.bounds)));
    }
    self.lastViewport = self.messages.bounds.size; self.lastContentHeight = y;
}
@end

UIView *WCGestureCreateChatPreview(WCGesturePreviewKind kind) {
    WCChatPreview *view = [WCChatPreview new]; view.kind = kind; return view;
}
void WCGestureSetPreviewEditing(UIView *preview, BOOL editing) {
    if ([preview isKindOfClass:WCChatPreview.class]) { ((WCChatPreview *)preview).editing = editing; [preview setNeedsLayout]; }
}
void WCGestureSetChatPreviewKind(UIView *preview, WCGesturePreviewKind kind) {
    if ([preview isKindOfClass:WCChatPreview.class]) { ((WCChatPreview *)preview).kind = kind; [preview setNeedsLayout]; }
}
void WCGestureSetPreviewNavigation(UIView *preview, void (^back)(void), void (^controls)(void)) {
    if ([preview isKindOfClass:WCChatPreview.class]) {
        ((WCChatPreview *)preview).backHandler = back; ((WCChatPreview *)preview).controlsHandler = controls;
    }
}
void WCGestureSetPreviewInputLines(UIView *preview, NSUInteger lines) {
    if ([preview isKindOfClass:WCChatPreview.class]) {
        ((WCChatPreview *)preview).inputLines = MIN(5, MAX(1, lines)); [preview setNeedsLayout];
    }
}
