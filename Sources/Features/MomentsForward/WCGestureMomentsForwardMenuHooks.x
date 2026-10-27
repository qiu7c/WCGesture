#import "Sources/API/WCGestureInternal.h"

%hook WCOperateFloatView
- (void)showWithItemData:(id)item tipPoint:(CGPoint)point {
    WCGestureMomentsForwardMenuReset((UIView *)self);
    %orig(item, point);
    WCGestureMomentsForwardMenuPrepare((UIView *)self, item);
}
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsForwardMenuLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureMomentsForwardMenuLayout((UIView *)self);
}
- (void)hide {
    WCGestureMomentsForwardMenuReset((UIView *)self);
    %orig;
}
%end

%ctor {
    %init;
}
