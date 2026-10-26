#import "Sources/API/WCGestureInternal.h"

%hook MMAssetPickerController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCGestureAutoCombineSendApply(self);
}
%end
%hook MMImagePreviewBrowserController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCGestureAutoCombineSendApply(self);
}
%end

%ctor {
    %init;
}
