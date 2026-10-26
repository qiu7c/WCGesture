#import "Sources/API/WCGestureInternal.h"
%hook ImageMessageCellView
- (void)layoutSubviews {
    %orig;
    WCGestureChatImageCornerLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureChatImageCornerLayout((UIView *)self);
}
%end
%ctor {
    %init;
}
