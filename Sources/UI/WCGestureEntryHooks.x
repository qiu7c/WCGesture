#import "Sources/API/WCGestureInternal.h"

%hook MoreViewController
- (void)addFunctionSection {
    %orig;
    WCGestureSettingsEntryRefresh(self, WCGestureSettingsEntryMe);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureSettingsEntryRefresh(self, WCGestureSettingsEntryMe);
}
%new
- (void)wc_pushGestureSettings {
    WCGesturePresentSettings(self);
}
%end

%hook NewSettingViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureSettingsEntryRefresh(self, WCGestureSettingsEntryWeChatSettings);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    WCGestureSettingsEntryRefresh(self, WCGestureSettingsEntryWeChatSettings);
}
%new
- (void)wc_pushGestureSettings {
    WCGesturePresentSettings(self);
}
%end

%ctor {
    %init;
}
