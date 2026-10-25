#import "Sources/API/WCGestureInternal.h"

%hook WCListBaseCellView
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
- (void)setGroupItem:(id)item inGroup:(id)group {
    WCGestureMomentsImageCornerReset(self);
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%hook WCContentItemViewTemplateGrid
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%hook WCSNSNodeVideoView
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%hook MMImageGridView
- (void)layoutSubviews {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%hook WCListPhotoCellView
- (void)initImageGridView {
    %orig;
    WCGestureMomentsImageCornerLayout(self);
}
%end

%hook WeixinContactInfoAssist
- (id)getAlbumView {
    id view = %orig;
    WCGestureMomentsImageCornerRegisterProfile(view);
    return view;
}
- (void)albumView:(id)view displayCellsWithDataItems:(id)items cellLeftContext:(double *)context {
    %orig;
    WCGestureMomentsImageCornerRegisterProfile(view);
}
%end

%ctor {
    %init;
}
