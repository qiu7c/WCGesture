#import "Sources/API/WCGestureInternal.h"

%hook WCNotificationCenterMgr
- (unsigned int)getUnReadMessageCount {
    unsigned int count = %orig;
    WCGestureMomentsInteractionObserveUnreadCount(self, count);
    return count;
}
- (id)getLastUnReadMessage {
    id message = %orig;
    WCGestureMomentsInteractionObserveLastUnreadMessage(self, message);
    return message;
}
%end

%ctor {
    %init;
}
