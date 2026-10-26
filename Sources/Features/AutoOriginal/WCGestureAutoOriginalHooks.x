#import "Sources/API/WCGestureInternal.h"

%hook MMAssetPickerController
- (void)viewDidLoad {
    %orig;
    WCGestureAutoOriginalApply(self, @"m_originImageCheck");
    WCGestureAutoCombineSendApply(self);
}
- (void)initCombineSendViewIfNeeded {
    %orig;
    WCGestureAutoOriginalApply(self, @"m_originImageCheck");
    WCGestureAutoCombineSendApply(self);
}
- (void)reloadBottomBar {
    %orig;
    WCGestureAutoOriginalApply(self, @"m_originImageCheck");
    WCGestureAutoCombineSendApply(self);
}
%end

%hook MMImagePreviewBrowserController
- (void)viewDidLoad {
    %orig;
    WCGestureAutoOriginalApply(self, @"_originImageCheck");
    WCGestureAutoCombineSendApply(self);
}
- (void)initCombineSendViewIfNeeded {
    %orig;
    WCGestureAutoOriginalApply(self, @"_originImageCheck");
    WCGestureAutoCombineSendApply(self);
}
- (void)reloadSelectedCollectionView {
    %orig;
    WCGestureAutoOriginalApply(self, @"_originImageCheck");
    WCGestureAutoCombineSendApply(self);
}
%end

%ctor {
    %init;
}
