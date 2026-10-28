#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureImageAnnotationLayout(UIView *host);
void WCGestureImageAnnotationStop(UIView *host);
BOOL WCGestureImageAnnotationBlocksGesture(UIScrollView *scroll,UIGestureRecognizer *gesture);
void WCGestureImageAnnotationSettingsChanged(NSString * _Nullable key);
void WCGestureImageAnnotationWidgetCapture(UIView *widget);
void WCGestureImageAnnotationWidgetRestore(UIView *widget);
NS_ASSUME_NONNULL_END
