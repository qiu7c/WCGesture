#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#import "Sources/WCGestureConfig.h"
#import "Sources/WCGestureAccount.h"
#import "Sources/WCGesturePrivateAPI.h"
#import "Sources/WCGestureSettingsVC.h"
#import "Sources/WCPopup.h"
#import "Sources/WCGestureTranslate.h"
#import "Sources/WCGestureAI.h"
#import "Sources/WCGestureSupport.h"
#import "Sources/WCGestureWeChatClasses.h"
#import "Sources/WCGestureInput.h"
#import "Sources/WCGestureKeyboard.h"
#import "Sources/WCGestureGlobal.h"
#import "Sources/WCGestureMessage.h"

#pragma mark - Hooks

%hook CommonMessageCellView

- (void)setViewModel:(id)viewModel {
    %orig;
    WCSynchronizeReplyGesture(self);
}

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeReplyGesture(self);
}

%new
- (void)wc_handleReplyPan:(UIPanGestureRecognizer *)recognizer {
    WCReplyPanHandle(self, recognizer);
}

%new
- (void)wc_handleMessageTapAction:(UITapGestureRecognizer *)recognizer {
    WCMessageTapHandle(self, recognizer);
}

%end

%hook BaseMsgContentViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCSetVisibleChatController(self);
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (WCVisibleChatControllerGet() == self) WCSetVisibleChatController(nil);
}

%end

%hook MMGrowTextView

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeInputGestures(self);
}

%new
- (void)wc_handleInputSwipeLeft:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeLeftActionKey];
    if (action == WCInputActionNone) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(self, action);
}

%new
- (void)wc_handleInputSwipeRight:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeRightActionKey];
    if (action == WCInputActionNone) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(self, action);
}

%new
- (void)wc_handleInputTapAction:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized ||
        !self.window ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    NSString *key = recognizer.numberOfTapsRequired >= 3
        ? WCInputTripleTapActionKey
        : WCInputDoubleTapActionKey;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults] integerForKey:key];
    if (action == WCInputActionNone) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(self, action);
}

%end

#pragma mark - Voice repeat upload hooks

// These four hooks make voice repeat actually deliver. Without them, the
// 12-second forward window set by WCSendVoiceMessage is never consulted and
// WeChat uploads the resent voice in ordinary-recording mode, which it rejects.
@interface UploadVoiceWrap : NSObject
@end
@interface UploadVoiceRequest : NSObject
@end
@interface MMNewUploadVoiceMgr : NSObject
@end
@interface UploadVoiceCDNMgr : NSObject
@end

%hook UploadVoiceWrap
- (void)setM_uiVoiceForwardFlag:(unsigned int)forwardFlag {
    %orig(WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag);
}
%end

%hook UploadVoiceRequest
- (void)setForwardFlag:(unsigned int)forwardFlag {
    %orig(WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag);
}
%end

%hook MMNewUploadVoiceMgr
- (void)AddNewPart:(id)part
           LocalID:(unsigned int)localID
          n64SvrID:(long long)serverID
            Offset:(unsigned int)offset
               Len:(unsigned int)length
         VoiceTime:(unsigned int)voiceTime
        CreateTime:(unsigned int)createTime
           EndFlag:(unsigned int)endFlag
        CancelFlag:(unsigned int)cancelFlag
       VoiceFormat:(unsigned int)voiceFormat
       ForwardFlag:(unsigned int)forwardFlag
         msgSource:(id)msgSource
          chatName:(id)chatName {
    %orig(part, localID, serverID, offset, length, voiceTime, createTime,
          endFlag, cancelFlag, voiceFormat,
          WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag,
          msgSource, chatName);
}
%end

%hook UploadVoiceCDNMgr
- (void)AddNewPart:(id)part
           LocalID:(unsigned int)localID
          n64SvrID:(long long)serverID
            Offset:(unsigned int)offset
               Len:(unsigned int)length
         VoiceTime:(unsigned int)voiceTime
        CreateTime:(unsigned int)createTime
           EndFlag:(unsigned int)endFlag
        CancelFlag:(unsigned int)cancelFlag
       VoiceFormat:(unsigned int)voiceFormat
       ForwardFlag:(unsigned int)forwardFlag
         msgSource:(id)msgSource
          chatName:(id)chatName {
    %orig(part, localID, serverID, offset, length, voiceTime, createTime,
          endFlag, cancelFlag, voiceFormat,
          WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag,
          msgSource, chatName);
}
%end

@interface MoreViewController : UIViewController
- (void)addFunctionSection;
@end

// Adds a "微信手势" row to WeChat's Me page (MoreViewController). We also
// register through WCPluginsMgr when available; either entry opens the
// settings sheet. The cell factory uses NSClassFromString to reach WeChat's
// WCTableViewCellManager without creating a link-time class-symbol reference
// (private classes are only registered at runtime).
%hook MoreViewController

- (void)addFunctionSection {
    %orig;
    @try {
        id tableManager = [self valueForKey:@"m_tableViewMgr"];
        if (![tableManager respondsToSelector:NSSelectorFromString(@"getSectionAt:")]) return;
        UIImage *icon = [UIImage systemImageNamed:@"hand.draw.fill"] ?: [UIImage systemImageNamed:@"hand.draw"];
        Class cellClass = NSClassFromString(@"WCTableViewCellManager");
        SEL factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:WithDisclosureIndicator:");
        id cell = nil;
        if (cellClass && [cellClass respondsToSelector:factory]) {
            cell = ((id (*)(id, SEL, SEL, id, UIImage *, NSString *, BOOL))objc_msgSend)
                (cellClass, factory,
                 @selector(wc_pushGestureSettings), self, icon ?: [UIImage new], @"微信手势", YES);
        }
        if (!cell) return;
        id section = ((id (*)(id, SEL, NSUInteger))objc_msgSend)
            (tableManager, NSSelectorFromString(@"getSectionAt:"), 2);
        if (section && [section respondsToSelector:NSSelectorFromString(@"addCell:")]) {
            ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"addCell:"), cell);
        }
        id tableView = nil;
        if ([tableManager respondsToSelector:NSSelectorFromString(@"getTableView")]) {
            tableView = ((id (*)(id, SEL))objc_msgSend)(tableManager, NSSelectorFromString(@"getTableView"));
        }
        if ([tableView respondsToSelector:@selector(reloadData)]) [tableView reloadData];
    } @catch (__unused NSException *exception) {
    }
}

%new
- (void)wc_pushGestureSettings {
    WCGesturePresentSettings(self);
}

%end

#pragma mark - Moments (朋友圈) double-tap like

@interface WCTimeLineCellView : UIView
- (void)onAccessibilityLike;
- (void)didMoveToWindow;
- (void)setViewModel:(id)viewModel;
- (void)prepareForReuse;
@end

static char WCMomentsDoubleTapRecognizerKey;

static BOOL WCMomentsIsNativeDetailContext(id responderObject) {
    Class detailClass = NSClassFromString(@"WCCommentDetailViewControllerFB");
    if (!detailClass) return NO;
    UIViewController *controller = WCViewControllerForResponder(responderObject);
    for (UIViewController *current = controller; current; current = current.parentViewController) {
        if ([current isKindOfClass:detailClass]) return YES;
    }
    return controller && [controller.navigationController.topViewController isKindOfClass:detailClass];
}

static void WCShowMomentsHeart(WCTimeLineCellView *cell, UITapGestureRecognizer *recognizer) {
    UIWindow *window = cell.window;
    if (!window || !recognizer) return;
    CGPoint point = [recognizer locationInView:window];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:34.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *heart = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill" withConfiguration:config]];
    heart.tintColor = [UIColor colorWithRed:0.96 green:0.25 blue:0.34 alpha:1.0];
    heart.contentMode = UIViewContentModeScaleAspectFit;
    heart.bounds = CGRectMake(0.0, 0.0, 44.0, 44.0);
    heart.center = point;
    heart.alpha = 0.0;
    heart.transform = CGAffineTransformMakeScale(0.52, 0.52);
    heart.userInteractionEnabled = NO;
    [window addSubview:heart];
    [UIView animateKeyframesWithDuration:0.52 delay:0.0
        options:UIViewKeyframeAnimationOptionCalculationModeCubic | UIViewAnimationOptionAllowUserInteraction
        animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.30 animations:^{
            heart.alpha = 1.0;
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -5.0), CGAffineTransformMakeScale(1.12, 1.12));
        }];
        [UIView addKeyframeWithRelativeStartTime:0.30 relativeDuration:0.32 animations:^{
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -12.0), CGAffineTransformIdentity);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.62 relativeDuration:0.38 animations:^{
            heart.alpha = 0.0;
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -24.0), CGAffineTransformMakeScale(0.88, 0.88));
        }];
    } completion:^(__unused BOOL finished) {
        [heart removeFromSuperview];
    }];
}

static void WCSynchronizeMomentsDoubleTap(WCTimeLineCellView *cell) {
    if (!cell) return;
    UITapGestureRecognizer *recognizer = objc_getAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey);
    BOOL enabled = WCGestureEnabled(WCMomentsDoubleTapLikeKey) &&
                   !WCMomentsIsNativeDetailContext(cell);
    if (enabled && !recognizer) {
        recognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wc_handleMomentsDoubleTap)];
        recognizer.numberOfTapsRequired = 2;
        recognizer.cancelsTouchesInView = NO;
        [cell addGestureRecognizer:recognizer];
        objc_setAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!enabled && recognizer) {
        [cell removeGestureRecognizer:recognizer];
        objc_setAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%hook WCTimeLineCellView

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

- (void)setViewModel:(id)viewModel {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

- (void)prepareForReuse {
    %orig;
    WCSynchronizeMomentsDoubleTap(self);
}

%new
- (void)wc_handleMomentsDoubleTap {
    if (!WCGestureEnabled(WCMomentsDoubleTapLikeKey) ||
        WCMomentsIsNativeDetailContext(self)) return;
    UITapGestureRecognizer *recognizer = objc_getAssociatedObject(self, &WCMomentsDoubleTapRecognizerKey);
    [self onAccessibilityLike];
    WCShowMomentsHeart(self, recognizer);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCMomentsLikeHapticKey]) {
        WCPlayConfiguredHaptic();
    }
}

%end

// 绑定到每个 window 的手势
%hook UIWindow

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeGlobalGesturesOnWindow(self);
}

- (void)didMoveToSuperview {
    %orig;
    WCSynchronizeGlobalGesturesOnWindow(self);
}

%new
- (void)wc_handleGlobalLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan ||
        !WCGestureEnabled(WCGlobalGestureEnabledKey)) return;
    UIViewController *presenter = WCRootTopController();
    NSInteger action;
    if (recognizer.numberOfTouchesRequired == 2) {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    } else {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCGlobalGestureHapticKey]) {
        WCPlayConfiguredHaptic();
    }
    WCPerformGlobalAction(presenter, (WCGlobalAction)action);
}

%end

#pragma mark - Hide separator lines (拓展设置)

static char WCSeparatorOriginalHiddenKey;

static BOOL WCViewLooksLikeGlobalSeparator(UIView *view) {
    if (!view) return NO;
    NSString *className = NSStringFromClass(view.class);
    BOOL nativeSeparator = [className isEqualToString:@"_UITableViewCellSeparatorView"];
    CGRect frame = view.frame;
    CGFloat width = CGRectGetWidth(frame);
    CGFloat height = CGRectGetHeight(frame);
    BOOL thinLine = ((width > 0.3 && width <= 0.55) ||
                     (height > 0.3 && height <= 0.55)) &&
                    view.alpha > 0.9 &&
                    view.backgroundColor != nil &&
                    ![view isKindOfClass:[UILabel class]] &&
                    ![view isKindOfClass:[UIImageView class]];
    BOOL candidate = nativeSeparator || thinLine;
    if ([className isEqualToString:@"UIView"]) candidate = thinLine && view.subviews.count == 0;
    return candidate;
}

%hook UIView

- (void)layoutSubviews {
    %orig;
    // The strip's layer.zPosition keeps it above the keyboard's own subviews.
    // Do not re-front it here: the keyboard lays out on every keystroke, and
    // reordering a translucent view that often makes it look like it flickers.
    NSNumber *originalHidden = objc_getAssociatedObject(self, &WCSeparatorOriginalHiddenKey);
    BOOL shouldHide = WCGestureEnabled(WCHideSeparatorLinesKey) && WCViewLooksLikeGlobalSeparator(self);
    if (shouldHide) {
        if (!originalHidden) {
            originalHidden = @(self.hidden);
            objc_setAssociatedObject(self, &WCSeparatorOriginalHiddenKey, originalHidden, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!self.hidden) self.hidden = YES;
    } else if (originalHidden) {
        self.hidden = originalHidden.boolValue;
        objc_setAssociatedObject(self, &WCSeparatorOriginalHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end

#pragma mark - Settings change observer

%ctor {
    @autoreleasepool {
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
