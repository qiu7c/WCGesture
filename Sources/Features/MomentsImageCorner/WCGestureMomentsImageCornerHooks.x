#import "Sources/API/WCGestureInternal.h"

%hook WCListBaseCellView
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
- (void)setGroupItem:(id)item inGroup:(id)group {
    WCGestureMomentsImageCornerReset(self);
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%hook WCContentItemViewTemplateGrid
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%ctor {
    %init;
}
