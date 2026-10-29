#import "Sources/API/WCGestureInternal.h"

%hook MainFrameTableView
- (void)layoutSubviews {
    %orig;
    WCGestureHomePageCornerLayoutTable((UITableView *)self);
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    %orig(previous);
    if ([((UIView *)self).traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous])
        WCGestureHomePageCornerThemeChanged();
}
%end
%hook NewMainFrameCell
- (void)layoutSubviews {
    %orig;
    WCGestureHomePageCornerLayoutCell((UITableViewCell *)self);
}
- (void)updateCellBackground:(id)background {
    %orig(background);
    WCGestureHomePageCornerLayoutCell((UITableViewCell *)self);
}
- (void)prepareForReuse {
    WCGestureHomePageCornerRestoreCell((UITableViewCell *)self);
    %orig;
}
%end
%hook MMTableViewCell
- (void)layoutSubviews {
    %orig;
    WCGestureHomePageCornerLayoutCell((UITableViewCell *)self);
}
- (void)prepareForReuse {
    WCGestureHomePageCornerRestoreCell((UITableViewCell *)self);
    %orig;
}
%end
%hook MFBannerBtn
- (void)layoutSubviews {
    %orig;
    WCGestureHomePageCornerLayoutChrome((UIView *)self);
}
%end
%hook WCSearchBar
- (void)layoutSubviews {
    %orig;
    WCGestureHomePageCornerLayoutSearch((UIView *)self);
}
%end
%hook MainFrameSectionFoldView
- (void)layoutSubviews {
    %orig;
    WCGestureHomePageCornerLayoutChrome((UIView *)self);
}
%end
%hook MMDarkModeConfigUtil
+ (void)updateCurrentIsDarkMode:(BOOL)dark {
    static BOOL hasMode, lastMode;
    BOOL changed=!hasMode || lastMode!=dark;
    hasMode=YES;lastMode=dark;
    %orig(dark);
    if (changed) WCGestureHomePageCornerThemeChanged();
}
%end
%ctor {
    %init;
}
