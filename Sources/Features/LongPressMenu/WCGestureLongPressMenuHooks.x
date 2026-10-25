#import "Sources/API/WCGestureInternal.h"

%hook BaseMessageCellView
- (NSArray *)filteredMenuItems:(NSArray *)items {
    NSArray *original = %orig;
    NSArray *itemsWithRepeat = WCGestureRepeatMenuItems(self, original);
    return WCGestureManagedLongPressMenuItems(itemsWithRepeat);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == NSSelectorFromString(@"wc_repeatMenuMessage:")) return WCGestureMessageCanRepeat(self);
    return %orig;
}
%new
- (void)wc_repeatMenuMessage:(id)sender {
    WCGestureRepeatMenuPerform(self);
}
%end

%ctor {
    %init;
}
