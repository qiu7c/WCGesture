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
    WCGestureChatSearchCapture(self, nil);
    %orig;
    WCGestureChatSearchDidDismiss(self);
}
%end

%hook WCSearcher
- (void)onWCSearchControllerDidLoad {
    %orig;
    WCGestureChatSearchCapture(self, nil);
}
- (void)searchBarCancelButtonClicked:(id)sender {
    WCGestureChatSearchCapture(self, nil);
    %orig(sender);
    WCGestureChatSearchDidDismiss(self);
}
- (void)didDismissSearchController:(id)controller {
    WCGestureChatSearchCapture(self, controller);
    %orig(controller);
    WCGestureChatSearchDidDismiss(self);
}
- (void)onWCSearchControllerDidDisappear:(BOOL)animated {
    WCGestureChatSearchCapture(self, nil);
    %orig(animated);
    WCGestureChatSearchDidDismiss(self);
}
%end

%hook WCSearchController
- (void)viewDidDisappear:(BOOL)animated {
    WCGestureChatSearchCapture(self, self);
    %orig(animated);
    WCGestureChatSearchDidDismiss(self);
}
%end

%ctor {
    %init;
}
