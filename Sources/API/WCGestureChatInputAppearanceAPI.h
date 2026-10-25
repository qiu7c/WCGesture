#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
void WCGestureChatInputRoundingApply(UIView *toolView);
void WCGestureChatInputRoundingSettingsChanged(NSString * _Nullable key);
/// Shared by the native controls and the full-page preview. Preview mode can
/// show configured radii without enabling the actual feature.
void WCGestureChatInputRoundingApplyToViews(UIView * _Nullable inner, UIView * _Nullable outer, BOOL preview);
CGFloat WCGestureChatInputRoundingRadius(BOOL inner, CGFloat height);
NS_ASSUME_NONNULL_END
