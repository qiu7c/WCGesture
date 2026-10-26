#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, WCGestureSettingsEntryLocation) {
    WCGestureSettingsEntryMe = 0,
    WCGestureSettingsEntryManager = 1,
    WCGestureSettingsEntryWeChatSettings = 2,
};
BOOL WCGestureSettingsEntryManagerAvailable(void);
WCGestureSettingsEntryLocation WCGestureSettingsEntryResolvedLocation(void);
void WCGestureRegisterEntry(void);
void WCGestureSettingsEntryRefresh(UIViewController *controller, WCGestureSettingsEntryLocation page);
void WCGestureSettingsEntrySettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
