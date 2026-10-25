#import "Sources/API/WCGestureInternal.h"

%hook CommonMessageCellView
- (void)handleTapReferMessage {
    if (WCGestureJumpToReferencedMessage(self)) return;
    %orig;
}
- (void)handleTapForReferMsg:(id)sender {
    if (WCGestureJumpToReferencedMessage(self)) return;
    %orig;
}
%end

%hook BaseMsgContentViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    WCGestureChatSearchUpdate(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    WCGestureChatSearchUpdate(self);
}
%new
- (void)wc_openChatSearch:(id)sender {
    WCGestureChatSearchOpen(self, sender);
}
%end

%ctor {
    %init;
}
