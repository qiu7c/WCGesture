#import "Sources/API/WCGestureInternal.h"


#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

@interface WCGestureMomentsPrewarmer : NSObject
@property (nonatomic, strong, nullable) UIWindow *window;
@property (nonatomic, copy, nullable) NSString *completedAccount;
@property (nonatomic, assign) BOOL scheduled;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) NSUInteger launchAttemptCount;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, copy) NSString *attemptAccount;
+ (instancetype)sharedPrewarmer;
- (void)scheduleIfNeeded;
- (void)cancel;
@end

static BOOL WCGestureMomentsPrewarmMethodMatches(Class cls, SEL selector, const char *encoding) {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    const char *actual = method ? method_getTypeEncoding(method) : NULL;
    return actual && encoding && strcmp(actual, encoding) == 0;
}

static UIWindowScene *WCGestureMomentsPrewarmActiveScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:UIWindowScene.class]) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

@implementation WCGestureMomentsPrewarmer

+ (instancetype)sharedPrewarmer {
    static WCGestureMomentsPrewarmer *prewarmer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ prewarmer = [WCGestureMomentsPrewarmer new]; });
    return prewarmer;
}

- (void)scheduleIfNeeded {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self scheduleIfNeeded]; });
        return;
    }
    if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey) ||
        self.scheduled || self.running) return;
    WCRefreshCachedCurrentUser();
    NSString *account = WCCurrentUserWXID();
    if (![self.attemptAccount isEqualToString:account]) {
        self.attemptAccount = account;
        self.launchAttemptCount = 0;
    }
    if ([self.completedAccount isEqualToString:account] || self.launchAttemptCount >= 15) return;
    self.scheduled = YES;
    NSUInteger generation = self.generation;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.generation != generation) return;
        strongSelf.scheduled = NO;
        if (!strongSelf || UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
            !WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)) return;
        strongSelf.launchAttemptCount += 1;
        NSString *currentAccount = WCCurrentUserWXID();
        if (currentAccount.length == 0) {
            [strongSelf scheduleIfNeeded];
            return;
        }
        if ([strongSelf.completedAccount isEqualToString:currentAccount]) return;

        Class entryClass = objc_getClass("FindFriendEntryViewController");
        SEL initSelector = sel_registerName("init");
        SEL openSelector = sel_registerName("openAlbum");
        if (!entryClass) {
            [strongSelf scheduleIfNeeded];
            return;
        }
        if (!WCGestureMomentsPrewarmMethodMatches(entryClass, initSelector, "@16@0:8") ||
            !WCGestureMomentsPrewarmMethodMatches(entryClass, openSelector, "v16@0:8")) {
            strongSelf.completedAccount = currentAccount;
            NSLog(@"[One Wx] 隐式初始化朋友圈失败：发现页入口 ABI 不匹配");
            return;
        }
        UIWindowScene *scene = WCGestureMomentsPrewarmActiveScene();
        if (!scene) {
            [strongSelf scheduleIfNeeded];
            return;
        }

        id entry = ((id (*)(id, SEL))objc_msgSend)([entryClass alloc], initSelector);
        if (![entry isKindOfClass:UIViewController.class]) {
            strongSelf.completedAccount = currentAccount;
            NSLog(@"[One Wx] 隐式初始化朋友圈失败：无法创建发现页");
            return;
        }

        UINavigationController *navigation = [[UINavigationController alloc]
            initWithRootViewController:(UIViewController *)entry];
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        window.frame = scene.coordinateSpace.bounds;
        window.windowLevel = UIWindowLevelNormal - 100.0;
        window.alpha = 0.001;
        window.userInteractionEnabled = NO;
        window.backgroundColor = UIColor.clearColor;
        window.accessibilityElementsHidden = YES;
        window.rootViewController = navigation;
        strongSelf.window = window;
        strongSelf.running = YES;
        window.hidden = NO;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            typeof(self) openSelf = weakSelf;
            if (!WCGestureEnabled(WCGestureMomentsInteractionReminderEnabledKey)
                || ![currentAccount isEqualToString:WCCurrentUserWXID()]
                || !openSelf.running || openSelf.window != window ||
                UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
            @try {
                ((void (*)(id, SEL))objc_msgSend)(entry, openSelector);
                NSLog(@"[One Wx] 已在隐式窗口调用朋友圈原生初始化入口");
            } @catch (NSException *exception) {
                NSLog(@"[One Wx] 隐式初始化朋友圈失败：%@", exception.reason ?: @"未知异常");
            }
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            typeof(self) finishSelf = weakSelf;
            if (!finishSelf || finishSelf.window != window) return;
            Class timelineClass = objc_getClass("WCTimeLineViewController");
            BOOL initialized = timelineClass &&
                [navigation.topViewController isKindOfClass:timelineClass];
            if (initialized && [currentAccount isEqualToString:WCCurrentUserWXID()]) {
                finishSelf.completedAccount = currentAccount;
                finishSelf.launchAttemptCount = 0;
            }
            [finishSelf cancel];
            NSLog(@"[One Wx] %@", initialized ? @"朋友圈隐式初始化完成" : @"朋友圈隐式初始化未进入目标控制器");
            if (!initialized) [finishSelf scheduleIfNeeded];
        });
    });
}

- (void)cancel {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self cancel]; });
        return;
    }
    self.generation++;
    self.scheduled = NO;
    self.running = NO;
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.window = nil;
}

@end

void WCGestureMomentsPrewarmIfNeeded(void) {
    [[WCGestureMomentsPrewarmer sharedPrewarmer] scheduleIfNeeded];
}

void WCGestureMomentsPrewarmCancel(void) {
    [[WCGestureMomentsPrewarmer sharedPrewarmer] cancel];
}
