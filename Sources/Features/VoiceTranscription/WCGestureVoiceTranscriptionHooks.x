#import "Sources/API/WCGestureInternal.h"
%hook VoiceMessageCellView
- (void)layoutSubviews {
    %orig;
    WCGestureVoiceTranscriptionSchedule(self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureVoiceTranscriptionSchedule(self);
}
%end
%ctor {
    %init;
}
