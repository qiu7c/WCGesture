#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCGestureSendConfirmationCoordinator : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIViewController *> *pendingAlerts;
@property (nonatomic, strong) NSMutableArray *pendingPresentations;
@property (nonatomic, strong) NSMutableSet<NSString *> *deferredPresentationTokens;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *temporaryAllowances;
@property (nonatomic, copy) NSString *temporaryAllowanceAccount;
@property (nonatomic) NSUInteger epoch;
+ (instancetype)sharedCoordinator;
- (BOOL)presentFrom:(UIViewController *)presenter
           username:(NSString *)username
            summary:(NSString *)summary
          validator:(WCGestureSendConfirmationValidator)validator
          confirmed:(dispatch_block_t)confirmedAction;
@end

@interface WCGestureSendConfirmationAlertController : UIViewController
@property (nonatomic, copy) dispatch_block_t cancelHandler;
@property (nonatomic, copy) dispatch_block_t confirmHandler;
@property (nonatomic, copy) dispatch_block_t pauseHandler;
- (instancetype)initWithUsername:(NSString *)username displayName:(NSString *)displayName summary:(NSString *)summary;
@end

static NSString *WCSendTrimmed(NSString *value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static UIViewController *WCSendPresentedControllerInTree(UIViewController *controller) {
    if (!controller) return nil;
    UIViewController *presented = controller.presentedViewController;
    if (presented) return presented;
    if ([controller isKindOfClass:UINavigationController.class]) {
        return WCSendPresentedControllerInTree(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return WCSendPresentedControllerInTree(((UITabBarController *)controller).selectedViewController);
    }
    return nil;
}

static BOOL WCSendHasAnimatedTransitionInTree(UIViewController *controller) {
    if (!controller) return NO;
    id<UIViewControllerTransitionCoordinator> transition = controller.transitionCoordinator;
    if (transition && transition.isAnimated) return YES;
    if ([controller isKindOfClass:UINavigationController.class]) {
        return WCSendHasAnimatedTransitionInTree(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return WCSendHasAnimatedTransitionInTree(((UITabBarController *)controller).selectedViewController);
    }
    return NO;
}

static NSString *WCSendAccountKey(void) {
    if (!WCRefreshCachedCurrentUser()) return nil;
    NSString *account = WCSendTrimmed(WCCurrentUserWXID());
    return account.length > 0 ? account : nil;
}

static NSInteger WCSendPauseSeconds(void) {
    NSInteger seconds = [NSUserDefaults.standardUserDefaults integerForKey:WCSendPauseSecondsKey];
    return seconds > 0 ? MIN(3600, MAX(5, seconds)) : 60;
}

static NSString *WCSendPauseDurationText(void) {
    NSInteger seconds = WCSendPauseSeconds();
    return seconds % 60 == 0 ?
        [NSString stringWithFormat:@"%ld 分钟", (long)(seconds / 60)] :
        [NSString stringWithFormat:@"%ld 秒", (long)seconds];
}

static NSString *WCSendPauseTitle(void) {
    return [NSString stringWithFormat:@"发送并暂停确认 %@", WCSendPauseDurationText()];
}

static NSDictionary<NSString *, NSArray<NSString *> *> *WCSendStoredMap(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:WCGestureSendConfirmationUsersKey];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

NSArray<NSString *> *WCGestureSendConfirmationProtectedConversations(void) {
    NSString *account = WCSendAccountKey();
    if (account.length == 0) return @[];
    id value = WCSendStoredMap()[account];
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableOrderedSet<NSString *> *users = [NSMutableOrderedSet orderedSet];
    for (id candidate in (NSArray *)value) {
        NSString *username = WCSendTrimmed(candidate);
        if (username.length > 0) [users addObject:username];
    }
    return users.array;
}

BOOL WCGestureSendConfirmationIsProtectedConversation(NSString *username) {
    if (!WCGestureEnabled(WCGestureSendConfirmationEnabledKey)) return NO;
    NSString *normalized = WCSendTrimmed(username);
    return normalized.length > 0 && [WCGestureSendConfirmationProtectedConversations() containsObject:normalized];
}

void WCGestureSendConfirmationSetProtected(NSString *username, BOOL protectedConversation) {
    if (![username isKindOfClass:NSString.class]) return;
    WCGestureSendConfirmationSetProtectedConversations(@[username], protectedConversation);
}

NSUInteger WCGestureSendConfirmationSetProtectedConversations(NSArray<NSString *> *usernames,
                                                              BOOL protectedConversation) {
    NSString *account = WCSendAccountKey();
    if (account.length == 0 || ![usernames isKindOfClass:NSArray.class]) return 0;
    NSMutableOrderedSet<NSString *> *normalizedUserNames = [NSMutableOrderedSet orderedSet];
    for (id candidate in usernames) {
        NSString *normalized = WCSendTrimmed(candidate);
        if (normalized.length > 0) [normalizedUserNames addObject:normalized];
    }
    if (normalizedUserNames.count == 0) return 0;
    NSMutableDictionary *map = [WCSendStoredMap() mutableCopy];
    NSMutableOrderedSet<NSString *> *users = [NSMutableOrderedSet orderedSetWithArray:WCGestureSendConfirmationProtectedConversations()];
    if (protectedConversation) [users addObjectsFromArray:normalizedUserNames.array];
    else [users removeObjectsInArray:normalizedUserNames.array];
    map[account] = users.array;
    [NSUserDefaults.standardUserDefaults setObject:map forKey:WCGestureSendConfirmationUsersKey];
    if (protectedConversation) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:WCGestureSendConfirmationEnabledKey];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:WCGestureDidChangeNotification
                                                       object:WCGestureSendConfirmationUsersKey];
    return normalizedUserNames.count;
}

@implementation WCGestureSendConfirmationAlertController {
    NSString *_username;
    NSString *_displayName;
    NSString *_summary;
}

- (instancetype)initWithUsername:(NSString *)username displayName:(NSString *)displayName summary:(NSString *)summary {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _username = [username copy];
        _displayName = [displayName copy];
        _summary = [summary copy];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (UIView *)avatarView {
    UIView *nativeAvatar = WCGestureContactUncroppedAvatarView(_username);
    if (nativeAvatar) return nativeAvatar;
    UIImageView *fallback = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    fallback.tintColor = UIColor.tertiaryLabelColor;
    fallback.contentMode = UIViewContentModeScaleAspectFit;
    return fallback;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38];
    UIControl *backdrop = [UIControl new];
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    [backdrop addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backdrop];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemBackgroundColor;
    card.layer.cornerRadius = 22.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview:card];

    UIView *avatar = [self avatarView];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 28.0;
    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = [NSString stringWithFormat:@"发送给 %@？", _displayName];
    title.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightRegular];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 2;
    UILabel *summary = [UILabel new];
    summary.translatesAutoresizingMaskIntoConstraints = NO;
    summary.text = _summary;
    summary.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    summary.textColor = UIColor.secondaryLabelColor;
    summary.textAlignment = NSTextAlignmentCenter;
    summary.numberOfLines = 4;
    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeSystem];
    confirm.translatesAutoresizingMaskIntoConstraints = NO;
    [confirm setTitle:@"仅发送本条" forState:UIControlStateNormal];
    confirm.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [confirm setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    confirm.backgroundColor = UIColor.systemBlueColor;
    confirm.layer.cornerRadius = 12.0;
    [confirm addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];
    UIButton *pause = [UIButton buttonWithType:UIButtonTypeSystem];
    pause.translatesAutoresizingMaskIntoConstraints = NO;
    [pause setTitle:WCSendPauseTitle() forState:UIControlStateNormal];
    pause.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    pause.titleLabel.adjustsFontSizeToFitWidth = YES;
    pause.titleLabel.minimumScaleFactor = 0.75;
    pause.backgroundColor = UIColor.secondarySystemFillColor;
    pause.layer.cornerRadius = 12.0;
    [pause addTarget:self action:@selector(pauseTapped) forControlEvents:UIControlEventTouchUpInside];
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.translatesAutoresizingMaskIntoConstraints = NO;
    [cancel setTitle:@"取消" forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    cancel.backgroundColor = UIColor.tertiarySystemFillColor;
    cancel.layer.cornerRadius = 12.0;
    [cancel addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[confirm, pause, cancel]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 10.0;
    buttons.distribution = UIStackViewDistributionFillEqually;
    [card addSubview:avatar];
    [card addSubview:title];
    [card addSubview:summary];
    [card addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
        [backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-28.0],
        [card.widthAnchor constraintEqualToConstant:MIN(UIScreen.mainScreen.bounds.size.width * 0.80, 360.0)],
        [avatar.topAnchor constraintEqualToAnchor:card.topAnchor constant:24.0],
        [avatar.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [avatar.widthAnchor constraintEqualToConstant:56.0],
        [avatar.heightAnchor constraintEqualToConstant:56.0],
        [title.topAnchor constraintEqualToAnchor:avatar.bottomAnchor constant:13.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],
        [summary.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8.0],
        [summary.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [summary.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [buttons.topAnchor constraintEqualToAnchor:summary.bottomAnchor constant:22.0],
        [buttons.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [buttons.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [buttons.heightAnchor constraintEqualToConstant:164.0],
        [buttons.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0],
    ]];
}

- (void)cancelTapped {
    dispatch_block_t handler = self.cancelHandler;
    [self dismissViewControllerAnimated:YES completion:handler];
}

- (void)confirmTapped {
    dispatch_block_t handler = self.confirmHandler;
    [self dismissViewControllerAnimated:YES completion:handler];
}

- (void)pauseTapped {
    dispatch_block_t handler = self.pauseHandler;
    [self dismissViewControllerAnimated:YES completion:handler];
}

@end

NSString *WCGestureSendConfirmationDisplayName(NSString *username) {
    NSString *normalized = WCSendTrimmed(username);
    if (normalized.length == 0) return @"未知会话";
    id contact = WCPrivateContact(normalized);
    NSString *name = WCGesturePrivateContactDisplayName(contact, normalized);
    return name.length > 0 ? name : normalized;
}

static void WCSendToast(__unused UIViewController *presenter, NSString *text) {
    WCShowToast(text);
}

@implementation WCGestureSendConfirmationCoordinator

+ (instancetype)sharedCoordinator {
    static WCGestureSendConfirmationCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ coordinator = [WCGestureSendConfirmationCoordinator new]; });
    return coordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pendingAlerts = [NSMutableDictionary dictionary];
        _pendingPresentations = [NSMutableArray array];
        _deferredPresentationTokens = [NSMutableSet set];
        _temporaryAllowances = [NSMutableDictionary dictionary];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationDidEnterBackground)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    }
    return self;
}

- (void)applicationDidEnterBackground {
    [self cancelAll];
}

- (void)cancelAll {
    self.epoch++;
    NSArray<UIViewController *> *alerts = self.pendingAlerts.allValues;
    [self.pendingAlerts removeAllObjects];
    [self.pendingPresentations removeAllObjects];
    [self.deferredPresentationTokens removeAllObjects];
    [self.temporaryAllowances removeAllObjects];
    for (UIViewController *alert in alerts) {
        if (alert.presentingViewController) [alert dismissViewControllerAnimated:NO completion:nil];
    }
}

- (NSString *)temporaryAllowanceKeyForUsername:(NSString *)username {
    NSString *account = WCSendAccountKey();
    if (![self.temporaryAllowanceAccount isEqualToString:account]) {
        [self.temporaryAllowances removeAllObjects];
        self.temporaryAllowanceAccount = account;
    }
    return account.length > 0 && username.length > 0 ?
        [NSString stringWithFormat:@"%@\n%@", account, username] : nil;
}

- (BOOL)isTemporarilyAllowedUsername:(NSString *)username {
    NSString *key = [self temporaryAllowanceKeyForUsername:username];
    NSDate *deadline = key ? self.temporaryAllowances[key] : nil;
    if (!deadline) return NO;
    if ([deadline timeIntervalSinceNow] > 0.0) return YES;
    [self.temporaryAllowances removeObjectForKey:key];
    return NO;
}

- (void)allowUsernameTemporarily:(NSString *)username {
    NSString *key = [self temporaryAllowanceKeyForUsername:username];
    if (key) self.temporaryAllowances[key] = [NSDate dateWithTimeIntervalSinceNow:WCSendPauseSeconds()];
}

- (void)presentNextIfNeeded {
    if (self.pendingAlerts.count > 0 || self.pendingPresentations.count == 0) return;
    dispatch_block_t next = self.pendingPresentations.firstObject;
    [self.pendingPresentations removeObjectAtIndex:0];
    NSUInteger epoch = self.epoch;
    dispatch_async(dispatch_get_main_queue(), ^{ if (epoch == self.epoch) next(); });
}

- (BOOL)isPresentationHostReady:(UIViewController *)presenter {
    if (!presenter.view.window || presenter.isBeingDismissed || presenter.isMovingFromParentViewController) return NO;
    if (WCSendPresentedControllerInTree(presenter)) return NO;
    return !WCSendHasAnimatedTransitionInTree(presenter);
}

- (void)retryDeferredPresentationWithToken:(NSString *)token
                                  presenter:(UIViewController *)presenter
                                   username:(NSString *)username
                                    summary:(NSString *)summary
                                  validator:(WCGestureSendConfirmationValidator)validator
                                  confirmed:(dispatch_block_t)confirmedAction
                                   deadline:(NSDate *)deadline {
    if (![self.deferredPresentationTokens containsObject:token]) return;
    if ((validator && !validator()) || !presenter.view.window) {
        [self.deferredPresentationTokens removeObject:token];
        return;
    }
    if ([self isPresentationHostReady:presenter]) {
        [self.deferredPresentationTokens removeObject:token];
        BOOL presented = [self presentFrom:presenter
                                  username:username
                                   summary:summary
                                 validator:validator
                                 confirmed:confirmedAction];
        if (!presented) WCSendToast(presenter, @"确认窗口未能显示，本次发送已取消");
        return;
    }
    if ([deadline timeIntervalSinceNow] <= 0.0) {
        [self.deferredPresentationTokens removeObject:token];
        WCSendToast(presenter, @"等待媒体选择界面关闭超时，本次发送已取消");
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf retryDeferredPresentationWithToken:token
                                            presenter:presenter
                                             username:username
                                              summary:summary
                                            validator:validator
                                            confirmed:confirmedAction
                                             deadline:deadline];
    });
}

- (BOOL)deferPresentationFrom:(UIViewController *)presenter
                      username:(NSString *)username
                       summary:(NSString *)summary
                     validator:(WCGestureSendConfirmationValidator)validator
                     confirmed:(dispatch_block_t)confirmedAction {
    NSString *token = NSUUID.UUID.UUIDString;
    [self.deferredPresentationTokens addObject:token];
    [self retryDeferredPresentationWithToken:token
                                   presenter:presenter
                                    username:[username copy]
                                     summary:[summary copy]
                                   validator:[validator copy]
                                   confirmed:[confirmedAction copy]
                                    deadline:[NSDate dateWithTimeIntervalSinceNow:15.0]];
    return YES;
}

- (BOOL)presentFrom:(UIViewController *)presenter
           username:(NSString *)username
            summary:(NSString *)summary
          validator:(WCGestureSendConfirmationValidator)validator
          confirmed:(dispatch_block_t)confirmedAction {
    if (!presenter.view.window || !WCGestureSendConfirmationIsProtectedConversation(username)) return NO;
    if ([self isTemporarilyAllowedUsername:username]) {
        if (!validator || validator()) {
            if (confirmedAction) confirmedAction();
        }
        return YES;
    }
    if (self.pendingPresentations.count >= 32 || self.deferredPresentationTokens.count >= 32) {
        WCShowToast(@"待确认消息过多，本次发送已取消"); return YES;
    }
    if (self.pendingAlerts.count > 0) {
        UIViewController *queuedPresenter = presenter;
        while ([queuedPresenter isKindOfClass:WCGestureSendConfirmationAlertController.class] &&
               queuedPresenter.presentingViewController) {
            queuedPresenter = queuedPresenter.presentingViewController;
        }
        NSString *retainedUsername = [username copy];
        NSString *retainedSummary = [summary copy];
        WCGestureSendConfirmationValidator retainedValidator = [validator copy];
        dispatch_block_t retainedAction = [confirmedAction copy];
        __weak typeof(self) weakSelf = self;
        [self.pendingPresentations addObject:^{
            WCGestureSendConfirmationCoordinator *strongSelf = weakSelf;
            if (!strongSelf || !queuedPresenter.view.window ||
                (retainedValidator && !retainedValidator())) {
                [strongSelf presentNextIfNeeded];
                return;
            }
            BOOL presented = [strongSelf presentFrom:queuedPresenter
                                            username:retainedUsername
                                             summary:retainedSummary
                                           validator:retainedValidator
                                           confirmed:retainedAction];
            if (!presented) [strongSelf presentNextIfNeeded];
        }];
        return YES;
    }
    if (![self isPresentationHostReady:presenter]) {
        return [self deferPresentationFrom:presenter
                                  username:username
                                   summary:summary
                                 validator:validator
                                 confirmed:confirmedAction];
    }
    NSString *token = NSUUID.UUID.UUIDString;
    NSString *displayName = WCGestureSendConfirmationDisplayName(username);
    NSString *message = WCSendTrimmed(summary);
    if (message.length == 0) message = @"请确认消息内容和接收人。";
    WCGestureSendConfirmationAlertController *alert = [[WCGestureSendConfirmationAlertController alloc] initWithUsername:username
                                                                                                     displayName:displayName
                                                                                                         summary:message];
    __weak typeof(self) weakSelf = self;
    alert.cancelHandler = ^{
        WCGestureSendConfirmationCoordinator *strongSelf = weakSelf;
        [strongSelf.pendingAlerts removeObjectForKey:token];
        [strongSelf presentNextIfNeeded];
    };
    alert.confirmHandler = ^{
        WCGestureSendConfirmationCoordinator *strongSelf = weakSelf;
        if (!strongSelf.pendingAlerts[token]) return;
        [strongSelf.pendingAlerts removeObjectForKey:token];
        BOOL valid = !validator || validator();
        if (valid && confirmedAction) confirmedAction();
        [strongSelf presentNextIfNeeded];
    };
    alert.pauseHandler = ^{
        WCGestureSendConfirmationCoordinator *strongSelf = weakSelf;
        if (!strongSelf.pendingAlerts[token]) return;
        [strongSelf.pendingAlerts removeObjectForKey:token];
        BOOL valid = !validator || validator();
        if (valid) {
            [strongSelf allowUsernameTemporarily:username];
            if (confirmedAction) confirmedAction();
            WCSendToast(presenter,
                                            [NSString stringWithFormat:@"本会话发送确认已暂停 %@",
                                             WCSendPauseDurationText()]);
        }
        [strongSelf presentNextIfNeeded];
    };
    self.pendingAlerts[token] = alert;
    [presenter presentViewController:alert animated:YES completion:nil];
    __weak WCGestureSendConfirmationAlertController *weakAlert = alert;
    __weak typeof(self) weakCoordinator = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WCGestureSendConfirmationCoordinator *strongCoordinator = weakCoordinator;
        WCGestureSendConfirmationAlertController *strongAlert = weakAlert;
        if (!strongCoordinator.pendingAlerts[token] || strongAlert.presentingViewController || strongAlert.view.window) return;
        [strongCoordinator.pendingAlerts removeObjectForKey:token];
        WCSendToast(presenter, @"确认窗口未能显示，本次发送已取消");
        [strongCoordinator presentNextIfNeeded];
    });
    return YES;
}

@end

BOOL WCGesturePresentSendConfirmationIfNeeded(UIViewController *presenter,
                                           NSString *username,
                                           NSString *summary,
                                           WCGestureSendConfirmationValidator validator,
                                           dispatch_block_t confirmedAction) {
    if (!presenter || username.length == 0 || !confirmedAction) return NO;
    NSString *account = WCSendAccountKey();
    WCGestureSendConfirmationValidator originalValidator = [validator copy];
    validator = ^BOOL{
        return UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
            [account isEqualToString:WCSendAccountKey()] &&
            WCGestureSendConfirmationIsProtectedConversation(username) &&
            (!originalValidator || originalValidator());
    };
    return [[WCGestureSendConfirmationCoordinator sharedCoordinator] presentFrom:presenter
                                                                    username:username
                                                                     summary:summary
                                                                   validator:validator
                                                                   confirmed:confirmedAction];
}

void WCGestureCancelPendingSendConfirmations(void) {
    [[WCGestureSendConfirmationCoordinator sharedCoordinator] cancelAll];
}

// A synchronous authorization scope prevents re-prompting deeper in the same
// native send. No time-based bypass can authorize an unrelated later message.
static NSString *const WCSendScopeKey = @"com.qiu7c.onewx.send-confirmation.scope";
static __weak UIViewController *WCSendChat;
static NSUInteger WCSendGeneration;
static NSString *WCSendChatName(UIViewController *controller) {
    id name = WCTweakSafeValue(controller, @"getCurrentChatName");
    return [name isKindOfClass:NSString.class] ? name : nil;
}
static BOOL WCSendChatMatches(UIViewController *controller, NSString *target) {
    if (!controller || controller.isMovingFromParentViewController || controller.isBeingDismissed) return NO;
    if (controller.navigationController && controller.navigationController.topViewController != controller) return NO;
    UITabBarController *tab = controller.tabBarController;
    if (tab && tab.selectedViewController != controller && tab.selectedViewController != controller.navigationController) return NO;
    return controller.isViewLoaded && controller.view.window && [WCSendChatName(controller) isEqualToString:target];
}
void WCGestureSendConfirmationTrackChat(UIViewController *controller) {
    if (WCSendChat && WCSendChat != controller) WCGestureCancelPendingSendConfirmations();
    WCSendChat = controller;
}
void WCGestureSendConfirmationChatLeaving(UIViewController *controller) {
    if (WCSendChat == controller && (controller.isMovingFromParentViewController || controller.isBeingDismissed)) {
        WCSendChat = nil;
        WCGestureCancelPendingSendConfirmations();
    }
}
void WCGestureSendConfirmationSettingsChanged(NSString *key) {
    if (key && ![@[WCGestureSendConfirmationEnabledKey, WCGestureSendConfirmationUsersKey,
        WCSendPauseSecondsKey, WCGestureSendConfirmationProfileSwitchEnabledKey] containsObject:key]) return;
    WCSendGeneration++;
    WCGestureCancelPendingSendConfirmations();
    WCGestureSendConfirmationRefreshProfiles();
}
BOOL WCGestureSendConfirmationHold(NSString *username, NSString *summary,
    WCGestureSendConfirmationValidator validator, dispatch_block_t action) {
    if (!NSThread.isMainThread || UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
        !action || ![username isKindOfClass:NSString.class] || !username.length) return NO;
    if ([NSThread.currentThread.threadDictionary[WCSendScopeKey] isEqualToString:username]) return NO;
    if (!WCGestureSendConfirmationIsProtectedConversation(username)) return NO;
    username = [username copy];
    UIViewController *source = WCSendChat;
    if (!WCSendChatMatches(source, username)) return NO;
    UIViewController *presenter = source.tabBarController ?: source.navigationController ?: source;
    NSUInteger generation = WCSendGeneration;
    __weak UIViewController *weakSource = source;
    BOOL held = WCGesturePresentSendConfirmationIfNeeded(presenter, username, summary, ^BOOL{
        return generation == WCSendGeneration && WCSendChatMatches(weakSource, username) && (!validator || validator());
    }, ^{
        NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
        id previous = thread[WCSendScopeKey];
        thread[WCSendScopeKey] = username;
        @try { action(); }
        @finally {
            if (previous) thread[WCSendScopeKey] = previous;
            else [thread removeObjectForKey:WCSendScopeKey];
        }
    });
    if (!held) WCShowToast(@"确认窗口不可用，本次发送已取消");
    return YES;
}
BOOL WCGestureSendConfirmationIsAppEmoticon(id wrap) {
    if ([WCTweakSafeValue(wrap, @"m_uiMessageType") integerValue] != 49) return NO;
    id md5 = WCTweakSafeValue(wrap, @"m_nsEmoticonMD5");
    if ([md5 isKindOfClass:NSString.class] && [md5 length]) return YES;
    id text = WCTweakSafeValue(wrap, @"m_nsContent");
    return [text isKindOfClass:NSString.class] &&
        ([text rangeOfString:@"<emoticonmd5>" options:NSCaseInsensitiveSearch].location != NSNotFound ||
         [text rangeOfString:@"<emoji" options:NSCaseInsensitiveSearch].location != NSNotFound);
}
NSString *WCGestureSendConfirmationMessageSummary(id wrap) {
    NSInteger type = [WCTweakSafeValue(wrap, @"m_uiMessageType") integerValue];
    if (type == 3) return @"图片：1 张";
    if (type == 34) return @"语音：1 条";
    if (type == 43 || type == 62) return @"视频：1 个";
    if (type == 47 || WCGestureSendConfirmationIsAppEmoticon(wrap)) return @"表情：1 个";
    if (type != 1) return @"复读当前消息";
    id raw = WCTweakSafeValue(wrap, @"m_nsContent");
    NSString *text = [raw isKindOfClass:NSString.class] ? raw : @"";
    if (text.length > 80) text = [[text substringWithRange:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 80)]] stringByAppendingString:@"…"];
    return text.length ? [@"文字：" stringByAppendingString:text] : @"文字消息";
}
BOOL WCGestureSendConfirmationRepeatIfNeeded(UIView *cell, NSString *target, dispatch_block_t action) {
    id message = WCGestureMessageWrapForCell(cell);
    __weak UIView *weakCell = cell;
    return WCGestureSendConfirmationHold(target, WCGestureSendConfirmationMessageSummary(message), ^BOOL{
        UIView *current = weakCell;
        return current.window && WCGestureMessageWrapForCell(current) == message;
    }, action);
}

BOOL WCGestureSendConfirmationHoldMessage(NSString *username, id wrap, dispatch_block_t action) {
    NSArray *keys = @[@"m_nsContent", @"m_nsFromUsr", @"m_nsToUsr", @"m_uiMessageType", @"m_nsEmoticonMD5"];
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        id value = WCTweakSafeValue(wrap, key);
        if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) snapshot[key] = [value copy];
        else snapshot[key] = NSNull.null;
    }
    NSString *target = [username copy];
    return WCGestureSendConfirmationHold(target, WCGestureSendConfirmationMessageSummary(wrap), ^BOOL{
        if (![username isEqualToString:target]) return NO;
        for (NSString *key in keys) {
            id value = WCTweakSafeValue(wrap, key) ?: NSNull.null;
            if (![value isEqual:snapshot[key]]) return NO;
        }
        return YES;
    }, action);
}
