#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, WCGesturePageLockTarget) {
    WCGesturePageLockService,
    WCGesturePageLockFavorites,
    WCGesturePageLockMomentsAlbum,
};
void WCGestureServicePageLockStart(void);
void WCGestureServicePageLockPerform(UIViewController *owner, dispatch_block_t action);
void WCGesturePageLockPerform(UIViewController *owner, WCGesturePageLockTarget target, dispatch_block_t action);
void WCGestureServicePageLockCancel(UIViewController * _Nullable owner);
void WCGestureServicePageLockSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
