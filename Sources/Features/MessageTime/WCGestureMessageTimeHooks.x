#import "Sources/API/WCGestureInternal.h"

%hook CommonMessageCellView
- (void)layoutSubviews {
    %orig;
    WCGestureMessageTimeLayout(self);
    WCGestureAntiRevokeLayout(self);
}

- (void)prepareForReuse {
    WCGestureChatMediaResetCell((UIView *)self);
    WCGestureMediaCornerReset(self);
    WCGestureMessageTimeHide(self);
    WCGestureAntiRevokeHide(self);
    %orig;
}
%end

%ctor {
    %init;
}
