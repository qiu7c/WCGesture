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

BOOL WCGesturePushPrivateChat(NSString *userName) {
    if (!NSThread.isMainThread || !userName.length) return NO;
    @try {
        Class managerClass = NSClassFromString(@"CAppViewControllerManager");
        SEL currentNavigation = NSSelectorFromString(@"getCurrentNavigationController");
        NSMethodSignature *navigationSignature = [managerClass methodSignatureForSelector:currentNavigation];
        id candidate = nil;
        if (navigationSignature.numberOfArguments == 2 && navigationSignature.methodReturnType[0] == '@') {
            candidate = ((id (*)(id, SEL))objc_msgSend)(managerClass, currentNavigation);
        }
        UINavigationController *navigation = [candidate isKindOfClass:UINavigationController.class] ? candidate : WCPushNavigation();
        if (!navigation || !navigation.view.window || navigation.isBeingDismissed || navigation.presentedViewController
            || navigation.transitionCoordinator) return NO;

        UIViewController *visible = navigation.visibleViewController;
        Class chatClass = NSClassFromString(@"BaseMsgContentViewController");
        if (chatClass && [visible isKindOfClass:chatClass]) {
            id currentContact = WCTweakSafeValue(visible, @"GetCContact");
            if ([WCPrivateContactUserName(currentContact) isEqualToString:userName]) return YES;
        }
        id logic = WCServiceForClass(NSClassFromString(@"MMMsgLogicManager"));
        id contact = WCPrivateContact(userName);
        SEL push = NSSelectorFromString(@"PushOtherBaseMsgControllerByContact:navigationController:animated:");
        NSMethodSignature *signature = [logic methodSignatureForSelector:push];
        if (!contact || signature.numberOfArguments != 5 || signature.methodReturnType[0] != 'v'
            || [signature getArgumentTypeAtIndex:2][0] != '@'
            || [signature getArgumentTypeAtIndex:3][0] != '@'
            || strcmp([signature getArgumentTypeAtIndex:4], @encode(BOOL)) != 0) return NO;
        ((void (*)(id, SEL, id, id, BOOL))objc_msgSend)(logic, push, contact, navigation, YES);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[One Wx] 通知聊天页跳转失败：%@", exception.reason);
        return NO;
    }
}
