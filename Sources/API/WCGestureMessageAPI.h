#import <UIKit/UIKit.h>
#import "Sources/Core/WCGestureConfig.h"
#import "Sources/WeChat/WCGestureWeChatClasses.h"

NS_ASSUME_NONNULL_BEGIN

/// Shared message-wrap resolution, including split-message parent models.
id _Nullable WCGestureMessageWrapForCell(UIView *cell);

/// Creates/removes the swipe and multi-tap recognizers on one message bubble.
void WCSynchronizeReplyGesture(CommonMessageCellView *cell);

/// Re-synchronizes every visible message bubble (after a settings change).
void WCSynchronizeVisibleReplyGestures(void);

/// Body of the bubble's pan recognizer.
void WCReplyPanHandle(CommonMessageCellView *cell, UIPanGestureRecognizer *recognizer);

/// Body of the bubble's double/triple-tap recognizer.
void WCMessageTapHandle(CommonMessageCellView *cell, UITapGestureRecognizer *recognizer);

/// YES while a voice repeat is uploading, so the upload hooks can mark the
/// voice as forwarded instead of as an ordinary recording.
BOOL WCVoiceRepeatUploadIsActive(void);
/// Shared native voice resend pipeline, including the upload-forward window.
BOOL WCGestureResendVoiceMessage(id message, NSString *session);

/// The chat controller currently on screen, cached by the chat hook. Used by
/// the repeat path to find a presenter and by the AI reply to find the input.
BaseMsgContentViewController * _Nullable WCVisibleChatControllerGet(void);
void WCSetVisibleChatController(BaseMsgContentViewController * _Nullable controller);

BOOL WCGestureRepeatMessage(CommonMessageCellView *cell);
NS_ASSUME_NONNULL_END
