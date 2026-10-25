#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureShowInAppNotification(NSString *title, NSString *body, NSString *identifier, NSString *symbolName, dispatch_block_t _Nullable action);
void WCGestureDismissInAppNotifications(void);
void WCGestureOpenMomentsTimeline(void);
BOOL WCGestureHandleMomentsNotificationResponse(id response, void (^ _Nullable completion)(void));
void WCGestureMomentsRequestNotificationAuthorization(void);
UIViewController *WCGestureCreateMomentsFriendPicker(void);
NS_ASSUME_NONNULL_END
