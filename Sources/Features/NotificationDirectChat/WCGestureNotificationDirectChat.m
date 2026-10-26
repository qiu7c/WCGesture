#import <UserNotifications/UserNotifications.h>
#import "Sources/API/WCGestureInternal.h"

static NSUInteger WCNotificationDirectChatGeneration;

static void WCNotificationOpenChat(NSString *userName, NSString *account, NSUInteger generation, NSUInteger attempts) {
    if (generation != WCNotificationDirectChatGeneration
        || !WCGestureEnabled(WCGestureNotificationDirectChatEnabledKey)) return;
    WCRefreshCachedCurrentUser();
    if (account.length && ![account isEqualToString:WCCurrentUserWXID()]) return;
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive
        && WCGesturePushPrivateChat(userName)) return;
    if (attempts) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WCNotificationOpenChat(userName, account, generation, attempts - 1);
        });
    } else {
        NSLog(@"[One Wx] 通知直达聊天未能取得原生聊天入口");
    }
}

BOOL WCGestureHandleDirectChatNotificationResponse(id response, void (^completion)(void)) {
    if (!WCGestureEnabled(WCGestureNotificationDirectChatEnabledKey)) return NO;
    // Reply, mark-read and dismiss actions must retain WeChat's native handling.
    NSString *action = WCTweakSafeValue(response, @"actionIdentifier");
    if (![action isEqualToString:UNNotificationDefaultActionIdentifier]) return NO;
    id content = WCTweakSafeValue(WCTweakSafeValue(WCTweakSafeValue(response, @"notification"), @"request"), @"content");
    id userInfo = WCTweakSafeValue(content, @"userInfo");
    if (![userInfo isKindOfClass:NSDictionary.class] || userInfo[@"onewx"]) return NO;
    id rawName = userInfo[@"u"];
    if (![rawName isKindOfClass:NSString.class]) return NO;
    NSString *userName = [rawName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!userName.length) return NO;
    Class logicClass = NSClassFromString(@"MMMsgLogicManager");
    if (![logicClass instancesRespondToSelector:NSSelectorFromString(@"PushOtherBaseMsgControllerByContact:navigationController:animated:")]) return NO;

    // Use the same delayed native navigation as WCAtlas, with a short launch/unlock retry window.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger generation = ++WCNotificationDirectChatGeneration;
        NSString *account = [WCCurrentUserWXID() copy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WCNotificationOpenChat(userName, account, generation, 8);
        });
    });
    if (completion) completion();
    return YES;
}
