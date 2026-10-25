#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
void WCGestureMomentsMonitoringStart(void);
void WCGestureMomentsMonitoringTick(void);
void WCGestureMomentsMonitoringSettingsChanged(NSString * _Nullable key);
void WCGestureMomentsMonitoringEnterBackground(void);
void WCGestureMomentsMonitoringEnterForeground(void);
void WCGestureMomentsMonitoringBecomeActive(void);
NS_ASSUME_NONNULL_END
