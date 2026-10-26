#import "Sources/API/WCGestureInternal.h"

%hook BaseMsgContentViewController
- (void)updateTitleView:(id)titleView {
    %orig(titleView);
    WCGestureChatTopBarTitleChanged(self, titleView);
}
- (void)updateTitleView:(id)titleView ignoreAnimation:(BOOL)ignoreAnimation {
    %orig(titleView, ignoreAnimation);
    WCGestureChatTopBarTitleChanged(self, titleView);
}
- (void)enterMultiSelectMode {
    WCGestureChatTopBarRestore(self);
    %orig;
}
- (void)exitMultiSelectMode {
    %orig;
    WCGestureChatTopBarUpdate(self);
}
%end

%hook MMMsgCommonTipsView
- (void)layoutSubviews {
    %orig;
    WCGestureChatPinnedLayout((UIView *)self);
}
- (void)didMoveToWindow {
    %orig;
    WCGestureChatPinnedLayout((UIView *)self);
}
%end

%hook UINavigationBar
- (void)layoutSubviews {
    %orig;
    WCGestureChatTopBarNavigationLayout(self);
}
%end

%ctor {
    %init;
}
