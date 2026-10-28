#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
NSArray * _Nullable WCGestureChatMediaMenuItems(UIView *cell, NSArray * _Nullable items);
BOOL WCGestureChatMediaAllowsAction(UIView *cell, SEL action);
void WCGestureChatMediaPick(UIView *cell);
void WCGestureChatMediaRestore(UIView *cell);
void WCGestureChatMediaLayout(UIView *cell);
void WCGestureChatMediaResetCell(UIView *cell);
BOOL WCGestureChatMediaPresent(UIView *cell);
void WCGestureChatMediaLeaving(UIViewController *controller);
void WCGestureChatMediaSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
