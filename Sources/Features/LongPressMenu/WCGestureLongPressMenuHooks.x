#import "Sources/API/WCGestureInternal.h"

%hook BaseMessageCellView
- (NSArray *)filteredMenuItems:(NSArray *)items {
    NSArray *original = %orig;
    NSArray *itemsWithRepeat = WCGestureRepeatMenuItems(self, original);
    NSArray *local = WCGestureLocalEditMenuItems((UIView *)self, itemsWithRepeat);
    local = WCGestureChatMediaMenuItems((UIView *)self, local);
    local = WCGestureChatSortMenuItems((UIView *)self, local);
    return WCGestureManagedLongPressMenuItems(local);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == NSSelectorFromString(@"wc_repeatMenuMessage:")) return WCGestureMessageCanRepeat(self);
    if (WCGestureLocalEditAllowsAction((UIView *)self, action) ||
        WCGestureChatMediaAllowsAction((UIView *)self, action) ||
        WCGestureChatSortAllowsAction((UIView *)self, action)) return YES;
    return %orig;
}
%new
- (void)wc_repeatMenuMessage:(id)sender {
    WCGestureRepeatMenuPerform(self);
}
%new
- (void)wc_localEditText:(id)sender { WCGestureLocalEditPerform((UIView *)self, NO); }
%new
- (void)wc_localEditTransfer:(id)sender { WCGestureLocalEditPerform((UIView *)self, YES); }
%new
- (void)wc_localRestoreEdit:(id)sender { WCGestureLocalEditRestore((UIView *)self); }
%new
- (void)wc_restoreLocalMedia:(id)sender { WCGestureChatMediaRestore((UIView *)self); }
%new
- (void)wc_replaceLocalMedia:(id)sender { WCGestureChatMediaPick((UIView *)self); }
%new
- (void)wc_toggleChatSort:(id)sender { WCGestureChatSortToggle((UIView *)self); }
%end

%ctor {
    %init;
}
