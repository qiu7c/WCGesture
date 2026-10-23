#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Photos/Photos.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#import "Sources/WCGestureConfig.h"
#import "Sources/WCGestureAccount.h"
#import "Sources/WCGesturePrivateAPI.h"
#import "Sources/WCGestureSettingsVC.h"

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
    if (action < WCReplySwipeActionNone || action > WCReplySwipeActionRepeat) return WCReplySwipeActionNone;
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
// connected scenes the same way WCAtlas does, with a windows fallback.
static UIWindow *WCActiveWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        NSArray<UIWindow *> *windows = ((UIWindowScene *)scene).windows;
        for (UIWindow *window in windows) {
            NSString *className = NSStringFromClass(window.class);
            if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal &&
                ![className containsString:@"iConsole"]) return window;
        }
        for (UIWindow *window in windows) {
            NSString *className = NSStringFromClass(window.class);
            if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal &&
                ![className containsString:@"iConsole"]) return window;
        }
    }
    id windows = WCTweakSafeValue(UIApplication.sharedApplication, @"windows");
    if ([windows isKindOfClass:[NSArray class]]) {
        for (UIWindow *window in windows) {
            if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal &&
                ![NSStringFromClass(window.class) containsString:@"iConsole"]) return window;
        }
    }
    return nil;
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
        ((void (*)(id, SEL, id))objc_msgSend)(cell, selector, nil);
        return YES;
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
    }
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
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        objc_setAssociatedObject(self, &WCReplyFeedbackGeneratorKey, feedback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    WCPerformInputAction(self, action);
}

%new
- (void)wc_handleInputSwipeRight:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        !WCGestureEnabled(WCInputGestureEnabledKey)) return;
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeRightActionKey];
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
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback prepare];
        [feedback impactOccurred];
    }
}

%end

#pragma mark - Global multi-finger long-press gestures

@interface CameraScanViewController : UIViewController
@end

static char WCGlobalTwoFingerRecognizerKey;
static char WCGlobalThreeFingerRecognizerKey;

// 截图当前 keyWindow
static void WCPerformGlobalScreenshot(void) {
    UIWindow *window = WCActiveWindow();
    if (!window) return;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = window.screen.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:window.bounds.size format:format];
    UIImage *image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    }];
    if (!image) return;
    NSData *data = UIImagePNGRepresentation(image);
    if (!data) return;
    UIImage *saved = [UIImage imageWithData:data];
    // 存入相册
    if (saved) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:saved];
        } completionHandler:^(BOOL success, __unused NSError *error) {
            if (!success) WCLog(@"截图保存相册失败");
        }];
    }
}

// 返回上一页
static void WCPerformGlobalBack(void) {
    UIViewController *vc = WCViewControllerForResponder(WCActiveWindow());
    UINavigationController *nav = vc.navigationController;
    if (nav && nav.viewControllers.count > 1) {
        [nav popViewControllerAnimated:YES];
    } else if (vc.presentingViewController) {
        [vc dismissViewControllerAnimated:YES completion:nil];
    } else {
        // 首页:弹到根
        if (nav) [nav popToRootViewControllerAnimated:YES];
    }
}

// 锁屏:调微信内部的锁屏入口(通过私有 API 模拟电源键不可行,iOS 不允许)
// 改为调出微信的设置页或关闭微信。这里用一个占位实现:回到首页。
static void WCPerformGlobalLockScreen(void) {
    Class mainFrameClass = NSClassFromString(@"NewMainFrameViewController");
    UIWindow *window = WCActiveWindow();
    if (!mainFrameClass || !window) return;
    UIViewController *root = window.rootViewController;
    if ([root isKindOfClass:mainFrameClass]) return;
    UINavigationController *nav = root.navigationController ?: (root.presentedViewController.navigationController);
    if (nav) [nav popToRootViewControllerAnimated:YES];
    [root dismissViewControllerAnimated:YES completion:nil];
}

// 扫一扫:创建 CameraScanViewController 并 push
static void WCPerformGlobalScanQR(void) {
    Class scanClass = NSClassFromString(@"CameraScanViewController");
    if (!scanClass) return;
    UIViewController *vc = WCViewControllerForResponder(WCActiveWindow());
    UINavigationController *nav = vc.navigationController;
    id scanVC = [[scanClass alloc] init];
    if (!scanVC) return;
    if (nav) {
        [nav pushViewController:scanVC animated:YES];
    } else {
        [vc presentViewController:scanVC animated:YES completion:nil];
    }
}

// 弹快捷菜单
static void WCPerformGlobalMenu(UIViewController *presenter) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"快捷操作"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"截图" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        WCPerformGlobalScreenshot();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"返回上一页" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        WCPerformGlobalBack();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"扫一扫" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        WCPerformGlobalScanQR();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"回到首页" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        WCPerformGlobalLockScreen();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
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
        case WCGlobalActionMenu: WCPerformGlobalMenu(presenter); break;
        case WCGlobalActionJump: WCPerformGlobalJump(presenter); break;
        case WCGlobalActionNone: break;
    }
}

// 绑定到每个 window 的手势
%hook UIWindow

- (void)didMoveToWindow {
    %orig;
    // 在 key window 上挂全局手势识别器
    if (!WCGestureEnabled(WCGlobalGestureEnabledKey)) return;
    UILongPressGestureRecognizer *two = objc_getAssociatedObject(self, &WCGlobalTwoFingerRecognizerKey);
    NSInteger twoAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    if (twoAction != WCGlobalActionNone && !two) {
        two = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(wc_handleGlobalLongPress:)];
        two.numberOfTouchesRequired = 2;
        two.minimumPressDuration = 0.5;
        two.cancelsTouchesInView = NO;
        [self addGestureRecognizer:two];
        objc_setAssociatedObject(self, &WCGlobalTwoFingerRecognizerKey, two, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UILongPressGestureRecognizer *three = objc_getAssociatedObject(self, &WCGlobalThreeFingerRecognizerKey);
    NSInteger threeAction = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];
    if (threeAction != WCGlobalActionNone && !three) {
        three = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(wc_handleGlobalLongPress:)];
        three.numberOfTouchesRequired = 3;
        three.minimumPressDuration = 0.5;
        three.cancelsTouchesInView = NO;
        [self addGestureRecognizer:three];
        objc_setAssociatedObject(self, &WCGlobalThreeFingerRecognizerKey, three, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)wc_handleGlobalLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan ||
        !WCGestureEnabled(WCGlobalGestureEnabledKey)) return;
    UIViewController *presenter = WCViewControllerForResponder(self);
    if (!presenter) presenter = WCViewControllerForResponder(self.rootViewController);
    NSInteger action;
    if (recognizer.numberOfTouchesRequired == 2) {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalTwoFingerActionKey];
    } else {
        action = [[NSUserDefaults standardUserDefaults] integerForKey:WCGlobalThreeFingerActionKey];
    }
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback prepare];
    [feedback impactOccurred];
    WCPerformGlobalAction(presenter, (WCGlobalAction)action);
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

        [[NSNotificationCenter defaultCenter] addObserverForName:WCGestureDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            // Resync on the next runloop so the cell re-reads the new value.
            dispatch_async(dispatch_get_main_queue(), ^{
                WCSynchronizeVisibleReplyGestures();
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
