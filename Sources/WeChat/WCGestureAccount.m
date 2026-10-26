#import <objc/message.h>
#import <string.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "Sources/API/WCGestureInternal.h"

static NSString *const WCCachedWXIDKey = @"com.qiu7c.onewx.cached-wxid";

static id WCServiceCenterFromCurrentContext(void) {
    Class contextClass = objc_getClass("MMContext");
    SEL currentContextSelector = sel_registerName("currentContext");
    SEL serviceCenterSelector = sel_registerName("serviceCenter");
    if (!contextClass || ![contextClass respondsToSelector:currentContextSelector]) return nil;
    id context = ((id (*)(id, SEL))objc_msgSend)(contextClass, currentContextSelector);
    if (!context || ![context respondsToSelector:serviceCenterSelector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(context, serviceCenterSelector);
}

void WCInstallServiceCenterCompatibility(void) {
    Class centerClass = objc_getClass("MMServiceCenter");
    if (!centerClass) return;
    SEL selector = sel_registerName("defaultCenter");
    if ([centerClass respondsToSelector:selector]) return;
    Class metaclass = object_getClass(centerClass);
    if (metaclass) class_addMethod(metaclass, selector, (IMP)WCServiceCenterFromCurrentContext, "@@:");
}

id WCDefaultServiceCenter(void) {
    id contextCenter = WCServiceCenterFromCurrentContext();
    if (contextCenter) return contextCenter;
    Class centerClass = objc_getClass("MMServiceCenter");
    SEL selector = sel_registerName("defaultCenter");
    if (!centerClass || ![centerClass respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(centerClass, selector);
}

id WCServiceForClass(Class serviceClass) {
    id center = WCDefaultServiceCenter();
    SEL selector = sel_registerName("getService:");
    if (!center || !serviceClass || ![center respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL, Class))objc_msgSend)(center, selector, serviceClass);
}

NSString *WCCurrentUserWXID(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:WCCachedWXIDKey];
}

static NSString *WCContactString(id contact, const char *selectorName) {
    if (!contact || !selectorName) return nil;
    SEL selector = sel_registerName(selectorName);
    id value = nil;
    if ([contact respondsToSelector:selector]) {
        value = ((id (*)(id, SEL))objc_msgSend)(contact, selector);
    } else {
        NSString *key = [NSString stringWithUTF8String:selectorName];
        @try { value = [contact valueForKey:key]; }
        @catch (__unused NSException *exception) { return nil; }
    }
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length > 0 ? text : nil;
}

BOOL WCRefreshCachedCurrentUser(void) {
    Class contactManagerClass = objc_getClass("CContactMgr");
    id manager = WCServiceForClass(contactManagerClass);
    SEL selector = sel_registerName("getSelfContact");
    if (!manager || ![manager respondsToSelector:selector]) return NO;
    id contact = ((id (*)(id, SEL))objc_msgSend)(manager, selector);
    NSString *wxid = WCContactString(contact, "m_nsUsrName");
    if (wxid.length == 0) return NO;
    [[NSUserDefaults standardUserDefaults] setObject:wxid forKey:WCCachedWXIDKey];
    return YES;
}

UIView *WCGestureCurrentUserAvatarView(void) {
    NSCAssert(NSThread.isMainThread, @"Avatar views must be created on the main thread");
    UIView *view = nil;
    @try {
        id manager = WCServiceForClass(NSClassFromString(@"CContactMgr"));
        id contact = WCTweakValueForSelectorNames(manager, @[@"getSelfContact"]);
        NSString *userName = WCPrivateContactUserName(contact);
        if (userName.length) {
            [NSUserDefaults.standardUserDefaults setObject:userName forKey:WCCachedWXIDKey];
        } else {
            userName = WCCurrentUserWXID();
            contact = userName.length ? WCPrivateContact(userName) : nil;
        }
        if (userName.length) view = WCGestureContactUncroppedAvatarView(userName);
    } @catch (NSException *exception) {
        WCLog(@"预览头像暂不可用：%@", exception.name);
    }
    if (!view) {
        view = [UIView new];
        view.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
        view.accessibilityIdentifier = @"com.qiu7c.onewx.preview.avatar-unavailable";
    }
    view.userInteractionEnabled = NO;
    view.contentMode = UIViewContentModeScaleAspectFit;
    if ([view isKindOfClass:UIImageView.class]) { view.layer.cornerRadius = 6; view.clipsToBounds = YES; }
    return view;
}
