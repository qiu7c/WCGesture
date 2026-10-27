#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureChatSortInstall(void);
NSArray * _Nullable WCGestureChatSortMenuItems(UIView *cell, NSArray * _Nullable items);
BOOL WCGestureChatSortAllowsAction(UIView *cell, SEL action);
void WCGestureChatSortToggle(UIView *cell);
void WCGestureChatSortEnd(UIViewController *controller);
void WCGestureChatSortSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
