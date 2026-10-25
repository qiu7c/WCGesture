#import "Sources/API/WCGestureInternal.h"

%hook MMInputToolView
- (void)didMoveToWindow {
    %orig;
    WCGestureChatInputRoundingApply(self);
}
- (void)layoutSubviews {
    %orig;
    WCGestureChatInputRoundingApply(self);
}
%end

%ctor {
    %init;
}
