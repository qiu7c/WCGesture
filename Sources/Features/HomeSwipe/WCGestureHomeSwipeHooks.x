#import "Sources/API/WCGestureInternal.h"
%hook NewMainFrameViewController
- (void)viewDidLoad {
    %orig;
    WCGestureHomeGroupsAttach((UIViewController *)self);
}
%end
%hook NewMainFrameCell
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (!WCGestureHomeSwipeAllowsCellGesture(gesture,(UIView *)self)) return NO;
    return %orig(gesture);
}
%end
%ctor {
    %init;
    WCGestureHomeSwipeInstall();
}
