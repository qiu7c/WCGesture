#import "Sources/API/WCGestureInternal.h"

%hook MoreViewController
- (void)showWCPayView {
    WCGestureServicePageLockPerform((UIViewController *)self, ^{
        %orig;
    });
}
- (void)showFavoriteView {
    WCGesturePageLockPerform((UIViewController *)self, WCGesturePageLockFavorites, ^{
        %orig;
    });
}
- (void)showMyWCView {
    WCGesturePageLockPerform((UIViewController *)self, WCGesturePageLockMomentsAlbum, ^{
        %orig;
    });
}
- (void)viewWillDisappear:(BOOL)animated {
    WCGestureServicePageLockCancel((UIViewController *)self);
    %orig(animated);
}
%end

%ctor {
    %init;
    WCGestureServicePageLockStart();
}
