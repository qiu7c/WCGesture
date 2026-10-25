#import "Sources/API/WCGestureInternal.h"

%hook MMHeadImageView
- (void)layoutSubviews {
    %orig;
    WCGestureApplyGlobalAvatarRoundingToHeadView(self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureApplyGlobalAvatarRoundingToHeadView(self);
}
- (void)setConerSize:(unsigned int)cornerSize {
    unsigned int value = WCGestureHeadViewIsExcludedFromGlobalAvatarRounding(self)
        ? cornerSize : WCGestureGlobalAvatarScaledCornerSize(cornerSize);
    %orig(value);
}
%end

%hook FakeHeadImageView
- (void)layoutSubviews {
    %orig;
    WCGestureApplyGlobalAvatarRoundingToHeadView(self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureApplyGlobalAvatarRoundingToHeadView(self);
}
- (void)setConerSize:(unsigned int)cornerSize {
    unsigned int value = WCGestureHeadViewIsExcludedFromGlobalAvatarRounding(self)
        ? cornerSize : WCGestureGlobalAvatarScaledCornerSize(cornerSize);
    %orig(value);
}
%end

%ctor {
    %init;
}
