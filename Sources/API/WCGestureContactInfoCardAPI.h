#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureContactInfoCardApply(id owner, BOOL group);
void WCGestureContactInfoCardOpen(id owner);
void WCGestureContactInfoCardSettingsChanged(NSString * _Nullable key);
UIViewController *WCGestureCreateContactInfoCard(NSString *title, NSString *name, NSString *userName,
                                               NSArray<NSDictionary<NSString *, NSString *> *> *rows);
NS_ASSUME_NONNULL_END
