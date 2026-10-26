#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^WCGestureSendConfirmationValidator)(void);

FOUNDATION_EXPORT NSArray<NSString *> *WCGestureSendConfirmationProtectedConversations(void);
FOUNDATION_EXPORT BOOL WCGestureSendConfirmationIsProtectedConversation(NSString *username);
FOUNDATION_EXPORT void WCGestureSendConfirmationSetProtected(NSString *username, BOOL protectedConversation);
/// Adds or removes several conversations in one account-scoped defaults update.
/// @return Number of valid, unique usernames processed; zero when the account or input is unavailable.
/// @discussion Enabling at least one conversation also enables the global send-confirmation switch.
FOUNDATION_EXPORT NSUInteger WCGestureSendConfirmationSetProtectedConversations(
    NSArray<NSString *> *usernames, BOOL protectedConversation);
FOUNDATION_EXPORT NSString *WCGestureSendConfirmationDisplayName(NSString *username);

/// Returns YES when the original action is being held for confirmation. The
/// caller must return without invoking the original method in that case.
FOUNDATION_EXPORT BOOL WCGesturePresentSendConfirmationIfNeeded(UIViewController *presenter,
                                                             NSString *username,
                                                             NSString *summary,
                                                             WCGestureSendConfirmationValidator _Nullable validator,
                                                             dispatch_block_t confirmedAction);
FOUNDATION_EXPORT void WCGestureCancelPendingSendConfirmations(void);

// Hook and UI integration; an action is held only when this returns YES.
BOOL WCGestureSendConfirmationHold(NSString *username, NSString *summary,
    WCGestureSendConfirmationValidator _Nullable validator, dispatch_block_t action);
BOOL WCGestureSendConfirmationHoldMessage(NSString *username, id wrap, dispatch_block_t action);
void WCGestureSendConfirmationTrackChat(UIViewController *controller);
void WCGestureSendConfirmationChatLeaving(UIViewController *controller);
void WCGestureSendConfirmationSettingsChanged(NSString * _Nullable key);
BOOL WCGestureSendConfirmationRepeatIfNeeded(UIView *cell, NSString *target, dispatch_block_t action);
NSString *WCGestureSendConfirmationMessageSummary(id wrap);
BOOL WCGestureSendConfirmationIsAppEmoticon(id wrap);
UIViewController *WCGestureCreateSendConfirmationPicker(void);
void WCGestureSendConfirmationProfileApply(id owner, BOOL group);
void WCGestureSendConfirmationProfileToggle(id owner, UISwitch *sender);
void WCGestureSendConfirmationRefreshProfiles(void);
NS_ASSUME_NONNULL_END
