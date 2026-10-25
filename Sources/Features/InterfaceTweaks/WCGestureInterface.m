#import <objc/runtime.h>

#import "Sources/API/WCGestureInternal.h"

static char WCSeparatorOriginalHiddenKey;

static BOOL WCViewLooksLikeGlobalSeparator(UIView *view) {
    if (!view) return NO;
    NSString *className = NSStringFromClass(view.class);
    BOOL nativeSeparator = [className isEqualToString:@"_UITableViewCellSeparatorView"];
    CGRect frame = view.frame;
    CGFloat width = CGRectGetWidth(frame);
    CGFloat height = CGRectGetHeight(frame);
    BOOL thinLine = ((width > 0.3 && width <= 0.55) ||
                     (height > 0.3 && height <= 0.55)) &&
                    view.alpha > 0.9 &&
                    view.backgroundColor != nil &&
                    ![view isKindOfClass:[UILabel class]] &&
                    ![view isKindOfClass:[UIImageView class]];
    BOOL candidate = nativeSeparator || thinLine;
    if ([className isEqualToString:@"UIView"]) candidate = thinLine && view.subviews.count == 0;
    return candidate;
}

void WCSeparatorHandleLayoutSubviews(UIView *view) {
    // The strip's layer.zPosition keeps it above the keyboard's own subviews.
    // Do not re-front it here: the keyboard lays out on every keystroke, and
    // reordering a translucent view that often makes it look like it flickers.
    NSNumber *originalHidden = objc_getAssociatedObject(view, &WCSeparatorOriginalHiddenKey);
    BOOL shouldHide = WCGestureEnabled(WCHideSeparatorLinesKey) && WCViewLooksLikeGlobalSeparator(view);
    if (shouldHide) {
        if (!originalHidden) {
            originalHidden = @(view.hidden);
            objc_setAssociatedObject(view, &WCSeparatorOriginalHiddenKey, originalHidden, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!view.hidden) view.hidden = YES;
    } else if (originalHidden) {
        view.hidden = originalHidden.boolValue;
        objc_setAssociatedObject(view, &WCSeparatorOriginalHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
