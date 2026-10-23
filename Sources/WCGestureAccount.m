#import "WCGestureAccount.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const WCCachedWXIDKey = @"com.qiu7c.wcgesture.cached-wxid";

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
