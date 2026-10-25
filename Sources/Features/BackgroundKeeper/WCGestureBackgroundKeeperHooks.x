#import "Sources/API/WCGestureInternal.h"

%hook MicroMessengerAppDelegate
- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    WCGestureMomentsMonitoringEnterBackground();
}
- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    WCGestureMomentsMonitoringEnterForeground();
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    WCGestureMomentsMonitoringBecomeActive();
}
- (void)careEnoughForTheLiving {
    %orig;
    WCGestureMomentsMonitoringTick();
}
%end

%ctor {
    %init;
}
