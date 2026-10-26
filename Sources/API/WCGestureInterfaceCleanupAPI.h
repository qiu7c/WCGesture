#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
BOOL WCGestureShouldHideMeEntry(NSString *title);
id _Nullable WCGestureGroupMemberLabel(id _Nullable label);
void WCGestureInterfaceCleanupSettingsChanged(NSString * _Nullable key);
void WCGestureGroupTitleLayout(UIViewController *controller);
void WCGestureGroupTitleRestore(UIViewController *controller);
void WCGestureInterfaceCleanupInstallOptionalHooks(void);
NS_ASSUME_NONNULL_END
