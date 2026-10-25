#import "Sources/API/WCGestureInternal.h"

static NSTimer *WCMomentsMonitoringTimer;
static NSString *WCMomentsMonitoringAccount;

static BOOL WCMomentsMonitoringEnabled(void) {
    return WCGestureEnabled(WCGestureMomentsReminderEnabledKey)
        || WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey);
}

void WCGestureMomentsMonitoringTick(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCGestureMomentsMonitoringTick(); });
        return;
    }
    if (!WCMomentsMonitoringEnabled() || !WCRefreshCachedCurrentUser()) return;
    NSString *account = WCCurrentUserWXID();
    if (![WCMomentsMonitoringAccount isEqualToString:account]) {
        WCMomentsMonitoringAccount = [account copy];
        WCGestureDismissInAppNotifications();
        WCGestureMomentsReminderSettingsDidChange();
        WCGestureMomentsInteractionReminderSettingsDidChange();
    }
    WCGestureMomentsReminderTick();
    WCGestureMomentsInteractionReminderTick();
}

static void WCMomentsMonitoringUpdateTimer(void) {
    if (!WCMomentsMonitoringEnabled()) {
        [WCMomentsMonitoringTimer invalidate];
        WCMomentsMonitoringTimer = nil;
        return;
    }
    if (WCMomentsMonitoringTimer) return;
    WCMomentsMonitoringTimer = [NSTimer timerWithTimeInterval:10 repeats:YES block:^(__unused NSTimer *timer) {
        WCGestureMomentsMonitoringTick();
    }];
    [NSRunLoop.mainRunLoop addTimer:WCMomentsMonitoringTimer forMode:NSRunLoopCommonModes];
}

void WCGestureMomentsMonitoringStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WCMomentsMonitoringUpdateTimer();
        WCGestureMomentsMonitoringTick();
        WCGestureMomentsPrewarmIfNeeded();
        WCGestureBackgroundKeeperSettingsDidChange();
    });
}

void WCGestureMomentsMonitoringSettingsChanged(NSString *key) {
    BOOL reminder = !key || [key hasPrefix:@"com.qiu7c.onewx.moments.reminder"];
    BOOL interaction = !key || [key hasPrefix:@"com.qiu7c.onewx.moments.interaction-reminder"];
    if (reminder) WCGestureMomentsReminderSettingsDidChange();
    if (interaction) {
        WCGestureMomentsInteractionReminderSettingsDidChange();
        if (WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) WCGestureMomentsPrewarmIfNeeded();
        else WCGestureMomentsPrewarmCancel();
    }
    if (!key || [key isEqualToString:WCGestureBackgroundKeepAliveEnabledKey]) {
        WCGestureBackgroundKeeperSettingsDidChange();
    }
    if (reminder || interaction) {
        WCMomentsMonitoringUpdateTimer();
        if (WCMomentsMonitoringEnabled()) WCGestureMomentsRequestNotificationAuthorization();
        else WCGestureDismissInAppNotifications();
    }
}

void WCGestureMomentsMonitoringEnterBackground(void) {
    WCGestureMomentsPrewarmCancel();
    WCGestureBackgroundKeeperEnterBackground();
}

void WCGestureMomentsMonitoringEnterForeground(void) {
    WCGestureBackgroundKeeperWillEnterForeground();
}

void WCGestureMomentsMonitoringBecomeActive(void) {
    WCGestureBackgroundKeeperWillEnterForeground();
    WCGestureMomentsPrewarmIfNeeded();
    WCGestureMomentsMonitoringTick();
}
