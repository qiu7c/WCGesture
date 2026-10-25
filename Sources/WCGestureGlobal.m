#import "WCGestureGlobal.h"
#import "WCGestureSupport.h"
#import "WCGestureConfig.h"
#import "WCGestureSettingsVC.h"
#import "WCPopup.h"
#import <objc/runtime.h>

#pragma mark - Global multi-finger long-press gestures

@interface CameraScanViewController : UIViewController
@end

static char WCGlobalTwoFingerRecognizerKey;
static char WCGlobalThreeFingerRecognizerKey;

@interface WCScreenshotSaver : NSObject
@end

@implementation WCScreenshotSaver
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    (void)image; (void)contextInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            WCShowToast(@"保存失败，请允许微信访问相册");
        } else {
            WCShowToast(@"已保存到相册");
        }
    });
}
@end

static WCScreenshotSaver *WCScreenshotSaverInstance = nil;

// Capture the key window with several fallbacks, then save via the system
// photo API (which prompts for permission).
static UIImage *WCCaptureScreen(void) {
    UIWindow *window = WCActiveWindow();
    if (!window) return nil;
    CGSize size = window.bounds.size;
    if (size.width < 1.0 || size.height < 1.0) return nil;
    __block BOOL ok = NO;
    UIGraphicsImageRenderer *r1 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *img = [r1 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        (void)ctx;
        ok = [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    }];
    if (ok && img) return img;
    ok = NO;
    UIGraphicsImageRenderer *r2 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    img = [r2 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        (void)ctx;
        ok = [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }];
    if (ok && img) return img;
    UIView *snapshot = [window snapshotViewAfterScreenUpdates:YES];
    if (snapshot) {
        UIGraphicsImageRenderer *r3 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
        img = [r3 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            [snapshot.layer renderInContext:ctx.CGContext];
        }];
        if (img) return img;
    }
    UIGraphicsImageRenderer *r4 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [r4 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [window.layer renderInContext:ctx.CGContext];
    }];
}

// 截图当前 keyWindow
static void WCPerformGlobalScreenshot(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = WCCaptureScreen();
        if (!image) {
            WCShowToast(@"截图失败");
            return;
        }
        if (!WCScreenshotSaverInstance) WCScreenshotSaverInstance = [WCScreenshotSaver new];
        UIImageWriteToSavedPhotosAlbum(image, WCScreenshotSaverInstance,
            @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    });
}

// 返回上一页
static void WCPerformGlobalBack(void) {
    UIViewController *top = WCRootTopController();
    UINavigationController *nav = [top isKindOfClass:[UINavigationController class]]
        ? (UINavigationController *)top : top.navigationController;
    if (nav && nav.viewControllers.count > 1) {
        [nav popViewControllerAnimated:YES];
    } else if (top.presentingViewController) {
        [top dismissViewControllerAnimated:YES completion:nil];
    } else if (nav) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

// 回到首页
static void WCPerformGlobalLockScreen(void) {
    UIViewController *top = WCRootTopController();
    UINavigationController *nav = [top isKindOfClass:[UINavigationController class]]
        ? (UINavigationController *)top : top.navigationController;
    if (nav) [nav popToRootViewControllerAnimated:YES];
    [top dismissViewControllerAnimated:YES completion:nil];
}

// 扫一扫:模态打开（微信本身也是模态展示，不需要全屏 push）
static void WCPerformGlobalScanQR(void) {
    Class scanClass = NSClassFromString(@"CameraScanViewController");
    if (!scanClass) { WCShowToast(@"扫一扫：当前微信版本不支持"); return; }
    id scanVC = [[scanClass alloc] init];
    if (!scanVC) { WCShowToast(@"扫一扫：初始化失败"); return; }
    WCPresentGlobalSheet(scanVC);
}

#pragma mark - Custom page

static void WCOpenMoments(void) {
    Class cls = NSClassFromString(@"WCTimeLineViewController");
    if (!cls) { [WCPopup showMessage:@"朋友圈" message:@"当前微信版本不支持"]; return; }
    @try { WCPushGlobal([[cls alloc] init]); } @catch (__unused NSException *e) {}
}

static void WCOpenAddFriend(void) {
    NSArray<NSString *> *candidates = @[@"AddFriendEntryViewController", @"FTSAddFriendViewController",
                                        @"NewFriendsViewController"];
    for (NSString *name in candidates) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        @try { WCPushGlobal([[cls alloc] init]); return; } @catch (__unused NSException *e) {}
    }
    WCShowToast(@"添加朋友：当前微信版本不支持");
}

static void WCOpenMyQRCode(void) {
    Class cls = NSClassFromString(@"CameraQRCodeListViewController");
    if (!cls) { WCShowToast(@"我的二维码：当前微信版本不支持"); return; }
    @try { WCPresentGlobalSheet([[cls alloc] init]); } @catch (__unused NSException *e) {}
}

// UIApplication treats our own weixin:// scheme as a no-op inside WeChat, but
// the system application workspace still routes it to the app's URL handler,
// which is what opens the payment code.
static BOOL WCOpenURLViaWorkspace(NSString *string) {
    NSURL *url = [NSURL URLWithString:string];
    if (!url) return NO;
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    id workspace = nil;
    if (workspaceClass && [workspaceClass respondsToSelector:defaultSelector]) {
        workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultSelector);
    }
    for (NSString *name in @[@"openSensitiveURL:withOptions:", @"openURL:withOptions:"]) {
        SEL selector = NSSelectorFromString(name);
        if (!workspace || ![workspace respondsToSelector:selector]) continue;
        @try {
            BOOL opened = ((BOOL (*)(id, SEL, id, id))objc_msgSend)(workspace, selector, url, nil);
            if (opened) return YES;
        } @catch (__unused NSException *e) {}
    }
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:url]) {
        [app openURL:url options:@{} completionHandler:nil];
        return YES;
    }
    return NO;
}

static void WCOpenPayCode(void) {
    Class cls = NSClassFromString(@"KindaViewController");
    if (cls) {
        @try {
            WCPresentGlobalSheet([[cls alloc] init]);
            return;
        } @catch (__unused NSException *e) {}
    }
    if (WCOpenURLViaWorkspace(@"weixin://widget/pay")) return;
    WCShowToast(@"付款码：当前微信版本不支持");
}

static void WCPushCustomPageEntry(NSDictionary *entry) {
    NSString *className = [entry[@"class"] isKindOfClass:[NSString class]] ? entry[@"class"] : nil;
    Class cls = className.length > 0 ? NSClassFromString(className) : nil;
    if (!cls) { WCShowToast(@"自定义页面：类名无效"); return; }
    // Each entry chooses 全屏 (push) or 模态 (page sheet); entries saved before
    // the option existed default to 全屏.
    NSString *mode = [entry[@"mode"] isKindOfClass:[NSString class]] ? entry[@"mode"] : @"";
    BOOL modal = [mode isEqualToString:@"modal"];
    @try {
        UIViewController *page = [[cls alloc] init];
        if (modal) WCPresentGlobalSheet(page);
        else WCPushGlobal(page);
    } @catch (__unused NSException *e) {}
}

static void WCOpenCustomPage(void) {
    NSArray<NSDictionary *> *pages = [[NSUserDefaults standardUserDefaults] arrayForKey:WCCustomPagesKey];
    if (![pages isKindOfClass:[NSArray class]] || pages.count == 0) {
        WCShowToast(@"未设置自定义页面");
        return;
    }
    if (pages.count == 1) { WCPushCustomPageEntry(pages.firstObject); return; }
    NSMutableArray<WCPopupOption *> *opts = [NSMutableArray array];
    for (NSUInteger i = 0; i < pages.count; i++) {
        NSDictionary *entry = pages[i];
        NSString *name = [entry[@"name"] isKindOfClass:[NSString class]] ? entry[@"name"] : nil;
        if (name.length == 0) name = entry[@"class"];
        if (name.length == 0) name = @"自定义页面";
        [opts addObject:[WCPopupOption optionWithTitle:name value:@(i)]];
    }
    [WCPopup showOptionsWithTitle:@"自定义页面" message:nil options:opts selected:nil
        completion:^(id value) {
        if (!value) return;
        NSUInteger idx = [value unsignedIntegerValue];
        if (idx < pages.count) WCPushCustomPageEntry(pages[idx]);
    }];
}

void WCPerformGlobalAction(UIViewController *presenter, WCGlobalAction action);

// 弹快捷菜单
static void WCPerformGlobalMenu(UIViewController *presenter) {
    (void)presenter;
    NSMutableArray<WCPopupOption *> *opts = [NSMutableArray array];
    [opts addObject:[WCPopupOption optionWithTitle:@"扫一扫" value:@(WCGlobalActionScanQR)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"朋友圈" value:@(WCGlobalActionMoments)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"添加朋友" value:@(WCGlobalActionAddFriend)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"我的二维码" value:@(WCGlobalActionMyQRCode)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"付款码" value:@(WCGlobalActionPayCode)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"自定义页面" value:@(WCGlobalActionCustomPage)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"截图" value:@(WCGlobalActionScreenshot)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"回到首页" value:@(WCGlobalActionLockScreen)]];
    [WCPopup showOptionsWithTitle:@"快捷操作" message:nil options:opts selected:nil
        completion:^(id value) {
        if (!value) return;
        WCPerformGlobalAction(nil, (WCGlobalAction)[value integerValue]);
    }];
}

// 跳转指定 view 页面(占位:打开 WCGesture 设置页)
static void WCPerformGlobalJump(UIViewController *presenter) {
    WCGesturePresentSettings(presenter);
}

void WCPerformGlobalAction(UIViewController *presenter, WCGlobalAction action) {
    switch (action) {
        case WCGlobalActionScreenshot: WCPerformGlobalScreenshot(); break;
        case WCGlobalActionBack: WCPerformGlobalBack(); break;
        case WCGlobalActionLockScreen: WCPerformGlobalLockScreen(); break;
        case WCGlobalActionScanQR: WCPerformGlobalScanQR(); break;
        case WCGlobalActionMoments: WCOpenMoments(); break;
        case WCGlobalActionAddFriend: WCOpenAddFriend(); break;
        case WCGlobalActionMyQRCode: WCOpenMyQRCode(); break;
        case WCGlobalActionPayCode: WCOpenPayCode(); break;
        case WCGlobalActionCustomPage: WCOpenCustomPage(); break;
        case WCGlobalActionMenu: WCPerformGlobalMenu(presenter); break;
        case WCGlobalActionJump: WCPerformGlobalJump(presenter); break;
        case WCGlobalActionNone: break;
    }
}

// 在指定 window 上按当前设置同步全局手势识别器
void WCSynchronizeGlobalGesturesOnWindow(UIWindow *window) {
    if (!window) return;
    BOOL enabled = WCGestureEnabled(WCGlobalGestureEnabledKey);
    NSInteger twoAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    NSInteger threeAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];

    UILongPressGestureRecognizer *two = objc_getAssociatedObject(window, &WCGlobalTwoFingerRecognizerKey);
    BOOL twoWanted = enabled && twoAction != WCGlobalActionNone;
    if (twoWanted && !two) {
        two = [[UILongPressGestureRecognizer alloc] initWithTarget:window action:@selector(wc_handleGlobalLongPress:)];
        two.numberOfTouchesRequired = 2;
        two.minimumPressDuration = 0.5;
        two.cancelsTouchesInView = NO;
        [window addGestureRecognizer:two];
        objc_setAssociatedObject(window, &WCGlobalTwoFingerRecognizerKey, two, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!twoWanted && two) {
        [window removeGestureRecognizer:two];
        objc_setAssociatedObject(window, &WCGlobalTwoFingerRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UILongPressGestureRecognizer *three = objc_getAssociatedObject(window, &WCGlobalThreeFingerRecognizerKey);
    BOOL threeWanted = enabled && threeAction != WCGlobalActionNone;
    if (threeWanted && !three) {
        three = [[UILongPressGestureRecognizer alloc] initWithTarget:window action:@selector(wc_handleGlobalLongPress:)];
        three.numberOfTouchesRequired = 3;
        three.minimumPressDuration = 0.5;
        three.cancelsTouchesInView = NO;
        [window addGestureRecognizer:three];
        objc_setAssociatedObject(window, &WCGlobalThreeFingerRecognizerKey, three, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!threeWanted && three) {
        [window removeGestureRecognizer:three];
        objc_setAssociatedObject(window, &WCGlobalThreeFingerRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void WCSynchronizeGlobalGestures(void) {
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        WCSynchronizeGlobalGesturesOnWindow(window);
    }
}

