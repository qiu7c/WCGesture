#import <UserNotifications/UserNotifications.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

static UIViewController *WCGestureFindControllerOfClass(UIViewController *controller, Class targetClass) {
    if (!controller || !targetClass) return nil;
    if ([controller isKindOfClass:targetClass]) return controller;
    UIViewController *found = WCGestureFindControllerOfClass(controller.presentedViewController, targetClass);
    if (found) return found;
    for (UIViewController *child in controller.childViewControllers) {
        found = WCGestureFindControllerOfClass(child, targetClass);
        if (found) return found;
    }
    return nil;
}

static void WCGestureOpenMomentsTimelineAttempt(NSUInteger remainingAttempts) {
    Class entryClass = objc_getClass("FindFriendEntryViewController");
    SEL openSelector = sel_registerName("openAlbum");
    Method method = entryClass ? class_getInstanceMethod(entryClass, openSelector) : NULL;
    const char *typeEncoding = method ? method_getTypeEncoding(method) : NULL;
    if (!typeEncoding || strcmp(typeEncoding, "v16@0:8") != 0) {
        NSLog(@"[One Wx] 打开朋友圈失败：当前版本入口 ABI 不匹配");
        return;
    }

    UIWindow *window = WCActiveWindow();
    UIViewController *entry = WCGestureFindControllerOfClass(window.rootViewController, entryClass);
    if (!entry) {
        if (remainingAttempts > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.50 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WCGestureOpenMomentsTimelineAttempt(remainingAttempts - 1);
            });
        } else {
            NSLog(@"[One Wx] 打开朋友圈失败：未找到发现页控制器");
        }
        return;
    }
    UITabBarController *tabBarController = entry.tabBarController;
    UIViewController *tabRoot = entry.navigationController ?: entry;
    if (tabBarController && tabBarController.selectedViewController != tabRoot) {
        tabBarController.selectedViewController = tabRoot;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try { ((void (*)(id, SEL))objc_msgSend)(entry, openSelector); }
        @catch (NSException *exception) {
            NSLog(@"[One Wx] 打开朋友圈失败：%@", exception.reason ?: @"未知异常");
        }
    });
}

void WCGestureOpenMomentsTimeline(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ WCGestureOpenMomentsTimelineAttempt(8); });
}

BOOL WCGestureHandleMomentsNotificationResponse(id response, void (^completionHandler)(void)) {
    id notification = WCTweakSafeValue(response, @"notification");
    id request = WCTweakSafeValue(notification, @"request");
    id content = WCTweakSafeValue(request, @"content");
    NSDictionary *userInfo = WCTweakSafeValue(content, @"userInfo");
    id rawWCGestureType = [userInfo isKindOfClass:[NSDictionary class]] ? userInfo[@"onewx"] : nil;
    NSString *wcAtlasType = [rawWCGestureType isKindOfClass:[NSString class]] ? rawWCGestureType : nil;
    if ([wcAtlasType isEqualToString:@"moments-reminder"] ||
        [wcAtlasType isEqualToString:@"moments-interaction"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WCGestureOpenMomentsTimeline(); });
        if (completionHandler) completionHandler();
        return YES;
    }

    return NO;
}

void WCGestureMomentsRequestNotificationAuthorization(void) {
    if (!WCGestureEnabled(WCGestureMomentsReminderEnabledKey)
        && !WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus != UNAuthorizationStatusNotDetermined) return;
        [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge
            completionHandler:^(__unused BOOL granted, NSError *error) {
                if (error) NSLog(@"[One Wx] 申请朋友圈通知权限失败：%@", error.localizedDescription);
            }];
    }];
}
