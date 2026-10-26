#import "Sources/API/WCGestureInternal.h"

%hook NotificationActionsMgr
- (void)userNotificationCenter:(id)center didReceiveNotificationResponse:(id)response withCompletionHandler:(void (^)(void))completion {
    if (WCGestureHandleMomentsNotificationResponse(response, completion)) return;
    if (WCGestureHandleDirectChatNotificationResponse(response, completion)) return;
    %orig;
}
%end

%hook MicroMessengerAppDelegate
- (void)userNotificationCenter:(id)center didReceiveNotificationResponse:(id)response withCompletionHandler:(void (^)(void))completion {
    if (WCGestureHandleMomentsNotificationResponse(response, completion)) return;
    if (WCGestureHandleDirectChatNotificationResponse(response, completion)) return;
    %orig;
}
%end

%ctor {
    %init;
}
