#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureMediaCornerApply(UIView *view, NSString *enabledKey, NSString *radiusKey, BOOL eligible);
void WCGestureMediaCornerViewDidLayout(UIView *view);
void WCGestureMediaCornerReset(UIView *root);
void WCGestureMediaCornerSettingsChanged(NSString * _Nullable key);
void WCGestureEmoticonCornerLayout(UIView *view);
void WCGestureChatImageCornerLayout(UIView *view);
NS_ASSUME_NONNULL_END
