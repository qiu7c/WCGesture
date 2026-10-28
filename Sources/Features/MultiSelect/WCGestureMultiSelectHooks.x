#import "Sources/API/WCGestureInternal.h"

// WeChatX 2.4-5: 0x18abe0/0x18ac44/0x18aca8/0x18ad10.
// ShortVideoToolbar.sightCaptureMaxDuration is a separate capability.
%hook BaseMsgContentViewController
- (unsigned int)uiMultiSelectMaxCount {
    if (WCGestureEnabled(WCGestureMultiSelectEnabledKey)) return 9999;
    return %orig;
}
- (unsigned int)getMultiSelectMaxCount {
    if (WCGestureEnabled(WCGestureMultiSelectEnabledKey)) return 9999;
    return %orig;
}
%end

%hook SessionSelectController
- (void)setMaxSelectionCount:(unsigned long long)count {
    unsigned long long limit = WCGestureEnabled(WCGestureMultiSelectEnabledKey) ? 999 : count;
    %orig(limit);
}
- (BOOL)ignoreMaxSelectionLimit {
    if (WCGestureEnabled(WCGestureMultiSelectEnabledKey)) return YES;
    return %orig;
}
%end

%ctor {
    %init;
}
