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

#pragma mark - WeChat private class interfaces

@interface CMessageWrap : NSObject
@end

@interface MMMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface CommonMessageCellView : UIView
@property (nonatomic, strong) id viewModel;
- (void)setViewModel:(id)viewModel;
- (void)didMoveToWindow;
- (void)prepareForReuse;
- (void)layoutSubviews;
- (void)updateStatus;
- (void)updateNodeStatus;
- (void)handleTapReferMessage;
- (void)handleTapForReferMsg:(id)sender;
- (void)onShowMsgReplyMenuItem:(id)sender;
- (void)onRevokeMsg:(id)sender;
- (void)onCopy:(id)sender;
- (void)onDelete:(id)sender;
- (void)onDeleteMessage:(id)sender;
- (void)onHeadImageLongPressed:(id)sender;
@end

@interface BaseMsgContentViewController : UIViewController
@end

@interface MMGrowTextView : UIView
- (void)didMoveToWindow;
- (void)textViewDidChange:(id)textView;
@end

@interface MMInputToolView : UIView
@end

@interface ForwardMessageLogicController : NSObject
- (void)setDelegate:(id)delegate;
- (void)forwardNoConfirmForMsgList:(NSArray *)messages toContacts:(NSArray *)contacts;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(NSString *)session MsgWrap:(id)message;
- (id)uploaderForMsgWrap:(id)message;
@end

@interface ForwardMsgUtil : NSObject
+ (BOOL)canBeForwardWithMsg:(id)message;
@end

@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)session MsgWrap:(id)message;
- (void)AddLocalMsg:(NSString *)session MsgWrap:(id)message;
- (BOOL)SaveMesVoice:(NSData *)data MsgWrap:(id)message;
@end

#pragma mark - KVC helpers

// Defined later in the global-gesture section; forward-declared for the
// Moments double-tap handler which appears earlier in the file.
static void WCPlayConfiguredHaptic(void);
static UIImpactFeedbackStyle WCHapticStyleFromConfig(void);
static void WCShowToast(NSString *text);

static id WCTweakSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void WCTweakSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0) return;
    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {
    }
}

static id WCTweakValueForSelectorNames(id object, NSArray<NSString *> *selectorNames) {
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([object respondsToSelector:selector]) {
            return ((id (*)(id, SEL))objc_msgSend)(object, selector);
        }
    }
    return nil;
}

#pragma mark - Logging

#define WCLog(fmt, ...) NSLog(@"[WCGesture] " fmt, ##__VA_ARGS__)

#pragma mark - Associated object keys

static char WCReplyPanRecognizerKey;
static char WCReplyPanDelegateKey;
static char WCMessageDoubleTapRecognizerKey;
static char WCMessageTripleTapRecognizerKey;
static char WCReplyOriginalTransformKey;
static char WCReplyTransformSnapshotsKey;
static char WCReplyFeedbackGeneratorKey;
static char WCReplyFeedbackTriggeredKey;
static char WCReplyPanRightwardKey;
static char WCInputSwipeLeftRecognizerKey;
static char WCInputSwipeRightRecognizerKey;
static char WCInputDoubleTapRecognizerKey;
static char WCInputTripleTapRecognizerKey;

#pragma mark - Visible chat controller cache (for repeat forwarding)

static __weak BaseMsgContentViewController *WCVisibleChatController;

#pragma mark - Message wrap resolution

// Resolves a CMessageWrap from any message-like object. Tries the wrap
// directly, then the standard selector/field paths across WeChat versions.
static id WCMessageWrapForObject(id object) {
    if (!object) return nil;
    Class messageClass = NSClassFromString(@"CMessageWrap");
    if (messageClass && [object isKindOfClass:messageClass]) return object;
    id message = WCTweakValueForSelectorNames(object,
        @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap", @"message"]);
    if (message) return message;
    id viewModel = WCTweakValueForSelectorNames(object, @[@"viewModel", @"m_viewModel"]);
    return WCTweakValueForSelectorNames(viewModel,
        @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
}

static id WCMessageWrapForCell(id cell) {
    id currentMessage = WCTweakValueForSelectorNames(cell,
        @[@"getCurrentMessageWrap", @"currentMessageWrap"]);
    if (currentMessage) return currentMessage;
    id directMessage = WCMessageWrapForObject(cell);
    if (directMessage) return directMessage;
    id viewModel = WCTweakValueForSelectorNames(cell, @[@"viewModel", @"m_viewModel"]);
    id directContent = WCTweakSafeValue(viewModel, @"m_nsContent");
    if ([directContent isKindOfClass:NSString.class]) return viewModel;
    id message = WCTweakValueForSelectorNames(viewModel,
        @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
    if (message) return message;
    id parentModel = WCTweakSafeValue(viewModel, @"parentModel");
    message = WCTweakValueForSelectorNames(parentModel,
        @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap"]);
    if (message) return message;
    return WCTweakValueForSelectorNames(cell,
        @[@"messageWrap", @"m_messageWrap", @"msgWrap", @"wrap", @"message"]);
}

static BOOL WCMessageCellIsSender(CommonMessageCellView *cell) {
    id viewModel = WCTweakSafeValue(cell, @"viewModel") ?: WCTweakSafeValue(cell, @"m_viewModel");
    id senderValue = WCTweakSafeValue(viewModel, @"isSender");
    if ([senderValue respondsToSelector:@selector(boolValue)] && [senderValue boolValue]) return YES;
    id message = WCMessageWrapForCell(cell);
    senderValue = WCTweakSafeValue(message, @"isSender");
    if ([senderValue respondsToSelector:@selector(boolValue)] && [senderValue boolValue]) return YES;
    NSString *fromUser = WCTweakSafeValue(message, @"m_nsFromUsr");
    NSString *currentUser = WCCurrentUserWXID();
    return fromUser.length > 0 && currentUser.length > 0 && [fromUser isEqualToString:currentUser];
}

#pragma mark - Gesture action selection

static WCReplySwipeAction WCMessageGestureAction(CommonMessageCellView *cell,
                                                 NSString *selfKey,
                                                 NSString *otherKey) {
    BOOL selfMessage = WCMessageCellIsSender(cell);
    NSInteger action = [[NSUserDefaults standardUserDefaults] integerForKey:selfMessage ? selfKey : otherKey];
    if (action < WCReplySwipeActionNone || action > WCReplySwipeActionTranslate) return WCReplySwipeActionNone;
    if (!selfMessage && action == WCReplySwipeActionRevoke) return WCReplySwipeActionNone;
    return (WCReplySwipeAction)action;
}

static WCReplySwipeAction WCMessageSwipeAction(CommonMessageCellView *cell, BOOL rightward) {
    return WCMessageGestureAction(cell,
        rightward ? WCReplySwipeRightSelfActionKey : WCReplySwipeSelfActionKey,
        rightward ? WCReplySwipeRightOtherActionKey : WCReplySwipeOtherActionKey);
}

static CGFloat WCReplySwipeTriggerDistance(void) {
    CGFloat value = [[NSUserDefaults standardUserDefaults] doubleForKey:WCReplySwipeTriggerDistanceKey];
    if (value <= 0.0) value = 56.0;
    return MIN(100.0, MAX(36.0, value));
}

#pragma mark - Active window (multi-scene safe)

// keyWindow is deprecated since iOS 13 and compiled with -Werror; this walks
// connected scenes. Do NOT filter by class name or window level: some WeChat
// environments host the app UI in a window whose class contains "iConsole"
// (see runtime dumps: window = iConsoleWindow). Filtering it out returned nil
// and made screenshots/pushes/toasts silently do nothing.
static UIWindow *WCActiveWindow(void) {
    NSArray<UIWindow *> *windows = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        windows = ((UIWindowScene *)scene).windows;
        if (windows.count) break;
    }
    if (windows.count == 0) {
        id all = WCTweakSafeValue(UIApplication.sharedApplication, @"windows");
        if ([all isKindOfClass:[NSArray class]]) windows = all;
    }
    for (UIWindow *window in windows) {
        if (window.isKeyWindow && !window.hidden && window.alpha > 0.0) return window;
    }
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.rootViewController) return window;
    }
    return windows.firstObject;
}

#pragma mark - Navigation return gesture detection

static UIViewController *WCViewControllerForResponder(id responderObject) {
    UIResponder *responder = [responderObject isKindOfClass:[UIResponder class]] ? (UIResponder *)responderObject : nil;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
        responder = responder.nextResponder;
    }
    return nil;
}

// Window-level presentation helpers. A UIWindow's responder chain does not lead
// to a UIViewController, so WCViewControllerForResponder(window) returns nil.
// Always start from rootViewController and walk presented controllers instead.
static UIViewController *WCRootTopController(void) {
    UIViewController *controller = WCActiveWindow().rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

static UINavigationController *WCPushNavigation(void) {
    UIViewController *top = WCRootTopController();
    if ([top isKindOfClass:[UINavigationController class]]) return (UINavigationController *)top;
    if (top.navigationController) return top.navigationController;
    if ([top isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = ((UITabBarController *)top).selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) return (UINavigationController *)selected;
        if (selected.navigationController) return selected.navigationController;
    }
    return nil;
}

static void WCPushGlobal(UIViewController *vc) {
    if (!vc) return;
    UINavigationController *nav = WCPushNavigation();
    if (nav) {
        [nav pushViewController:vc animated:YES];
    } else {
        UIViewController *top = WCRootTopController();
        [top presentViewController:vc animated:YES completion:nil];
    }
}

static NSArray<UIGestureRecognizer *> *WCNavigationReturnGesturesForView(UIView *view) {
    UIViewController *controller = WCViewControllerForResponder(view);
    UINavigationController *navigationController = controller.navigationController;
    if (!navigationController || navigationController.viewControllers.count <= 1) return @[];

    NSMutableArray<UIGestureRecognizer *> *gestures = [NSMutableArray array];
    UIGestureRecognizer *interactivePop = navigationController.interactivePopGestureRecognizer;
    if (interactivePop && interactivePop.enabled) [gestures addObject:interactivePop];

    for (id owner in @[navigationController, navigationController.view]) {
        for (NSString *selectorName in @[@"screenDismissPanGestureRecognizer", @"dismissPanGestureRecognizer"]) {
            SEL selector = NSSelectorFromString(selectorName);
            if (![owner respondsToSelector:selector]) continue;
            id candidate = ((id (*)(id, SEL))objc_msgSend)(owner, selector);
            if (![candidate isKindOfClass:[UIGestureRecognizer class]] ||
                ![(UIGestureRecognizer *)candidate isEnabled] ||
                [gestures containsObject:candidate]) continue;
            [gestures addObject:candidate];
        }
    }
    return gestures;
}

static BOOL WCIsNavigationReturnGesture(UIGestureRecognizer *candidate, UIView *view) {
    if (!candidate) return NO;
    return [WCNavigationReturnGesturesForView(view) containsObject:candidate];
}

#pragma mark - Transform snapshot

@interface WCReplyTransformSnapshot : NSObject
@property (nonatomic, strong) UIView *view;
@property (nonatomic, assign) CGAffineTransform transform;
@end

@implementation WCReplyTransformSnapshot
@end

// Resolves a stable cross-cell message identity. Returns nil when the
// message lacks a usable identity, so unrelated cells are never matched.
static NSString *WCMessageIdentityKeyForMessage(id message) {
    if (!message) return nil;
    SEL combinedSelector = NSSelectorFromString(@"combineChatNameWithLocalId");
    if ([message respondsToSelector:combinedSelector]) {
        id combined = ((id (*)(id, SEL))objc_msgSend)(message, combinedSelector);
        if ([combined isKindOfClass:[NSString class]] && [combined length] > 0) return combined;
    }
    SEL chatSelector = NSSelectorFromString(@"GetChatName");
    SEL localIDSelector = NSSelectorFromString(@"m_uiMesLocalID");
    if (![message respondsToSelector:chatSelector] || ![message respondsToSelector:localIDSelector]) return nil;
    id chatName = ((id (*)(id, SEL))objc_msgSend)(message, chatSelector);
    if (![chatName isKindOfClass:[NSString class]] || [chatName length] == 0) return nil;
    unsigned int localID = ((unsigned int (*)(id, SEL))objc_msgSend)(message, localIDSelector);
    return localID > 0 ? [NSString stringWithFormat:@"%@_%u", chatName, localID] : nil;
}

// Recursively walks the view tree collecting cells that share the message's
// identity, so a swipe translates all copies of the same message (e.g. an
// image cell and its hidden counterpart) together. Cells with no usable
// identity are skipped entirely.
static void WCCollectReplyTransformTargets(UIView *view,
                                           NSString *messageKey,
                                           NSMutableArray<WCReplyTransformSnapshot *> *snapshots) {
    if (!view || messageKey.length == 0) return;
    id message = WCMessageWrapForCell(view);
    NSString *candidateKey = WCMessageIdentityKeyForMessage(message);
    if (candidateKey.length > 0 && [candidateKey isEqualToString:messageKey]) {
        WCReplyTransformSnapshot *snapshot = [WCReplyTransformSnapshot new];
        snapshot.view = view;
        snapshot.transform = view.transform;
        [snapshots addObject:snapshot];
        return;
    }
    for (UIView *subview in view.subviews) WCCollectReplyTransformTargets(subview, messageKey, snapshots);
}

static NSArray<WCReplyTransformSnapshot *> *WCReplyTransformSnapshots(CommonMessageCellView *sourceCell) {
    NSString *messageKey = WCMessageIdentityKeyForMessage(WCMessageWrapForCell(sourceCell));
    NSMutableArray<WCReplyTransformSnapshot *> *snapshots = [NSMutableArray array];
    if (messageKey.length > 0 && sourceCell.window) {
        WCCollectReplyTransformTargets(sourceCell.window, messageKey, snapshots);
    }
    if (snapshots.count == 0 && sourceCell) {
        WCReplyTransformSnapshot *snapshot = [WCReplyTransformSnapshot new];
        snapshot.view = sourceCell;
        snapshot.transform = sourceCell.transform;
        [snapshots addObject:snapshot];
    }
    return snapshots;
}

static void WCApplyReplyTransform(NSArray<WCReplyTransformSnapshot *> *snapshots, CGFloat offset) {
    for (WCReplyTransformSnapshot *snapshot in snapshots) {
        UIView *view = snapshot.view;
        if (view.window) view.transform = CGAffineTransformTranslate(snapshot.transform, offset, 0.0);
    }
}

static void WCRestoreReplyTransforms(NSArray<WCReplyTransformSnapshot *> *snapshots) {
    for (WCReplyTransformSnapshot *snapshot in snapshots) {
        if (snapshot.view) snapshot.view.transform = snapshot.transform;
    }
}

#pragma mark - Pan gesture delegate

@interface WCReplyPanGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *cell;
@property (nonatomic, assign) CGFloat initialWindowX;
@end

@implementation WCReplyPanGestureDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if (!WCGestureEnabled(WCReplySwipeEnabledKey) ||
        !self.cell.window ||
        ![recognizer isKindOfClass:[UIPanGestureRecognizer class]]) return NO;
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)recognizer;
    CGPoint velocity = [pan velocityInView:self.cell];
    if (fabs(velocity.x) <= fabs(velocity.y)) return NO;
    if (WCMessageSwipeAction((CommonMessageCellView *)self.cell, velocity.x > 0.0) == WCReplySwipeActionNone) return NO;
    if (velocity.x > 0.0 && WCNavigationReturnGesturesForView(self.cell).count > 0) {
        CGFloat edgeWidth = MAX(50.0, self.cell.window.safeAreaInsets.left + 32.0);
        if (self.initialWindowX <= edgeWidth) return NO;
    }
    CGPoint location = [pan locationInView:self.cell];
    CGFloat width = CGRectGetWidth(self.cell.bounds);
    return location.x >= 24.0 && location.x <= MAX(24.0, width - 24.0);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    UIWindow *window = self.cell.window;
    self.initialWindowX = window ? [touch locationInView:window].x : CGFLOAT_MAX;
    if (!window || WCNavigationReturnGesturesForView(self.cell).count == 0) return YES;
    CGFloat edgeWidth = MAX(50.0, window.safeAreaInsets.left + 32.0);
    return self.initialWindowX > edgeWidth;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    return WCIsNavigationReturnGesture(otherGestureRecognizer, self.cell);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

@end

#pragma mark - Synchronize message gesture recognizers

static void WCSynchronizeReplyGesture(CommonMessageCellView *cell) {
    if (!cell) return;
    UIPanGestureRecognizer *panRecognizer = objc_getAssociatedObject(cell, &WCReplyPanRecognizerKey);
    UITapGestureRecognizer *doubleRecognizer = objc_getAssociatedObject(cell, &WCMessageDoubleTapRecognizerKey);
    UITapGestureRecognizer *tripleRecognizer = objc_getAssociatedObject(cell, &WCMessageTripleTapRecognizerKey);
    BOOL enabled = WCGestureEnabled(WCReplySwipeEnabledKey) && cell.window;
    WCReplySwipeAction leftSwipeAction = enabled ? WCMessageSwipeAction(cell, NO) : WCReplySwipeActionNone;
    WCReplySwipeAction rightSwipeAction = enabled ? WCMessageSwipeAction(cell, YES) : WCReplySwipeActionNone;
    BOOL hasSwipeAction = leftSwipeAction != WCReplySwipeActionNone || rightSwipeAction != WCReplySwipeActionNone;
    WCReplySwipeAction doubleAction = enabled
        ? WCMessageGestureAction(cell, WCMessageDoubleTapSelfActionKey, WCMessageDoubleTapOtherActionKey)
        : WCReplySwipeActionNone;
    WCReplySwipeAction tripleAction = enabled
        ? WCMessageGestureAction(cell, WCMessageTripleTapSelfActionKey, WCMessageTripleTapOtherActionKey)
        : WCReplySwipeActionNone;

    if (!hasSwipeAction) {
        if (panRecognizer) {
            NSArray *snapshots = objc_getAssociatedObject(cell, &WCReplyTransformSnapshotsKey);
            if (snapshots.count) WCRestoreReplyTransforms(snapshots);
            else {
                NSValue *originalTransform = objc_getAssociatedObject(cell, &WCReplyOriginalTransformKey);
                if (originalTransform) cell.transform = originalTransform.CGAffineTransformValue;
            }
            [cell removeGestureRecognizer:panRecognizer];
        }
        objc_setAssociatedObject(cell, &WCReplyPanRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyPanDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyOriginalTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyTransformSnapshotsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyFeedbackGeneratorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyFeedbackTriggeredKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyPanRightwardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        panRecognizer = nil;
    }
    if (!panRecognizer && hasSwipeAction) {
        WCReplyPanGestureDelegate *delegate = [WCReplyPanGestureDelegate new];
        delegate.cell = cell;
        panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:cell action:@selector(wc_handleReplyPan:)];
        panRecognizer.delegate = delegate;
        panRecognizer.maximumNumberOfTouches = 1;
        panRecognizer.cancelsTouchesInView = YES;
        panRecognizer.delaysTouchesBegan = NO;
        panRecognizer.delaysTouchesEnded = NO;
        [cell addGestureRecognizer:panRecognizer];
        for (UIGestureRecognizer *returnGesture in WCNavigationReturnGesturesForView(cell)) {
            if (returnGesture != panRecognizer) [panRecognizer requireGestureRecognizerToFail:returnGesture];
        }
        objc_setAssociatedObject(cell, &WCReplyPanRecognizerKey, panRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell, &WCReplyPanDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (doubleAction == WCReplySwipeActionNone && doubleRecognizer) {
        [cell removeGestureRecognizer:doubleRecognizer];
        objc_setAssociatedObject(cell, &WCMessageDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        doubleRecognizer = nil;
    }
    if (tripleAction == WCReplySwipeActionNone && tripleRecognizer) {
        [cell removeGestureRecognizer:tripleRecognizer];
        objc_setAssociatedObject(cell, &WCMessageTripleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tripleRecognizer = nil;
        if (doubleRecognizer) {
            [cell removeGestureRecognizer:doubleRecognizer];
            objc_setAssociatedObject(cell, &WCMessageDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            doubleRecognizer = nil;
        }
    }
    if (!doubleRecognizer && doubleAction != WCReplySwipeActionNone) {
        doubleRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wc_handleMessageTapAction:)];
        doubleRecognizer.numberOfTapsRequired = 2;
        doubleRecognizer.numberOfTouchesRequired = 1;
        doubleRecognizer.cancelsTouchesInView = YES;
        [cell addGestureRecognizer:doubleRecognizer];
        objc_setAssociatedObject(cell, &WCMessageDoubleTapRecognizerKey, doubleRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!tripleRecognizer && tripleAction != WCReplySwipeActionNone) {
        tripleRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wc_handleMessageTapAction:)];
        tripleRecognizer.numberOfTapsRequired = 3;
        tripleRecognizer.numberOfTouchesRequired = 1;
        tripleRecognizer.cancelsTouchesInView = YES;
        [cell addGestureRecognizer:tripleRecognizer];
        objc_setAssociatedObject(cell, &WCMessageTripleTapRecognizerKey, tripleRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (doubleRecognizer && tripleRecognizer) [doubleRecognizer requireGestureRecognizerToFail:tripleRecognizer];
}

#pragma mark - Repeat path (no send-confirmation)

static NSMutableSet *WCActiveQuickSendSessions(void) {
    static NSMutableSet *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

@interface WCMessageRepeatSession : NSObject
@property (nonatomic, strong) id forwardLogic;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, assign) BOOL finished;
- (void)finishSession;
@end

@implementation WCMessageRepeatSession

- (void)finishSession {
    if (self.finished) return;
    self.finished = YES;
    [WCActiveQuickSendSessions() removeObject:self];
    self.forwardLogic = nil;
    self.message = nil;
    self.contact = nil;
    self.presenter = nil;
}

- (UIViewController *)getCurrentViewController { return self.presenter; }
- (UIViewController *)GetCurrentViewController { return self.presenter; }
- (void)OnForwardMessageSend:(__unused id)logic { [self finishSession]; }
- (void)OnForwardMessageCancel:(__unused id)logic { [self finishSession]; }
- (void)OnForwardMessageConfirmCanceled:(id)logic { [self OnForwardMessageCancel:logic]; }
- (void)OnForwardDone { [self finishSession]; }

@end

static id WCMessageManager(void) {
    Class managerClass = objc_getClass("CMessageMgr");
    return WCServiceForClass(managerClass);
}

static NSString *WCSessionForMessage(id message) {
    SEL selector = NSSelectorFromString(@"GetChatName");
    if ([message respondsToSelector:selector]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(message, selector);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    }
    NSString *fromUser = WCTweakSafeValue(message, @"m_nsFromUsr");
    NSString *toUser = WCTweakSafeValue(message, @"m_nsToUsr");
    NSString *currentUser = WCCurrentUserWXID();
    if ([fromUser hasSuffix:@"@chatroom"]) return fromUser;
    if ([toUser hasSuffix:@"@chatroom"]) return toUser;
    if (currentUser.length > 0 && [fromUser isEqualToString:currentUser]) return toUser;
    return fromUser.length > 0 ? fromUser : toUser;
}

static id WCContactForUserName(NSString *userName) {
    return WCPrivateContact(userName);
}

// Voice repeat keeps a short native-forward upload window so WeChat's
// upload pipeline stays in forwarding mode for this resend only.
static NSTimeInterval WCVoiceRepeatForwardDeadline = 0;

static BOOL WCVoiceRepeatUploadIsActive(void) {
    return WCVoiceRepeatForwardDeadline > NSDate.date.timeIntervalSince1970;
}

static BOOL WCSendVoiceMessage(id source, NSString *sourcePathOverride, NSString *session) {
    if (!source || session.length == 0) return NO;

    id manager = WCMessageManager();
    SEL voicePathSelector = sel_registerName("getVoicePath");
    SEL destinationPathSelector = sel_registerName("getPathOfAudio:");
    SEL addLocalSelector = sel_registerName("AddLocalMsg:MsgWrap:");
    SEL saveVoiceSelector = sel_registerName("SaveMesVoice:MsgWrap:");
    SEL resendSelector = sel_registerName("ResendVoiceMsg:MsgWrap:");
    SEL uploaderSelector = sel_registerName("uploaderForMsgWrap:");
    Class messageWrapClass = objc_getClass("CMessageWrap");
    Class audioSenderClass = objc_getClass("AudioSender");
    id audioSender = audioSenderClass ? WCServiceForClass(audioSenderClass) : nil;
    if ((sourcePathOverride.length == 0 && ![source respondsToSelector:voicePathSelector]) ||
        !manager ||
        ![manager respondsToSelector:addLocalSelector] ||
        !messageWrapClass ||
        ![messageWrapClass respondsToSelector:destinationPathSelector] ||
        !audioSender) {
        WCLog(@"语音复读入口不完整，取消发送");
        return NO;
    }

    NSString *sourcePath = sourcePathOverride;
    if (sourcePath.length == 0) sourcePath = ((id (*)(id, SEL))objc_msgSend)(source, voicePathSelector);
    if (![sourcePath isKindOfClass:[NSString class]] || sourcePath.length == 0 ||
        ![[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
        WCLog(@"语音复读找不到本地语音文件");
        return NO;
    }

    id repeated = nil;
    @try {
        repeated = [source copy];
        if (!repeated) return NO;

        WCTweakSetValue(repeated, @"m_uiMesLocalID", @0);
        WCTweakSetValue(repeated, @"m_n64MesSvrID", @0);
        SEL resetLocalIDSelector = sel_registerName("resetLocalId");
        if ([repeated respondsToSelector:resetLocalIDSelector]) {
            ((void (*)(id, SEL))objc_msgSend)(repeated, resetLocalIDSelector);
        }

        NSString *currentUser = WCCurrentUserWXID() ?: @"";
        NSUInteger now = (NSUInteger)NSDate.date.timeIntervalSince1970;
        WCTweakSetValue(repeated, @"m_nsFromUsr", currentUser);
        WCTweakSetValue(repeated, @"m_nsRealChatUsr", currentUser);
        WCTweakSetValue(repeated, @"m_nsToUsr", session);
        WCTweakSetValue(repeated, @"m_uiCreateTime", @(now));
        WCTweakSetValue(repeated, @"m_uiSendTime", @(now));
        WCTweakSetValue(repeated, @"m_uiStatus", @1);
        WCTweakSetValue(repeated, @"m_uiVoiceForwardFlag", @1);
        id extendInfo = WCTweakSafeValue(repeated, @"m_extendInfoWithMsgType");
        WCTweakSetValue(extendInfo, @"m_uiVoiceForwardFlag", @1);

        ((void (*)(id, SEL, id, id))objc_msgSend)(manager, addLocalSelector, session, repeated);

        NSString *destinationPath = ((id (*)(id, SEL, id))objc_msgSend)(messageWrapClass,
                                                                        destinationPathSelector,
                                                                        repeated);
        if (![destinationPath isKindOfClass:[NSString class]] || destinationPath.length == 0) {
            WCLog(@"语音复读无法生成目标文件路径");
            return NO;
        }

        BOOL voiceSaved = [sourcePath isEqualToString:destinationPath];
        if (!voiceSaved) {
            NSString *destinationDirectory = destinationPath.stringByDeletingLastPathComponent;
            if (destinationDirectory.length > 0) {
                [[NSFileManager defaultManager] createDirectoryAtPath:destinationDirectory
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:nil];
            }
            [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
            NSError *copyError = nil;
            voiceSaved = [[NSFileManager defaultManager] copyItemAtPath:sourcePath
                                                                 toPath:destinationPath
                                                                  error:&copyError];
            if (!voiceSaved && [manager respondsToSelector:saveVoiceSelector]) {
                NSData *voiceData = [NSData dataWithContentsOfFile:sourcePath];
                if (voiceData.length > 0) {
                    voiceSaved = ((BOOL (*)(id, SEL, id, id))objc_msgSend)(manager,
                                                                           saveVoiceSelector,
                                                                           voiceData,
                                                                           repeated);
                }
            }
            NSDictionary *destinationAttributes = [[NSFileManager defaultManager]
                                                    attributesOfItemAtPath:destinationPath
                                                                      error:nil];
            unsigned long long destinationSize = [destinationAttributes[NSFileSize] unsignedLongLongValue];
            if (!voiceSaved || destinationSize == 0) {
                WCLog(@"语音复读保存语音失败：%@", copyError.localizedDescription ?: @"未知错误");
                return NO;
            }
        }

        id resendTarget = audioSender;
        if (![resendTarget respondsToSelector:resendSelector] &&
            [audioSender respondsToSelector:uploaderSelector]) {
            resendTarget = ((id (*)(id, SEL, id))objc_msgSend)(audioSender, uploaderSelector, repeated);
        }
        if (![resendTarget respondsToSelector:resendSelector]) {
            WCLog(@"语音复读找不到微信语音上传入口");
            return NO;
        }
        WCVoiceRepeatForwardDeadline = NSDate.date.timeIntervalSince1970 + 12.0;
        ((void (*)(id, SEL, id, id))objc_msgSend)(resendTarget, resendSelector, session, repeated);
        return YES;
    } @catch (NSException *exception) {
        WCLog(@"语音复读调用失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

static BOOL WCRepeatVoiceMessage(id source, NSString *session) {
    return WCSendVoiceMessage(source, nil, session);
}

static BOOL WCRepeatPlainTextMessageFallback(CommonMessageCellView *cell) {
    id source = WCMessageWrapForCell(cell);
    NSInteger messageType = [WCTweakSafeValue(source, @"m_uiMessageType") integerValue];
    NSString *content = WCTweakSafeValue(source, @"m_nsContent");
    NSString *session = WCSessionForMessage(source);
    if (messageType != 1 || content.length == 0 || session.length == 0) return NO;

    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initSelector = sel_registerName("initWithMsgType:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initSelector]) return NO;
    id repeated = ((id (*)(id, SEL, NSUInteger))objc_msgSend)([wrapClass alloc], initSelector, 1);
    if (!repeated) return NO;
    WCTweakSetValue(repeated, @"m_nsFromUsr", WCCurrentUserWXID() ?: @"");
    WCTweakSetValue(repeated, @"m_nsToUsr", session);
    WCTweakSetValue(repeated, @"m_nsContent", content);
    WCTweakSetValue(repeated, @"m_uiStatus", @1);
    WCTweakSetValue(repeated, @"m_uiCreateTime", @((NSUInteger)NSDate.date.timeIntervalSince1970));

    id manager = WCMessageManager();
    SEL sendSelector = sel_registerName("AddMsg:MsgWrap:");
    if (!manager || ![manager respondsToSelector:sendSelector]) return NO;
    ((void (*)(id, SEL, NSString *, id))objc_msgSend)(manager, sendSelector, session, repeated);
    return YES;
}

static BOOL WCRepeatMessage(CommonMessageCellView *cell) {
    id source = WCMessageWrapForCell(cell);
    NSString *chatName = WCSessionForMessage(source);
    NSInteger messageType = [WCTweakSafeValue(source, @"m_uiMessageType") integerValue];
    if (messageType == 34) return WCRepeatVoiceMessage(source, chatName);
    id contact = WCContactForUserName(chatName);
    Class forwardClass = objc_getClass("ForwardMessageLogicController");
    SEL forwardSelector = sel_registerName("forwardNoConfirmForMsgList:toContacts:");
    SEL delegateSelector = sel_registerName("setDelegate:");
    if (source && contact && forwardClass) {
        BOOL canForward = YES;
        Class utilityClass = objc_getClass("ForwardMsgUtil");
        SEL canForwardSelector = sel_registerName("canBeForwardWithMsg:");
        if ([utilityClass respondsToSelector:canForwardSelector]) {
            canForward = ((BOOL (*)(id, SEL, id))objc_msgSend)(utilityClass, canForwardSelector, source);
        }
        id logic = canForward ? [forwardClass new] : nil;
        if (logic && [logic respondsToSelector:forwardSelector] && [logic respondsToSelector:delegateSelector]) {
            WCMessageRepeatSession *repeatSession = [WCMessageRepeatSession new];
            repeatSession.forwardLogic = logic;
            repeatSession.message = source;
            repeatSession.contact = contact;
            repeatSession.presenter = WCVisibleChatController;
            ((void (*)(id, SEL, id))objc_msgSend)(logic, delegateSelector, repeatSession);
            [WCActiveQuickSendSessions() addObject:repeatSession];
            @try {
                ((void (*)(id, SEL, id, id))objc_msgSend)(logic, forwardSelector, @[source], @[contact]);
            } @catch (NSException *exception) {
                WCLog(@"复读调用微信转发引擎失败：%@", exception.reason ?: exception.name);
                [repeatSession finishSession];
                return WCRepeatPlainTextMessageFallback(cell);
            }
            __weak WCMessageRepeatSession *weakSession = repeatSession;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                WCMessageRepeatSession *activeSession = weakSession;
                if (activeSession && !activeSession.finished) [activeSession finishSession];
            });
            return YES;
        }
    }
    return WCRepeatPlainTextMessageFallback(cell);
}

#pragma mark - Perform gesture action

static BOOL WCInvokeFirstMessageCellAction(CommonMessageCellView *cell, NSArray<NSString *> *selectorNames) {
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![cell respondsToSelector:selector]) continue;
        @try {
            ((void (*)(id, SEL, id))objc_msgSend)(cell, selector, nil);
            return YES;
        } @catch (__unused NSException *exception) {
            continue;
        }
    }
    return NO;
}

static BOOL WCPerformMessageGestureAction(CommonMessageCellView *cell, WCReplySwipeAction action) {
    if (!cell.window || action == WCReplySwipeActionNone) return NO;
    BOOL performed = NO;
    switch (action) {
        case WCReplySwipeActionQuote:
            performed = WCInvokeFirstMessageCellAction(cell, @[@"onShowMsgReplyMenuItem:"]);
            break;
        case WCReplySwipeActionRevoke:
            if (!WCMessageCellIsSender(cell)) return NO;
            performed = WCInvokeFirstMessageCellAction(cell, @[@"onRevokeMsg:"]);
            break;
        case WCReplySwipeActionCopy:
            performed = WCInvokeFirstMessageCellAction(cell, @[@"onCopy:"]);
            if (!performed) {
                NSString *content = WCTweakSafeValue(WCMessageWrapForCell(cell), @"m_nsContent");
                if (content.length > 0) {
                    UIPasteboard.generalPasteboard.string = content;
                    performed = YES;
                }
            }
            break;
        case WCReplySwipeActionDelete:
            performed = WCInvokeFirstMessageCellAction(cell, @[@"onDelete:", @"onDeleteMessage:"]);
            break;
        case WCReplySwipeActionRepeat:
            performed = WCRepeatMessage(cell);
            break;
        case WCReplySwipeActionForward:
            performed = WCInvokeFirstMessageCellAction(cell, @[@"onForward:", @"doForward"]);
            break;
        case WCReplySwipeActionFavorite:
            performed = WCInvokeFirstMessageCellAction(cell, @[@"onFavorite:", @"doFavorite"]);
            break;
        case WCReplySwipeActionTranslate: {
            id message = WCMessageWrapForCell(cell);
            NSInteger messageType = [WCTweakSafeValue(message, @"m_uiMessageType") integerValue];
            Class voiceClass = NSClassFromString(@"VoiceMessageCellView");
            BOOL isVoice = messageType == 34 || (voiceClass && [cell isKindOfClass:voiceClass]);
            if (isVoice) {
                performed = WCInvokeFirstMessageCellAction(cell, @[@"onVoiceTrans:", @"onVoiceTrans"]);
            } else {
                performed = WCInvokeFirstMessageCellAction(cell, @[@"onTranslateMsg:", @"translateMsg"]);
            }
            break;
        }
        case WCReplySwipeActionSpeak:
            performed = WCInvokeFirstMessageCellAction(cell,
                @[@"onSpeakMsg", @"onTextTranslateSpeak:", @"onSpeakMsgFromTextTranslate:"]);
            break;
        case WCReplySwipeActionNone:
            break;
    }
    if (!performed) WCLog(@"消息手势动作不可用，action=%ld cell=%@", (long)action, NSStringFromClass(cell.class));
    return performed;
}

#pragma mark - Input box gestures (swipe + multi-tap)

static UITextView *WCInnerTextView(id growTextView) {
    id textView = WCTweakSafeValue(growTextView, @"textView");
    if (![textView isKindOfClass:[UITextView class]]) textView = WCTweakSafeValue(growTextView, @"_textView");
    return [textView isKindOfClass:[UITextView class]] ? textView : nil;
}

static NSString *WCInputText(MMGrowTextView *view) {
    NSString *text = WCTweakSafeValue(view, @"text");
    if (![text isKindOfClass:[NSString class]]) {
        UITextView *textView = WCInnerTextView(view);
        text = textView.text;
    }
    return text ?: @"";
}

static void WCReplaceInputText(MMGrowTextView *view, NSString *text) {
    if (!view) return;
    NSString *value = text ?: @"";
    WCTweakSetValue(view, @"text", value);
    UITextView *textView = WCInnerTextView(view);
    if (textView) {
        textView.text = value;
        textView.selectedRange = NSMakeRange(value.length, 0);
        SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
        if ([view respondsToSelector:changeSelector]) {
            ((void (*)(id, SEL, id))objc_msgSend)(view, changeSelector, textView);
        }
    }
}

static void WCApplyTranslation(MMGrowTextView *view, NSString *translated, NSString *errorMessage) {
    if (![translated isKindOfClass:[NSString class]] || translated.length == 0) {
        WCShowToast(errorMessage.length > 0 ? errorMessage : @"翻译失败");
        return;
    }
    WCReplaceInputText(view, translated);
    WCShowToast(@"已翻译");
}

// Uses the configurable translation engine (Edge / MyMemory / custom).
static void WCTranslateInputText(MMGrowTextView *view, BOOL toEnglish) {
    NSString *text = WCInputText(view);
    if (text.length == 0) { WCShowToast(@"输入框为空"); return; }
    WCGestureTranslateText(text, toEnglish, ^(NSString *translated, NSString *errorMessage) {
        WCApplyTranslation(view, translated, errorMessage);
    });
}

// Performs a configured input-gesture action on the grow-text-view.
static void WCPerformInputAction(MMGrowTextView *view, WCInputAction action) {
    if (action == WCInputActionNone) return;
    UITextView *textView = WCInnerTextView(view);
    if (action == WCInputActionClear) {
        WCTweakSetValue(view, @"text", @"");
        if (textView) {
            textView.text = @"";
            textView.selectedRange = NSMakeRange(0, 0);
            SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
            if ([view respondsToSelector:changeSelector]) {
                ((void (*)(id, SEL, id))objc_msgSend)(view, changeSelector, textView);
            }
        }
        return;
    }
    if (action == WCInputActionPaste) {
        if (textView) {
            [textView becomeFirstResponder];
            [textView paste:nil];
            return;
        }
        NSString *pasteText = UIPasteboard.generalPasteboard.string;
        if (pasteText.length == 0) return;
        NSString *currentText = WCTweakSafeValue(view, @"text");
        if (![currentText isKindOfClass:[NSString class]]) currentText = @"";
        WCTweakSetValue(view, @"text", [currentText stringByAppendingString:pasteText]);
        return;
    }
    if (action == WCInputActionCopy) {
        NSString *text = WCTweakSafeValue(view, @"text");
        if ([text length] > 0) UIPasteboard.generalPasteboard.string = text;
        return;
    }
    if (action == WCInputActionCut) {
        NSString *text = WCTweakSafeValue(view, @"text");
        if ([text length] > 0) {
            UIPasteboard.generalPasteboard.string = text;
            WCTweakSetValue(view, @"text", @"");
            if (textView) {
                textView.text = @"";
                textView.selectedRange = NSMakeRange(0, 0);
                SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
                if ([view respondsToSelector:changeSelector]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(view, changeSelector, textView);
                }
            }
        }
        return;
    }
    if (action == WCInputActionUppercase) {
        NSString *text = WCInputText(view);
        if (text.length) WCReplaceInputText(view, [text uppercaseString]);
        return;
    }
    if (action == WCInputActionLowercase) {
        NSString *text = WCInputText(view);
        if (text.length) WCReplaceInputText(view, [text lowercaseString]);
        return;
    }
    if (action == WCInputActionTrim) {
        NSString *text = WCInputText(view);
        NSString *trimmed = [[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                             componentsJoinedByString:@""];
        if (trimmed.length) WCReplaceInputText(view, trimmed);
        return;
    }
    if (action == WCInputActionTranslateToEnglish) { WCTranslateInputText(view, YES); return; }
    if (action == WCInputActionTranslateToChinese) { WCTranslateInputText(view, NO); return; }
}

static void WCSynchronizeInputGestures(MMGrowTextView *view) {
    if (!view) return;
    BOOL enabled = WCGestureEnabled(WCInputGestureEnabledKey) && view.window;
    // Swipe recognizers
    UISwipeGestureRecognizer *left = objc_getAssociatedObject(view, &WCInputSwipeLeftRecognizerKey);
    UISwipeGestureRecognizer *right = objc_getAssociatedObject(view, &WCInputSwipeRightRecognizerKey);
    BOOL swipeLeftOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeLeftActionKey] != WCInputActionNone;
    BOOL swipeRightOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeRightActionKey] != WCInputActionNone;
    if (swipeLeftOn && !left) {
        left = [[UISwipeGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputSwipeLeft:)];
        left.direction = UISwipeGestureRecognizerDirectionLeft;
        left.cancelsTouchesInView = NO;
        [view addGestureRecognizer:left];
        objc_setAssociatedObject(view, &WCInputSwipeLeftRecognizerKey, left, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!swipeLeftOn && left) {
        [view removeGestureRecognizer:left];
        objc_setAssociatedObject(view, &WCInputSwipeLeftRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (swipeRightOn && !right) {
        right = [[UISwipeGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputSwipeRight:)];
        right.direction = UISwipeGestureRecognizerDirectionRight;
        right.cancelsTouchesInView = NO;
        [view addGestureRecognizer:right];
        objc_setAssociatedObject(view, &WCInputSwipeRightRecognizerKey, right, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!swipeRightOn && right) {
        [view removeGestureRecognizer:right];
        objc_setAssociatedObject(view, &WCInputSwipeRightRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Multi-tap recognizers
    UITapGestureRecognizer *doubleTap = objc_getAssociatedObject(view, &WCInputDoubleTapRecognizerKey);
    UITapGestureRecognizer *tripleTap = objc_getAssociatedObject(view, &WCInputTripleTapRecognizerKey);
    BOOL doubleOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputDoubleTapActionKey] != WCInputActionNone;
    BOOL tripleOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputTripleTapActionKey] != WCInputActionNone;
    if (!doubleOn && doubleTap) {
        [view removeGestureRecognizer:doubleTap];
        objc_setAssociatedObject(view, &WCInputDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        doubleTap = nil;
    }
    if (!tripleOn && tripleTap) {
        [view removeGestureRecognizer:tripleTap];
        objc_setAssociatedObject(view, &WCInputTripleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tripleTap = nil;
        if (doubleTap) {
            [view removeGestureRecognizer:doubleTap];
            objc_setAssociatedObject(view, &WCInputDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            doubleTap = nil;
        }
    }
    if (!doubleTap && doubleOn) {
        doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputTapAction:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.numberOfTouchesRequired = 1;
        doubleTap.cancelsTouchesInView = YES;
        [view addGestureRecognizer:doubleTap];
        objc_setAssociatedObject(view, &WCInputDoubleTapRecognizerKey, doubleTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!tripleTap && tripleOn) {
        tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputTapAction:)];
        tripleTap.numberOfTapsRequired = 3;
        tripleTap.numberOfTouchesRequired = 1;
        tripleTap.cancelsTouchesInView = YES;
        [view addGestureRecognizer:tripleTap];
        objc_setAssociatedObject(view, &WCInputTripleTapRecognizerKey, tripleTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (doubleTap && tripleTap) [doubleTap requireGestureRecognizerToFail:tripleTap];
}

#pragma mark - Bulk resync on settings change

static void WCSynchronizeReplyGesturesInView(UIView *view) {
    if (!view) return;
    static Class cellViewClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cellViewClass = NSClassFromString(@"CommonMessageCellView"); });
    if (cellViewClass && [view isKindOfClass:cellViewClass]) {
        WCSynchronizeReplyGesture((CommonMessageCellView *)view);
    }
    for (UIView *subview in view.subviews) WCSynchronizeReplyGesturesInView(subview);
}

static void WCSynchronizeVisibleReplyGestures(void) {
    UIWindow *window = WCActiveWindow();
    if (window) WCSynchronizeReplyGesturesInView(window);
}

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
    if (!WCGestureEnabled(WCReplySwipeEnabledKey)) return;
    CGPoint translation = [recognizer translationInView:self];
    CGPoint velocity = [recognizer velocityInView:self];
    CGFloat triggerDistance = WCReplySwipeTriggerDistance();

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        BOOL rightward = velocity.x > 0.0;
        if (WCMessageSwipeAction(self, rightward) == WCReplySwipeActionNone) return;
        objc_setAssociatedObject(self, &WCReplyPanRightwardKey, @(rightward), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,
                                 &WCReplyOriginalTransformKey,
                                 [NSValue valueWithCGAffineTransform:self.transform],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self,
                                 &WCReplyTransformSnapshotsKey,
                                 WCReplyTransformSnapshots(self),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:WCMessageGestureHapticKey]) {
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:WCHapticStyleFromConfig()];
            [feedback prepare];
            objc_setAssociatedObject(self, &WCReplyFeedbackGeneratorKey, feedback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(self, &WCReplyFeedbackTriggeredKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSValue *originalTransformValue = objc_getAssociatedObject(self, &WCReplyOriginalTransformKey);
    CGAffineTransform originalTransform = originalTransformValue
        ? originalTransformValue.CGAffineTransformValue
        : CGAffineTransformIdentity;
    BOOL rightward = [objc_getAssociatedObject(self, &WCReplyPanRightwardKey) boolValue];
    NSArray<WCReplyTransformSnapshot *> *snapshots = objc_getAssociatedObject(self, &WCReplyTransformSnapshotsKey);

    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat distance = MAX(0.0, rightward ? translation.x : -translation.x);
        if (distance > triggerDistance) {
            distance = triggerDistance + MIN(10.0, (distance - triggerDistance) * 0.18);
        }
        CGFloat offset = rightward ? distance : -distance;
        if (snapshots.count) WCApplyReplyTransform(snapshots, offset);
        else self.transform = CGAffineTransformTranslate(originalTransform, offset, 0.0);
        if (distance >= triggerDistance &&
            ![objc_getAssociatedObject(self, &WCReplyFeedbackTriggeredKey) boolValue]) {
            UIImpactFeedbackGenerator *feedback = objc_getAssociatedObject(self, &WCReplyFeedbackGeneratorKey);
            [feedback impactOccurred];
            objc_setAssociatedObject(self, &WCReplyFeedbackTriggeredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    if (recognizer.state != UIGestureRecognizerStateEnded &&
        recognizer.state != UIGestureRecognizerStateCancelled &&
        recognizer.state != UIGestureRecognizerStateFailed) return;

    BOOL shouldTrigger = recognizer.state == UIGestureRecognizerStateEnded &&
                         fabs(translation.x) > fabs(translation.y) &&
                         (rightward
                              ? (translation.x >= triggerDistance || velocity.x >= 700.0)
                              : (translation.x <= -triggerDistance || velocity.x <= -700.0));
    __weak CommonMessageCellView *weakCell = self;
    if (shouldTrigger && self.window && WCGestureEnabled(WCReplySwipeEnabledKey)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CommonMessageCellView *cell = weakCell;
            if (!cell.window || !WCGestureEnabled(WCReplySwipeEnabledKey)) return;
            WCReplySwipeAction currentAction = WCMessageSwipeAction(cell, rightward);
            WCPerformMessageGestureAction(cell, currentAction);
        });
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         if (snapshots.count) WCRestoreReplyTransforms(snapshots);
                         else weakCell.transform = originalTransform;
                     }
                     completion:^(BOOL finished) {
                         (void)finished;
                         CommonMessageCellView *cell = weakCell;
                         if (!cell) return;
                         objc_setAssociatedObject(cell, &WCReplyOriginalTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         objc_setAssociatedObject(cell, &WCReplyTransformSnapshotsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         objc_setAssociatedObject(cell, &WCReplyFeedbackGeneratorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         objc_setAssociatedObject(cell, &WCReplyFeedbackTriggeredKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         objc_setAssociatedObject(cell, &WCReplyPanRightwardKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                     }];
}

%new
- (void)wc_handleMessageTapAction:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized ||
        !self.window ||
        !WCGestureEnabled(WCReplySwipeEnabledKey)) return;
    NSString *selfKey = recognizer.numberOfTapsRequired >= 3
        ? WCMessageTripleTapSelfActionKey
        : WCMessageDoubleTapSelfActionKey;
    NSString *otherKey = recognizer.numberOfTapsRequired >= 3
        ? WCMessageTripleTapOtherActionKey
        : WCMessageDoubleTapOtherActionKey;
    WCReplySwipeAction action = WCMessageGestureAction(self, selfKey, otherKey);
    WCPerformMessageGestureAction(self, action);
}

%end

%hook BaseMsgContentViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCVisibleChatController = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (WCVisibleChatController == self) WCVisibleChatController = nil;
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

#pragma mark - Keyboard enhancement (键盘增强)

// Finds the chat input's MMGrowTextView whose inner text view is first responder.
static MMGrowTextView *WCFirstResponderGrowTextView(void) {
    Class growClass = NSClassFromString(@"MMGrowTextView");
    if (!growClass) return nil;
    UIWindow *window = WCActiveWindow();
    if (!window) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithArray:window.subviews];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:growClass]) {
            UITextView *textView = WCInnerTextView(view);
            if (textView.isFirstResponder) return (MMGrowTextView *)view;
        }
        [stack addObjectsFromArray:view.subviews];
    }
    return nil;
}

static void WCKeyboardEnhancePerform(NSString *actionKey) {
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults] integerForKey:actionKey];
    if (action == WCInputActionNone) return;
    MMGrowTextView *view = WCFirstResponderGrowTextView();
    if (!view) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCInputGestureHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(view, action);
}

@interface WCKeyboardEnhanceController : NSObject
+ (instancetype)sharedController;
@end

@implementation WCKeyboardEnhanceController

+ (instancetype)sharedController {
    static WCKeyboardEnhanceController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ controller = [WCKeyboardEnhanceController new]; });
    return controller;
}

- (void)handleSwipeLeft:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) WCKeyboardEnhancePerform(WCKeyboardSwipeLeftActionKey);
}

- (void)handleSwipeRight:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) WCKeyboardEnhancePerform(WCKeyboardSwipeRightActionKey);
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) return;
    NSString *key = recognizer.numberOfTapsRequired >= 3 ? WCKeyboardTripleTapActionKey : WCKeyboardDoubleTapActionKey;
    WCKeyboardEnhancePerform(key);
}

@end

static UIWindow *WCKeyboardEnhanceWindow = nil;
static UIView *WCKeyboardEnhanceView = nil;

static void WCKeyboardEnhanceHide(void) {
    WCKeyboardEnhanceWindow.hidden = YES;
}

// The strip sits in the blank band at the bottom of the keyboard (between the
// globe and mic keys, above the home indicator), i.e. the keyboard's bottom
// safe-area. It is a transparent window above the keyboard window, so it only
// covers the empty band and never the keys.
static void WCKeyboardEnhanceUpdate(NSNotification *note) {
    if (!WCGestureEnabled(WCKeyboardEnhanceEnabledKey)) { WCKeyboardEnhanceHide(); return; }
    UIWindow *appWindow = WCActiveWindow();
    if (!appWindow) { WCKeyboardEnhanceHide(); return; }
    CGFloat safeBottom = appWindow.safeAreaInsets.bottom;
    if (safeBottom <= 0.0) { WCKeyboardEnhanceHide(); return; }

    CGRect keyboardFrame = CGRectZero;
    id frameValue = note.userInfo[UIKeyboardFrameEndUserInfoKey];
    if ([frameValue isKindOfClass:[NSValue class]]) keyboardFrame = [(NSValue *)frameValue CGRectValue];
    if (CGRectIsEmpty(keyboardFrame)) { WCKeyboardEnhanceHide(); return; }

    CGFloat screenHeight = appWindow.bounds.size.height;
    if (CGRectGetMinY(keyboardFrame) >= screenHeight - 1.0) { WCKeyboardEnhanceHide(); return; }

    CGRect strip = CGRectMake(0, CGRectGetMaxY(keyboardFrame) - safeBottom,
                              appWindow.bounds.size.width, safeBottom);
    if (CGRectIsEmpty(strip)) { WCKeyboardEnhanceHide(); return; }

    if (!WCKeyboardEnhanceWindow) {
        CGFloat level = UIWindowLevelAlert;
        id allWindows = WCTweakSafeValue(UIApplication.sharedApplication, @"windows");
        if ([allWindows isKindOfClass:[NSArray class]]) {
            for (UIWindow *window in (NSArray *)allWindows) {
                if ([NSStringFromClass(window.class) containsString:@"Keyboard"]) level = MAX(level, window.windowLevel);
            }
        }
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = appWindow.windowScene;
            if (scene) window = [[UIWindow alloc] initWithWindowScene:scene];
        }
        if (!window) window = [[UIWindow alloc] initWithFrame:strip];
        window.windowLevel = level + 1.0;
        window.backgroundColor = UIColor.clearColor;
        window.hidden = YES;

        UIViewController *root = [UIViewController new];
        UIView *view = [[UIView alloc] initWithFrame:strip];
        view.backgroundColor = UIColor.clearColor;
        root.view = view;
        window.rootViewController = root;

        WCKeyboardEnhanceController *controller = [WCKeyboardEnhanceController sharedController];
        UISwipeGestureRecognizer *left = [[UISwipeGestureRecognizer alloc] initWithTarget:controller action:@selector(handleSwipeLeft:)];
        left.direction = UISwipeGestureRecognizerDirectionLeft;
        left.cancelsTouchesInView = NO;
        [view addGestureRecognizer:left];
        UISwipeGestureRecognizer *right = [[UISwipeGestureRecognizer alloc] initWithTarget:controller action:@selector(handleSwipeRight:)];
        right.direction = UISwipeGestureRecognizerDirectionRight;
        right.cancelsTouchesInView = NO;
        [view addGestureRecognizer:right];
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(handleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.cancelsTouchesInView = NO;
        [view addGestureRecognizer:doubleTap];
        UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(handleTap:)];
        tripleTap.numberOfTapsRequired = 3;
        tripleTap.cancelsTouchesInView = NO;
        [view addGestureRecognizer:tripleTap];
        [doubleTap requireGestureRecognizerToFail:tripleTap];

        WCKeyboardEnhanceWindow = window;
        WCKeyboardEnhanceView = view;
    }
    WCKeyboardEnhanceWindow.frame = strip;
    WCKeyboardEnhanceView.frame = WCKeyboardEnhanceWindow.rootViewController.view.bounds;
    WCKeyboardEnhanceWindow.hidden = NO;
}

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

#pragma mark - Global multi-finger long-press gestures

@interface CameraScanViewController : UIViewController
@end

static UIImpactFeedbackStyle WCHapticStyleFromConfig(void) {
    switch ((WCHapticStyle)[[NSUserDefaults standardUserDefaults] integerForKey:WCGestureHapticStyleKey]) {
        case WCHapticStyleLight: return UIImpactFeedbackStyleLight;
        case WCHapticStyleHeavy: return UIImpactFeedbackStyleHeavy;
        case WCHapticStyleSoft: return UIImpactFeedbackStyleSoft;
        case WCHapticStyleRigid: return UIImpactFeedbackStyleRigid;
        case WCHapticStyleMedium: default: return UIImpactFeedbackStyleMedium;
    }
}

static void WCPlayConfiguredHaptic(void) {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:WCHapticStyleFromConfig()];
    [feedback prepare];
    [feedback impactOccurred];
}

static char WCGlobalTwoFingerRecognizerKey;
static char WCGlobalThreeFingerRecognizerKey;

// Lightweight auto-dismissing toast (no buttons, no dimming).
static void WCShowToast(NSString *text) {
    if (text.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = WCActiveWindow();
        if (!window) return;
        UIView *toast = [[UIView alloc] init];
        toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.82];
        toast.layer.cornerRadius = 12.0;
        toast.userInteractionEnabled = NO;
        toast.alpha = 0.0;
        toast.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *label = [[UILabel alloc] init];
        label.text = text;
        label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [toast addSubview:label];
        [window addSubview:toast];

        [NSLayoutConstraint activateConstraints:@[
            [label.topAnchor constraintEqualToAnchor:toast.topAnchor constant:10.0],
            [label.bottomAnchor constraintEqualToAnchor:toast.bottomAnchor constant:-10.0],
            [label.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:16.0],
            [label.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-16.0],
            [toast.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
            [toast.centerYAnchor constraintEqualToAnchor:window.centerYAnchor],
            [toast.widthAnchor constraintLessThanOrEqualToAnchor:window.widthAnchor constant:-64.0],
        ]];

        [UIView animateWithDuration:0.18 animations:^{
            toast.alpha = 1.0;
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.25 delay:1.5 options:0 animations:^{
                toast.alpha = 0.0;
            } completion:^(__unused BOOL done) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

@interface WCScreenshotSaver : NSObject
@end

@implementation WCScreenshotSaver
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    (void)image; (void)contextInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            WCShowToast(@"保存失败，请允许微信访问相册");
        } else {
            WCShowToast(@"已保存到相册");
        }
    });
}
@end

static WCScreenshotSaver *WCScreenshotSaverInstance = nil;

// Capture the key window with several fallbacks, then save via the system
// photo API (which prompts for permission).
static UIImage *WCCaptureScreen(void) {
    UIWindow *window = WCActiveWindow();
    if (!window) return nil;
    CGSize size = window.bounds.size;
    if (size.width < 1.0 || size.height < 1.0) return nil;
    __block BOOL ok = NO;
    UIGraphicsImageRenderer *r1 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *img = [r1 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        (void)ctx;
        ok = [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    }];
    if (ok && img) return img;
    ok = NO;
    UIGraphicsImageRenderer *r2 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    img = [r2 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        (void)ctx;
        ok = [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }];
    if (ok && img) return img;
    UIView *snapshot = [window snapshotViewAfterScreenUpdates:YES];
    if (snapshot) {
        UIGraphicsImageRenderer *r3 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
        img = [r3 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            [snapshot.layer renderInContext:ctx.CGContext];
        }];
        if (img) return img;
    }
    UIGraphicsImageRenderer *r4 = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [r4 imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [window.layer renderInContext:ctx.CGContext];
    }];
}

// 截图当前 keyWindow
static void WCPerformGlobalScreenshot(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = WCCaptureScreen();
        if (!image) {
            WCShowToast(@"截图失败");
            return;
        }
        if (!WCScreenshotSaverInstance) WCScreenshotSaverInstance = [WCScreenshotSaver new];
        UIImageWriteToSavedPhotosAlbum(image, WCScreenshotSaverInstance,
            @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    });
}

// 返回上一页
static void WCPerformGlobalBack(void) {
    UIViewController *top = WCRootTopController();
    UINavigationController *nav = [top isKindOfClass:[UINavigationController class]]
        ? (UINavigationController *)top : top.navigationController;
    if (nav && nav.viewControllers.count > 1) {
        [nav popViewControllerAnimated:YES];
    } else if (top.presentingViewController) {
        [top dismissViewControllerAnimated:YES completion:nil];
    } else if (nav) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

// 回到首页
static void WCPerformGlobalLockScreen(void) {
    UIViewController *top = WCRootTopController();
    UINavigationController *nav = [top isKindOfClass:[UINavigationController class]]
        ? (UINavigationController *)top : top.navigationController;
    if (nav) [nav popToRootViewControllerAnimated:YES];
    [top dismissViewControllerAnimated:YES completion:nil];
}

// 扫一扫:创建 CameraScanViewController 并 push
static void WCPerformGlobalScanQR(void) {
    Class scanClass = NSClassFromString(@"CameraScanViewController");
    if (!scanClass) { WCShowToast(@"扫一扫：当前微信版本不支持"); return; }
    id scanVC = [[scanClass alloc] init];
    if (!scanVC) { WCShowToast(@"扫一扫：初始化失败"); return; }
    WCPushGlobal(scanVC);
}

#pragma mark - Custom page

static void WCOpenMoments(void) {
    Class cls = NSClassFromString(@"WCTimeLineViewController");
    if (!cls) { [WCPopup showMessage:@"朋友圈" message:@"当前微信版本不支持"]; return; }
    @try { WCPushGlobal([[cls alloc] init]); } @catch (__unused NSException *e) {}
}

static void WCOpenAddFriend(void) {
    NSArray<NSString *> *candidates = @[@"AddFriendEntryViewController", @"FTSAddFriendViewController",
                                        @"NewFriendsViewController"];
    for (NSString *name in candidates) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        @try { WCPushGlobal([[cls alloc] init]); return; } @catch (__unused NSException *e) {}
    }
    WCShowToast(@"添加朋友：当前微信版本不支持");
}

static void WCOpenMyQRCode(void) {
    Class cls = NSClassFromString(@"CameraQRCodeListViewController");
    if (!cls) { WCShowToast(@"我的二维码：当前微信版本不支持"); return; }
    @try { WCPushGlobal([[cls alloc] init]); } @catch (__unused NSException *e) {}
}

static void WCOpenPayCode(void) {
    Class cls = NSClassFromString(@"KindaViewController");
    if (!cls) { WCShowToast(@"付款码：当前微信版本不支持"); return; }
    @try { WCPushGlobal([[cls alloc] init]); } @catch (__unused NSException *e) {}
}

static void WCPushCustomPageEntry(NSDictionary *entry) {
    NSString *className = [entry[@"class"] isKindOfClass:[NSString class]] ? entry[@"class"] : nil;
    Class cls = className.length > 0 ? NSClassFromString(className) : nil;
    if (!cls) { WCShowToast(@"自定义页面：类名无效"); return; }
    @try { WCPushGlobal([[cls alloc] init]); } @catch (__unused NSException *e) {}
}

static void WCOpenCustomPage(void) {
    NSArray<NSDictionary *> *pages = [[NSUserDefaults standardUserDefaults] arrayForKey:WCCustomPagesKey];
    if (![pages isKindOfClass:[NSArray class]] || pages.count == 0) {
        WCShowToast(@"未设置自定义页面");
        return;
    }
    if (pages.count == 1) { WCPushCustomPageEntry(pages.firstObject); return; }
    NSMutableArray<WCPopupOption *> *opts = [NSMutableArray array];
    for (NSUInteger i = 0; i < pages.count; i++) {
        NSDictionary *entry = pages[i];
        NSString *name = [entry[@"name"] isKindOfClass:[NSString class]] ? entry[@"name"] : nil;
        if (name.length == 0) name = entry[@"class"];
        if (name.length == 0) name = @"自定义页面";
        [opts addObject:[WCPopupOption optionWithTitle:name value:@(i)]];
    }
    [WCPopup showOptionsWithTitle:@"自定义页面" message:nil options:opts selected:nil
        completion:^(id value) {
        if (!value) return;
        NSUInteger idx = [value unsignedIntegerValue];
        if (idx < pages.count) WCPushCustomPageEntry(pages[idx]);
    }];
}

static void WCPerformGlobalAction(UIViewController *presenter, WCGlobalAction action);

// 弹快捷菜单
static void WCPerformGlobalMenu(UIViewController *presenter) {
    (void)presenter;
    NSMutableArray<WCPopupOption *> *opts = [NSMutableArray array];
    [opts addObject:[WCPopupOption optionWithTitle:@"扫一扫" value:@(WCGlobalActionScanQR)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"朋友圈" value:@(WCGlobalActionMoments)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"添加朋友" value:@(WCGlobalActionAddFriend)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"我的二维码" value:@(WCGlobalActionMyQRCode)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"付款码" value:@(WCGlobalActionPayCode)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"自定义页面" value:@(WCGlobalActionCustomPage)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"截图" value:@(WCGlobalActionScreenshot)]];
    [opts addObject:[WCPopupOption optionWithTitle:@"回到首页" value:@(WCGlobalActionLockScreen)]];
    [WCPopup showOptionsWithTitle:@"快捷操作" message:nil options:opts selected:nil
        completion:^(id value) {
        if (!value) return;
        WCPerformGlobalAction(nil, (WCGlobalAction)[value integerValue]);
    }];
}

// 跳转指定 view 页面(占位:打开 WCGesture 设置页)
static void WCPerformGlobalJump(UIViewController *presenter) {
    WCGesturePresentSettings(presenter);
}

static void WCPerformGlobalAction(UIViewController *presenter, WCGlobalAction action) {
    switch (action) {
        case WCGlobalActionScreenshot: WCPerformGlobalScreenshot(); break;
        case WCGlobalActionBack: WCPerformGlobalBack(); break;
        case WCGlobalActionLockScreen: WCPerformGlobalLockScreen(); break;
        case WCGlobalActionScanQR: WCPerformGlobalScanQR(); break;
        case WCGlobalActionMoments: WCOpenMoments(); break;
        case WCGlobalActionAddFriend: WCOpenAddFriend(); break;
        case WCGlobalActionMyQRCode: WCOpenMyQRCode(); break;
        case WCGlobalActionPayCode: WCOpenPayCode(); break;
        case WCGlobalActionCustomPage: WCOpenCustomPage(); break;
        case WCGlobalActionMenu: WCPerformGlobalMenu(presenter); break;
        case WCGlobalActionJump: WCPerformGlobalJump(presenter); break;
        case WCGlobalActionNone: break;
    }
}

// 在指定 window 上按当前设置同步全局手势识别器
static void WCSynchronizeGlobalGesturesOnWindow(UIWindow *window) {
    if (!window) return;
    BOOL enabled = WCGestureEnabled(WCGlobalGestureEnabledKey);
    NSInteger twoAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    NSInteger threeAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];

    UILongPressGestureRecognizer *two = objc_getAssociatedObject(window, &WCGlobalTwoFingerRecognizerKey);
    BOOL twoWanted = enabled && twoAction != WCGlobalActionNone;
    if (twoWanted && !two) {
        two = [[UILongPressGestureRecognizer alloc] initWithTarget:window action:@selector(wc_handleGlobalLongPress:)];
        two.numberOfTouchesRequired = 2;
        two.minimumPressDuration = 0.5;
        two.cancelsTouchesInView = NO;
        [window addGestureRecognizer:two];
        objc_setAssociatedObject(window, &WCGlobalTwoFingerRecognizerKey, two, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!twoWanted && two) {
        [window removeGestureRecognizer:two];
        objc_setAssociatedObject(window, &WCGlobalTwoFingerRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UILongPressGestureRecognizer *three = objc_getAssociatedObject(window, &WCGlobalThreeFingerRecognizerKey);
    BOOL threeWanted = enabled && threeAction != WCGlobalActionNone;
    if (threeWanted && !three) {
        three = [[UILongPressGestureRecognizer alloc] initWithTarget:window action:@selector(wc_handleGlobalLongPress:)];
        three.numberOfTouchesRequired = 3;
        three.minimumPressDuration = 0.5;
        three.cancelsTouchesInView = NO;
        [window addGestureRecognizer:three];
        objc_setAssociatedObject(window, &WCGlobalThreeFingerRecognizerKey, three, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!threeWanted && three) {
        [window removeGestureRecognizer:three];
        objc_setAssociatedObject(window, &WCGlobalThreeFingerRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void WCSynchronizeGlobalGestures(void) {
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        WCSynchronizeGlobalGesturesOnWindow(window);
    }
}

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
        %init;

        [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillChangeFrameNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            WCKeyboardEnhanceUpdate(note);
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
                WCKeyboardEnhanceHide();
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
