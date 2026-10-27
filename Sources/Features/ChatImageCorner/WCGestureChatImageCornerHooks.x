#import "Sources/API/WCGestureInternal.h"
%hook ImageMessageCellView
- (void)layoutContentView {
    %orig;
    WCSynchronizeReplyGesture((CommonMessageCellView *)self);
    WCGestureChatImageCornerLayout((UIView *)self);
    WCGestureChatMediaLayout((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    WCSynchronizeReplyGesture((CommonMessageCellView *)self);
    WCGestureChatImageCornerLayout((UIView *)self);
    WCGestureChatMediaLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCSynchronizeReplyGesture((CommonMessageCellView *)self);
    WCGestureChatImageCornerLayout((UIView *)self);
    WCGestureChatMediaLayout((UIView *)self);
}
%end
%hook VideoMessageCellView
- (void)layoutContentView {
    %orig;
    WCSynchronizeReplyGesture((CommonMessageCellView *)self);
    WCGestureChatImageCornerLayout((UIView *)self);
    WCGestureChatMediaLayout((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    WCSynchronizeReplyGesture((CommonMessageCellView *)self);
    WCGestureChatImageCornerLayout((UIView *)self);
    WCGestureChatMediaLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCSynchronizeReplyGesture((CommonMessageCellView *)self);
    WCGestureChatImageCornerLayout((UIView *)self);
    WCGestureChatMediaLayout((UIView *)self);
}
%end
%ctor {
    %init;
}
