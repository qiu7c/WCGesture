#import "Sources/API/WCGestureInternal.h"

static BOOL WCChatImageClass(UIView *view, NSString *name) {
    Class cls = NSClassFromString(name); return cls && [view isKindOfClass:cls];
}
static BOOL WCChatImageHost(UIView *view) {
    for (UIView *host = view.superview; host; host = host.superview)
        if (WCChatImageClass(host, @"ImageMessageCellView")) return YES;
    return NO;
}
static void WCChatImageWalk(UIView *view, NSUInteger depth, NSUInteger *budget) {
    if (!view || depth > 8 || !*budget) return;
    (*budget)--;
    NSString *name = NSStringFromClass(view.class);
    if ([name containsString:@"HeadImage"] || [name containsString:@"Avatar"] || [view isKindOfClass:UILabel.class]) return;
    if (WCChatImageClass(view, @"YYAsyncImageView")) {
        WCGestureMediaCornerApply(view, WCGestureChatImageCornerEnabledKey, WCGestureChatImageCornerRadiusKey, WCChatImageHost(view));
        return;
    }
    for (UIView *child in view.subviews) WCChatImageWalk(child, depth + 1, budget);
}
void WCGestureChatImageCornerLayout(UIView *view) {
    if (WCChatImageClass(view, @"ImageMessageCellView")) {
        NSUInteger budget = 150; WCChatImageWalk(view, 0, &budget);
    } else if (WCChatImageClass(view, @"YYAsyncImageView")) {
        WCGestureMediaCornerApply(view, WCGestureChatImageCornerEnabledKey, WCGestureChatImageCornerRadiusKey, WCChatImageHost(view));
    }
}
