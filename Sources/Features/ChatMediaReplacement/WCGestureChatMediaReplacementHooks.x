#import "Sources/API/WCGestureInternal.h"
%hook ImageMessageCellView
- (void)showImage {
    if (WCGestureChatMediaPresent((UIView *)self)) return;
    %orig;
}
- (void)showImageNeedEdit:(BOOL)edit {
    if (!edit && WCGestureChatMediaPresent((UIView *)self)) return;
    %orig(edit);
}
%end
%hook VideoMessageCellView
- (void)showVideo {
    if (WCGestureChatMediaPresent((UIView *)self)) return;
    %orig;
}
- (void)onClickToPlayWithSoundable:(BOOL)sound {
    if (WCGestureChatMediaPresent((UIView *)self)) return;
    %orig(sound);
}
%end
%ctor {
    %init;
}
