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

/// Keyboard enhancement: a transparent gesture strip in the blank area below
/// the keyboard's bottom row (between the globe and mic keys), above the home
/// indicator. It has its own action configuration, independent of the input
/// box gestures.
FOUNDATION_EXPORT NSString *const WCKeyboardEnhanceEnabledKey;
FOUNDATION_EXPORT NSString *const WCKeyboardSwipeLeftActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardSwipeRightActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardDoubleTapActionKey;
FOUNDATION_EXPORT NSString *const WCKeyboardTripleTapActionKey;

/// Debug aid: paints the keyboard gesture strip red and shows its live size at
/// the top of the screen so the touchable band is visible while tuning.
FOUNDATION_EXPORT NSString *const WCKeyboardDebugFrameKey;

/// Geometry of the keyboard gesture strip, all in points. Width 0 means the
/// full keyboard width; the offsets move the strip from its default spot
/// (positive X = right, positive Y = up).
FOUNDATION_EXPORT NSString *const WCKeyboardStripWidthKey;
FOUNDATION_EXPORT NSString *const WCKeyboardStripHeightKey;
FOUNDATION_EXPORT NSString *const WCKeyboardStripOffsetXKey;
FOUNDATION_EXPORT NSString *const WCKeyboardStripOffsetYKey;

/// Translation engine selection and optional custom (OpenAI-compatible) endpoint.
typedef NS_ENUM(NSInteger, WCTranslateEngine) {
    WCTranslateEngineEdge = 0,     // 微软 Edge(免费,无需 key)
    WCTranslateEngineMyMemory = 1, // MyMemory(免费,无需 key)
    WCTranslateEngineCustom = 2,   // 自定义(OpenAI 兼容接口)
};

FOUNDATION_EXPORT NSString *const WCTranslateEngineKey;
FOUNDATION_EXPORT NSString *const WCTranslateCustomURLKey;
FOUNDATION_EXPORT NSString *const WCTranslateCustomKeyKey;
FOUNDATION_EXPORT NSString *const WCTranslateCustomModelKey;

/// Moments (朋友圈) double-tap like.
FOUNDATION_EXPORT NSString *const WCMomentsDoubleTapLikeKey;
FOUNDATION_EXPORT NSString *const WCMomentsLikeHapticKey;

/// Per-gesture vibration switches. Intensity is shared via WCGestureHapticStyleKey.
FOUNDATION_EXPORT NSString *const WCMessageGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCInputGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCKeyboardHapticKey;

/// Global multi-finger long-press (any WeChat page).
FOUNDATION_EXPORT NSString *const WCGlobalGestureEnabledKey;
FOUNDATION_EXPORT NSString *const WCGlobalTwoFingerActionKey;
FOUNDATION_EXPORT NSString *const WCGlobalThreeFingerActionKey;
FOUNDATION_EXPORT NSString *const WCGlobalGestureHapticKey;
FOUNDATION_EXPORT NSString *const WCGestureHapticStyleKey;

/// Custom pages used by the "custom page" global action. An array of
/// dictionaries: { @"name": 备注, @"class": UIViewController 类名 }.
FOUNDATION_EXPORT NSString *const WCCustomPagesKey;

/// Enhancement switches (拓展设置).
FOUNDATION_EXPORT NSString *const WCHideSeparatorLinesKey;

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
    WCInputActionTranslateToEnglish = 5, // 翻译:中译英,替换输入框
    WCInputActionTranslateToChinese = 6, // 翻译:英译中,替换输入框
    WCInputActionUppercase = 7,          // 转大写
    WCInputActionLowercase = 8,          // 转小写
    WCInputActionTrim = 9,               // 去空格/换行
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
    WCReplySwipeActionForward = 6,
    WCReplySwipeActionFavorite = 7,
    WCReplySwipeActionSpeak = 8,
    WCReplySwipeActionTranslate = 9,
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
    WCGlobalActionMyQRCode = 10,    // 我的二维码
    WCGlobalActionPayCode = 11,     // 付款码
};

/// Registers the default values for all keys once per process.
void WCGestureRegisterDefaults(void);

/// Returns YES only when the master switch is on and the given feature key is on.
BOOL WCGestureEnabled(NSString *key);

NS_ASSUME_NONNULL_END
