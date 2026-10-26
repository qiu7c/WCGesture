#import "Sources/API/WCGestureInternal.h"
%hook ImageMessageCellView
- (void)layoutContentView {
    %orig;
    WCGestureChatImageCornerLayout((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    WCGestureChatImageCornerLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureChatImageCornerLayout((UIView *)self);
}
%end
%hook VideoMessageCellView
- (void)layoutContentView {
    %orig;
    WCGestureChatImageCornerLayout((UIView *)self);
}
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
