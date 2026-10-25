#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCChatPreview : UIView
@property (nonatomic, assign) WCGesturePreviewKind kind;
@property (nonatomic, assign) BOOL editing;
@property (nonatomic, assign) CGPoint panStart;
@property (nonatomic, strong) UILabel *caption;
@property (nonatomic, strong) UILabel *localPrompt;
@property (nonatomic, strong) NSArray<UILabel *> *avatars;
@property (nonatomic, strong) NSArray<UILabel *> *bubbles;
@property (nonatomic, strong) NSArray<UILabel *> *metadata;
@property (nonatomic, strong) NSArray<UILabel *> *times;
@end

@implementation WCChatPreview
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
        self.layer.cornerRadius = 16;
        _caption = [UILabel new];
        _caption.font = [UIFont systemFontOfSize:12];
        _caption.textColor = UIColor.secondaryLabelColor;
        [self addSubview:_caption];
        _localPrompt = [UILabel new];
        _localPrompt.font = [UIFont systemFontOfSize:12];
        _localPrompt.numberOfLines = 0;
        _localPrompt.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_localPrompt];
        NSMutableArray *avatars = [NSMutableArray array], *bubbles = [NSMutableArray array];
        NSMutableArray *metadata = [NSMutableArray array], *times = [NSMutableArray array];
        for (NSUInteger i = 0; i < 2; i++) {
            UILabel *avatar = [UILabel new];
            avatar.text = i ? @"我" : @"对";
            avatar.textColor = UIColor.labelColor;
            avatar.textAlignment = NSTextAlignmentCenter;
            avatar.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.13];
            avatar.layer.cornerRadius = 9; avatar.layer.masksToBounds = YES;
            [self addSubview:avatar]; [avatars addObject:avatar];
            UILabel *bubble = [UILabel new];
            bubble.textColor = UIColor.labelColor;
            bubble.textAlignment = NSTextAlignmentCenter;
            bubble.layer.cornerRadius = 8; bubble.layer.masksToBounds = YES;
            bubble.backgroundColor = i ? [UIColor.systemGreenColor colorWithAlphaComponent:0.3] : UIColor.secondarySystemGroupedBackgroundColor;
            [self addSubview:bubble]; [bubbles addObject:bubble];
            UILabel *label = [UILabel new]; label.tag = i;
            [label addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)]];
            [self addSubview:label]; [metadata addObject:label];
            UILabel *time = [UILabel new]; [self addSubview:time]; [times addObject:time];
        }
        _avatars = avatars; _bubbles = bubbles; _metadata = metadata; _times = times;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.caption.font = [UIFont systemFontOfSize:12 * WCGestureSettingsScaleFactor()];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL revoke = self.kind == WCGesturePreviewAntiRevoke;
    BOOL local = revoke && [defaults integerForKey:WCGestureAntiRevokePromptStyleKey] == 0;
    BOOL enabled = [defaults boolForKey:revoke ? WCGestureAntiRevokeEnabledKey : WCGestureMessageTimeEnabledKey];
    self.caption.text = self.editing ? @"拖动文字或用下方控件精调 · 自动保存" : @"效果预览（示意）";
    if (self.kind == WCGesturePreviewMessageTime && !self.editing) self.caption.text = enabled ? @"消息时间预览（已开启）" : @"消息时间预览（仅预览）";
    self.caption.frame = CGRectMake(12, 8, MAX(0, self.bounds.size.width - 24), 20);
    CGFloat scale = self.kind == WCGesturePreviewLayout ? WCGestureLayoutScaleFactor() : 1;
    BOOL sideTime = [defaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    for (NSUInteger i = 0; i < 2; i++) {
        UILabel *avatar = self.avatars[i], *bubble = self.bubbles[i], *label = self.metadata[i], *time = self.times[i];
        avatar.hidden = bubble.hidden = local && i == 1;
        CGFloat rowY = 44 + i * 88;
        avatar.frame = CGRectMake(i ? self.bounds.size.width - 44 : 12, rowY, 32, 32);
        CGFloat width = MIN(116 * scale, MAX(48, self.bounds.size.width - 180));
        bubble.frame = CGRectMake(i ? CGRectGetMinX(avatar.frame) - 8 - width : CGRectGetMaxX(avatar.frame) + 8, rowY, width, 42 * scale);
        bubble.text = i ? @"这是一条回复" : @"这是一条消息";
        bubble.font = [UIFont systemFontOfSize:14 * scale];
        WCGestureMessageTimeStyleLabel(time, [NSDate dateWithTimeIntervalSince1970:1700000000 + i * 60]);
        CGSize timeSize = [time sizeThatFits:CGSizeMake(160, 26)];
        timeSize.width = MIN(118, MAX(50, timeSize.width + 4));
        timeSize.height = MAX(12, ceil(time.font.pointSize * 1.5));
        time.frame = sideTime ? WCGestureMessageTimeSideFrame(self.bounds, bubble.frame, i == 1, timeSize)
            : WCGestureMessageTimeAvatarFrame(self.bounds, avatar.frame, timeSize);
        time.hidden = !revoke || local || !WCGestureEnabled(WCGestureMessageTimeEnabledKey) || CGRectIsEmpty(time.frame);
        if (revoke) {
            WCGestureAntiRevokeStyleLabel(label);
            label.frame = WCGestureAntiRevokeSideFrame(self.bounds, bubble.frame, i == 1, [label sizeThatFits:CGSizeMake(160, 18)]);
            if (!time.hidden && CGRectIntersectsRect(CGRectInset(label.frame, -2, -2), time.frame)) {
                CGRect adjusted = label.frame;
                CGFloat below = CGRectGetMaxY(time.frame) + 2;
                CGFloat above = CGRectGetMinY(time.frame) - adjusted.size.height - 2;
                if (below + adjusted.size.height <= self.bounds.size.height) adjusted.origin.y = below;
                else if (above >= 0) adjusted.origin.y = above;
                else adjusted = CGRectZero;
                label.frame = adjusted;
            }
            label.hidden = local || CGRectIsEmpty(label.frame);
        } else {
            WCGestureMessageTimeStyleLabel(label, [NSDate dateWithTimeIntervalSince1970:1700000000 + i * 60]);
            label.frame = time.frame;
            label.hidden = CGRectIsEmpty(label.frame) || (self.kind == WCGesturePreviewLayout && !WCGestureEnabled(WCGestureMessageTimeEnabledKey));
        }
        label.userInteractionEnabled = self.editing && !label.hidden;
    }
    self.localPrompt.hidden = !local;
    if (local) {
        NSString *text = [defaults stringForKey:WCGestureAntiRevokeLocalTemplateKey];
        if (!text.length) text = WCGestureAntiRevokeDefaultTemplate(NO);
        NSDictionary *fields = @{ @"用户名": @"好友", @"内容": @"这是一条消息", @"yyyy": @"2026", @"MM": @"10", @"dd": @"25", @"HH": @"12", @"mm": @"30", @"ss": @"00" };
        for (NSString *key in fields) text = [text stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key] withString:fields[key]];
        self.localPrompt.text = text;
        self.localPrompt.textColor = WCGestureDynamicColorForDefaultsKeys(WCGestureAntiRevokeLocalLightTextColorKey, WCGestureAntiRevokeLocalDarkTextColorKey, WCGestureAntiRevokeLocalTextColorKey, UIColor.secondaryLabelColor, UIColor.secondaryLabelColor);
        self.localPrompt.frame = CGRectMake(16, 100, MAX(0, self.bounds.size.width - 32), MAX(0, self.bounds.size.height - 110));
    }
}
- (void)dragged:(UIPanGestureRecognizer *)gesture {
    BOOL revoke = self.kind == WCGesturePreviewAntiRevoke;
    BOOL avatar = !revoke && ![NSUserDefaults.standardUserDefaults boolForKey:WCGestureMessageTimeBubbleSideKey];
    NSString *xKey = revoke ? WCGestureAntiRevokeSideOffsetXKey : WCGestureMessageTimeOffsetXKey;
    NSString *yKey = revoke ? WCGestureAntiRevokeSideOffsetYKey : (avatar ? WCGestureMessageTimeAvatarSpacingKey : WCGestureMessageTimeOffsetYKey);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (gesture.state == UIGestureRecognizerStateBegan) self.panStart = CGPointMake([defaults doubleForKey:xKey], [defaults doubleForKey:yKey]);
    CGPoint translation = [gesture translationInView:self];
    if (!avatar) {
        CGFloat direction = gesture.view.tag == 1 ? 1 : -1;
        [defaults setDouble:MIN(80, MAX(-80, self.panStart.x + translation.x * direction)) forKey:xKey];
    }
    [defaults setDouble:MIN(avatar ? 8 : 80, MAX(avatar ? -6 : -80, self.panStart.y + translation.y)) forKey:yKey];
    [self setNeedsLayout];
    WCGestureSettingsPostChange(yKey);
}
@end

UIView *WCGestureCreateChatPreview(WCGesturePreviewKind kind) {
    WCChatPreview *view = [[WCChatPreview alloc] initWithFrame:CGRectZero]; view.kind = kind; return view;
}
void WCGestureSetPreviewEditing(UIView *preview, BOOL editing) {
    if ([preview isKindOfClass:WCChatPreview.class]) { ((WCChatPreview *)preview).editing = editing; [preview setNeedsLayout]; }
}
