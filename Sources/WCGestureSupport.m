#import "WCGestureSupport.h"
#import "WCGestureConfig.h"
#import <objc/message.h>

#pragma mark - KVC helpers

id WCTweakSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

void WCTweakSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0) return;
    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {
    }
}

id WCTweakValueForSelectorNames(id object, NSArray<NSString *> *selectorNames) {
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([object respondsToSelector:selector]) {
            return ((id (*)(id, SEL))objc_msgSend)(object, selector);
        }
    }
    return nil;
}

#pragma mark - Active window (multi-scene safe)

// keyWindow is deprecated since iOS 13 and compiled with -Werror; this walks
// connected scenes. Do NOT filter by class name or window level: some WeChat
// environments host the app UI in a window whose class contains "iConsole"
// (see runtime dumps: window = iConsoleWindow). Filtering it out returned nil
// and made screenshots/pushes/toasts silently do nothing.
UIWindow *WCActiveWindow(void) {
    NSArray<UIWindow *> *windows = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        windows = ((UIWindowScene *)scene).windows;
        if (windows.count) break;
    }
    if (windows.count == 0) {
        id all = WCTweakSafeValue(UIApplication.sharedApplication, @"windows");
        if ([all isKindOfClass:[NSArray class]]) windows = all;
    }
    for (UIWindow *window in windows) {
        if (window.isKeyWindow && !window.hidden && window.alpha > 0.0) return window;
    }
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.rootViewController) return window;
    }
    return windows.firstObject;
}

#pragma mark - Responder chain

UIViewController *WCViewControllerForResponder(id responderObject) {
    UIResponder *responder = [responderObject isKindOfClass:[UIResponder class]] ? (UIResponder *)responderObject : nil;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
        responder = responder.nextResponder;
    }
    return nil;
}

#pragma mark - Presentation helpers

// Window-level presentation helpers. A UIWindow's responder chain does not lead
// to a UIViewController, so WCViewControllerForResponder(window) returns nil.
// Always start from rootViewController and walk presented controllers instead.
UIViewController *WCRootTopController(void) {
    UIViewController *controller = WCActiveWindow().rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

UINavigationController *WCPushNavigation(void) {
    UIViewController *top = WCRootTopController();
    if ([top isKindOfClass:[UINavigationController class]]) return (UINavigationController *)top;
    if (top.navigationController) return top.navigationController;
    if ([top isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = ((UITabBarController *)top).selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) return (UINavigationController *)selected;
        if (selected.navigationController) return selected.navigationController;
    }
    return nil;
}

void WCPushGlobal(UIViewController *vc) {
    if (!vc) return;
    UINavigationController *nav = WCPushNavigation();
    // Only push into a navigation stack that is actually on screen; otherwise
    // the page silently lands in a hidden controller and nothing appears.
    if (nav && nav.view.window && !nav.isBeingDismissed && !nav.presentedViewController) {
        [nav pushViewController:vc animated:YES];
        return;
    }
    UIViewController *top = WCRootTopController();
    if (top) {
        vc.modalPresentationStyle = UIModalPresentationPageSheet;
        [top presentViewController:vc animated:YES completion:nil];
    }
}

// Pages WeChat itself shows as sheets (scan, QR code, payment code) do not
// render when pushed into the chat navigation stack. Present them as a page
// sheet: they can be swiped away, so no extra close button is needed.
void WCPresentGlobalSheet(UIViewController *vc) {
    if (!vc) return;
    UIViewController *top = WCRootTopController();
    if (!top) return;
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Haptics

UIImpactFeedbackStyle WCHapticStyleFromConfig(void) {
    switch ((WCHapticStyle)[[NSUserDefaults standardUserDefaults] integerForKey:WCGestureHapticStyleKey]) {
        case WCHapticStyleLight: return UIImpactFeedbackStyleLight;
        case WCHapticStyleHeavy: return UIImpactFeedbackStyleHeavy;
        case WCHapticStyleSoft: return UIImpactFeedbackStyleSoft;
        case WCHapticStyleRigid: return UIImpactFeedbackStyleRigid;
        case WCHapticStyleMedium: default: return UIImpactFeedbackStyleMedium;
    }
}

void WCPlayConfiguredHaptic(void) {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:WCHapticStyleFromConfig()];
    [feedback prepare];
    [feedback impactOccurred];
}

#pragma mark - Toast

// Lightweight auto-dismissing toast (no buttons, no dimming).
void WCShowToast(NSString *text) {
    if (text.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = WCActiveWindow();
        if (!window) return;
        UIView *toast = [[UIView alloc] init];
        toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.82];
        toast.layer.cornerRadius = 12.0;
        toast.layer.zPosition = 10000.0;
        toast.userInteractionEnabled = NO;
        toast.alpha = 0.0;
        toast.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *label = [[UILabel alloc] init];
        label.text = text;
        label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [toast addSubview:label];
        [window addSubview:toast];

        [NSLayoutConstraint activateConstraints:@[
            [label.topAnchor constraintEqualToAnchor:toast.topAnchor constant:10.0],
            [label.bottomAnchor constraintEqualToAnchor:toast.bottomAnchor constant:-10.0],
            [label.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:16.0],
            [label.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-16.0],
            [toast.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
            // Banner position: just under the navigation bar, out of the way of
            // whatever the user is reading in the middle of the screen.
            [toast.topAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:56.0],
            [toast.widthAnchor constraintLessThanOrEqualToAnchor:window.widthAnchor constant:-64.0],
        ]];

        [UIView animateWithDuration:0.18 animations:^{
            toast.alpha = 1.0;
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.25 delay:1.5 options:0 animations:^{
                toast.alpha = 0.0;
            } completion:^(__unused BOOL done) {
                [toast removeFromSuperview];
            }];
        }];
    });
}
