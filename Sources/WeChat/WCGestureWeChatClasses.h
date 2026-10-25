#import <UIKit/UIKit.h>

// Forward declarations of the WeChat classes the tweak hooks or messages.
// Only the methods we actually call are declared; everything else is reached
// through KVC helpers in WCGestureSupport.h.

NS_ASSUME_NONNULL_BEGIN

@interface CMessageWrap : NSObject
@end

@interface MMMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface CommonMessageCellView : UIView
@property (nonatomic, strong) id viewModel;
- (void)setViewModel:(id)viewModel;
- (void)didMoveToWindow;
- (void)prepareForReuse;
- (void)layoutSubviews;
- (void)updateStatus;
- (void)updateNodeStatus;
- (void)handleTapReferMessage;
- (void)handleTapForReferMsg:(id)sender;
- (void)onShowMsgReplyMenuItem:(id)sender;
- (void)onRevokeMsg:(id)sender;
- (void)onCopy:(id)sender;
- (void)onDelete:(id)sender;
- (void)onDeleteMessage:(id)sender;
- (void)onHeadImageLongPressed:(id)sender;
@end

@interface BaseMsgContentViewController : UIViewController
@end

@interface MMGrowTextView : UIView
- (void)didMoveToWindow;
- (void)textViewDidChange:(id)textView;
@end

@interface MMInputToolView : UIView
@end

@interface ForwardMessageLogicController : NSObject
- (void)setDelegate:(id)delegate;
- (void)forwardNoConfirmForMsgList:(NSArray *)messages toContacts:(NSArray *)contacts;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(NSString *)session MsgWrap:(id)message;
- (id)uploaderForMsgWrap:(id)message;
@end

@interface ForwardMsgUtil : NSObject
+ (BOOL)canBeForwardWithMsg:(id)message;
@end

@interface CMessageMgr : NSObject
- (id)GetMsg:(id)session n64SvrID:(long long)serverID;
- (void)onNewSyncNotAddDBMessage:(id)message;
- (void)AddMsg:(NSString *)session MsgWrap:(id)message;
- (void)AddLocalMsg:(NSString *)session MsgWrap:(id)message;
- (BOOL)SaveMesVoice:(NSData *)data MsgWrap:(id)message;
@end

/// The Moments (朋友圈) cell whose content is double-tapped to like it.
@interface WCTimeLineCellView : UIView
- (void)onAccessibilityLike;
- (void)didMoveToWindow;
- (void)setViewModel:(id)viewModel;
- (void)prepareForReuse;
@end

@interface CLocalInfo : NSObject
- (unsigned int)m_uiWebviewFontLevel;
- (unsigned int)m_uiGlobalFontLevel;
- (void)setM_uiGlobalFontLevel:(unsigned int)level;
@end

@interface MMThemeManager : NSObject
- (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet;
- (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet isAdapt:(BOOL)isAdapt;
@end

@interface WAThemeProxy : NSObject
+ (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet;
@end

@interface WCListBaseCellView : UIView
+ (double)getLayoutHeightWithGroup:(id)group groupItem:(id)item width:(double)width isFirstOneInsection:(BOOL)first isLastOneInSection:(BOOL)last;
@end

@interface WCTimeLineCommentCellView : UIView
+ (double)getCellHeightForDataItem:(id)item RowIndex:(long long)rowIndex pageContext:(id)context;
@end

NS_ASSUME_NONNULL_END
