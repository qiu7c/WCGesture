#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
NSString *WCGestureLocalChatSession(id controller);
NSString *WCGestureLocalChatIdentity(UIView *cell);
id _Nullable WCGestureLocalChatMenuItem(UIView *cell, NSString *title, NSString *symbol, SEL action);
void WCGestureLocalChatRefreshCell(UIView *cell);
NSArray * _Nullable WCGestureLocalEditMenuItems(UIView *cell, NSArray * _Nullable items);
BOOL WCGestureLocalEditAllowsAction(UIView *cell, SEL action);
void WCGestureLocalEditPerform(UIView *cell, BOOL transfer);
void WCGestureLocalEditRestore(UIView *cell);
void WCGestureLocalEditSettingsChanged(NSString * _Nullable key);
void WCGestureLocalEditLeaving(UIViewController *controller);
void WCGestureLocalTimeLayout(UIView *cell);
void WCGestureLocalTimeReset(UIView *cell);
void WCGestureLocalTimeLongPress(UIView *cell, UILongPressGestureRecognizer *gesture);
NS_ASSUME_NONNULL_END
