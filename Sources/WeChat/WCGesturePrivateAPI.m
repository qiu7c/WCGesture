#import <objc/message.h>
#import <objc/runtime.h>

#import "Sources/API/WCGestureInternal.h"

static NSString *WCNonemptyString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length > 0 ? text : nil;
}

static id WCObjectField(id object, NSArray<NSString *> *names) {
    if (!object) return nil;
    for (NSString *name in names) {
        @try {
            id value = [object valueForKey:name];
            if (value) return value;
        } @catch (__unused NSException *exception) {
        }
        SEL selector = NSSelectorFromString(name);
        if ([object respondsToSelector:selector]) {
            NSMethodSignature *signature = [object methodSignatureForSelector:selector];
            if (signature && strcmp(signature.methodReturnType, @encode(id)) == 0) {
                id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
                if (value) return value;
            }
        }
    }
    return nil;
}

id WCPrivateContact(NSString *userName) {
    if (userName.length == 0) return nil;
    Class managerClass = objc_getClass("CContactMgr");
    id manager = WCServiceForClass(managerClass);
    if (!manager) return nil;
    for (NSString *selectorName in @[
        @"getContactByName:", @"getContactForSearchByName:",
        @"getContactByNameFromCache:", @"getContact:"
    ]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![manager respondsToSelector:selector]) continue;
        @try {
            id contact = ((id (*)(id, SEL, id))objc_msgSend)(manager, selector, userName);
            if (contact) return contact;
        } @catch (__unused NSException *exception) {
        }
    }
    return nil;
}

NSString *WCPrivateContactUserName(id contact) {
    return WCNonemptyString(WCObjectField(contact,
        @[@"m_nsUsrName", @"m_nsUserName", @"getUsrName", @"userName", @"username"]));
}
