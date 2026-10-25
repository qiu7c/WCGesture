#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
void WCGestureMessageTimeLayout(UIView *cell);
void WCGestureMessageTimeHide(UIView *cell);
void WCGestureMessageTimeSettingsChanged(NSString * _Nullable key);
/// Shared by actual message cells and the settings preview.
void WCGestureMessageTimeStyleLabel(UILabel *label, NSDate *date);
CGRect WCGestureMessageTimeSideFrame(CGRect bounds, CGRect bubble, BOOL sender, CGSize size);
NS_ASSUME_NONNULL_END
