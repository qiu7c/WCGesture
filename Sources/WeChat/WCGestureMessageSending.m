#import "Sources/API/WCGestureInternal.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
static const char *WCGesturePrivateUnqualifiedType(const char *type) {
    if (!type) return "";
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

static BOOL WCGesturePrivateTypeIsObject(const char *type) {
    return WCGesturePrivateUnqualifiedType(type)[0] == '@';
}

static BOOL WCGesturePrivateTypeIsInteger(const char *type) {
    const char value = WCGesturePrivateUnqualifiedType(type)[0];
    return value && strchr("cCsSiIlLqQB", value) != NULL;
}

static BOOL WCGesturePrivateTypeIsVoid(const char *type) {
    return WCGesturePrivateUnqualifiedType(type)[0] == 'v';
}

static NSMethodSignature *WCGesturePrivateSignature(id receiver,
                                                SEL selector,
                                                NSUInteger argumentCount) {
    if (!receiver || !selector || ![receiver respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [receiver methodSignatureForSelector:selector];
    return signature.numberOfArguments == argumentCount ? signature : nil;
}

static BOOL WCGesturePrivateObjectArguments(NSMethodSignature *signature,
                                        NSRange indexes) {
    if (!signature || NSMaxRange(indexes) > signature.numberOfArguments) return NO;
    for (NSUInteger index = indexes.location; index < NSMaxRange(indexes); index++) {
        if (!WCGesturePrivateTypeIsObject([signature getArgumentTypeAtIndex:index])) return NO;
    }
    return YES;
}

static NSString *WCGesturePrivateNonemptyString(id value) {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return string.length > 0 ? string : nil;
}

static BOOL WCGesturePrivateSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0 || !value) return NO;
    NSString *capitalized = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                                          withString:[[key substringToIndex:1] uppercaseString]];
    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@:", capitalized]);
    NSMethodSignature *signature = WCGesturePrivateSignature(object, setter, 3);
    if (signature && WCGesturePrivateTypeIsVoid(signature.methodReturnType)) {
        const char *argumentType = [signature getArgumentTypeAtIndex:2];
        @try {
            if (WCGesturePrivateTypeIsObject(argumentType)) {
                ((void (*)(id, SEL, id))objc_msgSend)(object, setter, value);
                return YES;
            }
        } @catch (__unused NSException *exception) {}
    }
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static id WCGesturePrivateInitializeMessageWrap(Class wrapClass,
                                             SEL initializer,
                                             char argumentCode) {
    id allocated = [wrapClass alloc];
    switch (argumentCode) {
        case 'c': return ((id (*)(id, SEL, signed char))objc_msgSend)(allocated, initializer, 1);
        case 'C': return ((id (*)(id, SEL, unsigned char))objc_msgSend)(allocated, initializer, 1);
        case 's': return ((id (*)(id, SEL, short))objc_msgSend)(allocated, initializer, 1);
        case 'S': return ((id (*)(id, SEL, unsigned short))objc_msgSend)(allocated, initializer, 1);
        case 'i': return ((id (*)(id, SEL, int))objc_msgSend)(allocated, initializer, 1);
        case 'I': return ((id (*)(id, SEL, unsigned int))objc_msgSend)(allocated, initializer, 1);
        case 'l': return ((id (*)(id, SEL, long))objc_msgSend)(allocated, initializer, 1);
        case 'L': return ((id (*)(id, SEL, unsigned long))objc_msgSend)(allocated, initializer, 1);
        case 'q': return ((id (*)(id, SEL, long long))objc_msgSend)(allocated, initializer, 1);
        case 'Q': return ((id (*)(id, SEL, unsigned long long))objc_msgSend)(allocated, initializer, 1);
        case 'B': return ((id (*)(id, SEL, BOOL))objc_msgSend)(allocated, initializer, YES);
        default: return nil;
    }
}

static void WCGesturePrivateSubmitMessage(id manager,
                                      SEL selector,
                                      id target,
                                      id wrap,
                                      const char *returnType) {
    switch (WCGesturePrivateUnqualifiedType(returnType)[0]) {
        case 'v': ((void (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'c': (void)((signed char (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'C': (void)((unsigned char (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 's': (void)((short (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'S': (void)((unsigned short (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'i': (void)((int (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'I': (void)((unsigned int (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'l': (void)((long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'L': (void)((unsigned long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'q': (void)((long long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'Q': (void)((unsigned long long (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        case 'B': (void)((BOOL (*)(id, SEL, id, id))objc_msgSend)(manager, selector, target, wrap); break;
        default: break;
    }
}

static id WCGesturePrivateService(NSString *name) { return WCServiceForClass(NSClassFromString(name)); }

BOOL WCGesturePrivateSendTextMessage(NSString *userName, NSString *text) {
    NSCAssert(NSThread.isMainThread, @"Message submission must run on the main thread");
    NSString *target = WCGesturePrivateNonemptyString(userName);
    NSString *content = WCGesturePrivateNonemptyString(text);
    NSString *currentUser = WCGesturePrivateNonemptyString(WCCurrentUserWXID());
    if (target.length == 0 || content.length == 0 || currentUser.length == 0) return NO;

    Class wrapClass = NSClassFromString(@"CMessageWrap");
    SEL initializer = NSSelectorFromString(@"initWithMsgType:");
    Method initializerMethod = wrapClass ? class_getInstanceMethod(wrapClass, initializer) : NULL;
    if (!initializerMethod || method_getNumberOfArguments(initializerMethod) != 3) return NO;
    char *returnType = method_copyReturnType(initializerMethod);
    BOOL objectReturn = WCGesturePrivateTypeIsObject(returnType);
    if (returnType) free(returnType);
    if (!objectReturn) return NO;
    char *argumentType = method_copyArgumentType(initializerMethod, 2);
    BOOL integerArgument = WCGesturePrivateTypeIsInteger(argumentType);
    char argumentCode = WCGesturePrivateUnqualifiedType(argumentType)[0];
    if (argumentType) free(argumentType);
    if (!integerArgument) return NO;

    id wrap = nil;
    @try {
        wrap = WCGesturePrivateInitializeMessageWrap(wrapClass, initializer, argumentCode);
    } @catch (__unused NSException *exception) {
        return NO;
    }
    if (!wrap || !WCGesturePrivateSetValue(wrap, @"m_nsFromUsr", currentUser) ||
        !WCGesturePrivateSetValue(wrap, @"m_nsToUsr", target) ||
        !WCGesturePrivateSetValue(wrap, @"m_nsContent", content)) return NO;
    WCGesturePrivateSetValue(wrap, @"m_uiMessageType", @1);
    WCGesturePrivateSetValue(wrap, @"m_uiStatus", @1);
    WCGesturePrivateSetValue(wrap, @"m_uiCreateTime",
                         @((NSUInteger)NSDate.date.timeIntervalSince1970));

    id manager = WCGesturePrivateService(@"CMessageMgr");
    SEL sendSelector = NSSelectorFromString(@"AddMsg:MsgWrap:");
    NSMethodSignature *sendSignature = WCGesturePrivateSignature(manager, sendSelector, 4);
    if (!sendSignature ||
        !WCGesturePrivateObjectArguments(sendSignature, NSMakeRange(2, 2)) ||
        (!WCGesturePrivateTypeIsVoid(sendSignature.methodReturnType) &&
         !WCGesturePrivateTypeIsInteger(sendSignature.methodReturnType))) return NO;
    @try {
        WCGesturePrivateSubmitMessage(manager, sendSelector, target, wrap,
                                  sendSignature.methodReturnType);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[One Wx] 文本消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

@interface WCGesturePrivateMediaSendSession : NSObject
@property (nonatomic, strong) id logic;
@property (nonatomic, strong) id message;
@property (nonatomic, strong) id contact;
@end
@implementation WCGesturePrivateMediaSendSession
@end

static NSMutableSet<WCGesturePrivateMediaSendSession *> *WCGesturePrivateMediaSessions(void) {
    static NSMutableSet *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableSet set]; });
    return sessions;
}

BOOL WCGesturePrivateSendImageMessage(NSString *userName, NSString *imagePath) {
    NSCAssert(NSThread.isMainThread, @"Image submission must run on the main thread");
    NSString *target = WCGesturePrivateNonemptyString(userName);
    NSString *path = WCGesturePrivateNonemptyString(imagePath);
    UIImage *image = path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    id contact = target.length ? WCPrivateContact(target) : nil;
    Class providerClass = NSClassFromString(@"PasteboardMsgProvider");
    Class logicClass = NSClassFromString(@"ForwardMessageLogicController");
    SEL makeSelector = NSSelectorFromString(@"GetMessageFromImage:contact:");
    SEL sendSelector = NSSelectorFromString(@"forwardNoConfirmForMsgList:toContacts:");
    Method makeMethod = providerClass ? class_getClassMethod(providerClass, makeSelector) : NULL;
    Method sendMethod = logicClass ? class_getInstanceMethod(logicClass, sendSelector) : NULL;
    char *makeReturnType = makeMethod ? method_copyReturnType(makeMethod) : NULL;
    BOOL makeReturnsObject = WCGesturePrivateTypeIsObject(makeReturnType);
    if (makeReturnType) free(makeReturnType);
    char *makeFirstType = makeMethod ? method_copyArgumentType(makeMethod, 2) : NULL;
    char *makeSecondType = makeMethod ? method_copyArgumentType(makeMethod, 3) : NULL;
    BOOL makeArgumentsAreObjects = WCGesturePrivateTypeIsObject(makeFirstType) && WCGesturePrivateTypeIsObject(makeSecondType);
    if (makeFirstType) free(makeFirstType);
    if (makeSecondType) free(makeSecondType);
    char *sendReturnType = sendMethod ? method_copyReturnType(sendMethod) : NULL;
    char sendReturnEncoding[2] = { WCGesturePrivateUnqualifiedType(sendReturnType)[0], '\0' };
    char *sendFirstType = sendMethod ? method_copyArgumentType(sendMethod, 2) : NULL;
    char *sendSecondType = sendMethod ? method_copyArgumentType(sendMethod, 3) : NULL;
    BOOL sendABIValid = (WCGesturePrivateTypeIsVoid(sendReturnType) || WCGesturePrivateTypeIsInteger(sendReturnType)) &&
        WCGesturePrivateTypeIsObject(sendFirstType) && WCGesturePrivateTypeIsObject(sendSecondType);
    if (sendReturnType) free(sendReturnType);
    if (sendFirstType) free(sendFirstType);
    if (sendSecondType) free(sendSecondType);
    if (!image || !contact || !makeMethod || method_getNumberOfArguments(makeMethod) != 4 ||
        !makeReturnsObject || !makeArgumentsAreObjects ||
        !sendMethod || method_getNumberOfArguments(sendMethod) != 4 || !sendABIValid) return NO;
    id message = nil;
    id logic = nil;
    WCGesturePrivateMediaSendSession *session = nil;
    @try {
        message = ((id (*)(id, SEL, id, id))objc_msgSend)(providerClass, makeSelector, image, contact);
        logic = message ? [logicClass new] : nil;
        if (!logic) return NO;
        session = [WCGesturePrivateMediaSendSession new];
        session.logic = logic; session.message = message; session.contact = contact;
        [WCGesturePrivateMediaSessions() addObject:session];
        WCGesturePrivateSubmitMessage(logic, sendSelector, @[message], @[contact], sendReturnEncoding);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [WCGesturePrivateMediaSessions() removeObject:session]; });
        return YES;
    } @catch (NSException *exception) {
        if (session) [WCGesturePrivateMediaSessions() removeObject:session];
        NSLog(@"[One Wx] 图片消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    }
}

static BOOL WCGesturePrivateInvokeThreeObjects(id receiver, SEL selector, id first, id second, id third,
                                            const char *returnType) {
    switch (WCGesturePrivateUnqualifiedType(returnType)[0]) {
        case 'v': ((void (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case '@': (void)((id (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'c': (void)((signed char (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'C': (void)((unsigned char (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 's': (void)((short (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'S': (void)((unsigned short (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'i': (void)((int (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'I': (void)((unsigned int (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'l': (void)((long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'L': (void)((unsigned long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'q': (void)((long long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'Q': (void)((unsigned long long (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        case 'B': (void)((BOOL (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third); return YES;
        default: return NO;
    }
}

BOOL WCGesturePrivateSendVideoMessage(NSString *userName, NSString *videoPath) {
    NSCAssert(NSThread.isMainThread, @"Video submission must run on the main thread");
    NSString *target = WCGesturePrivateNonemptyString(userName);
    NSString *path = WCGesturePrivateNonemptyString(videoPath);
    NSString *currentUser = WCGesturePrivateNonemptyString(WCCurrentUserWXID());
    if (!target || !currentUser || ![NSFileManager.defaultManager fileExistsAtPath:path]) return NO;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!track) return NO;
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    CGImageRef frame = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.1, 600) actualTime:NULL error:nil];
    UIImage *thumbnail = frame ? [UIImage imageWithCGImage:frame] : nil;
    if (frame) CGImageRelease(frame);
    NSString *thumbnailPath = nil;
    NSData *thumbnailData = thumbnail ? UIImageJPEGRepresentation(thumbnail, 0.85) : nil;
    if (thumbnailData.length) {
        thumbnailPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"onewx-video-%@.jpg", NSUUID.UUID.UUIDString]];
        if (![thumbnailData writeToFile:thumbnailPath atomically:YES]) thumbnailPath = nil;
    }
    @try {
        id videoInfo = nil;
        Class highClass = NSClassFromString(@"OpenApiMgrHelper");
        SEL highSelector = NSSelectorFromString(@"genCaptureVideoInfoWithVideoData:mediaMessage:param:");
        NSMethodSignature *highSignature = WCGesturePrivateSignature(highClass, highSelector, 5);
        if (track.estimatedDataRate >= 5000000.0 && highSignature &&
            WCGesturePrivateTypeIsObject(highSignature.methodReturnType) &&
            WCGesturePrivateObjectArguments(highSignature, NSMakeRange(2, 3))) {
            NSData *videoData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
            if (videoData.length) videoInfo = ((id (*)(id, SEL, id, id, id))objc_msgSend)(highClass, highSelector, videoData, nil, nil);
        }
        if (!videoInfo) {
            Class infoClass = NSClassFromString(@"CaptureVideoInfo");
            SEL infoSelector = NSSelectorFromString(@"genVideoInfoWithVideoUrl:thumb:");
            NSMethodSignature *infoSignature = WCGesturePrivateSignature(infoClass, infoSelector, 4);
            if (!infoSignature || !WCGesturePrivateTypeIsObject(infoSignature.methodReturnType) ||
                !WCGesturePrivateObjectArguments(infoSignature, NSMakeRange(2, 2))) return NO;
            videoInfo = ((id (*)(id, SEL, id, id))objc_msgSend)(infoClass, infoSelector,
                [NSURL fileURLWithPath:path], thumbnail);
        }
        if (!videoInfo) return NO;
        if (thumbnailPath.length) WCGesturePrivateSetValue(videoInfo, @"thumb_path", thumbnailPath);
        id manager = WCGesturePrivateService(@"CMessageMgr");
        SEL addSelector = NSSelectorFromString(@"AddVideoMsg:ToUsr:VideoInfo:");
        NSMethodSignature *signature = WCGesturePrivateSignature(manager, addSelector, 5);
        if (!signature || !WCGesturePrivateObjectArguments(signature, NSMakeRange(2, 3))) return NO;
        BOOL submitted = WCGesturePrivateInvokeThreeObjects(manager, addSelector, currentUser, target,
                                                         videoInfo, signature.methodReturnType);
        return submitted;
    } @catch (NSException *exception) {
        NSLog(@"[One Wx] 视频消息适配发送失败：%@", exception.reason ?: exception.name);
        return NO;
    } @finally {
        if (thumbnailPath.length) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC),
            dispatch_get_main_queue(), ^{ [NSFileManager.defaultManager removeItemAtPath:thumbnailPath error:nil]; });
    }
}
