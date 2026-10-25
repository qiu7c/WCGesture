#import "Sources/API/WCGestureInternal.h"

%hook CommonMessageCellView
- (void)layoutSubviews {
    %orig;
    WCGestureMessageTimeLayout(self);
}

- (void)prepareForReuse {
    WCGestureMessageTimeHide(self);
    %orig;
}
%end

%ctor {
    %init;
}
