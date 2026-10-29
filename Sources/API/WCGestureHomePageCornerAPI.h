#import <UIKit/UIKit.h>

BOOL WCGestureHomePageCornerEnabled(void);
BOOL WCGestureHomePageIsDark(UIView *view);
UIColor *WCGestureHomePageCornerColor(UIView *view, BOOL surface);
CGFloat WCGestureHomePageCornerInset(void);
CGFloat WCGestureHomePageCornerGap(void);
void WCGestureHomePageCornerAttach(UIViewController *controller);
void WCGestureHomePageCornerLayoutTable(UITableView *table);
void WCGestureHomePageCornerLayoutCell(UITableViewCell *cell);
void WCGestureHomePageCornerRestoreCell(UITableViewCell *cell);
void WCGestureHomePageCornerLayoutChrome(UIView *view);
void WCGestureHomePageCornerLayoutSearch(UIView *view);
NSInteger WCGestureHomePageCornerMergedSection(UITableView *table);
void WCGestureHomePageCornerLayoutGroup(UIView *banner, CGFloat nativeHeight, CGFloat height, BOOL joined);
CGFloat WCGestureHomePageCornerHeaderHeight(UITableView *table, NSInteger section, CGFloat original);
UIView *WCGestureHomePageCornerHeaderView(UITableView *table, NSInteger section, UIView *original);
CGFloat WCGestureHomePageCornerFooterHeight(UITableView *table, NSInteger section, CGFloat original);
UIView *WCGestureHomePageCornerFooterView(UITableView *table, NSInteger section, UIView *original);
void WCGestureHomePageCornerSettingsChanged(NSString *key);
void WCGestureHomePageCornerThemeChanged(void);
