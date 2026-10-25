#import "Sources/API/WCGestureInternal.h"

%hook MultiDeviceCardLoginContentView
- (void)layoutSubviews {
    %orig;
    WCGestureAutoDeviceLoginApply(self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureAutoDeviceLoginApply(self);
}
%end

%ctor {
    %init;
}
