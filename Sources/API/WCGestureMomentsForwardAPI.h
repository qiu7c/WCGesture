#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
BOOL WCGestureMomentsForwardCanForward(id item);
void WCGestureMomentsForwardPresent(id item, UIViewController *presenter);
void WCGestureMomentsForwardSettingsChanged(NSString * _Nullable key);
void WCGestureMomentsForwardMenuPrepare(UIView *view, id item);
void WCGestureMomentsForwardMenuLayout(UIView *view);
void WCGestureMomentsForwardMenuReset(UIView *view);
void WCGestureMomentsForwardMenuSettingsChanged(void);
NS_ASSUME_NONNULL_END
