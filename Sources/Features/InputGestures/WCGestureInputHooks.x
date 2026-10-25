#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Input box hooks

%hook MMGrowTextView

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeInputGestures(self);
}

%new
- (void)wc_handleInputSwipeLeft:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeLeftActionKey];
    if (action == WCInputActionNone) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(self, action);
}

%new
- (void)wc_handleInputSwipeRight:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeRightActionKey];
    if (action == WCInputActionNone) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(self, action);
}

%new
- (void)wc_handleInputTapAction:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized ||
        !self.window ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    NSString *key = recognizer.numberOfTapsRequired >= 3
        ? WCInputTripleTapActionKey
        : WCInputDoubleTapActionKey;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults] integerForKey:key];
    if (action == WCInputActionNone) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(self, action);
}

%end

%ctor {
    %init;
}
