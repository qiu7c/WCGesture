#import "Sources/API/WCGestureInternal.h"

@interface WCChatPreview : UIView
@property (nonatomic, assign) WCGesturePreviewKind kind;
@property (nonatomic, strong) UILabel *caption;
@property (nonatomic, strong) NSArray<UILabel *> *bubbles;
@property (nonatomic, strong) NSArray<UILabel *> *metadata;
@end

@implementation WCChatPreview
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
        self.layer.cornerRadius = 12;
        self.userInteractionEnabled = NO;
        _caption = [UILabel new];
        _caption.font = [UIFont systemFontOfSize:12];
        _caption.textColor = UIColor.secondaryLabelColor;
        [self addSubview:_caption];
        NSMutableArray *bubbles = [NSMutableArray array];
        NSMutableArray *metadata = [NSMutableArray array];
        for (NSUInteger i = 0; i < 2; i++) {
            UILabel *bubble = [UILabel new];
            bubble.textAlignment = NSTextAlignmentCenter;
            bubble.layer.cornerRadius = 8;
            bubble.layer.masksToBounds = YES;
            bubble.backgroundColor = i ? [UIColor.systemGreenColor colorWithAlphaComponent:0.3] : UIColor.secondarySystemGroupedBackgroundColor;
            [self addSubview:bubble];
            [bubbles addObject:bubble];
            UILabel *label = [UILabel new];
            [self addSubview:label];
            [metadata addObject:label];
        }
        _bubbles = bubbles;
        _metadata = metadata;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.caption.text = @"效果预览（示意）";
    if (self.kind == WCGesturePreviewMessageTime) {
        self.caption.text = WCGestureEnabled(WCGestureMessageTimeEnabledKey)
            ? @"消息时间预览（已开启）" : @"消息时间预览（仅预览，尚未开启）";
    }
    self.caption.frame = CGRectMake(12, 8, MAX(0, self.bounds.size.width - 24), 20);
    CGFloat scale = self.kind == WCGesturePreviewLayout ? WCGestureLayoutScaleFactor() : 1.0;
    for (NSUInteger i = 0; i < 2; i++) {
        UILabel *bubble = self.bubbles[i];
        UILabel *label = self.metadata[i];
        WCGestureMessageTimeStyleLabel(label, [NSDate dateWithTimeIntervalSince1970:1700000000 + i * 60]);
        CGSize timeSize = [label sizeThatFits:CGSizeMake(180, 24)];
        CGFloat reservedWidth = MAX(135.0, timeSize.width + 28.0);
        CGFloat width = MIN(130 * scale, MAX(0, self.bounds.size.width - reservedWidth));
        CGFloat height = 40 * scale;
        bubble.frame = CGRectMake(i ? self.bounds.size.width - width - 12 : 12, 42 + i * 74 * scale, width, height);
        bubble.font = [UIFont systemFontOfSize:14 * scale];
        bubble.text = i ? @"这是一条回复" : @"这是一条消息";
        if (self.kind == WCGesturePreviewAntiRevoke) {
            BOOL enabled = WCGestureEnabled(WCGestureAntiRevokeEnabledKey);
            bubble.text = i ? @"自己撤回仍生效" : (enabled ? @"对方消息已保留" : @"对方消息被撤回");
            label.text = nil;
            label.hidden = YES;
        } else {
            label.frame = WCGestureMessageTimeSideFrame(self.bounds, bubble.frame, i == 1,
                timeSize);
            BOOL showTime = self.kind == WCGesturePreviewMessageTime || WCGestureEnabled(WCGestureMessageTimeEnabledKey);
            label.hidden = !showTime || CGRectIsEmpty(label.frame);
        }
    }
}
@end

UIView *WCGestureCreateChatPreview(WCGesturePreviewKind kind) {
    WCChatPreview *view = [[WCChatPreview alloc] initWithFrame:CGRectZero];
    view.kind = kind;
    return view;
}
