#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Moments double-tap hook

%hook WCTimeLineCellView

- (void)layoutSubviews {
    WCGestureMomentsFeedBeforeLayout(self);
    %orig;
    WCGestureMomentsImageCornerLayout(self);
    WCGestureMomentsTimeApply(self, NO);
    WCGestureMomentsFeedLayout(self);
}

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
    WCGestureMomentsImageCornerLayout(self);
    WCGestureMomentsTimeApply(self, NO);
    WCGestureMomentsFeedLayout(self);
}

- (void)setViewModel:(id)viewModel {
    WCGestureMomentsFeedReset(self);
    WCGestureMomentsImageCornerReset(self);
    WCGestureMomentsTimeReset(self);
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

- (void)prepareForReuse {
    WCGestureMomentsFeedReset(self);
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
