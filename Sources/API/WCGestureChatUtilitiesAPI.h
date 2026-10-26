#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureChatSearchUpdate(UIViewController *controller);
BOOL WCGestureChatSearchIsActive(UIViewController *controller);
void WCGestureChatSearchOpen(UIViewController *controller, id _Nullable sender);
void WCGestureChatSearchWillAppear(UIViewController *controller);
void WCGestureChatSearchHandleEdgePan(UIViewController *controller, UIScreenEdgePanGestureRecognizer *recognizer);
void WCGestureChatSearchDidDismiss(id helper);
BOOL WCGestureJumpToReferencedMessage(UIView *cell);
void WCGestureChatUtilitiesSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
