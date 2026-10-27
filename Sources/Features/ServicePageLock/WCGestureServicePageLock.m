#import <LocalAuthentication/LocalAuthentication.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCServiceLockRequest : NSObject
@property (nonatomic, strong) LAContext *context;
@property (nonatomic, weak) UIViewController *owner;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) dispatch_block_t action;
@property (nonatomic) BOOL approved;
@end
@implementation WCServiceLockRequest
@end

// All request state is main-thread-only. Authorization lasts only for this
// synchronous native navigation call, never for later taps or other pages.
static WCServiceLockRequest *WCServicePending;
static WCServiceLockRequest *WCServiceAuthorized;

static NSString *WCPageLockKey(WCGesturePageLockTarget target) {
    switch (target) {
        case WCGesturePageLockService: return WCGestureServicePageLockEnabledKey;
        case WCGesturePageLockFavorites: return WCGestureFavoritesPageLockEnabledKey;
        case WCGesturePageLockMomentsAlbum: return WCGestureMomentsAlbumPageLockEnabledKey;
    }
    return nil;
}
static NSString *WCPageLockTitle(WCGesturePageLockTarget target) {
    switch (target) {
        case WCGesturePageLockService: return @"服务";
        case WCGesturePageLockFavorites: return @"收藏";
        case WCGesturePageLockMomentsAlbum: return @"我的朋友圈";
    }
    return @"页面";
}

static void WCServiceCancelPending(void) {
    WCServiceLockRequest *request = WCServicePending;
    WCServicePending = nil;
    request.action = nil;
    [request.context invalidate];
}
static BOOL WCServiceOriginVisible(WCServiceLockRequest *request) {
    UIViewController *owner = request.owner;
    UIWindow *window = request.window;
    if (!owner.isViewLoaded || !window || owner.view.window != window || window.hidden || window.alpha < .01 ||
        owner.isBeingDismissed || owner.isMovingFromParentViewController || owner.presentedViewController) return NO;
    for (UIView *view = owner.view; view; view = view.superview)
        if (view.hidden || view.alpha < .01) return NO;
    if (owner.navigationController && owner.navigationController.topViewController != owner) return NO;
    UITabBarController *tabs = owner.tabBarController;
    if (tabs && tabs.selectedViewController != owner &&
        tabs.selectedViewController != owner.navigationController) return NO;
    return YES;
}
static void WCServiceResumeApproved(void) {
    WCServiceLockRequest *request = WCServicePending;
    if (!request || !request.approved || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    UIWindowScene *scene = request.window.windowScene;
    if (scene && scene.activationState != UISceneActivationStateForegroundActive) return;
    if (!WCGestureEnabled(request.key) || !WCServiceOriginVisible(request) ||
        !WCRefreshCachedCurrentUser() || ![request.account isEqualToString:WCCurrentUserWXID() ?: @""]) {
        WCServiceCancelPending(); return;
    }
    dispatch_block_t action = request.action;
    WCServiceCancelPending();
    if (!action) return;
    WCServiceLockRequest *previous = WCServiceAuthorized;
    WCServiceAuthorized = request;
    @try { action(); }
    @finally { WCServiceAuthorized = previous; }
}

void WCGestureServicePageLockPerform(UIViewController *owner, dispatch_block_t action) {
    WCGesturePageLockPerform(owner, WCGesturePageLockService, action);
}
void WCGesturePageLockPerform(UIViewController *owner, WCGesturePageLockTarget target, dispatch_block_t action) {
    if (!action) return;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCGesturePageLockPerform(owner, target, action); }); return;
    }
    NSString *key = WCPageLockKey(target), *title = WCPageLockTitle(target);
    if (!key) return;
    if (!WCGestureEnabled(key) || (WCServiceAuthorized.owner == owner && [WCServiceAuthorized.key isEqualToString:key])) {
        action(); return;
    }
    if (WCServicePending || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    if (!WCRefreshCachedCurrentUser() || !WCCurrentUserWXID().length) {
        WCShowToast(@"尚未获取当前账号，未打开页面"); return;
    }
    WCServiceLockRequest *request = [WCServiceLockRequest new];
    request.owner = owner; request.window = owner.isViewLoaded ? owner.view.window : nil;
    request.account = WCCurrentUserWXID(); request.key = key; request.action = action;
    if (!WCServiceOriginVisible(request)) return;
    WCServicePending = request;
    @try {
        LAContext *context = [LAContext new]; request.context = context;
        context.localizedCancelTitle = @"取消";
        NSError *error = nil;
        // Match the confirmed policy=2 call, while retaining WeChat's own wallet
        // verification inside the original method after our entry check.
        if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
            WCServiceCancelPending();
            WCShowToast(@"系统身份验证不可用，未打开页面"); return;
        }
        id faceUsage = [NSBundle.mainBundle objectForInfoDictionaryKey:@"NSFaceIDUsageDescription"];
        if (context.biometryType == LABiometryTypeFaceID &&
            (![faceUsage isKindOfClass:NSString.class] || ![(NSString *)faceUsage length])) {
            WCServiceCancelPending();
            WCShowToast(@"当前微信未配置 Face ID 权限，未打开页面"); return;
        }
        __weak WCServiceLockRequest *weakRequest = request;
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:[@"验证身份以进入" stringByAppendingString:title]
            reply:^(BOOL success, NSError *authenticationError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    WCServiceLockRequest *current = weakRequest;
                    if (!current || WCServicePending != current) return;
                    if (!success) {
                        WCServiceCancelPending();
                        if (authenticationError.code != LAErrorUserCancel && authenticationError.code != LAErrorSystemCancel &&
                            authenticationError.code != LAErrorAppCancel) WCShowToast(@"验证未通过，未打开页面");
                        return;
                    }
                    current.approved = YES;
                    // The system prompt can temporarily deactivate the app.
                    // Wait for activation if necessary; backgrounding cancels.
                    WCServiceResumeApproved();
                });
            }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 90 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            WCServiceLockRequest *current = weakRequest;
            if (current && WCServicePending == current) WCServiceCancelPending();
        });
    } @catch (__unused NSException *exception) {
        if (WCServicePending == request) WCServiceCancelPending();
        WCShowToast(@"身份验证暂不可用，未打开页面");
    }
}
void WCGestureServicePageLockCancel(UIViewController *owner) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ WCGestureServicePageLockCancel(owner); }); return;
    }
    if (!owner || WCServicePending.owner == owner) WCServiceCancelPending();
}
void WCGestureServicePageLockSettingsChanged(NSString *key) {
    if (key && ![@[WCGestureServicePageLockEnabledKey, WCGestureFavoritesPageLockEnabledKey,
        WCGestureMomentsAlbumPageLockEnabledKey] containsObject:key]) return;
    if (!key || [WCServicePending.key isEqualToString:key]) WCGestureServicePageLockCancel(nil);
}
void WCGestureServicePageLockStart(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *note) { WCServiceCancelPending(); }];
            [center addObserverForName:UISceneDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) {
                    if (WCServicePending.window.windowScene == note.object) WCServiceCancelPending();
                }];
            [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *note) { WCServiceResumeApproved(); }];
            [center addObserverForName:UISceneDidActivateNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *note) { WCServiceResumeApproved(); }];
        });
    });
}
