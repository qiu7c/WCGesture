#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#import "Sources/API/WCGestureInternal.h"

// Defined in the AI helper block below; the gesture action switch calls it.
static void WCAIReplyToMessage(CommonMessageCellView *cell);

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

#pragma mark - Visible chat controller cache (for repeat forwarding)

static __weak BaseMsgContentViewController *WCVisibleChatControllerStorage;

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

id WCGestureMessageWrapForCell(UIView *cell) {
    return WCMessageWrapForCell(cell);
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

#pragma mark - Navigation return gesture detection

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

void WCSynchronizeReplyGesture(CommonMessageCellView *cell) {
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

BOOL WCVoiceRepeatUploadIsActive(void) {
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

BOOL WCGestureResendVoiceMessage(id message, NSString *session) {
    return WCSendVoiceMessage(message, nil, session);
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

static BOOL WCRepeatMessageNow(CommonMessageCellView *cell) {
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
            repeatSession.presenter = WCVisibleChatControllerStorage;
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

static BOOL WCRepeatMessage(CommonMessageCellView *cell) {
    __weak CommonMessageCellView *weakCell = cell;
    if (WCGestureSendConfirmationRepeatIfNeeded(cell, WCSessionForMessage(WCMessageWrapForCell(cell)), ^{
        CommonMessageCellView *source = weakCell;
        if (source && !WCRepeatMessageNow(source)) WCShowToast(@"这条消息暂时无法复读");
    })) return YES;
    return WCRepeatMessageNow(cell);
}

BOOL WCGestureRepeatMessage(CommonMessageCellView *cell) { return WCRepeatMessage(cell); }

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

// Whether the voice cell currently shows its transcription result. The result
// view stays in the hierarchy hidden/transparent, so only an actually visible
// (or still loading) view counts; the cached message result does not.
static BOOL WCVoiceTranscriptionVisible(CommonMessageCellView *cell) {
    if ([WCTweakSafeValue(cell, @"m_isTranslating") boolValue]) return YES;
    for (NSString *key in @[@"m_translateView", @"m_textTranslateView", @"m_translatingView"]) {
        UIView *view = WCTweakSafeValue(cell, key);
        if ([view isKindOfClass:[UIView class]] && !view.hidden && view.alpha > 0.01) return YES;
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
                // Already transcribed (or transcribing): the gesture cancels it,
                // which is what WeChat's own "取消转文字" menu item does.
                if (WCVoiceTranscriptionVisible(cell)) {
                    performed = WCInvokeFirstMessageCellAction(cell,
                        @[@"onVoiceTransClose:", @"onVoiceTransStop:", @"onVoiceTrans:"]);
                } else {
                    performed = WCInvokeFirstMessageCellAction(cell, @[@"onVoiceTrans:", @"onVoiceTrans"]);
                }
            } else {
                performed = WCInvokeFirstMessageCellAction(cell, @[@"onTranslateMsg:", @"translateMsg"]);
            }
            break;
        }
        case WCReplySwipeActionSpeak:
            performed = WCInvokeFirstMessageCellAction(cell,
                @[@"onSpeakMsg", @"onTextTranslateSpeak:", @"onSpeakMsgFromTextTranslate:"]);
            break;
        case WCReplySwipeActionAIReply:
            // Async: the reply lands in the input box when the model answers.
            WCAIReplyToMessage(cell);
            performed = YES;
            break;
        case WCReplySwipeActionNone:
            break;
    }
    if (!performed) WCLog(@"消息手势动作不可用，action=%ld cell=%@", (long)action, NSStringFromClass(cell.class));
    return performed;
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

void WCSynchronizeVisibleReplyGestures(void) {
    UIWindow *window = WCActiveWindow();
    if (window) WCSynchronizeReplyGesturesInView(window);
}

static MMGrowTextView *WCGrowTextViewInHierarchy(UIView *root) {
    Class growClass = NSClassFromString(@"MMGrowTextView");
    if (!growClass || !root) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:growClass]) return (MMGrowTextView *)view;
        [stack addObjectsFromArray:view.subviews];
    }
    return nil;
}

// The chat input may not be first responder when a message gesture fires, so
// fall back to the visible chat controller and then the whole window.
static MMGrowTextView *WCChatInputView(void) {
    MMGrowTextView *view = WCFirstResponderGrowTextView();
    if (view) return view;
    if (WCVisibleChatControllerStorage) {
        view = WCGrowTextViewInHierarchy(WCVisibleChatControllerStorage.view);
        if (view) return view;
    }
    return WCGrowTextViewInHierarchy(WCActiveWindow());
}

// Text the model should react to. Media and app messages carry XML, so only a
// plain text body (or a shared link's <title>) is usable.
static NSString *WCMessageTextForAI(id message) {
    NSString *content = WCTweakSafeValue(message, @"m_nsContent");
    if (![content isKindOfClass:[NSString class]] || content.length == 0) return nil;
    if ([content hasPrefix:@"<"]) {
        NSRange start = [content rangeOfString:@"<title>"];
        NSRange end = [content rangeOfString:@"</title>"];
        if (start.location != NSNotFound && end.location != NSNotFound
            && end.location > NSMaxRange(start)) {
            NSString *title = [content substringWithRange:
                NSMakeRange(NSMaxRange(start), end.location - NSMaxRange(start))];
            return title.length > 0 ? title : nil;
        }
        return nil;
    }
    return content;
}

static void WCAIReplyToMessage(CommonMessageCellView *cell) {
    if (!cell) return;
    if (!WCGestureAIIsEnabled()) { WCShowToast(@"AI 未开启"); return; }
    if (!WCGestureAIIsConfigured()) { WCShowToast(@"请先在插件设置中配置 AI"); return; }
    NSString *content = WCMessageTextForAI(WCMessageWrapForCell(cell));
    if (content.length == 0) { WCShowToast(@"这条消息不支持 AI 回复"); return; }
    MMGrowTextView *input = WCChatInputView();
    if (!input) { WCShowToast(@"找不到聊天输入框"); return; }
    WCShowToast(@"AI 回复生成中…");
    WCGestureAIPerform(WCGestureAITaskReply, content, ^(NSString *reply, NSString *errorMessage) {
        if (reply.length == 0) {
            WCShowToast(errorMessage.length > 0 ? errorMessage : @"AI 回复失败");
            return;
        }
        WCReplaceInputText(input, reply);
        UITextView *textView = WCInnerTextView(input);
        if (textView && !textView.isFirstResponder) [textView becomeFirstResponder];
        WCShowToast(@"AI 回复已填入输入框");
    });
}


#pragma mark - Visible chat controller (set from the chat hook)

BaseMsgContentViewController *WCVisibleChatControllerGet(void) {
    return WCVisibleChatControllerStorage;
}

void WCSetVisibleChatController(BaseMsgContentViewController *controller) {
    WCVisibleChatControllerStorage = controller;
    if (controller) WCGestureSendConfirmationTrackChat(controller);
}

#pragma mark - Gesture handlers (called from the Logos hooks)

void WCReplyPanHandle(CommonMessageCellView *cell, UIPanGestureRecognizer *recognizer) {
    if (!WCGestureEnabled(WCReplySwipeEnabledKey)) return;
    CGPoint translation = [recognizer translationInView:cell];
    CGPoint velocity = [recognizer velocityInView:cell];
    CGFloat triggerDistance = WCReplySwipeTriggerDistance();

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        BOOL rightward = velocity.x > 0.0;
        if (WCMessageSwipeAction(cell, rightward) == WCReplySwipeActionNone) return;
        objc_setAssociatedObject(cell, &WCReplyPanRightwardKey, @(rightward), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell,
                                 &WCReplyOriginalTransformKey,
                                 [NSValue valueWithCGAffineTransform:cell.transform],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell,
                                 &WCReplyTransformSnapshotsKey,
                                 WCReplyTransformSnapshots(cell),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:WCMessageGestureHapticKey]) {
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:WCHapticStyleFromConfig()];
            [feedback prepare];
            objc_setAssociatedObject(cell, &WCReplyFeedbackGeneratorKey, feedback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(cell, &WCReplyFeedbackTriggeredKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSValue *originalTransformValue = objc_getAssociatedObject(cell, &WCReplyOriginalTransformKey);
    CGAffineTransform originalTransform = originalTransformValue
        ? originalTransformValue.CGAffineTransformValue
        : CGAffineTransformIdentity;
    BOOL rightward = [objc_getAssociatedObject(cell, &WCReplyPanRightwardKey) boolValue];
    NSArray<WCReplyTransformSnapshot *> *snapshots = objc_getAssociatedObject(cell, &WCReplyTransformSnapshotsKey);

    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat distance = MAX(0.0, rightward ? translation.x : -translation.x);
        if (distance > triggerDistance) {
            distance = triggerDistance + MIN(10.0, (distance - triggerDistance) * 0.18);
        }
        CGFloat offset = rightward ? distance : -distance;
        if (snapshots.count) WCApplyReplyTransform(snapshots, offset);
        else cell.transform = CGAffineTransformTranslate(originalTransform, offset, 0.0);
        if (distance >= triggerDistance &&
            ![objc_getAssociatedObject(cell, &WCReplyFeedbackTriggeredKey) boolValue]) {
            UIImpactFeedbackGenerator *feedback = objc_getAssociatedObject(cell, &WCReplyFeedbackGeneratorKey);
            [feedback impactOccurred];
            objc_setAssociatedObject(cell, &WCReplyFeedbackTriggeredKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    __weak CommonMessageCellView *weakCell = cell;
    if (shouldTrigger && cell.window && WCGestureEnabled(WCReplySwipeEnabledKey)) {
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

void WCMessageTapHandle(CommonMessageCellView *cell, UITapGestureRecognizer *recognizer) {
    if (recognizer.state != UIGestureRecognizerStateRecognized ||
        !cell.window ||
        !WCGestureEnabled(WCReplySwipeEnabledKey)) return;
    NSString *selfKey = recognizer.numberOfTapsRequired >= 3
        ? WCMessageTripleTapSelfActionKey
        : WCMessageDoubleTapSelfActionKey;
    NSString *otherKey = recognizer.numberOfTapsRequired >= 3
        ? WCMessageTripleTapOtherActionKey
        : WCMessageDoubleTapOtherActionKey;
    WCReplySwipeAction action = WCMessageGestureAction(cell, selfKey, otherKey);
    WCPerformMessageGestureAction(cell, action);
}

