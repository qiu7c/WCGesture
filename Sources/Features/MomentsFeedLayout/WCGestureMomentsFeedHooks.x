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

%ctor {
    %init;
}
