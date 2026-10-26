#import "Sources/API/WCGestureInternal.h"

%hook CommonMessageCellView
- (void)layoutSubviews {
    %orig;
    WCGestureMessageTimeLayout(self);
    WCGestureAntiRevokeLayout(self);
}

- (void)prepareForReuse {
    WCGestureMediaCornerReset(self);
    WCGestureMessageTimeHide(self);
    WCGestureAntiRevokeHide(self);
    %orig;
}
%end

%ctor {
    %init;
}
