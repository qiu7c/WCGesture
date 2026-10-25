#import "Sources/API/WCGestureInternal.h"

%hook MMAssetPickerController
- (void)viewDidLoad {
    %orig;
    WCGestureAutoOriginalApply(self, @"m_originImageCheck");
}
- (void)initCombineSendViewIfNeeded {
    %orig;
    WCGestureAutoOriginalApply(self, @"m_originImageCheck");
}
- (void)reloadBottomBar {
    %orig;
    WCGestureAutoOriginalApply(self, @"m_originImageCheck");
}
%end

%hook MMImagePreviewBrowserController
- (void)viewDidLoad {
    %orig;
    WCGestureAutoOriginalApply(self, @"_originImageCheck");
}
- (void)initCombineSendViewIfNeeded {
    %orig;
    WCGestureAutoOriginalApply(self, @"_originImageCheck");
}
- (void)reloadSelectedCollectionView {
    %orig;
    WCGestureAutoOriginalApply(self, @"_originImageCheck");
}
%end

%ctor {
    %init;
}
