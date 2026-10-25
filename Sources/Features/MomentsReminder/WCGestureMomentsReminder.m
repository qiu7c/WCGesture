#import "Sources/API/WCGestureInternal.h"
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import <math.h>


static id WCGestureMomentsReminderService(const char *className) {
    Class contextClass = objc_getClass("MMContext");
    Class serviceClass = objc_getClass(className);
    SEL activeSelector = sel_registerName("activeUserContext");
    SEL serviceSelector = sel_registerName("getService:");
    if (!contextClass || !serviceClass || ![contextClass respondsToSelector:activeSelector]) return nil;
    id context = ((id (*)(id, SEL))objc_msgSend)(contextClass, activeSelector);
    if (!context || ![context respondsToSelector:serviceSelector]) return nil;
    return ((id (*)(id, SEL, Class))objc_msgSend)(context, serviceSelector, serviceClass);
}

static NSString *WCGestureMomentsReminderLocalUsername(void) {
    Class settingClass = objc_getClass("SettingUtil");
    SEL selector = sel_registerName("getLocalUsrName:");
    if (settingClass && [settingClass respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL, unsigned int))objc_msgSend)(settingClass, selector, 0);
        if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
    }
    return WCCurrentUserWXID();
}

static NSString *WCGestureMomentsReminderForwardTarget(void) {
    return [NSUserDefaults.standardUserDefaults integerForKey:WCGestureMomentsReminderForwardTargetKey] == 1
        ? @"filehelper" : WCGestureMomentsReminderLocalUsername();
}

static NSUInteger WCMomentsReminderForwardGeneration;
@interface WCMomentsForwardContext : NSObject
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *target;
@property (nonatomic) NSUInteger generation;
@end
@implementation WCMomentsForwardContext
@end

static BOOL WCMomentsReminderCanForward(WCMomentsForwardContext *context, NSString *mediaKey) {
    return context && context.generation == WCMomentsReminderForwardGeneration
        && WCGestureEnabled(WCGestureMomentsReminderEnabledKey)
        && WCGestureEnabled(WCGestureMomentsReminderForwardEnabledKey)
        && (!mediaKey || WCGestureEnabled(mediaKey))
        && [WCGestureMomentsReminderUsers() containsObject:context.username]
        && WCRefreshCachedCurrentUser() && [context.account isEqualToString:WCCurrentUserWXID()]
        && [context.target isEqualToString:WCGestureMomentsReminderForwardTarget()];
}

static void WCGestureMomentsReminderSendText(WCMomentsForwardContext *context, NSString *content) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (content.length && WCMomentsReminderCanForward(context, nil)) {
            if (!WCGesturePrivateSendTextMessage(context.target, content)) NSLog(@"[One Wx] 朋友圈文字转发未提交");
        }
    });
}

static void WCGestureMomentsReminderSendImage(WCMomentsForwardContext *context, UIImage *image) {
    if (!image || !WCMomentsReminderCanForward(context, WCGestureMomentsReminderForwardImagesKey)) return;
    NSData *data = UIImagePNGRepresentation(image);
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"onewx-moments-%@.png", NSUUID.UUID.UUIDString]];
    if (![data writeToFile:path atomically:YES]) return;
    if (!WCGesturePrivateSendImageMessage(context.target, path)) NSLog(@"[One Wx] 朋友圈图片转发未提交");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    });
}

static void WCGestureMomentsReminderSendVideo(WCMomentsForwardContext *context, NSString *path) {
    if (path.length && WCMomentsReminderCanForward(context, WCGestureMomentsReminderForwardVideosKey)) {
        if (!WCGesturePrivateSendVideoMessage(context.target, path)) NSLog(@"[One Wx] 朋友圈视频转发未提交");
    }
}

NSArray<NSString *> *WCGestureMomentsReminderUsers(void) {
    NSMutableOrderedSet<NSString *> *users = [NSMutableOrderedSet orderedSet];
    for (id value in [NSUserDefaults.standardUserDefaults arrayForKey:WCGestureMomentsReminderUsersKey] ?: @[]) {
        if ([value isKindOfClass:NSString.class] && [value length] > 0 && ![value hasSuffix:@"@chatroom"]) {
            [users addObject:value];
        }
    }
    return users.array;
}

void WCGestureMomentsReminderSetUserSelected(NSString *username, BOOL selected) {
    if (username.length == 0 || [username hasSuffix:@"@chatroom"]) return;
    NSMutableOrderedSet<NSString *> *users = [NSMutableOrderedSet orderedSetWithArray:WCGestureMomentsReminderUsers()];
    if (selected) [users addObject:username]; else [users removeObject:username];
    [NSUserDefaults.standardUserDefaults setObject:users.array forKey:WCGestureMomentsReminderUsersKey];
    [NSNotificationCenter.defaultCenter postNotificationName:WCGestureDidChangeNotification
                                                       object:WCGestureMomentsReminderUsersKey];
}

static id WCGestureMomentsReminderObjectValue(id object, const char *selectorName) {
    if (!object || !selectorName) return nil;
    SEL selector = sel_registerName(selectorName);
    Method method = class_getInstanceMethod([object class], selector);
    if (!method || method_getNumberOfArguments(method) != 2) return nil;
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] != '@') return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static uint64_t WCGestureMomentsReminderIntegerValue(id object, const char *selectorName) {
    if (!object || !selectorName) return 0;
    SEL selector = sel_registerName(selectorName);
    Method method = class_getInstanceMethod([object class], selector);
    if (!method || method_getNumberOfArguments(method) != 2) return 0;
    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    if (returnType[0] == '@') {
        id value = WCGestureMomentsReminderObjectValue(object, selectorName);
        return [value respondsToSelector:@selector(unsignedLongLongValue)] ? [value unsignedLongLongValue] : 0;
    }
    @try {
        switch (returnType[0]) {
            case 'I': return ((unsigned int (*)(id, SEL))objc_msgSend)(object, selector);
            case 'i': return (uint64_t)((int (*)(id, SEL))objc_msgSend)(object, selector);
            case 'Q': return ((unsigned long long (*)(id, SEL))objc_msgSend)(object, selector);
            case 'q': return (uint64_t)((long long (*)(id, SEL))objc_msgSend)(object, selector);
            default: return 0;
        }
    }
    @catch (__unused NSException *exception) { return 0; }
}

static NSString *WCGestureMomentsReminderString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return text.length > 0 ? text : nil;
    }
    return [value respondsToSelector:@selector(stringValue)] ? [value stringValue] : nil;
}

static NSArray *WCGestureMomentsReminderMediaList(id dataItem) {
    id contentObject = WCGestureMomentsReminderObjectValue(dataItem, "contentObj");
    id mediaList = WCGestureMomentsReminderObjectValue(contentObject, "mediaList");
    return [mediaList isKindOfClass:NSArray.class] ? mediaList : @[];
}

static id WCGestureMomentsReminderFacade(void) {
    return WCGestureMomentsReminderService("WCFacade");
}

static void WCMomentsReminderPollMedia(id mediaItem, WCMomentsForwardContext *context, BOOL video, NSUInteger attempts) {
    NSString *key = video ? WCGestureMomentsReminderForwardVideosKey : WCGestureMomentsReminderForwardImagesKey;
    if (!WCMomentsReminderCanForward(context, key)) return;
    if (video) {
        for (NSArray<NSString *> *pair in @[@[@"hasSight", @"pathForSightData"], @[@"hasAttachVideo", @"pathForAttachVideoData"]]) {
            SEL ready = NSSelectorFromString(pair[0]);
            if (![mediaItem respondsToSelector:ready] || !((BOOL (*)(id, SEL))objc_msgSend)(mediaItem, ready)) continue;
            id path = WCGestureMomentsReminderObjectValue(mediaItem, pair[1].UTF8String);
            if (![path isKindOfClass:NSString.class]) continue;
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
            if ([attributes[NSFileSize] unsignedLongLongValue] > 0) {
                WCGestureMomentsReminderSendVideo(context, path);
                return;
            }
        }
    } else {
        SEL imageSelector = NSSelectorFromString(@"imageOfSize:");
        id image = [mediaItem respondsToSelector:imageSelector]
            ? ((id (*)(id, SEL, long long))objc_msgSend)(mediaItem, imageSelector, 2) : nil;
        if ([image isKindOfClass:UIImage.class]) {
            WCGestureMomentsReminderSendImage(context, image);
            return;
        }
    }
    if (attempts == 0) { NSLog(@"[One Wx] 朋友圈媒体下载超时"); return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        WCMomentsReminderPollMedia(mediaItem, context, video, attempts - 1);
    });
}

static long long WCMomentsReminderDownloadCategory(id mediaItem, BOOL video) {
    Class cls = NSClassFromString(video ? @"WCDownloadVideoCDNMgr" : @"WCDownloadImageCdnMgr");
    SEL selector = NSSelectorFromString(video ? @"videoDownloadCategoryForMediaItem:" : @"imageDownloadCategoryForMediaItem:");
    return [cls respondsToSelector:selector] ? ((long long (*)(id, SEL, id))objc_msgSend)(cls, selector, mediaItem) : 0;
}

static void WCGestureMomentsReminderDownloadImage(id mediaItem, WCMomentsForwardContext *context) {
    if (!mediaItem || !WCMomentsReminderCanForward(context, WCGestureMomentsReminderForwardImagesKey)) return;
    id facade = WCGestureMomentsReminderFacade();
    SEL managerSelector = NSSelectorFromString(@"imageDownloadCdnMgrForCategory:");
    if (![facade respondsToSelector:managerSelector]) return;
    id manager = ((id (*)(id, SEL, long long))objc_msgSend)(facade, managerSelector, WCMomentsReminderDownloadCategory(mediaItem, NO));
    SEL download = NSSelectorFromString(@"StartDownloadImage:downloadType:needNotify:force:");
    if (![manager respondsToSelector:download]) return;
    @try {
        ((void (*)(id, SEL, id, long long, BOOL, BOOL))objc_msgSend)(manager, download, mediaItem, 2, NO, YES);
        WCMomentsReminderPollMedia(mediaItem, context, NO, 180);
    } @catch (NSException *exception) { NSLog(@"[One Wx] 朋友圈图片下载失败：%@", exception.name); }
}

static void WCGestureMomentsReminderDownloadVideo(id mediaItem, WCMomentsForwardContext *context) {
    if (!mediaItem || !WCMomentsReminderCanForward(context, WCGestureMomentsReminderForwardVideosKey)) return;
    id facade = WCGestureMomentsReminderFacade();
    SEL managerSelector = NSSelectorFromString(@"videoDownloadCdnMgrForCategory:");
    if (![facade respondsToSelector:managerSelector]) return;
    id manager = ((id (*)(id, SEL, long long))objc_msgSend)(facade, managerSelector, WCMomentsReminderDownloadCategory(mediaItem, YES));
    SEL download = NSSelectorFromString(@"StartDownloadVideo:DownloadMode:");
    if (![manager respondsToSelector:download]) return;
    @try {
        (void)((unsigned long long (*)(id, SEL, id, unsigned long long))objc_msgSend)(manager, download, mediaItem, 1);
        WCMomentsReminderPollMedia(mediaItem, context, YES, 300);
    } @catch (NSException *exception) { NSLog(@"[One Wx] 朋友圈视频下载失败：%@", exception.name); }
}

static NSString *WCGestureMomentsReminderContentTypeName(id dataItem) {
    id contentObject = WCGestureMomentsReminderObjectValue(dataItem, "contentObj");
    uint64_t type = WCGestureMomentsReminderIntegerValue(contentObject, "type");
    if (type == 1 || type == 54) return @"图片";
    if (type == 15) return @"视频";
    return @"文字";
}

static void WCGestureMomentsReminderForwardItem(id dataItem, NSString *username, NSString *nickname,
                                            NSString *content, uint64_t createdAt) {
    if (!WCGestureEnabled(WCGestureMomentsReminderForwardEnabledKey) || !dataItem) return;
    NSString *target = WCGestureMomentsReminderForwardTarget();
    if (target.length == 0) return;
    WCMomentsForwardContext *context = [WCMomentsForwardContext new];
    context.account = WCCurrentUserWXID();
    context.username = username;
    context.target = target;
    context.generation = WCMomentsReminderForwardGeneration;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *name = WCGesturePrivateNotificationDisplayName(username, nickname);
    NSString *copyText = content.length > 0 ? [NSString stringWithFormat:@"文案: %@", content] : @"";
    NSString *message = [NSString stringWithFormat:@"【朋友圈特别关注】\n好友: %@\n类型: %@\n时间: %@\n%@",
                         name ?: @"", WCGestureMomentsReminderContentTypeName(dataItem),
                         [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:createdAt]], copyText];
    WCGestureMomentsReminderSendText(context, message);

    id contentObject = WCGestureMomentsReminderObjectValue(dataItem, "contentObj");
    uint64_t type = WCGestureMomentsReminderIntegerValue(contentObject, "type");
    NSArray *mediaList = WCGestureMomentsReminderMediaList(dataItem);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:WCGestureMomentsReminderForwardImagesKey] && (type == 1 || type == 54)) {
        for (id mediaItem in mediaList) WCGestureMomentsReminderDownloadImage(mediaItem, context);
    }
    if ([defaults boolForKey:WCGestureMomentsReminderForwardVideosKey]) {
        if (type == 15 && mediaList.count > 0) {
            WCGestureMomentsReminderDownloadVideo(mediaList.firstObject, context);
        } else if (type == 54) {
            for (id mediaItem in mediaList) {
                id liveMedia = WCGestureMomentsReminderObjectValue(mediaItem, "livePhotoMediaItem");
                if (liveMedia) WCGestureMomentsReminderDownloadVideo(liveMedia, context);
            }
        }
    }
}

static id WCGestureMomentsReminderContact(NSString *username) {
    return WCPrivateContact(username);
}

static void WCGestureMomentsReminderNotify(NSString *username, NSString *nickname, NSString *content, uint64_t createdAt, NSString *tid) {
    NSString *name = WCGesturePrivateNotificationDisplayName(username, nickname);
    if (name.length == 0) name = @"好友";
    NSString *body = content.length > 0 ? content : @"发布了新朋友圈";
    if (body.length > 180) body = [[body substringToIndex:177] stringByAppendingString:@"…"];
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        NSString *identifier = [NSString stringWithFormat:@"moments-reminder:%@:%@",
                                  username ?: @"unknown", tid ?: @"unknown"];
        WCGestureShowInAppNotification(name, body, identifier, @"circle.grid.3x3", ^{
            WCGestureOpenMomentsTimeline();
        });
        return;
    }
    UNMutableNotificationContent *notification = [UNMutableNotificationContent new];
    notification.title = name;
    notification.body = body;
    notification.sound = UNNotificationSound.defaultSound;
    notification.threadIdentifier = @"onewx.moments.reminder";
    notification.userInfo = @{ @"onewx": @"moments-reminder", @"username": username ?: @"", @"tid": tid ?: @"" };
    NSString *identifier = [NSString stringWithFormat:@"onewx.moments.%@.%@.%llu", username ?: @"unknown", tid ?: @"unknown", createdAt];
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.0 repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:notification trigger:trigger];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        if (error) NSLog(@"[One Wx] 发送朋友圈提醒失败：%@", error.localizedDescription ?: @"未知错误");
    }];
}

@interface WCGestureMomentsReminderManager : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *controllers;
@property (nonatomic, assign) NSTimeInterval lastCheckTime;
@property (nonatomic, assign) BOOL checking;
@property (nonatomic, copy) NSString *account;
+ (instancetype)sharedManager;
- (void)tick;
- (void)performCheck;
- (void)settingsDidChange;
@end

@implementation WCGestureMomentsReminderManager

+ (instancetype)sharedManager {
    static WCGestureMomentsReminderManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [WCGestureMomentsReminderManager new];
        manager.controllers = [NSMutableDictionary dictionary];
    });
    return manager;
}

- (NSTimeInterval)checkInterval {
    NSTimeInterval interval = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureMomentsReminderIntervalKey];
    return MIN(3600.0, MAX(30.0, isfinite(interval) && interval > 0.0 ? interval : 60.0));
}

- (id)controllerForUsername:(NSString *)username {
    id controller = self.controllers[username];
    if (controller) return controller;
    Class controllerClass = objc_getClass("WCListViewController");
    id contact = WCGestureMomentsReminderContact(username);
    if (!controllerClass || !contact) return nil;
    controller = [[controllerClass alloc] init];
    SEL setContactSelector = sel_registerName("setM_contact:");
    if (![controller respondsToSelector:setContactSelector]) return nil;
    ((void (*)(id, SEL, id))objc_msgSend)(controller, setContactSelector, contact);
    self.controllers[username] = controller;
    return controller;
}

- (NSArray *)loadItemsForUsername:(NSString *)username success:(BOOL *)success {
    if (success) *success = NO;
    id controller = [self controllerForUsername:username];
    SEL initDataSelector = sel_registerName("initData:");
    Method initDataMethod = controller ? class_getInstanceMethod([controller class], initDataSelector) : NULL;
    const char *initDataEncoding = initDataMethod ? method_getTypeEncoding(initDataMethod) : NULL;
    if (!initDataEncoding || strcmp(initDataEncoding, "v20@0:8B16") != 0) {
        NSLog(@"[One Wx] 读取 %@ 的朋友圈数据失败：initData: ABI 不匹配", username);
        return @[];
    }
    @try {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(controller, initDataSelector, YES);
        id value = [controller valueForKey:@"m_arrPhotoDatas"];
        if (![value isKindOfClass:NSArray.class]) return @[];
        if (success) *success = YES;
        return [value copy];
    } @catch (NSException *exception) {
        NSLog(@"[One Wx] 读取 %@ 的朋友圈数据失败：%@", username, exception.reason ?: @"未知异常");
        return @[];
    }
}

- (void)processItems:(NSArray *)items username:(NSString *)username seenRoot:(NSMutableDictionary *)seenRoot account:(NSString *)account {
    if (username.length == 0) return;
    NSMutableDictionary *accountSeen = [seenRoot[account] isKindOfClass:NSDictionary.class]
        ? [seenRoot[account] mutableCopy] : [NSMutableDictionary dictionary];
    BOOL hasBaseline = [accountSeen[username] isKindOfClass:NSArray.class];
    NSArray<NSString *> *previouslySeen = hasBaseline ? accountSeen[username] : @[];
    NSSet<NSString *> *previouslySeenSet = [NSSet setWithArray:previouslySeen];
    NSMutableOrderedSet<NSString *> *currentTids = [NSMutableOrderedSet orderedSet];
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSMutableArray<NSDictionary *> *newItems = [NSMutableArray array];

    for (id item in items) {
        NSString *tid = WCGestureMomentsReminderString(WCGestureMomentsReminderObjectValue(item, "tid"));
        if (tid.length == 0 || [currentTids containsObject:tid]) continue;
        BOOL alreadySeen = [previouslySeenSet containsObject:tid];
        [currentTids addObject:tid];
        if (!hasBaseline || alreadySeen) continue;
        uint64_t createdAt = WCGestureMomentsReminderIntegerValue(item, "createtime");
        if (createdAt == 0 || now - (NSTimeInterval)createdAt > 86400.0) continue;
        NSString *nickname = WCGestureMomentsReminderString(WCGestureMomentsReminderObjectValue(item, "nickname"));
        NSString *content = WCGestureMomentsReminderString(WCGestureMomentsReminderObjectValue(item, "contentDesc"));
        [newItems addObject:@{ @"tid": tid,
                               @"createdAt": @(createdAt),
                               @"nickname": nickname ?: @"",
                               @"content": content ?: @"",
                               @"dataItem": item }];
    }

    NSMutableOrderedSet<NSString *> *mergedSeen = [NSMutableOrderedSet orderedSetWithOrderedSet:currentTids];
    [mergedSeen addObjectsFromArray:previouslySeen];
    while (mergedSeen.count > 200) [mergedSeen removeObjectAtIndex:mergedSeen.count - 1];
    accountSeen[username] = mergedSeen.array;
    seenRoot[account] = accountSeen;
    for (NSDictionary *item in [newItems sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"createdAt"] compare:right[@"createdAt"]];
    }]) {
        WCGestureMomentsReminderNotify(username, item[@"nickname"], item[@"content"],
                                   [item[@"createdAt"] unsignedLongLongValue], item[@"tid"]);
        WCGestureMomentsReminderForwardItem(item[@"dataItem"], username, item[@"nickname"], item[@"content"],
                                        [item[@"createdAt"] unsignedLongLongValue]);
    }
}

- (void)tick {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self tick]; });
        return;
    }
    if (!WCGestureEnabled(WCGestureMomentsReminderEnabledKey) || !WCRefreshCachedCurrentUser()) return;
    NSString *account = WCCurrentUserWXID();
    if (![self.account isEqualToString:account]) {
        self.account = account;
        [self.controllers removeAllObjects];
        self.lastCheckTime = 0;
        WCMomentsReminderForwardGeneration++;
    }
    if (self.checking) return;
    NSArray<NSString *> *users = WCGestureMomentsReminderUsers();
    if (users.count == 0) return;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (self.lastCheckTime > 0.0 && now - self.lastCheckTime < [self checkInterval]) return;
    self.lastCheckTime = now;
    self.checking = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performCheck];
    });
}

- (void)performCheck {
    if (!WCGestureEnabled(WCGestureMomentsReminderEnabledKey) || !WCRefreshCachedCurrentUser()
        || ![self.account isEqualToString:WCCurrentUserWXID()]) {
        self.checking = NO;
        return;
    }
    NSArray<NSString *> *users = WCGestureMomentsReminderUsers();
    if (users.count == 0) {
        self.checking = NO;
        return;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *seenRoot = [[defaults dictionaryForKey:WCGestureMomentsReminderSeenItemsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *account = self.account;
    for (NSString *username in users) {
        BOOL loaded = NO;
        NSArray *items = [self loadItemsForUsername:username success:&loaded];
        if (loaded) {
            [self processItems:items username:username seenRoot:seenRoot account:account];
        }
    }
    [defaults setObject:seenRoot forKey:WCGestureMomentsReminderSeenItemsKey];
    self.checking = NO;
}

- (void)settingsDidChange {
    WCMomentsReminderForwardGeneration++;
    if (!WCGestureEnabled(WCGestureMomentsReminderEnabledKey)) [self.controllers removeAllObjects];
    self.lastCheckTime = 0.0;
    NSSet *selected = [NSSet setWithArray:WCGestureMomentsReminderUsers()];
    for (NSString *username in self.controllers.allKeys.copy) {
        if (![selected containsObject:username]) [self.controllers removeObjectForKey:username];
    }
    if (WCGestureEnabled(WCGestureMomentsReminderEnabledKey)) [self tick];
}

@end

void WCGestureMomentsReminderTick(void) {
    [[WCGestureMomentsReminderManager sharedManager] tick];
}

void WCGestureMomentsReminderSettingsDidChange(void) {
    [[WCGestureMomentsReminderManager sharedManager] settingsDidChange];
}
