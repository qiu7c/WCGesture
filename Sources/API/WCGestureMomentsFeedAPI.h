#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureMomentsFeedBeginHeight(void);
double WCGestureMomentsFeedEndHeight(double nativeHeight, id item, id context, id model);
double WCGestureMomentsFeedRowHeight(UIViewController *controller, UITableView *table, NSIndexPath *path, double original);
void WCGestureMomentsFeedBeforeLayout(UIView *cell);
void WCGestureMomentsFeedLayout(UIView *cell);
void WCGestureMomentsFeedReset(UIView *cell);
UIView * _Nullable WCGestureMomentsFeedHitTest(UIView *cell, CGPoint point, UIEvent * _Nullable event, UIView * _Nullable original);
BOOL WCGestureMomentsFeedIsActionPoint(UIView *cell, CGPoint point);
void WCGestureMomentsFeedSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
