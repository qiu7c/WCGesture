#import "Sources/API/WCGestureInternal.h"

%hook WeixinContactInfoAssist
- (void)initData {
    %orig;
    WCGestureContactInfoCardApply(self, NO);
}
- (void)reloadTableView {
    %orig;
    WCGestureContactInfoCardApply(self, NO);
}
- (void)viewDidAppear {
    %orig;
    WCGestureContactInfoCardApply(self, NO);
}
%new
- (void)wc_openContactInfoCard {
    WCGestureContactInfoCardOpen(self);
}
%end

%hook ChatRoomInfoViewController
- (void)initData {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
}
- (void)reloadTableData {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
}
- (void)reloadProfileTableData {
    %orig;
    WCGestureContactInfoCardApply(self, YES);
}
%new
- (void)wc_openContactInfoCard {
    WCGestureContactInfoCardOpen(self);
}
%end

%ctor {
    %init;
}
