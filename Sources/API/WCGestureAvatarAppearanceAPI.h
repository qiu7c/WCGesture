#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureApplyGlobalAvatarRoundingToHeadView(UIView *headView);
BOOL WCGestureHeadViewIsExcludedFromGlobalAvatarRounding(UIView *headView);
void WCGestureExcludeHeadViewFromGlobalAvatarRounding(UIView *headView);
void WCGestureRefreshTrackedGlobalAvatarViews(void);
unsigned int WCGestureGlobalAvatarScaledCornerSize(unsigned int originalSize);
NS_ASSUME_NONNULL_END
