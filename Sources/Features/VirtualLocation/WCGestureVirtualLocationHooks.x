#import "Sources/API/WCGestureInternal.h"

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    CLLocationCoordinate2D original = %orig;
    return WCGestureVirtualLocationSpoofedCoordinate(original);
}
%end

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureVirtualLocationSurfaceChanged((UIViewController *)self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    WCGestureVirtualLocationSurfaceChanged((UIViewController *)self);
}
%end

%hook MMPickLocationViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    WCGestureVirtualLocationPickerDisappeared((UIViewController *)self);
}
%end

%ctor {
    %init;
}
