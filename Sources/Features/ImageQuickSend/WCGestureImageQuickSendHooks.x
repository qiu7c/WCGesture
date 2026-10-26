#import "Sources/API/WCGestureInternal.h"
%hook EditImageForwardAndEditLogicController
- (void)startEditImage {
    WCGestureImageQuickSendPrepare(self);
    %orig;
}
- (id)getEditImageAttr {
    id attribute = %orig;
    WCGestureImageQuickSendBindAttribute(self, attribute);
    return attribute;
}
%end
%hook WCActionSheet
- (void)showInView:(UIView *)view {
    WCGestureImageQuickSendAddAction(self, view);
    %orig(view);
}
%end
%hook SharePreConfirmSheetView
- (void)onConfirmButtonClick {
    if (!WCGestureImageQuickSendConfirmAllowed(self)) return;
    %orig;
}
- (void)onCancelButtonClick {
    id session = WCGestureImageQuickSendSessionForSheet(self);
    %orig;
    WCGestureImageQuickSendCancelSession(session);
}
%end
%ctor {
    %init;
}
