#import <UIKit/UIKit.h>

// Forward declarations of the WeChat classes the tweak hooks or messages.
// Only the methods we actually call are declared; everything else is reached
// through KVC helpers in WCGestureSupport.h.

NS_ASSUME_NONNULL_BEGIN

@interface CMessageWrap : NSObject
@end

@interface MMHeadImageView : UIView
- (instancetype)initWithUsrName:(id)userName headImgUrl:(id)url bAutoUpdate:(BOOL)autoUpdate bRoundCorner:(BOOL)round;
@end

@interface MMMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface BaseMessageCellView : UIView
- (NSArray *)filteredMenuItems:(NSArray *)items;
@end

@interface CommonMessageCellView : BaseMessageCellView
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

@interface VoiceMessageCellView : CommonMessageCellView
- (NSArray *)operationMenuItems;
@end

@interface VoIPBubbleMessageCellView : CommonMessageCellView
- (void)startVoiceVoip;
- (void)startVideoVoip;
@end

@interface ChatRoomInfoViewController : UIViewController
@end

@interface BaseMsgContentViewController : UIViewController
@end

@interface MsgSearchHelper : NSObject
@end

@interface SystemMessageCellView : UIView
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

@interface FakeHeadImageView : UIView
@end


@interface RoomContentLogicController : NSObject
@end
@interface MMScreenShotViewController : UIViewController
@end
@interface MoreViewController : UIViewController
@end
@interface WCOperateFloatView : UIView
@end
@interface NewSettingViewController : UIViewController
@end
@interface MMAssetPickerController : UIViewController
@end
@interface MMImagePreviewBrowserController : UIViewController
@end
@interface WCContentItemViewTemplateGrid : UIView
@end
@interface WCSNSNodeVideoView : UIView
@end
@interface MMImageGridView : UIView
@end
@interface WCListPhotoCellView : WCListBaseCellView
@end
@interface WeixinContactInfoAssist : NSObject
@end

@interface MultiDeviceCardLoginContentView : UIView
@property (retain, nonatomic, nullable) id deviceLoginInfo;
@property (retain, nonatomic, nullable) UIButton *confirmButton;
@property (nonatomic) long long errorType;
- (void)onTapConfirmButton;
@end

@interface MicroMessengerAppDelegate : UIResponder
@end
@interface WCNotificationCenterMgr : NSObject
@end
@interface NotificationActionsMgr : NSObject
@end

@interface WebviewJSEventHandler_adDataReport : NSObject
@end
@interface WCAdvertiseStatMgr : NSObject
@end
@interface WAAppTaskSplashADConfig : NSObject
@end
@interface WAJSEventHandler_showSplashAd : NSObject
@end
@interface WAJSEventHandler_showSplashAdMenu : NSObject
@end
@interface BrandTLExptConfig : NSObject
@end
@interface BSTLExptConfig : NSObject
@end
@interface BrandTLFlutterViewController : NSObject
@end
@interface BoxBrandTLFlutterViewController : NSObject
@end
@interface BSTimelineFlutterViewController : NSObject
@end
@interface _TtC6WeChat19MagicAdBrandService : NSObject
@end
@interface MagicAdPushMgrService : NSObject
@end
@interface BrandTimelineMsgMgr : NSObject
@end
@interface BoxBrandTimelineMsgMgr : NSObject
@end
@interface WAJSEventHandler_adOperateWXData : NSObject
@end
@interface WCUserComment : NSObject
@end
@interface BrandTLCanvasCardMgr : NSObject
@end
@interface WCTimelineMgr : NSObject
@end

@interface VoipUIManager : NSObject
@end
@interface EditImageForwardAndEditLogicController : NSObject
@end
@interface WCActionSheet : NSObject
@end
@interface SharePreConfirmSheetView : NSObject
@end

@interface BaseMsgContentLogicController : NSObject
@end
@interface WeixinContentLogicController : BaseMsgContentLogicController
@end

// Native row-height owners (WeChat 8.0.79).
@interface WCBaseTimelineViewController : UIViewController
@end
@interface WCCommentDetailViewControllerFB : UIViewController
@end

NS_ASSUME_NONNULL_END

@interface ChatTimeCellView : UIView
@end
@interface TimeoutNumber : UIView
- (void)updateNumber:(unsigned long long)value;
@end
@interface WCPayWalletEntryHeaderView : UIView
@end

@interface MMHeadImageMgr : NSObject
@end

@interface WCPayWalletViewController : UIViewController
@end
@interface WCPayLQTDetailViewController : UIViewController
@end
@interface WCPayBalanceDetailViewController : UIViewController
@end

@interface WCEditImageLayoutView : UIView
@end
@interface EditImageIntialView : UIView
@end
@interface WCEditImageScrollView : UIScrollView
@end
@interface EditImageScrollView : UIScrollView
@end
@interface EditImageEmotionTool : UIView
@end
