#import "Sources/API/WCGestureInternal.h"
%hook VoipUIManager
- (void)audioDeviceStartedSuccess:(id)event {
    %orig(event);
    WCGestureAutoSpeakerphoneApply(self);
}
- (void)setM_hasBeganTalk:(BOOL)began {
    %orig(began);
    WCGestureAutoSpeakerphoneTalkChanged(self, began);
}
- (void)setStartTalkTimestamp:(double)timestamp {
    %orig(timestamp);
    WCGestureAutoSpeakerphoneTalkChanged(self, YES);
}
%end
%ctor {
    %init;
}
