#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
unsigned long long WCGestureWalletDisplayNumber(UIView *view,unsigned long long original);
void WCGestureWalletDisplayLayout(UIView *header);
void WCGestureWalletDisplaySettingsChanged(NSString * _Nullable key);
void WCGestureWalletDisplayEdit(void);
NSString *WCGestureWalletDisplayText(void);
void WCGestureWalletDisplayNumberEnded(UIView *view);
void WCGestureWalletDisplayControllerChanged(UIViewController *controller);
NSString *WCGestureWalletDisplayTextForKind(NSInteger kind);
void WCGestureWalletDisplayEditKind(NSInteger kind);
NS_ASSUME_NONNULL_END
