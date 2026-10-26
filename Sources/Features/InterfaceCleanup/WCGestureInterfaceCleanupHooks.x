#import "Sources/API/WCGestureInternal.h"

%hook RoomContentLogicController
- (id)getDefaultTitleTailSubViews {
    if (WCGestureEnabled(WCGestureHideGroupTitleTailKey)) return @[];
    return %orig;
}
- (id)getMemeberCountLabel {
    id label = %orig;
    return WCGestureGroupMemberLabel(label);
}
%end

%hook MMScreenShotViewController
- (void)show {
    if (WCGestureEnabled(WCGestureHideScreenshotForwardKey)) return;
    %orig;
}
%end

%hook MoreViewController
- (void)addCardsIfNeededToSection:(id)section {
    if (WCGestureShouldHideMeEntry(@"小店与卡包")) return;
    %orig;
}
- (void)addEmoticonsIfNeededToSection:(id)section {
    if (WCGestureShouldHideMeEntry(@"表情")) return;
    %orig;
}
// 8.0.79 takes CGSize here, rather than WCAtlas's older CGRect declaration.
- (id)createFinderEntranceCellConfig:(CGSize)size {
    if (WCGestureShouldHideMeEntry(@"作品")) return nil;
    return %orig(size);
}
%end

%ctor {
    %init;
    WCGestureInterfaceCleanupInstallOptionalHooks();
}
