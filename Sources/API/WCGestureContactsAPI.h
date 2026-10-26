#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
NSArray *WCGesturePrivateContactList(void);
NSString *WCGesturePrivateContactDisplayName(id _Nullable contact, NSString * _Nullable fallback);
NSString *WCGesturePrivateNotificationDisplayName(NSString * _Nullable username, NSString * _Nullable fallback);
UIView *WCGestureContactAvatarView(NSString *username);
UIView *WCGestureContactUnroundedAvatarView(NSString *username);
UIView *WCGestureContactUncroppedAvatarView(NSString *username);
NS_ASSUME_NONNULL_END
