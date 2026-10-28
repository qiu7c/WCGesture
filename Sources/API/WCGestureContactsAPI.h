#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
NSArray *WCGesturePrivateContactList(void);
NSString *WCGesturePrivateContactDisplayName(id _Nullable contact, NSString * _Nullable fallback);
NSString *WCGesturePrivateNotificationDisplayName(NSString * _Nullable username, NSString * _Nullable fallback);
UIView *WCGestureContactAvatarView(NSString *username);
UIView *WCGestureContactUnroundedAvatarView(NSString *username);
UIView *WCGestureContactUncroppedAvatarView(NSString *username);
// 0: friend, 1: group, NSNotFound: service/official/other contact.
NSInteger WCGestureContactPickerKind(id _Nullable contact, NSString *username);
NS_ASSUME_NONNULL_END
