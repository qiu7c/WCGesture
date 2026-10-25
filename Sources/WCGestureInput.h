#import <UIKit/UIKit.h>
#import "WCGestureConfig.h"
#import "WCGestureWeChatClasses.h"

NS_ASSUME_NONNULL_BEGIN

/// The UITextView inside an MMGrowTextView, or nil when the view is not one.
UITextView * _Nullable WCInnerTextView(id growTextView);

/// The visible chat input whose inner text view is the first responder.
MMGrowTextView * _Nullable WCFirstResponderGrowTextView(void);

/// Current input text, read from the grow text view (falls back to its inner
/// text view). Never nil.
NSString *WCInputText(MMGrowTextView *view);

/// Replaces the input text and tells WeChat the text changed so its send
/// button state follows.
void WCReplaceInputText(MMGrowTextView *view, NSString *text);

/// Runs one configured input-box or keyboard-strip action.
void WCPerformInputAction(MMGrowTextView *view, WCInputAction action);

/// Adds/removes the swipe and multi-tap recognizers for the current settings.
/// Called from the MMGrowTextView hook and whenever settings change.
void WCSynchronizeInputGestures(MMGrowTextView *view);

NS_ASSUME_NONNULL_END
