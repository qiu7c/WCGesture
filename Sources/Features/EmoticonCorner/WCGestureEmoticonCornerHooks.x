#import "Sources/API/WCGestureInternal.h"

%hook EmoticonViewWithPreview
- (void)layoutSubviews {
    %orig;
    WCGestureEmoticonCornerLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureEmoticonCornerLayout((UIView *)self);
}
- (void)showPreview {
    %orig;
    WCGestureEmoticonCornerLayout((UIView *)self);
}
- (void)hidePreview {
    %orig;
    WCGestureEmoticonCornerLayout((UIView *)self);
}
%end
%hook MMEmoticonView
- (void)layoutSubviews {
    %orig;
    WCGestureEmoticonCornerLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureEmoticonCornerLayout((UIView *)self);
}
- (BOOL)setEmoticonWrap:(id)wrap PlayGif:(BOOL)play {
    BOOL result = %orig(wrap, play);
    WCGestureEmoticonCornerLayout((UIView *)self);
    return result;
}
%end
%ctor {
    %init;
}
