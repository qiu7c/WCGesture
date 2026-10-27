#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureInputVoiceHandle(UIView *source, UILongPressGestureRecognizer *gesture);
void WCGestureInputVoiceCancel(void);
void WCGestureInputVoiceSettingsChanged(void);
BOOL WCGestureSendRecordedVoiceFile(NSString *path, NSUInteger durationMilliseconds, NSString *session);
BOOL WCGestureEncodeRecordedVoice(NSURL *source, NSURL *destination, NSUInteger *durationMilliseconds);
NS_ASSUME_NONNULL_END
