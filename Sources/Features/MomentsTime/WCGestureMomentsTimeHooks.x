#import "Sources/API/WCGestureInternal.h"

%hook WCTimeLineCellView
- (void)initTimeLabel {
    WCGestureMomentsTimeReset(self);
    %orig;
    WCGestureMomentsTimeApply(self, YES);
}
- (void)updateWithDataItem:(id)item actionAreaVM:(id)model {
    WCGestureMomentsImageCornerReset(self);
    WCGestureMomentsTimeReset(self);
    %orig;
    WCGestureMomentsImageCornerLayout(self);
    WCGestureMomentsTimeApply(self, NO);
}
%end

%ctor {
    %init;
}
