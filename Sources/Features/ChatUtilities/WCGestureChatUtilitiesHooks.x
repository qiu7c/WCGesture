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
    WCGestureChatSearchWillAppear(self);
    WCGestureChatTopBarPrepareAppearance(self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    WCGestureGroupTitleLayout(self);
    WCGestureChatSearchUpdate(self);
}
%new
- (void)wc_openChatSearch:(id)sender {
    WCGestureChatSearchOpen(self, sender);
}
%new
- (void)wc_handleChatSearchEdgePan:(UIScreenEdgePanGestureRecognizer *)recognizer {
    WCGestureChatSearchHandleEdgePan(self, recognizer);
}
%end

%hook MsgSearchHelper
- (void)wcsDidDismissSearch:(id)searcher {
    %orig;
    WCGestureChatSearchDidDismiss(self);
}
%end

%ctor {
    %init;
}
