#import "Sources/API/WCGestureInternal.h"

%hook CMessageMgr
- (void)onNewSyncNotAddDBMessage:(id)message {
    if (WCGestureAntiRevokeHandle(self, message)) return;
    %orig;
}
%end

%hook SystemMessageCellView
- (void)layoutSubviews {
    %orig;
    WCGestureAntiRevokeSystemCellLayout(self);
}
%end

%ctor {
    %init;
}
