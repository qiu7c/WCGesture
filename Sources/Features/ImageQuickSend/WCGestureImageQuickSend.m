#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCQuickSendContext : NSObject
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *target;
@property (nonatomic, strong) id attribute;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) BOOL busy;
@end
@implementation WCQuickSendContext
@end

@interface WCQuickSendSession : NSObject
@property (nonatomic, strong) id source;
@property (nonatomic, strong) id forward;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIViewController *presenter;
@property (nonatomic, strong) WCQuickSendContext *context;
@property (nonatomic) BOOL tapped;
@property (nonatomic) BOOL finished;
- (void)finish;
@end
static char WCQuickSendContextKey;
static NSMutableSet<WCQuickSendSession *> *WCQuickSendSessions;
static id WCQuickSendGet(id object, NSString *key) {
    return object ? WCTweakSafeValue(object, key) : nil;
}
static NSString *WCQuickSendString(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}
static NSString *WCQuickSendTarget(id logic, NSString *account) {
    id wrap = WCQuickSendGet(logic, @"originalMessageWrap");
    NSString *from = WCQuickSendString(WCQuickSendGet(wrap, @"m_nsFromUsr"));
    NSString *to = WCQuickSendString(WCQuickSendGet(wrap, @"m_nsToUsr"));
    NSString *target = [from isEqualToString:account] ? to : from;
    NSString *peer = WCQuickSendString(WCQuickSendGet(logic, @"c2CUserName"));
    // A contradictory editor context must never silently pick a recipient.
    if (target.length && peer.length && ![target isEqualToString:peer]) return nil;
    return target.length ? target : peer;
}
static BOOL WCQuickSendValid(id logic, WCQuickSendContext *context) {
    if (!context || objc_getAssociatedObject(logic, &WCQuickSendContextKey) != context || !WCGestureEnabled(WCGestureImageEditQuickSendEnabledKey) ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive ||
        !WCRefreshCachedCurrentUser()) return NO;
    NSString *account = WCCurrentUserWXID();
    return account.length && [context.account isEqualToString:account] &&
        context.target.length && [context.target isEqualToString:WCQuickSendTarget(logic, account)];
}
static UIViewController *WCQuickSendPresenter(id logic) {
    id vc = WCQuickSendGet(logic, @"currentViewController") ?: WCQuickSendGet(logic, @"forwardBasedViewController");
    if (![vc isKindOfClass:UIViewController.class]) vc = WCQuickSendGet(logic, @"getCurrentViewController");
    if (![vc isKindOfClass:UIViewController.class]) return nil;
    UIViewController *presenter = vc;
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed)
        presenter = presenter.presentedViewController;
    return presenter.isViewLoaded && presenter.view.window && !presenter.isBeingDismissed ? presenter : nil;
}
static UIImage *WCQuickSendImage(id value, NSUInteger depth) {
    if (!value || depth > 4) return nil;
    if ([value isKindOfClass:UIImage.class]) return value;
    if ([value isKindOfClass:NSClassFromString(@"CIImage")]) return [UIImage imageWithCIImage:value];
    if ([value isKindOfClass:NSData.class]) return [UIImage imageWithData:value];
    if ([value isKindOfClass:NSURL.class]) return [value isFileURL] ? [UIImage imageWithContentsOfFile:[value path]] : nil;
    if ([value isKindOfClass:NSString.class]) {
        NSString *path = [value hasPrefix:@"file://"] ? [NSURL URLWithString:value].path : value;
        return path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id item in [value reverseObjectEnumerator]) {
            UIImage *image = WCQuickSendImage(item, depth + 1);
            if (image) return image;
        }
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        for (NSString *key in @[@"editedImage", @"outputImage", @"resultImage", @"image", @"path", @"url"]) {
            UIImage *image = WCQuickSendImage(value[key], depth + 1);
            if (image) return image;
        }
    }
    return nil;
}
static UIImage *WCQuickSendEditedImage(id logic, WCQuickSendContext *context) {
    id initialView = WCQuickSendGet(logic, @"_editImageInitialView");
    id scrollView = WCQuickSendGet(initialView, @"eIScrollView");
    id finalAttribute = WCQuickSendGet(scrollView, @"getEditImageAttr");
    UIImage *finalImage = WCQuickSendImage(WCQuickSendGet(finalAttribute, @"editedImage"), 0);
    if (!finalImage) finalImage = WCQuickSendImage(WCQuickSendGet(finalAttribute, @"editedImages"), 0);
    if (finalImage) return finalImage;
    id attribute = WCQuickSendGet(logic, @"getEditImageAttr");
    if (attribute) context.attribute = attribute;
    if (!context.attribute) context.attribute = WCQuickSendGet(logic, @"editImageAttr");
    UIImage *image = WCQuickSendImage(WCQuickSendGet(context.attribute, @"editedImage"), 0);
    return image ?: WCQuickSendImage(WCQuickSendGet(context.attribute, @"editedImages"), 0);
}
@implementation WCQuickSendSession
- (UIViewController *)getCurrentViewController { return self.presenter; }
- (UIViewController *)GetCurrentViewController { return self.presenter; }
- (BOOL)shouldShowSendSuccessView:(id)logic { return YES; }
- (void)finish {
    if (self.finished) return;
    self.finished = YES;
    self.context.busy = NO;
    self.context.generation++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [WCQuickSendSessions removeObject:self];
        self.source = nil; self.forward = nil; self.message = nil;
        self.contact = nil; self.image = nil; self.presenter = nil;
    });
}
- (void)OnForwardMessageSend:(id)logic {
    if (self.finished) return;
    if (!self.tapped && ![WCQuickSendGet(WCQuickSendGet(self.forward, @"confirmSheetView"), @"isClickedSend") boolValue]) return;
    SEL selector = NSSelectorFromString(@"OnForwardMessageSend:");
    if ([self.source respondsToSelector:selector]) ((void (*)(id, SEL, id))objc_msgSend)(self.source, selector, logic);
    [self finish];
}
- (void)OnForwardMessageCancel:(id)logic {
    if (self.finished) return;
    SEL selector = NSSelectorFromString(@"OnForwardMessageCancel:");
    if ([self.source respondsToSelector:selector]) ((void (*)(id, SEL, id))objc_msgSend)(self.source, selector, logic);
    [self finish];
}
- (void)OnForwardMessageConfirmCanceled:(id)logic { [self OnForwardMessageCancel:logic]; }
@end

void WCGestureImageQuickSendPrepare(id logic) {
    WCQuickSendContext *old = objc_getAssociatedObject(logic, &WCQuickSendContextKey);
    old.generation++;
    objc_setAssociatedObject(logic, &WCQuickSendContextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!WCGestureEnabled(WCGestureImageEditQuickSendEnabledKey) || !WCRefreshCachedCurrentUser()) return;
    WCQuickSendContext *context = [WCQuickSendContext new];
    context.account = WCCurrentUserWXID();
    context.target = WCQuickSendTarget(logic, context.account);
    objc_setAssociatedObject(logic, &WCQuickSendContextKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void WCGestureImageQuickSendBindAttribute(id logic, id attribute) {
    WCQuickSendContext *context = objc_getAssociatedObject(logic, &WCQuickSendContextKey);
    if (context && attribute) context.attribute = attribute;
}
static void WCQuickSendLaunch(id logic, WCQuickSendContext *context, UIImage *image) {
    UIViewController *presenter = WCQuickSendPresenter(logic);
    id contact = WCPrivateContact(context.target);
    if (!presenter || !contact || ![WCPrivateContactUserName(contact) isEqualToString:context.target]) { context.busy = NO; WCShowToast(@"当前会话不可用，请返回聊天后重试"); return; }
    Class provider = NSClassFromString(@"PasteboardMsgProvider");
    SEL make = NSSelectorFromString(@"GetMessageFromImage:contact:");
    SEL send = NSSelectorFromString(@"forwardMsgList:msgOriginList:toContacts:ignoreTips:showConfirmView:");
    id forward = [[NSClassFromString(@"ForwardMessageLogicController") alloc] init];
    if (![provider respondsToSelector:make] || ![forward respondsToSelector:send] || ![forward respondsToSelector:@selector(setDelegate:)]) { context.busy = NO; WCShowToast(@"当前微信版本不支持图片快捷发送"); return; }
    id message = ((id (*)(id, SEL, id, id))objc_msgSend)(provider, make, image, contact);
    if (!message) { context.busy = NO; WCShowToast(@"无法生成编辑后的图片消息"); return; }
    WCQuickSendSession *session = [WCQuickSendSession new];
    session.source = logic; session.forward = forward; session.message = message;
    session.image = image; session.contact = contact; session.presenter = presenter; session.context = context;
    if (!WCQuickSendSessions) WCQuickSendSessions = [NSMutableSet new];
    [WCQuickSendSessions addObject:session];
    @try {
        ((void (*)(id, SEL, id))objc_msgSend)(forward, @selector(setDelegate:), session);
        [forward setValue:@YES forKey:@"bSpecificContact"];
        [forward setValue:@YES forKey:@"bPresent"];
        [forward setValue:@YES forKey:@"bAnimation"];
        ((void (*)(id, SEL, id, id, id, BOOL, BOOL))objc_msgSend)(forward, send, @[message], nil, @[contact], NO, YES);
    } @catch (__unused NSException *exception) { [session finish]; WCShowToast(@"无法打开微信发送确认页"); }
    __weak WCQuickSendSession *weakSession = session;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        WCQuickSendSession *active = weakSession;
        if (!active || active.finished) return;
        id sheet = WCQuickSendGet(active.forward, @"confirmSheetView");
        SEL cancel = NSSelectorFromString(@"onCancelButtonClick");
        if (!active.tapped && [sheet respondsToSelector:cancel]) ((void (*)(id, SEL))objc_msgSend)(sheet, cancel);
        [active finish];
    });
}
static void WCQuickSendWait(id logic, WCQuickSendContext *context, NSUInteger generation, NSUInteger attempt) {
    if (generation != context.generation) return;
    if (!WCQuickSendValid(logic, context) || !WCQuickSendPresenter(logic)) { context.busy = NO; return; }
    UIImage *image = WCQuickSendEditedImage(logic, context);
    if (image) { WCQuickSendLaunch(logic, context, image); return; }
    if (attempt >= 30) { context.busy = NO; WCShowToast(@"未取得编辑后的图片，请重试"); return; }
    __weak id weakLogic = logic;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{
        id source = weakLogic;
        if (source) WCQuickSendWait(source, context, generation, attempt + 1);
        else context.busy = NO;
    });
}
void WCGestureImageQuickSendAddAction(id sheet, UIView *view) {
    if (!WCGestureEnabled(WCGestureImageEditQuickSendEnabledKey)) return;
    Class editorClass = NSClassFromString(@"EditImageForwardAndEditLogicController");
    id logic = WCQuickSendGet(sheet, @"delegateEx");
    if (![logic isKindOfClass:editorClass]) logic = WCQuickSendGet(sheet, @"delegate");
    if (![logic isKindOfClass:editorClass]) return;
    SEL contains = NSSelectorFromString(@"isContainButtonTitle:");
    SEL add = NSSelectorFromString(@"addButtonWithTitle:eventAction:");
    if (![sheet respondsToSelector:contains] || ![sheet respondsToSelector:add]) return;
    BOOL (^has)(NSString *) = ^BOOL(NSString *title) { return ((BOOL (*)(id, SEL, id))objc_msgSend)(sheet, contains, title); };
    if (!(has(@"转发给朋友") || has(@"发送给朋友")) || !has(@"收藏") || !has(@"保存图片") || has(@"发送到当前会话")) return;
    WCQuickSendContext *context = objc_getAssociatedObject(logic, &WCQuickSendContextKey);
    if (!context) {
        WCGestureImageQuickSendPrepare(logic);
        context = objc_getAssociatedObject(logic, &WCQuickSendContextKey);
    }
    if (!WCQuickSendValid(logic, context)) return;
    __weak id weakLogic = logic;
    void (^action)(void) = ^{
        id source = weakLogic;
        if (!source || context.busy || !WCQuickSendValid(source, context)) return;
        context.busy = YES;
        NSUInteger generation = ++context.generation;
        // Let the action sheet finish dismissing before presenting the native confirm sheet.
        dispatch_async(dispatch_get_main_queue(), ^{ WCQuickSendWait(source, context, generation, 0); });
    };
    ((long long (*)(id, SEL, id, id))objc_msgSend)(sheet, add, @"发送到当前会话", action);
}
id WCGestureImageQuickSendSessionForSheet(id sheet) {
    id delegate = WCQuickSendGet(sheet, @"delegate");
    id owner = WCQuickSendGet(sheet, @"msgLogicController");
    for (WCQuickSendSession *session in WCQuickSendSessions) {
        if (!session.finished && (session.forward == delegate || session.forward == owner || WCQuickSendGet(session.forward, @"confirmSheetView") == sheet)) return session;
    }
    return nil;
}
void WCGestureImageQuickSendCancelSession(id value) {
    if ([value isKindOfClass:WCQuickSendSession.class]) {
        WCQuickSendSession *session = value;
        [session OnForwardMessageCancel:session.forward];
    }
}
BOOL WCGestureImageQuickSendConfirmAllowed(id sheet) {
    WCQuickSendSession *session = WCGestureImageQuickSendSessionForSheet(sheet);
    if (!session) return YES;
    if (!WCQuickSendValid(session.source, session.context)) {
        SEL cancel = NSSelectorFromString(@"onCancelButtonClick");
        if ([sheet respondsToSelector:cancel]) ((void (*)(id, SEL))objc_msgSend)(sheet, cancel);
        WCGestureImageQuickSendCancelSession(session);
        return NO;
    }
    session.tapped = YES;
    return YES;
}
void WCGestureImageQuickSendSettingsChanged(id key) {
    if (WCGestureEnabled(WCGestureImageEditQuickSendEnabledKey)) return;
    for (WCQuickSendSession *session in [WCQuickSendSessions copy]) {
        id sheet = WCQuickSendGet(session.forward, @"confirmSheetView");
        SEL cancel = NSSelectorFromString(@"onCancelButtonClick");
        if (!session.tapped && [sheet respondsToSelector:cancel]) ((void (*)(id, SEL))objc_msgSend)(sheet, cancel);
        if (!session.tapped) [session finish];
    }
}
