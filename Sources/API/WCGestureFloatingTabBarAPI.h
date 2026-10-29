#import <UIKit/UIKit.h>

void WCGestureFloatingTabBarInstall(void);
void WCGestureFloatingTabBarPrepareForDisplay(UITabBar *bar);
BOOL WCGestureFloatingTabBarBeginLayout(UITabBar *bar);
void WCGestureFloatingTabBarEndLayout(UITabBar *bar);
id WCGestureFloatingTabBarAppearance(UITabBar *bar, SEL setter, id value);
UIView *WCGestureFloatingTabBarHitTest(UITabBar *bar, CGPoint point, UIView *original);
void WCGestureFloatingTabBarItemLayout(UIView *item);
void WCGestureFloatingTabBarButtonLayout(UIView *button);
void WCGestureFloatingTabBarItemWillSelect(UIView *item);
void WCGestureFloatingTabBarItemDidSelect(UIView *item, BOOL selected);
CGRect WCGestureFloatingTabBarBadgeFrame(UIView *badge, CGRect frame);
void WCGestureFloatingTabBarSettingsChanged(NSString *key);
void WCGestureFloatingTabBarThemeChanged(void);
UIView *WCGestureCreateFloatingTabBarPreview(void);
UIViewController *WCGestureCreateFloatingTabBarSettingsController(void);
