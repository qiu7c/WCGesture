#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<NSString *> *WCGestureMomentsReminderUsers(void);
FOUNDATION_EXPORT void WCGestureMomentsReminderSetUserSelected(NSString *username, BOOL selected);
FOUNDATION_EXPORT void WCGestureMomentsReminderTick(void);
FOUNDATION_EXPORT void WCGestureMomentsReminderSettingsDidChange(void);

NS_ASSUME_NONNULL_END
