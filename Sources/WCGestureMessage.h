#import <UIKit/UIKit.h>
#import "WCGestureConfig.h"
#import "WCGestureWeChatClasses.h"

NS_ASSUME_NONNULL_BEGIN

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

/// The chat controller currently on screen, cached by the chat hook. Used by
/// the repeat path to find a presenter and by the AI reply to find the input.
BaseMsgContentViewController * _Nullable WCVisibleChatControllerGet(void);
void WCSetVisibleChatController(BaseMsgContentViewController * _Nullable controller);

NS_ASSUME_NONNULL_END
