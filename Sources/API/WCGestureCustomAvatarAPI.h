#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
UIImage * _Nullable WCGestureCustomAvatarImage(NSString *username, CGSize size, CGFloat radius);
void WCGestureCustomAvatarApply(UIView *headView);
void WCGestureCustomAvatarWillChangeUser(UIView *headView);
void WCGestureCustomAvatarSettingsChanged(NSString * _Nullable key);
NSArray<NSString *> *WCGestureCustomAvatarSavedUsers(void);
void WCGestureCustomAvatarSave(NSString *username, UIImage *image, void (^completion)(BOOL success));
void WCGestureCustomAvatarRemove(NSString *username, void (^completion)(BOOL success));
UIViewController *WCGestureCreateCustomAvatarController(void);
NS_ASSUME_NONNULL_END
