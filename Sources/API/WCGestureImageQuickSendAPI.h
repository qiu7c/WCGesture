#import <UIKit/UIKit.h>
void WCGestureImageQuickSendPrepare(id logic);
void WCGestureImageQuickSendBindAttribute(id logic, id attribute);
void WCGestureImageQuickSendAddAction(id sheet, UIView *view);
BOOL WCGestureImageQuickSendConfirmAllowed(id sheet);
id WCGestureImageQuickSendSessionForSheet(id sheet);
void WCGestureImageQuickSendCancelSession(id session);
void WCGestureImageQuickSendSettingsChanged(id key);
