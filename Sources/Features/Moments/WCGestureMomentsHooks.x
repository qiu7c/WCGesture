#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Moments double-tap hook

%hook WCTimeLineCellView

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

- (void)setViewModel:(id)viewModel {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

- (void)prepareForReuse {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

%new
- (void)wc_handleMomentsDoubleTap {
    WCMomentsHandleDoubleTap(self);
}

%end

%ctor {
    %init;
}
