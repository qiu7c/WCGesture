#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Moments double-tap hook

%hook WCTimeLineCellView

- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
    WCGestureMomentsTimeApply(self, NO);
}

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
    WCGestureMomentsImageCornerLayout(self);
    WCGestureMomentsTimeApply(self, NO);
}

- (void)setViewModel:(id)viewModel {
    WCGestureMomentsImageCornerReset(self);
    WCGestureMomentsTimeReset(self);
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

- (void)prepareForReuse {
    WCGestureMomentsImageCornerReset(self);
    WCGestureMomentsTimeReset(self);
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
