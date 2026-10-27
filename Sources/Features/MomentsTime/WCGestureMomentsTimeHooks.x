#import "Sources/API/WCGestureInternal.h"

%hook WCTimeLineCellView
- (void)initTimeLabel {
    WCGestureMomentsFeedBeforeLayout(self);
    WCGestureMomentsTimeReset(self);
    %orig;
    WCGestureMomentsTimeApply(self, YES);
}
- (void)updateWithDataItem:(id)item actionAreaVM:(id)model {
    WCGestureMomentsFeedReset(self);
    WCGestureMomentsImageCornerReset(self);
    WCGestureMomentsTimeReset(self);
    %orig;
    WCGestureMomentsImageCornerLayout(self);
    WCGestureMomentsTimeApply(self, NO);
    WCGestureMomentsFeedLayout(self);
}
%end

%ctor {
    %init;
}
