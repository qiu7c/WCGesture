#import "Sources/API/WCGestureInternal.h"
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>


static id WCMomentsInteractionCurrentManager(void) {
    id facade = WCServiceForClass(NSClassFromString(@"WCFacade"));
    return WCTweakSafeValue(facade, @"m_messageMgr");
}

static const char *WCGestureMomentsInteractionSkipQualifiers(const char *type) {
    while (type && *type && strchr("rnNoORV", *type)) type++;
    return type ?: "";
}

static BOOL WCGestureMomentsInteractionMethodMatches(id object, SEL selector, char returnType) {
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return NO;
    char *type = method_copyReturnType(method);
    BOOL matches = WCGestureMomentsInteractionSkipQualifiers(type)[0] == returnType;
    free(type);
    return matches;
}

static BOOL WCGestureMomentsInteractionMethodHasEncoding(id object, SEL selector, const char *encoding) {
    Method method = object ? class_getInstanceMethod([object class], selector) : NULL;
    const char *actual = method ? method_getTypeEncoding(method) : NULL;
    return actual && encoding && strcmp(actual, encoding) == 0;
}

static id WCGestureMomentsInteractionObjectGetter(id object, const char *selectorName) {
    if (!object || !selectorName) return nil;
    SEL selector = sel_registerName(selectorName);
    if (!WCGestureMomentsInteractionMethodHasEncoding(object, selector, "@16@0:8")) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static NSString *WCGestureMomentsInteractionStringGetter(id object, const char *selectorName) {
    SEL selector = sel_registerName(selectorName);
    if (!WCGestureMomentsInteractionMethodMatches(object, selector, '@')) return nil;
    id value = nil;
    @try { value = ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *string = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return string.length > 0 ? string : nil;
}

static NSString *WCGestureMomentsInteractionMessageKey(id message) {
    if (!message) return nil;
    NSString *msgID = WCGestureMomentsInteractionStringGetter(message, "msgID");
    if (msgID.length > 0) return [@"msg:" stringByAppendingString:msgID];
    NSString *clientID = WCGestureMomentsInteractionStringGetter(message, "clientId");
    if (clientID.length > 0) return [@"client:" stringByAppendingString:clientID];
    NSString *objectID = WCGestureMomentsInteractionStringGetter(message, "objID");
    NSString *parentID = WCGestureMomentsInteractionStringGetter(message, "parentObjID");
    if (objectID.length > 0 || parentID.length > 0) {
        return [NSString stringWithFormat:@"object:%@:%@", objectID ?: @"", parentID ?: @""];
    }
    return [NSString stringWithFormat:@"pointer:%p", (__bridge void *)message];
}

static long long WCGestureMomentsInteractionMessageType(id message) {
    SEL selector = sel_registerName("msgTypeFromClientId");
    Method method = message ? class_getInstanceMethod([message class], selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != 2) return 0;
    char *returnType = method_copyReturnType(method);
    BOOL matches = WCGestureMomentsInteractionSkipQualifiers(returnType)[0] == 'q';
    free(returnType);
    if (!matches) return 0;
    @try { return ((long long (*)(id, SEL))objc_msgSend)(message, selector); }
    @catch (__unused NSException *exception) { return 0; }
}

static void WCGestureMomentsInteractionNotify(NSUInteger count, NSString *messageKey,
                                           long long messageType, id message) {
    NSString *typeName = messageType == 1 ? @"点赞" : (messageType == 2 ? @"评论" : @"互动");
    BOOL showsDetails = [NSUserDefaults.standardUserDefaults
        boolForKey:WCGestureMomentsInteractionReminderDetailsEnabledKey];
    id comment = WCGestureMomentsInteractionObjectGetter(message, "comment");
    NSString *username = WCGestureMomentsInteractionStringGetter(comment, "username");
    NSString *nickname = WCGestureMomentsInteractionStringGetter(comment, "nickname");
    NSString *author = WCGesturePrivateNotificationDisplayName(username, nickname);
    NSString *commentContent = WCGestureMomentsInteractionStringGetter(comment, "content");
    if (commentContent.length > 100) {
        commentContent = [[commentContent substringToIndex:97] stringByAppendingString:@"…"];
    }
    NSString *title = showsDetails && author.length > 0 ? author : @"朋友圈互动";
    NSString *detail = nil;
    if (showsDetails && messageType == 1) {
        detail = @"点赞了你的朋友圈";
    } else if (showsDetails && messageType == 2 && commentContent.length > 0) {
        detail = [NSString stringWithFormat:@"评论：%@", commentContent];
    } else if (showsDetails && messageType == 2) {
        detail = @"评论了你的朋友圈";
    } else {
        detail = [NSString stringWithFormat:@"朋友圈收到新的%@", typeName];
    }
    NSString *body = nil;
    if (!showsDetails) {
        body = count > 1
            ? [NSString stringWithFormat:@"朋友圈收到 %lu 条新互动", (unsigned long)count]
            : detail;
    } else {
        body = count > 1
            ? [NSString stringWithFormat:@"收到 %lu 条新互动，最新：%@", (unsigned long)count, detail]
            : detail;
    }
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        NSString *symbolName = messageType == 1 ? @"heart.fill" :
                               (messageType == 2 ? @"bubble.left.fill" : @"bell.fill");
        NSString *identifier = [@"moments-interaction:" stringByAppendingString:messageKey ?: @"unknown"];
        WCGestureShowInAppNotification(title, body, identifier, symbolName, ^{
            WCGestureOpenMomentsTimeline();
        });
        return;
    }
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body = body;
    content.sound = UNNotificationSound.defaultSound;
    content.threadIdentifier = @"onewx.moments.interaction";
    content.userInfo = @{ @"onewx": @"moments-interaction" };
    NSString *identifier = [NSString stringWithFormat:@"onewx.moments.interaction.%lu.%lu",
                              (unsigned long)messageKey.hash, (unsigned long)count];
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.0 repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error) NSLog(@"[One Wx] 发送朋友圈互动提醒失败：%@", error.localizedDescription ?: @"未知错误");
    }];
}

@interface WCGestureMomentsInteractionReminderManager : NSObject
@property (nonatomic, weak) id notificationManager;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *lastMessageKey;
@property (nonatomic, assign) unsigned int lastUnreadCount;
@property (nonatomic, assign) NSUInteger pendingIncrease;
@property (nonatomic, assign) BOOL baselineReady;
@property (nonatomic, assign) BOOL lastMessageReadScheduled;
@property (nonatomic, assign) NSUInteger generation;
+ (instancetype)sharedManager;
- (void)observeManager:(id)manager unreadCount:(unsigned int)count;
- (void)observeManager:(id)manager lastUnreadMessage:(id)message;
- (void)tick;
- (void)settingsDidChange;
@end

@implementation WCGestureMomentsInteractionReminderManager

+ (instancetype)sharedManager {
    static WCGestureMomentsInteractionReminderManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WCGestureMomentsInteractionReminderManager new]; });
    return manager;
}

- (NSString *)currentAccount {
    return WCCurrentUserWXID() ?: @"default";
}

- (NSMutableDictionary *)stateRoot {
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureMomentsInteractionStateKey];
    return saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)prepareAccountIfNeeded {
    NSString *account = [self currentAccount];
    if ([self.account isEqualToString:account]) return;
    self.generation++;
    self.account = account;
    NSMutableDictionary *root = [self stateRoot];
    id savedState = root[account];
    NSDictionary *state = [savedState isKindOfClass:NSDictionary.class] ? savedState : nil;
    self.baselineReady = state != nil;
    self.lastUnreadCount = [state[@"count"] unsignedIntValue];
    self.lastMessageKey = [state[@"messageKey"] isKindOfClass:NSString.class] ? state[@"messageKey"] : nil;
    self.pendingIncrease = [state[@"pending"] unsignedIntegerValue];
    self.lastMessageReadScheduled = NO;
}

- (void)saveState {
    if (self.account.length == 0) return;
    NSMutableDictionary *root = [self stateRoot];
    root[self.account] = @{ @"count": @(self.lastUnreadCount),
                            @"messageKey": self.lastMessageKey ?: @"",
                            @"pending": @(self.pendingIncrease) };
    [NSUserDefaults.standardUserDefaults setObject:root forKey:WCGestureMomentsInteractionStateKey];
}

- (void)scheduleLastMessageReadFromManager:(id)manager {
    if (self.lastMessageReadScheduled || !manager) return;
    self.lastMessageReadScheduled = YES;
    NSUInteger generation = self.generation;
    NSString *account = [self currentAccount];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.generation != generation
            || ![account isEqualToString:[strongSelf currentAccount]]) return;
        strongSelf.lastMessageReadScheduled = NO;
        if (!strongSelf || strongSelf.pendingIncrease == 0 ||
            !WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
        SEL lastSelector = sel_registerName("getLastUnReadMessage");
        if (!WCGestureMomentsInteractionMethodHasEncoding(manager, lastSelector, "@16@0:8")) return;
        @try { ((id (*)(id, SEL))objc_msgSend)(manager, lastSelector); }
        @catch (NSException *exception) {
            NSLog(@"[One Wx] 读取朋友圈最后未读互动失败：%@", exception.reason ?: @"未知异常");
        }
    });
}

- (void)observeManager:(id)manager unreadCount:(unsigned int)count {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self observeManager:manager unreadCount:count]; });
        return;
    }
    if (!WCRefreshCachedCurrentUser()) return;
    id currentManager = WCMomentsInteractionCurrentManager();
    if (currentManager && currentManager != manager) return;
    if (manager) self.notificationManager = manager;
    if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
    [self prepareAccountIfNeeded];
    if (!self.baselineReady) {
        self.baselineReady = YES;
        self.lastUnreadCount = count;
        [self saveState];
        return;
    }
    if (count > self.lastUnreadCount) {
        self.pendingIncrease += count - self.lastUnreadCount;
        self.lastUnreadCount = count;
        [self saveState];
        [self scheduleLastMessageReadFromManager:manager ?: self.notificationManager];
    } else if (count < self.lastUnreadCount) {
        self.lastUnreadCount = count;
        self.pendingIncrease = 0;
        [self saveState];
    }
}

- (void)observeManager:(id)manager lastUnreadMessage:(id)message {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self observeManager:manager lastUnreadMessage:message]; });
        return;
    }
    if (!WCRefreshCachedCurrentUser()) return;
    id currentManager = WCMomentsInteractionCurrentManager();
    if (currentManager && currentManager != manager) return;
    if (manager) self.notificationManager = manager;
    if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey) || !message) return;
    [self prepareAccountIfNeeded];
    if (self.pendingIncrease == 0) return;
    NSString *messageKey = WCGestureMomentsInteractionMessageKey(message);
    if (messageKey.length == 0) return;
    NSUInteger increase = self.pendingIncrease;
    self.pendingIncrease = 0;
    BOOL duplicate = [self.lastMessageKey isEqualToString:messageKey];
    long long messageType = WCGestureMomentsInteractionMessageType(message);
    self.lastMessageKey = messageKey;
    [self saveState];
    if (!duplicate) WCGestureMomentsInteractionNotify(increase, messageKey, messageType, message);
}

- (void)tick {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self tick]; });
        return;
    }
    if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
    if (!WCRefreshCachedCurrentUser()) return;
    id manager = WCMomentsInteractionCurrentManager();
    if (!manager && [self.account isEqualToString:WCCurrentUserWXID()]) manager = self.notificationManager;
    if (manager) self.notificationManager = manager;
    SEL selector = sel_registerName("getUnReadMessageCount");
    if (!WCGestureMomentsInteractionMethodHasEncoding(manager, selector, "I16@0:8")) return;
    @try {
        ((unsigned int (*)(id, SEL))objc_msgSend)(manager, selector);
        if (self.pendingIncrease > 0) [self scheduleLastMessageReadFromManager:manager];
    }
    @catch (NSException *exception) { NSLog(@"[One Wx] 读取朋友圈互动未读数失败：%@", exception.reason ?: @"未知异常"); }
}

- (void)settingsDidChange {
    self.generation++;
    if (self.account.length > 0) {
        self.pendingIncrease = 0;
        [self saveState];
    }
    self.account = nil;
    self.baselineReady = NO;
    self.lastMessageReadScheduled = NO;
    if (WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) [self tick];
}

@end

void WCGestureMomentsInteractionObserveUnreadCount(id manager, unsigned int count) {
    if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
    [[WCGestureMomentsInteractionReminderManager sharedManager] observeManager:manager unreadCount:count];
}

void WCGestureMomentsInteractionObserveLastUnreadMessage(id manager, id message) {
    if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
    [[WCGestureMomentsInteractionReminderManager sharedManager] observeManager:manager lastUnreadMessage:message];
}

void WCGestureMomentsInteractionReminderTick(void) {
    [[WCGestureMomentsInteractionReminderManager sharedManager] tick];
}

void WCGestureMomentsInteractionReminderSettingsDidChange(void) {
    [[WCGestureMomentsInteractionReminderManager sharedManager] settingsDidChange];
}
