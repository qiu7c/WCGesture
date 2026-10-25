#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void WCGestureMomentsInteractionObserveUnreadCount(id manager, unsigned int count);
FOUNDATION_EXPORT void WCGestureMomentsInteractionObserveLastUnreadMessage(id manager, id _Nullable message);
FOUNDATION_EXPORT void WCGestureMomentsInteractionReminderTick(void);
FOUNDATION_EXPORT void WCGestureMomentsInteractionReminderSettingsDidChange(void);

void WCGestureMomentsPrewarmIfNeeded(void);
void WCGestureMomentsPrewarmCancel(void);

NS_ASSUME_NONNULL_END
