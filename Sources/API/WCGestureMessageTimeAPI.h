#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
void WCGestureMessageTimeLayout(UIView *cell);
void WCGestureMessageTimeHide(UIView *cell);
void WCGestureMessageTimeSchedule(UIView *cell);
UIView * _Nullable WCGestureMessageSideAnchorView(UIView *cell);
BOOL WCGestureShouldShowSplitMessageMetadata(id _Nullable model, BOOL head);
UILabel * _Nullable WCGestureVisibleMessageTimeSideLabel(UIView *cell);
void WCGestureMessageTimeSettingsChanged(NSString * _Nullable key);
/// Shared by actual message cells and the settings preview.
void WCGestureMessageTimeStyleLabel(UILabel *label, NSDate *date);
CGRect WCGestureMessageTimeSideFrame(CGRect bounds, CGRect bubble, BOOL sender, CGSize size);
CGRect WCGestureMessageTimeAvatarFrame(CGRect bounds, CGRect avatar, CGSize size);
NS_ASSUME_NONNULL_END
