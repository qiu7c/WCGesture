#import "Sources/API/WCGestureInternal.h"
%hook NewMainFrameViewController
- (void)viewDidLoad {
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
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
