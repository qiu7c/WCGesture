#import <UIKit/UIKit.h>

BOOL WCGestureHomeGroupsEnabled(void);
BOOL WCGestureHomeGroupsNative(void);
void WCGestureHomeGroupsBeginNative(void);
void WCGestureHomeGroupsEndNative(void);
NSArray<NSDictionary *> *WCGestureHomeGroupsList(void);
NSString *WCGestureHomeGroupsSelected(void);
void WCGestureHomeGroupsSave(NSArray<NSDictionary *> *groups);
void WCGestureHomeGroupsSelect(NSString *groupID);
NSString *WCGestureHomeGroupsUserName(id session);
NSArray *WCGestureHomeGroupsSection(id logic, NSInteger section);
NSIndexPath *WCGestureHomeGroupsNativePath(id logic, NSIndexPath *path);
NSIndexPath *WCGestureHomeGroupsFind(id logic, NSString *user);
void WCGestureHomeGroupsInvalidate(id logic);
void WCGestureHomeGroupsAttach(UIViewController *controller);
void WCGestureHomeGroupsDidAppear(UIViewController *controller);
void WCGestureHomeGroupsSettingsChanged(NSString *key);
void WCGestureHomeGroupsMessageAdded(id target, id wrap, BOOL localMessage);
void WCGestureHomeGroupsChatEntered(id controller);
UIViewController *WCGestureCreateHomeGroupsSettingsController(void);

NSArray<NSString *> *WCGestureHomeGroupsPendingNames(void);
void WCGestureHomeGroupsSetPendingNames(NSArray<NSString *> *names);
UIViewController *WCGestureCreateHomeGroupsPendingController(void);

void WCGestureHomeGroupsStyleCell(UIViewController *controller, UITableViewCell *cell, NSIndexPath *path);
