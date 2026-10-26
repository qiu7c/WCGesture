#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Global interface hook

// Kept in this translation unit on purpose: WCInstallKeyboardDockHook() must
// run after %init so UIKeyboardDockView's layoutSubviews chains into this hook
// instead of bypassing it. Feature hooks live next to their feature under
// Sources/Features/.
%hook UIView

- (void)layoutSubviews {
    %orig;
    WCSeparatorHandleLayoutSubviews(self);
    WCGestureMomentsImageCornerViewDidLayout(self);
    WCGestureMediaCornerViewDidLayout(self);
}

%end

#pragma mark - Entry point

%ctor {
    @autoreleasepool {
        WCGestureMigrateLegacyDefaults();
        WCGestureRegisterDefaults();
        WCInstallServiceCenterCompatibility();
        // Cache the current-user wxid asynchronously; voice/text repeat need it
        // to fill m_nsFromUsr. Refresh again when opening settings.
        dispatch_async(dispatch_get_main_queue(), ^{ WCRefreshCachedCurrentUser(); });
        WCGestureRegisterEntry();
        WCInstallKeyboardWindowCapture();
        %init;
        // Install after %init so the dock's layoutSubviews chains into the
        // global UIView hook below instead of bypassing it.
        WCInstallKeyboardDockHook();
        WCGestureMomentsMonitoringStart();

        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillChangeFrameNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            WCKeyboardEnhanceUpdate(note);
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardDidShowNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            WCKeyboardEnhanceRefresh();
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            WCKeyboardEnhanceHide();
        }];

        [[NSNotificationCenter defaultCenter] addObserverForName:WCGestureDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            // Resync on the next runloop so the cell re-reads the new value.
            dispatch_async(dispatch_get_main_queue(), ^{
                WCGestureLayoutSettingsChanged(note.object);
                WCGestureChatInputRoundingSettingsChanged(note.object);
                WCGestureRefreshTrackedGlobalAvatarViews();
                WCGestureInterfaceCleanupSettingsChanged(note.object);
                WCGestureMomentsImageCornerSettingsChanged(note.object);
                WCGestureMomentsTimeSettingsChanged(note.object);
                WCGestureMomentsMonitoringSettingsChanged(note.object);
                WCGestureChatUtilitiesSettingsChanged(note.object);
                WCGestureChatTopBarSettingsChanged(note.object);
                WCGestureContactInfoCardSettingsChanged(note.object);
                WCGestureMediaCornerSettingsChanged(note.object);
                WCGestureVoiceTranscriptionSettingsChanged(note.object);
                WCGestureMessageTimeSettingsChanged(note.object);
                WCGestureAntiRevokeSettingsChanged(note.object);
                WCKeyboardEnhanceRefresh();
                WCSynchronizeVisibleReplyGestures();
                WCSynchronizeGlobalGestures();
                // Re-sync input swipe on the active chat too.
                UIWindow *window = WCActiveWindow();
                if (window) {
                    Class growClass = NSClassFromString(@"MMGrowTextView");
                    if (growClass) {
                        NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithArray:window.subviews];
                        while (stack.count) {
                            UIView *view = stack.lastObject;
                            [stack removeLastObject];
                            if ([view isKindOfClass:growClass]) WCSynchronizeInputGestures((MMGrowTextView *)view);
                            [stack addObjectsFromArray:view.subviews];
                        }
                    }
                }
            });
        }];
    }
}
