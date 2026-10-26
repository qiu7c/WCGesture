#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureContactInfoCardApply(id owner, BOOL group);
void WCGestureContactInfoCardOpen(id owner);
void WCGestureContactInfoCardSettingsChanged(NSString * _Nullable key);
UIViewController *WCGestureCreateContactInfoCard(NSString *title, NSString *name, NSString *userName,
                                               NSArray<NSDictionary<NSString *, NSString *> *> *rows);
/// Retain the returned request while the card is visible. nil groups means unavailable, not zero.
id _Nullable WCGestureContactInfoCardLoadGroups(NSString *userName, void (^update)(NSArray<NSDictionary<NSString *, NSString *> *> * _Nullable groups, BOOL finished));
NS_ASSUME_NONNULL_END
