#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Global gesture hook

// Early window callbacks supplement startup/activation/visible-window notifications.
%hook UIWindow

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeGlobalGesturesOnWindow(self);
}

- (void)didMoveToSuperview {
    %orig;
    WCSynchronizeGlobalGesturesOnWindow(self);
}

%new
- (void)wc_handleGlobalLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan ||
        !WCGestureEnabled(WCGlobalGestureEnabledKey)) return;
    UIViewController *presenter = WCRootTopController();
    NSInteger action;
    if (recognizer.numberOfTouchesRequired == 2) {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    } else {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCGlobalGestureHapticKey]) {
        WCPlayConfiguredHaptic();
    }
    WCPerformGlobalAction(presenter, (WCGlobalAction)action);
}

%end

%ctor {
    %init;
    WCGestureGlobalGesturesStart();
}
