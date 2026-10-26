#import "Sources/API/WCGestureInternal.h"

%hook WeixinContactInfoAssist
- (void)initData {
    %orig;
    WCGestureContactInfoCardApply(self, NO);
    WCGestureSendConfirmationProfileApply(self, NO);
}
- (void)reloadTableView {
    %orig;
    WCGestureContactInfoCardApply(self, NO);
    WCGestureSendConfirmationProfileApply(self, NO);
}
- (void)viewDidAppear {
    %orig;
    WCGestureContactInfoCardApply(self, NO);
    WCGestureSendConfirmationProfileApply(self, NO);
}
%new
- (void)wc_toggleConversationSendConfirmation:(UISwitch *)sender {
    WCGestureSendConfirmationProfileToggle(self, sender);
}
%new
- (void)wc_openContactInfoCard {
    WCGestureContactInfoCardOpen(self);
}
%end

%hook ChatRoomInfoViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
    WCGestureSendConfirmationProfileApply(self, YES);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
    WCGestureSendConfirmationProfileApply(self, YES);
}
- (void)initData {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
    WCGestureSendConfirmationProfileApply(self, YES);
}
- (void)reloadTableData {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
    WCGestureSendConfirmationProfileApply(self, YES);
}
- (void)reloadProfileTableData {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
    WCGestureSendConfirmationProfileApply(self, YES);
}
%new
- (void)wc_toggleConversationSendConfirmation:(UISwitch *)sender {
    WCGestureSendConfirmationProfileToggle(self, sender);
}
%new
- (void)wc_openContactInfoCard {
    WCGestureContactInfoCardOpen(self);
}
%end

%ctor {
    %init;
}
