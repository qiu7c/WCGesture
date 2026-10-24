

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "Sources/WCGestureConfig.h"
#import "Sources/WCGestureAccount.h"
#import "Sources/WCGestureSettingsVC.h"
#import "Sources/WCPopup.h"

#pragma mark - Helpers

static UIWindow *WCGlobalActiveWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) return w;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (!w.hidden && w.alpha > 0.0) return w;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static UIViewController *WCTopController(void) {
    UIViewController *root = WCGlobalActiveWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

static UINavigationController *WCPushableNavigation(void) {
    UIViewController *top = WCTopController();
    if ([top isKindOfClass:[UINavigationController class]]) return (UINavigationController *)top;
    UIViewController *cur = top;
    while (cur && !cur.navigationController) cur = cur.parentViewController;
    return cur.navigationController;
}

static void WCPushController(UIViewController *vc) {
    if (!vc) return;
    UINavigationController *nav = WCPushableNavigation();
    if (nav) {
        [nav pushViewController:vc animated:YES];
    } else {
        UIViewController *top = WCTopController();
        [top presentViewController:vc animated:YES completion:nil];
    }
}

static void WCPlayHaptic(void) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:WCGlobalGestureHapticKey]) return;
    UIImpactFeedbackStyle style = UIImpactFeedbackStyleMedium;
    switch ((WCHapticStyle)[[NSUserDefaults standardUserDefaults] integerForKey:WCGestureHapticStyleKey]) {
        case WCHapticStyleLight: style = UIImpactFeedbackStyleLight; break;
        case WCHapticStyleHeavy: style = UIImpactFeedbackStyleHeavy; break;
        case WCHapticStyleSoft: style = UIImpactFeedbackStyleSoft; break;
        case WCHapticStyleRigid: style = UIImpactFeedbackStyleRigid; break;
        default: style = UIImpactFeedbackStyleMedium; break;
    }
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
    [gen prepare];
    [gen impactOccurred];
}

#pragma mark - Custom page (WKWebView)

@interface WCCustomPageController : UIViewController
- (instancetype)initWithURLString:(NSString *)urlString;
@end

@implementation WCCustomPageController {
    NSString *_urlString;
    WKWebView *_webView;
}

- (instancetype)initWithURLString:(NSString *)urlString {
    self = [super init];
    if (self) {
        _urlString = [urlString copy];
        self.title = @"自定义页面";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:cfg];
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_webView];
    NSURL *url = _urlString.length > 0 ? [NSURL URLWithString:_urlString] : nil;
    if (url) [_webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Global actions

static BOOL WCOpenScanQR(void) {
    Class cls = NSClassFromString(@"CameraScanViewController");
    if (!cls) return NO;
    @try {
        UIViewController *vc = [[cls alloc] init];
        if (vc) { WCPushController(vc); return YES; }
    } @catch (__unused NSException *e) {}
    return NO;
}

static BOOL WCOpenMoments(void) {
    Class cls = NSClassFromString(@"WCTimeLineViewController");
    if (!cls) return NO;
    @try {
        UIViewController *vc = [[cls alloc] init];
        if (vc) { WCPushController(vc); return YES; }
    } @catch (__unused NSException *e) {}
    return NO;
}

static BOOL WCOpenAddFriend(void) {
    NSArray<NSString *> *candidates = @[
        @"FTSAddFriendViewController", @"NewFriendsViewController",
        @"AddContactViewController", @"ContactsViewController",
    ];
    for (NSString *name in candidates) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        @try {
            UIViewController *vc = [[cls alloc] init];
            if (vc) { WCPushController(vc); return YES; }
        } @catch (__unused NSException *e) {}
    }
    return NO;
}

static BOOL WCOpenCustomPage(void) {
    NSString *url = [[NSUserDefaults standardUserDefaults] stringForKey:WCCustomPageURLKey];
    if (url.length == 0) {
        [WCPopup showMessage:@"未设置自定义页面" message:@"请在 全局手势 › 自定义页面地址 中填写网址"];
        return NO;
    }
    WCCustomPageController *vc = [[WCCustomPageController alloc] initWithURLString:url];
    WCPushController(vc);
    return YES;
}

static void WCPerformBack(void) {
    UIViewController *top = WCTopController();
    if (top.navigationController && top.navigationController.viewControllers.count > 1) {
        [top.navigationController popViewControllerAnimated:YES];
    } else if (top.presentingViewController) {
        [top dismissViewControllerAnimated:YES completion:nil];
    } else if (top.navigationController) {
        [top.navigationController popToRootViewControllerAnimated:YES];
    }
}

static void WCPerformHome(void) {
    UIViewController *root = WCGlobalActiveWindow().rootViewController;
    UINavigationController *nav = root.navigationController ?: (root.presentedViewController.navigationController);
    if (nav) [nav popToRootViewControllerAnimated:YES];
    [root dismissViewControllerAnimated:YES completion:nil];
}

@interface WCScreenshotSaver : NSObject
@end

@implementation WCScreenshotSaver
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    (void)image; (void)contextInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            [WCPopup showMessage:@"保存失败" message:@"请允许微信访问相册后重试"];
        } else {
            [WCPopup showMessage:@"已保存到相册" message:nil];
        }
    });
}
@end

static WCScreenshotSaver *WCScreenshotSaverInstance = nil;

// Capture the key window with several fallbacks. drawViewHierarchy can return
// NO (blank) when called right after a gesture, so we try afterScreenUpdates
// both ways and fall back to rendering a snapshot / the window layer.
static UIImage *WCCaptureScreen(void) {
    UIWindow *window = WCGlobalActiveWindow();
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

static void WCPerformScreenshot(void) {
    // Defer to the next runloop so the UI has settled after the long-press.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = WCCaptureScreen();
        if (!image) {
            [WCPopup showMessage:@"截图失败" message:@"无法捕获当前画面"];
            return;
        }
        if (!WCScreenshotSaverInstance) WCScreenshotSaverInstance = [WCScreenshotSaver new];
        UIImageWriteToSavedPhotosAlbum(image, WCScreenshotSaverInstance,
            @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    });
}

static void WCPerformGlobalAction(WCGlobalAction action) {
    switch (action) {
        case WCGlobalActionScanQR: WCOpenScanQR(); break;
        case WCGlobalActionMoments: WCOpenMoments(); break;
        case WCGlobalActionAddFriend: WCOpenAddFriend(); break;
        case WCGlobalActionCustomPage: WCOpenCustomPage(); break;
        case WCGlobalActionScreenshot: WCPerformScreenshot(); break;
        case WCGlobalActionBack: WCPerformBack(); break;
        case WCGlobalActionLockScreen: WCPerformHome(); break;
        case WCGlobalActionMenu: {
            NSMutableArray<WCPopupOption *> *opts = [NSMutableArray array];
            [opts addObject:[WCPopupOption optionWithTitle:@"扫一扫" value:@(WCGlobalActionScanQR)]];
            [opts addObject:[WCPopupOption optionWithTitle:@"朋友圈" value:@(WCGlobalActionMoments)]];
            [opts addObject:[WCPopupOption optionWithTitle:@"添加朋友" value:@(WCGlobalActionAddFriend)]];
            [opts addObject:[WCPopupOption optionWithTitle:@"自定义页面" value:@(WCGlobalActionCustomPage)]];
            [opts addObject:[WCPopupOption optionWithTitle:@"截图" value:@(WCGlobalActionScreenshot)]];
            [opts addObject:[WCPopupOption optionWithTitle:@"回到首页" value:@(WCGlobalActionLockScreen)]];
            [WCPopup showOptionsWithTitle:@"快捷操作" message:nil options:opts selected:nil
                completion:^(id value) {
                if (!value) return;
                WCPerformGlobalAction((WCGlobalAction)[value integerValue]);
            }];
            break;
        }
        case WCGlobalActionJump: WCGesturePresentSettings(WCTopController()); break;
        case WCGlobalActionNone: break;
    }
}

#pragma mark - Global gesture recognizers

static char WCGlobalTwoFingerKey;
static char WCGlobalThreeFingerKey;

static void WCSyncGlobalGesturesOnWindow(UIWindow *window) {
    if (!window) return;
    BOOL enabled = WCGestureEnabled(WCGlobalGestureEnabledKey);
    NSInteger twoAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    NSInteger threeAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];

    UILongPressGestureRecognizer *two = objc_getAssociatedObject(window, &WCGlobalTwoFingerKey);
    BOOL twoWanted = enabled && twoAction != WCGlobalActionNone;
    if (twoWanted && !two) {
        two = [[UILongPressGestureRecognizer alloc] initWithTarget:window action:@selector(wc_handleGlobalLongPress:)];
        two.numberOfTouchesRequired = 2;
        two.minimumPressDuration = 0.5;
        two.cancelsTouchesInView = NO;
        [window addGestureRecognizer:two];
        objc_setAssociatedObject(window, &WCGlobalTwoFingerKey, two, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!twoWanted && two) {
        [window removeGestureRecognizer:two];
        objc_setAssociatedObject(window, &WCGlobalTwoFingerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UILongPressGestureRecognizer *three = objc_getAssociatedObject(window, &WCGlobalThreeFingerKey);
    BOOL threeWanted = enabled && threeAction != WCGlobalActionNone;
    if (threeWanted && !three) {
        three = [[UILongPressGestureRecognizer alloc] initWithTarget:window action:@selector(wc_handleGlobalLongPress:)];
        three.numberOfTouchesRequired = 3;
        three.minimumPressDuration = 0.5;
        three.cancelsTouchesInView = NO;
        [window addGestureRecognizer:three];
        objc_setAssociatedObject(window, &WCGlobalThreeFingerKey, three, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!threeWanted && three) {
        [window removeGestureRecognizer:three];
        objc_setAssociatedObject(window, &WCGlobalThreeFingerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCSyncGlobalGestures(void) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) WCSyncGlobalGesturesOnWindow(w);
}

%hook UIWindow

- (void)didMoveToWindow {
    %orig;
    WCSyncGlobalGesturesOnWindow(self);
}

- (void)didMoveToSuperview {
    %orig;
    WCSyncGlobalGesturesOnWindow(self);
}

%new
- (void)wc_handleGlobalLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan ||
        !WCGestureEnabled(WCGlobalGestureEnabledKey)) return;
    NSInteger action;
    if (recognizer.numberOfTouchesRequired == 2) {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    } else {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];
    }
    if (action == WCGlobalActionNone) return;
    WCPlayHaptic();
    WCPerformGlobalAction((WCGlobalAction)action);
}

%end

#pragma mark - Me page entry

@interface MoreViewController : UIViewController
- (void)addFunctionSection;
@end

%hook MoreViewController

- (void)addFunctionSection {
    %orig;
    @try {
        id tableManager = [self valueForKey:@"m_tableViewMgr"];
        if (![tableManager respondsToSelector:NSSelectorFromString(@"getSectionAt:")]) return;
        UIImage *icon = [UIImage systemImageNamed:@"hand.draw.fill"] ?: [UIImage systemImageNamed:@"hand.draw"];
        Class cellClass = NSClassFromString(@"WCTableViewCellManager");
        SEL factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:WithDisclosureIndicator:");
        id cell = nil;
        if (cellClass && [cellClass respondsToSelector:factory]) {
            cell = ((id (*)(id, SEL, SEL, id, UIImage *, NSString *, BOOL))objc_msgSend)
                (cellClass, factory, @selector(wc_pushGestureSettings), self,
                 icon ?: [UIImage new], @"微信手势", YES);
        }
        if (!cell) return;
        id section = ((id (*)(id, SEL, NSUInteger))objc_msgSend)
            (tableManager, NSSelectorFromString(@"getSectionAt:"), 2);
        if (section && [section respondsToSelector:NSSelectorFromString(@"addCell:")]) {
            ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"addCell:"), cell);
        }
        id tableView = nil;
        if ([tableManager respondsToSelector:NSSelectorFromString(@"getTableView")]) {
            tableView = ((id (*)(id, SEL))objc_msgSend)(tableManager, NSSelectorFromString(@"getTableView"));
        }
        if ([tableView respondsToSelector:@selector(reloadData)]) [tableView reloadData];
    } @catch (__unused NSException *exception) {
    }
}

%new
- (void)wc_pushGestureSettings {
    WCGesturePresentSettings(self);
}

%end

#pragma mark - Entry point

%ctor {
    @autoreleasepool {
        WCGestureRegisterDefaults();
        WCInstallServiceCenterCompatibility();
        WCGestureRegisterEntry();
        %init;
        dispatch_async(dispatch_get_main_queue(), ^{ WCSyncGlobalGestures(); });
        [[NSNotificationCenter defaultCenter] addObserverForName:WCGestureDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            dispatch_async(dispatch_get_main_queue(), ^{ WCSyncGlobalGestures(); });
        }];
    }
}
