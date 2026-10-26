#import <math.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCChatImageTargetKey;
@interface WCChatImageTarget : NSObject
@property (nonatomic, weak) UIView *view;
@end
@implementation WCChatImageTarget
@end

static BOOL WCChatImageClass(UIView *view, NSString *name) {
    Class cls = NSClassFromString(name); return cls && [view isKindOfClass:cls];
}
static UIView *WCChatImageCell(UIView *view) {
    for (UIView *host = view; host; host = host.superview)
        if (WCChatImageClass(host, @"ImageMessageCellView") || WCChatImageClass(host, @"VideoMessageCellView")) return host;
    return nil;
}
static UIView *WCChatImageContentTarget(UIView *image, UIView *cell) {
    // The supplied image/video trees place the media and its overlays inside
    // one dedicated direct child of the cell. Clip this host, never the cell.
    UIView *container = image.superview;
    if (!container || container == cell || container.superview != cell) return image;
    if (![container isKindOfClass:UIView.class] || [container isKindOfClass:UIScrollView.class]) return image;
    CGRect media = [image convertRect:image.bounds toView:container];
    CGRect bounds = container.bounds;
    CGFloat left = CGRectGetMinX(media) - CGRectGetMinX(bounds);
    CGFloat top = CGRectGetMinY(media) - CGRectGetMinY(bounds);
    CGFloat right = CGRectGetMaxX(bounds) - CGRectGetMaxX(media);
    CGFloat bottom = CGRectGetMaxY(bounds) - CGRectGetMaxY(media);
    // Permit a small native border, while rejecting a row-wide wrapper that
    // also contains the avatar, timestamp, caption or unrelated content.
    if (!isfinite(media.size.width) || !isfinite(media.size.height) || CGRectIsEmpty(media)) return image;
    for (NSNumber *inset in @[@(left),@(top),@(right),@(bottom)])
        if (!isfinite(inset.doubleValue) || inset.doubleValue < -0.5 || inset.doubleValue > 8.0) return image;
    return container;
}
void WCGestureChatImageCornerLayout(UIView *view) {
    UIView *cell = WCChatImageCell(view);
    if (!cell) {
        WCGestureMediaCornerApply(view, WCGestureChatImageCornerEnabledKey, WCGestureChatImageCornerRadiusKey, NO);
        return;
    }
    BOOL video = WCChatImageClass(cell, @"VideoMessageCellView");
    id candidate = WCTweakSafeValue(cell, video ? @"m_thumbImageView" : @"m_imageView");
    UIView *image = [candidate isKindOfClass:UIView.class] && candidate != cell
        && [(UIView *)candidate isDescendantOfView:cell] && WCChatImageClass(candidate, @"YYAsyncImageView") ? candidate : nil;
    UIView *target = image ? WCChatImageContentTarget(image, cell) : nil;
    WCChatImageTarget *tracked = objc_getAssociatedObject(cell, &WCChatImageTargetKey);
    if (tracked.view && tracked.view != target)
        WCGestureMediaCornerApply(tracked.view, WCGestureChatImageCornerEnabledKey, WCGestureChatImageCornerRadiusKey, NO);
    // Undo the old inner-image rounding when the outer host owns the shape.
    // This exposes neither its rectangular background nor sibling overlays.
    if (image && target != image)
        WCGestureMediaCornerApply(image, WCGestureChatImageCornerEnabledKey, WCGestureChatImageCornerRadiusKey, NO);
    if (!target) return;
    if (!tracked) {
        tracked = [WCChatImageTarget new];
        objc_setAssociatedObject(cell, &WCChatImageTargetKey, tracked, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    tracked.view = target;
    WCGestureMediaCornerApply(target, WCGestureChatImageCornerEnabledKey, WCGestureChatImageCornerRadiusKey, YES);
}
