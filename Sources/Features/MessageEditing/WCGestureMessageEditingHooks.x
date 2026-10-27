#import "Sources/API/WCGestureInternal.h"
%hook ChatTimeCellView
- (void)layoutSubviews {
    %orig;
    WCGestureLocalTimeLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureLocalTimeLayout((UIView *)self);
}
- (void)setViewModel:(id)model {
    WCGestureLocalTimeReset((UIView *)self);
    %orig(model);
}
%new
- (void)wc_editLocalTime:(UILongPressGestureRecognizer *)gesture { WCGestureLocalTimeLongPress((UIView *)self,gesture); }
%end
%hook BaseMsgContentViewController
- (void)viewWillBePoped:(BOOL)animated {
    WCGestureLocalEditLeaving((UIViewController *)self);
    WCGestureChatMediaLeaving((UIViewController *)self);
    WCGestureChatSortEnd((UIViewController *)self);
    WCGestureInputVoiceCancel();
    %orig(animated);
}
%end
%ctor {
    %init;
}
