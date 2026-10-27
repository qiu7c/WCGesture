#import "Sources/API/WCGestureInternal.h"

%hook WCTimeLineCellView
+ (double)heightForDataItem:(id)item pageContext:(id)context actionAreaVM:(id)model {
    double height = 0;
    WCGestureMomentsFeedBeginHeight();
    @try {
        height = %orig(item, context, model);
    } @finally {
        height = WCGestureMomentsFeedEndHeight(height, item, context, model);
    }
    return height;
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *original = %orig(point, event);
    return WCGestureMomentsFeedHitTest((UIView *)self, point, event, original);
}
%end

%hook WCBaseTimelineViewController
- (double)tableView:(id)table heightForRowAtIndexPath:(id)path {
    double height = %orig(table, path);
    return WCGestureMomentsFeedRowHeight((UIViewController *)self, table, path, height);
}
%end

%hook WCCommentDetailViewControllerFB
- (double)tableView:(id)table heightForRowAtIndexPath:(id)path {
    double height = %orig(table, path);
    return WCGestureMomentsFeedRowHeight((UIViewController *)self, table, path, height);
}
%end

%ctor {
    %init;
}
