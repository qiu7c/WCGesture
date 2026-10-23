#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Master switch key. When OFF, every gesture feature is disabled.
FOUNDATION_EXPORT NSString *const WCGestureEnabledKey;

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

/// Registers the default values for all keys once per process.
void WCGestureRegisterDefaults(void);

/// Returns YES only when the master switch is on and the given feature key is on.
BOOL WCGestureEnabled(NSString *key);

NS_ASSUME_NONNULL_END
