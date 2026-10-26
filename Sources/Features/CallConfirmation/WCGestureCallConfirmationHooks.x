#import "Sources/API/WCGestureInternal.h"

%hook VoIPBubbleMessageCellView
- (void)startVoiceVoip {
    if (WCGestureCallConfirmationIntercept(self, NO)) return;
    %orig;
}
- (void)startVideoVoip {
    if (WCGestureCallConfirmationIntercept(self, YES)) return;
    %orig;
}
%end

%ctor {
    %init;
}
