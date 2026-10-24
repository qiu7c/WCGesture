#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Master switch key. When OFF, every gesture feature is disabled.
FOUNDATION_EXPORT NSString *const WCGestureEnabledKey;

/// User-customizable plugin display name shown in WeChat's plugin manager.
FOUNDATION_EXPORT NSString *const WCPluginNameKey;

/// Message-gesture feature keys (left/right swipe, double/triple tap on bubbles).
FOUNDATION_EXPORT NSString *const WCReplySwipeEnabledKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeSelfActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeOtherActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeRightSelfActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeRightOtherActionKey;
FOUNDATION_EXPORT NSString *const WCReplySwipeTriggerDistanceKey;
FOUNDATION_EXPORT NSString *const WCMessageDoubleTapSelfActionKey;
FOUNDATION_EXPORT NSString *const WCMessageDoubleTapOtherActionKey;
FOUNDATION_EXPORT NSString *const WCMessageTripleTapSelfActionKey;
FOUNDATION_EXPORT NSString *const WCMessageTripleTapOtherActionKey;

/// Input-box gesture keys (swipe + multi-tap on the chat input).
FOUNDATION_EXPORT NSString *const WCInputGestureEnabledKey;
FOUNDATION_EXPORT NSString *const WCInputSwipeLeftActionKey;
FOUNDATION_EXPORT NSString *const WCInputSwipeRightActionKey;
FOUNDATION_EXPORT NSString *const WCInputDoubleTapActionKey;
FOUNDATION_EXPORT NSString *const WCInputTripleTapActionKey;

/// Moments (朋友圈) double-tap like.
FOUNDATION_EXPORT NSString *const WCMomentsDoubleTapLikeKey;
FOUNDATION_EXPORT NSString *const WCMomentsLikeHapticKey;

/// Per-gesture vibration switches. Intensity is shared via WCGestureHapticStyleKey.
FOUNDATION_EXPORT NSString *const WCMessageGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCInputGestureHapticKey;

/// Global multi-finger long-press (any WeChat page).
FOUNDATION_EXPORT NSString *const WCGlobalGestureEnabledKey;
FOUNDATION_EXPORT NSString *const WCGlobalTwoFingerActionKey;
FOUNDATION_EXPORT NSString *const WCGlobalThreeFingerActionKey;
FOUNDATION_EXPORT NSString *const WCGlobalGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCGestureHapticStyleKey;

/// URL used by the "custom page" global action.
FOUNDATION_EXPORT NSString *const WCCustomPageURLKey;

/// Haptic intensity levels (maps to UIImpactFeedbackStyle).
typedef NS_ENUM(NSInteger, WCHapticStyle) {
    WCHapticStyleLight = 0,
    WCHapticStyleMedium = 1,
    WCHapticStyleHeavy = 2,
    WCHapticStyleSoft = 3,
    WCHapticStyleRigid = 4,
};

/// Input-box gesture action enum (shared by swipe and multi-tap).
typedef NS_ENUM(NSInteger, WCInputAction) {
    WCInputActionNone = 0,
    WCInputActionClear = 1,   // 清空输入框
    WCInputActionPaste = 2,   // 粘贴剪贴板
    WCInputActionCopy = 3,    // 复制输入框内容
    WCInputActionCut = 4,     // 剪切输入框内容
};

/// Notification posted when an enhancement key changes, so gesture recognizers
/// can be re-synchronized on the next view appearance. Object carries the key.
FOUNDATION_EXPORT NSString *const WCGestureDidChangeNotification;

typedef NS_ENUM(NSInteger, WCReplySwipeAction) {
    WCReplySwipeActionNone = 0,
    WCReplySwipeActionQuote = 1,
    WCReplySwipeActionRevoke = 2,
    WCReplySwipeActionCopy = 3,
    WCReplySwipeActionDelete = 4,
    WCReplySwipeActionRepeat = 5,
};

/// Global multi-finger long-press action.
typedef NS_ENUM(NSInteger, WCGlobalAction) {
    WCGlobalActionNone = 0,
    WCGlobalActionScreenshot = 1,   // 截图当前页面
    WCGlobalActionBack = 2,         // 返回上一页
    WCGlobalActionLockScreen = 3,   // 回到首页
    WCGlobalActionScanQR = 4,       // 扫一扫
    WCGlobalActionMenu = 5,         // 弹快捷菜单
    WCGlobalActionJump = 6,         // 跳转设置页
    WCGlobalActionMoments = 7,      // 朋友圈
    WCGlobalActionAddFriend = 8,    // 添加朋友
    WCGlobalActionCustomPage = 9,   // 前往自定义页面
};

/// Registers the default values for all keys once per process.
void WCGestureRegisterDefaults(void);

/// Returns YES only when the master switch is on and the given feature key is on.
BOOL WCGestureEnabled(NSString *key);

NS_ASSUME_NONNULL_END
