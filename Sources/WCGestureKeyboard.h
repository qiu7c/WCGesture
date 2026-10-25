#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs the runtime (non-Logos) hooks the keyboard strip needs: the
/// keyboard window capture and the dock's layout pass.
void WCInstallKeyboardWindowCapture(void);
void WCInstallKeyboardDockHook(void);

/// Called from the keyboard notifications. `update` positions the strip for
/// the new keyboard frame, `refresh` re-applies the last frame (e.g. after a
/// settings change or when the keyboard settles), `hide` tears it down.
void WCKeyboardEnhanceUpdate(NSNotification *note);
void WCKeyboardEnhanceRefresh(void);
void WCKeyboardEnhanceHide(void);

NS_ASSUME_NONNULL_END
