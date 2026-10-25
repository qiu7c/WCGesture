#import <UIKit/UIKit.h>

#ifndef WCLog
#define WCLog(fmt, ...) NSLog(@"[WCGesture] " fmt, ##__VA_ARGS__)
#endif

NS_ASSUME_NONNULL_BEGIN

/// KVC helpers used to talk to WeChat's private classes without compile-time
/// knowledge of their properties. Each returns nil / does nothing when the
/// object does not respond, so callers never need a try/catch of their own.
id _Nullable WCTweakSafeValue(id _Nullable object, NSString *key);
void WCTweakSetValue(id _Nullable object, NSString *key, id _Nullable value);

/// Calls the first selector in `selectorNames` that the object responds to.
id _Nullable WCTweakValueForSelectorNames(id object, NSArray<NSString *> *selectorNames);

/// Foreground window. Walks connected scenes instead of the deprecated
/// `keyWindow`; deliberately does not filter by window class (see the
/// implementation for why).
UIWindow * _Nullable WCActiveWindow(void);

/// First UIViewController in the responder chain of `responderObject`.
UIViewController * _Nullable WCViewControllerForResponder(id responderObject);

/// Topmost controller reachable from the active window's root controller,
/// following the presented-controller chain.
UIViewController * _Nullable WCRootTopController(void);

/// Navigation controller that new pages can be pushed into, if one is visible.
UINavigationController * _Nullable WCPushNavigation(void);

/// Pushes into the visible navigation stack when there is one; otherwise
/// presents the page as a sheet so it cannot land in a hidden controller.
void WCPushGlobal(UIViewController *viewController);

/// Presents a page as a page sheet (scan, QR code, payment code and other
/// pages WeChat itself shows modally).
void WCPresentGlobalSheet(UIViewController *viewController);

/// Small auto-dismissing banner at the top of the screen.
void WCShowToast(NSString *text);

/// The UIImpactFeedbackStyle chosen in settings.
UIImpactFeedbackStyle WCHapticStyleFromConfig(void);

/// Plays the haptic style chosen in settings.
void WCPlayConfiguredHaptic(void);

NS_ASSUME_NONNULL_END
