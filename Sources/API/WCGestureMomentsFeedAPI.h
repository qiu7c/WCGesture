#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef struct {
    CGFloat buttonWidth;
    CGFloat buttonHeight;
    CGFloat totalWidth;
    CGFloat spacing;
    BOOL hidesText;
} WCGestureMomentsFeedActionMetrics;
WCGestureMomentsFeedActionMetrics WCGestureMomentsFeedResolveActionMetrics(CGFloat width, NSUInteger count, BOOL hideText);
UIButton *WCGestureCreateMomentsFeedButton(NSString *title, NSString *symbol);
void WCGestureConfigureMomentsFeedButton(UIButton *button, NSString *title, NSString *symbol, BOOL hideText);
UIViewController *WCGestureCreateMomentsFeedPreviewController(void);
void WCGestureMomentsFeedBeginHeight(void);
double WCGestureMomentsFeedEndHeight(double nativeHeight, id item, id context, id model);
double WCGestureMomentsFeedRowHeight(UIViewController *controller, UITableView *table, NSIndexPath *path, double original);
id _Nullable WCGestureMomentsFeedCachedHeight(UIViewController *controller, id item, id _Nullable original);
void WCGestureMomentsFeedBeforeLayout(UIView *cell);
void WCGestureMomentsFeedLayout(UIView *cell);
void WCGestureMomentsFeedReset(UIView *cell);
UIView * _Nullable WCGestureMomentsFeedHitTest(UIView *cell, CGPoint point, UIEvent * _Nullable event, UIView * _Nullable original);
BOOL WCGestureMomentsFeedIsActionPoint(UIView *cell, CGPoint point);
void WCGestureMomentsFeedSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
