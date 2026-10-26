#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCEmoticonPreviewOwner : NSObject
@property (nonatomic, weak) UIView *view;
@end
@implementation WCEmoticonPreviewOwner
@end
static char WCEmoticonPreviewOwnerKey;

static BOOL WCEmoticonClass(UIView *view, NSString *name) {
    Class cls = NSClassFromString(name); return cls && [view isKindOfClass:cls];
}
static BOOL WCEmoticonHost(UIView *view) {
    for (UIView *host = view.superview; host; host = host.superview)
        if (WCEmoticonClass(host, @"EmoticonViewWithPreview") || WCEmoticonClass(host, @"EmoticonMessageCellView")) return YES;
    WCEmoticonPreviewOwner *owner = objc_getAssociatedObject(view, &WCEmoticonPreviewOwnerKey);
    UIView *host = owner.view;
    id backdrop = WCTweakSafeValue(host, @"m_emoticonPreviewBack");
    BOOL previewSlot = WCTweakSafeValue(host, @"m_emoticonPreview") == view || WCTweakSafeValue(host, @"m_emoticonShowPlayView") == view;
    return host.window && previewSlot && [WCTweakSafeValue(host, @"m_isPreviewing") boolValue]
        && [backdrop isKindOfClass:UIView.class] && [view isDescendantOfView:backdrop];
}
void WCGestureEmoticonCornerLayout(UIView *view) {
    if (WCEmoticonClass(view, @"EmoticonViewWithPreview")) {
        for (NSString *key in @[@"m_emoticonView", @"m_emoticonPreview", @"m_emoticonShowPlayView"]) {
            id media = WCTweakSafeValue(view, key);
            if ([media isKindOfClass:UIView.class]) {
                WCEmoticonPreviewOwner *owner = objc_getAssociatedObject(media, &WCEmoticonPreviewOwnerKey);
                if (!owner) { owner = [WCEmoticonPreviewOwner new]; objc_setAssociatedObject(media, &WCEmoticonPreviewOwnerKey, owner, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
                owner.view = view;
                WCGestureMediaCornerApply(media, WCGestureEmoticonCornerEnabledKey, WCGestureEmoticonCornerRadiusKey, WCEmoticonHost(media));
            }
        }
        return;
    }
    BOOL media = WCEmoticonClass(view, @"MMEmoticonView") || WCEmoticonClass(view, @"YYAsyncImageView");
    if (media) WCGestureMediaCornerApply(view, WCGestureEmoticonCornerEnabledKey, WCGestureEmoticonCornerRadiusKey, WCEmoticonHost(view));
}
