#import <UIKit/UIKit.h>
#import "Sources/Core/WCGestureConfig.h"

NS_ASSUME_NONNULL_BEGIN

/// Adds or removes the two-/three-finger recognizers on a window according to
/// the current settings. The UIWindow hook calls this for every window.
void WCSynchronizeGlobalGesturesOnWindow(UIWindow *window);

/// Applies WCSynchronizeGlobalGesturesOnWindow to every window.
void WCSynchronizeGlobalGestures(void);

/// Runs a configured multi-finger action from `presenter`.
void WCPerformGlobalAction(UIViewController * _Nullable presenter, WCGlobalAction action);

NS_ASSUME_NONNULL_END
