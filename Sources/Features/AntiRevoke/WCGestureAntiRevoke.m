#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static NSUInteger WCGestureUIntegerValue(id object, NSString *key);

static NSString *const WCGestureAntiRevokeSidePromptRecordsKey = @"com.qiu7c.onewx.chat.anti-revoke.side-records";
static NSString *const WCGestureAntiRevokeArchiveKey = @"com.qiu7c.onewx.chat.anti-revoke.archive";
static NSString *const WCGestureAntiRevokeLocalPromptContentsKey = @"com.qiu7c.onewx.chat.anti-revoke.local-prompt-contents";

static NSMutableArray<NSDictionary *> *WCGestureAntiRevokeMemoryRecords(void) {
    static NSMutableArray<NSDictionary *> *records;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:WCGestureAntiRevokeArchiveKey];
        records = [([saved isKindOfClass:[NSArray class]] ? saved : @[]) mutableCopy];
    });
    return records;
}

void WCGestureAntiRevokeSetPersistenceEnabled(BOOL enabled) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:enabled forKey:WCGestureAntiRevokePersistRecordsKey];
    if (enabled) {
        @synchronized (WCGestureAntiRevokeMemoryRecords()) { [defaults setObject:WCGestureAntiRevokeMemoryRecords() forKey:WCGestureAntiRevokeArchiveKey]; }
    } else {
        [defaults removeObjectForKey:WCGestureAntiRevokeArchiveKey];
    }
}

static void WCGestureAntiRevokeAppendRecord(NSString *session, NSString *operatorName, id message, NSString *summary, NSDate *date) {
    NSUInteger type = WCGestureUIntegerValue(message, @"m_uiMessageType");
    NSDictionary *record = @{
        @"session": session ?: @"",
        @"contact": operatorName ?: @"用户",
        @"summary": summary ?: @"",
        @"type": @(type),
        @"time": @((date ?: [NSDate date]).timeIntervalSince1970),
    };
    @synchronized (WCGestureAntiRevokeMemoryRecords()) {
        [WCGestureAntiRevokeMemoryRecords() insertObject:record atIndex:0];
        if (WCGestureAntiRevokeMemoryRecords().count > 500) {
            [WCGestureAntiRevokeMemoryRecords() removeObjectsInRange:NSMakeRange(500, WCGestureAntiRevokeMemoryRecords().count - 500)];
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:WCGestureAntiRevokePersistRecordsKey]) {
            [[NSUserDefaults standardUserDefaults] setObject:WCGestureAntiRevokeMemoryRecords() forKey:WCGestureAntiRevokeArchiveKey];
        }
    }
}

static NSString *const WCGestureDefaultLocalRevokeTemplate =
    @"拦截到一条{用户名}撤回的消息\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n内容：{内容}";

static NSString *const WCGestureDefaultRevokeReplyTemplate =
    @"【捕捉到一条撤回消息】\n操作用户：{用户名}\n发送时间：{yyyy}-{MM}-{dd} {HH}:{mm}:{ss}\n"
    @"撤回内容：{内容}\n\n撤回无效，消息已保存";

static id WCGestureSafeValue(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void WCGestureSafeSetValue(id object, NSString *key, id value) {
    if (!object || key.length == 0) return;
    @try {
        [object setValue:value forKey:key];
    } @catch (__unused NSException *exception) {}
}

static NSString *WCGestureStringValue(id object, NSString *key) {
    id value = WCGestureSafeValue(object, key);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSUInteger WCGestureUIntegerValue(id object, NSString *key) {
    id value = WCGestureSafeValue(object, key);
    return [value respondsToSelector:@selector(unsignedIntegerValue)] ? [value unsignedIntegerValue] : 0;
}

static unsigned long long WCGestureUInt64Value(id object, NSString *key) {
    id value = WCGestureSafeValue(object, key);
    if (![value respondsToSelector:@selector(unsignedLongLongValue)]) return 0;
    return [value unsignedLongLongValue];
}

static NSArray<NSString *> *WCGestureSidePromptRecordKeys(id message) {
    unsigned long long serverID = WCGestureUInt64Value(message, @"m_n64MesSvrID");
    unsigned long long localID = WCGestureUInt64Value(message, @"m_uiMesLocalID");
    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:1];
    if (serverID > 0) {
        [keys addObject:[NSString stringWithFormat:@"server:%llu", serverID]];
        return keys;
    }
    if (localID > 0) {
        NSString *account = WCCurrentUserWXID() ?: @"";
        NSString *fromUser = WCGestureStringValue(message, @"m_nsFromUsr") ?: @"";
        NSString *toUser = WCGestureStringValue(message, @"m_nsToUsr") ?: @"";
        NSUInteger createTime = WCGestureUIntegerValue(message, @"m_uiCreateTime");
        [keys addObject:[NSString stringWithFormat:@"local:%@:%@:%@:%llu:%lu",
                         account, fromUser, toUser, localID, (unsigned long)createTime]];
    }
    return keys;
}

NSString *WCGestureAntiRevokeSidePromptForMessage(id message) {
    NSArray<NSString *> *recordKeys = WCGestureSidePromptRecordKeys(message);
    if (recordKeys.count == 0) return nil;
    NSDictionary *records = [[NSUserDefaults standardUserDefaults] dictionaryForKey:WCGestureAntiRevokeSidePromptRecordsKey];
    BOOL matched = NO;
    for (NSString *recordKey in recordKeys) {
        if (records[recordKey]) { matched = YES; break; }
    }
    if (!matched) return nil;
    NSString *customText = [[NSUserDefaults standardUserDefaults] stringForKey:WCGestureAntiRevokeSideTextKey];
    return customText.length > 0 ? customText : @"已拦截撤回";
}

BOOL WCGestureAntiRevokeIsLocalPromptMessage(id message) {
    if (WCGestureUIntegerValue(message, @"m_uiMessageType") != 10000) return NO;
    NSString *content = WCGestureStringValue(message, @"m_nsContent");
    if (content.length == 0) return NO;
    NSArray<NSString *> *knownContents = [[NSUserDefaults standardUserDefaults] arrayForKey:WCGestureAntiRevokeLocalPromptContentsKey];
    return [knownContents containsObject:content];
}

static void WCGestureRememberLocalPromptContent(NSString *content) {
    if (content.length == 0) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *knownContents = [[defaults arrayForKey:WCGestureAntiRevokeLocalPromptContentsKey] mutableCopy] ?: [NSMutableArray array];
    [knownContents removeObject:content];
    [knownContents insertObject:content atIndex:0];
    if (knownContents.count > 200) [knownContents removeObjectsInRange:NSMakeRange(200, knownContents.count - 200)];
    [defaults setObject:knownContents forKey:WCGestureAntiRevokeLocalPromptContentsKey];
}

static void WCGestureRememberSidePrompt(id message, NSString *text, unsigned long long explicitServerID) {
    NSMutableArray<NSString *> *recordKeys = [WCGestureSidePromptRecordKeys(message) mutableCopy];
    if (explicitServerID > 0) {
        NSString *serverKey = [NSString stringWithFormat:@"server:%llu", explicitServerID];
        if (![recordKeys containsObject:serverKey]) [recordKeys addObject:serverKey];
    }
    if (recordKeys.count == 0 || text.length == 0) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    @synchronized (defaults) {
        NSMutableDictionary *records = [[defaults dictionaryForKey:WCGestureAntiRevokeSidePromptRecordsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
        while (records.count >= 800) [records removeObjectForKey:records.allKeys.firstObject];
        for (NSString *recordKey in recordKeys) records[recordKey] = text;
        [defaults setObject:records forKey:WCGestureAntiRevokeSidePromptRecordsKey];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:WCGestureDidChangeNotification object:WCGestureAntiRevokeEnabledKey];
    });
}

static NSString *WCGestureTextBetween(NSString *text, NSString *opening, NSString *closing) {
    if (text.length == 0 || opening.length == 0 || closing.length == 0) return nil;
    NSRange first = [text rangeOfString:opening];
    if (first.location == NSNotFound) return nil;
    NSUInteger contentStart = NSMaxRange(first);
    if (contentStart > text.length) return nil;
    NSRange searchRange = NSMakeRange(contentStart, text.length - contentStart);
    NSRange last = [text rangeOfString:closing options:0 range:searchRange];
    if (last.location == NSNotFound) return nil;
    return [text substringWithRange:NSMakeRange(contentStart, last.location - contentStart)];
}

static NSDictionary<NSString *, NSString *> *WCGestureDateFields(NSDate *date) {
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                           NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *parts = [[NSCalendar currentCalendar] components:units fromDate:date];
    return @{
        @"yyyy": [NSString stringWithFormat:@"%ld", (long)parts.year],
        @"MM": [NSString stringWithFormat:@"%02ld", (long)parts.month],
        @"dd": [NSString stringWithFormat:@"%02ld", (long)parts.day],
        @"HH": [NSString stringWithFormat:@"%02ld", (long)parts.hour],
        @"mm": [NSString stringWithFormat:@"%02ld", (long)parts.minute],
        @"ss": [NSString stringWithFormat:@"%02ld", (long)parts.second],
    };
}

static NSString *WCGestureMessageTypeName(NSUInteger type) {
    switch (type) {
        case 1:  return @"文本";
        case 3:  return @"图片";
        case 34: return @"语音";
        case 42: return @"名片";
        case 43: return @"视频";
        case 47: return @"表情";
        case 48: return @"位置";
        case 49: return @"分享";
        default: return [NSString stringWithFormat:@"类型(%lu)", (unsigned long)type];
    }
}

static NSString *WCGestureContentSummary(id message) {
    NSUInteger type = WCGestureUIntegerValue(message, @"m_uiMessageType");
    NSString *content = WCGestureStringValue(message, @"m_nsContent");
    if (type == 1 && content.length > 0) return content;
    return [NSString stringWithFormat:@"[%@]", WCGestureMessageTypeName(type)];
}

static NSString *WCGestureApplyRevokeTemplate(NSString *templateText,
                                          NSString *operatorName,
                                          NSString *contentSummary,
                                          NSDate *messageDate) {
    NSString *result = [templateText stringByReplacingOccurrencesOfString:@"{用户名}"
                                                                withString:operatorName ?: @"用户"];
    result = [result stringByReplacingOccurrencesOfString:@"{内容}"
                                                withString:contentSummary ?: @""];
    NSDictionary<NSString *, NSString *> *fields = WCGestureDateFields(messageDate ?: [NSDate date]);
    for (NSString *key in fields) {
        result = [result stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key]
                                                    withString:fields[key]];
    }
    return result;
}

static NSString *WCGestureRevokeOperatorName(NSString *replaceMessage) {
    NSRange phrase = [replaceMessage rangeOfString:@"撤回了一条消息"];
    NSString *name = phrase.location == NSNotFound ? @"用户" : [replaceMessage substringToIndex:phrase.location];
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length >= 2 && [name hasPrefix:@"\""] && [name hasSuffix:@"\""]) {
        name = [name substringWithRange:NSMakeRange(1, name.length - 2)];
    }
    return name.length > 0 ? name : @"用户";
}

static id WCGestureNewMessageWrap(long long type) {
    Class wrapClass = objc_getClass("CMessageWrap");
    SEL initSelector = sel_registerName("initWithMsgType:");
    if (!wrapClass || ![wrapClass instancesRespondToSelector:initSelector]) return nil;
    id allocated = [wrapClass alloc];
    return ((id (*)(id, SEL, long long))objc_msgSend)(allocated, initSelector, type);
}

static id WCGestureOriginalMessage(id manager, NSString *session, long long serverID) {
    SEL selector = sel_registerName("GetMsg:n64SvrID:");
    if (!manager || ![manager respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL, NSString *, long long))objc_msgSend)(manager, selector, session, serverID);
}

static BOOL WCGestureInsertLocalMessage(id manager, NSString *session, id message) {
    SEL selector = sel_registerName("AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:");
    if (![manager respondsToSelector:selector]) return NO;
    ((void (*)(id, SEL, NSString *, id, BOOL, BOOL))objc_msgSend)(manager, selector, session, message, YES, NO);
    return YES;
}

static void WCGestureSendMessage(id manager, NSString *session, id message) {
    SEL selector = sel_registerName("AddMsg:MsgWrap:");
    if (![manager respondsToSelector:selector]) return;
    ((void (*)(id, SEL, NSString *, id))objc_msgSend)(manager, selector, session, message);
}

static BOOL WCHandleRevokeMessage(id messageManager, id incomingMessage) {
    if (!WCGestureEnabled(WCGestureAntiRevokeEnabledKey) || !incomingMessage) return NO;

    NSString *xml = WCGestureStringValue(incomingMessage, @"m_nsContent");
    BOOL isRevokeXML = [xml containsString:@"<sysmsg type=\"revokemsg\""] ||
                       [xml containsString:@"<sysmsg type='revokemsg'"] ||
                       [xml containsString:@"<revokemsg>"];
    if (!isRevokeXML) return NO;

    NSString *session = WCGestureTextBetween(xml, @"<session>", @"</session>");
    NSString *serverIDText = WCGestureTextBetween(xml, @"<newmsgid>", @"</newmsgid>");
    NSString *replaceMessage = WCGestureTextBetween(xml, @"<replacemsg><![CDATA[", @"]]></replacemsg>");
    long long serverID = serverIDText.longLongValue;
    if (session.length == 0 || serverID == 0 || replaceMessage.length == 0) return NO;

    // Own-message revoke notifications must keep WeChat's original behavior.
    if ([replaceMessage hasPrefix:@"你"] || [replaceMessage containsString:@"你撤回了一条消息"]) return NO;

    NSString *selfUsername = WCCurrentUserWXID();
    if (selfUsername.length == 0) return NO;
    id original = WCGestureOriginalMessage(messageManager, session, serverID);
    NSString *originalFrom = WCGestureStringValue(original, @"m_nsFromUsr");
    if (!original || (selfUsername.length > 0 && [originalFrom isEqualToString:selfUsername])) return NO;

    NSString *operatorName = WCGestureRevokeOperatorName(replaceMessage);
    if ([operatorName isEqualToString:selfUsername]) return NO;
    NSUInteger createTime = WCGestureUIntegerValue(original, @"m_uiCreateTime");
    NSDate *messageDate = [NSDate dateWithTimeIntervalSince1970:createTime];
    NSString *summary = WCGestureContentSummary(original);
    WCGestureAntiRevokeAppendRecord(session, operatorName, original, summary, messageDate);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *localTemplate = [defaults stringForKey:WCGestureAntiRevokeLocalTemplateKey];
    if (localTemplate.length == 0) localTemplate = WCGestureDefaultLocalRevokeTemplate;

    NSInteger promptStyle = [defaults integerForKey:WCGestureAntiRevokePromptStyleKey];
    if (promptStyle == 1) {
        WCGestureRememberSidePrompt(original, @"已拦截撤回", (unsigned long long)serverID);
    } else {
        id localMessage = WCGestureNewMessageWrap(10000);
        if (!localMessage) return NO;
        WCGestureSafeSetValue(localMessage, @"m_nsFromUsr", originalFrom);
        WCGestureSafeSetValue(localMessage, @"m_nsToUsr", WCGestureStringValue(original, @"m_nsToUsr"));
        WCGestureSafeSetValue(localMessage, @"m_uiStatus", @4);
        NSString *localPromptContent = WCGestureApplyRevokeTemplate(localTemplate, operatorName, summary, messageDate);
        WCGestureSafeSetValue(localMessage, @"m_nsContent", localPromptContent);
        WCGestureSafeSetValue(localMessage, @"m_uiCreateTime", @(createTime + 1));
        if (!WCGestureInsertLocalMessage(messageManager, session, localMessage)) return NO;
        WCGestureRememberLocalPromptContent(localPromptContent);
    }
    WCLog(@"已拦截 %@ 的撤回消息：%@", operatorName, summary);

    if (![defaults boolForKey:WCGestureAntiRevokeNotifySenderKey]) return YES;
    NSTimeInterval filter = [defaults doubleForKey:WCGestureAntiRevokeTimeFilterKey];
    NSTimeInterval age = [NSDate date].timeIntervalSince1970 - createTime;
    if (filter > 0.0 && age > filter) return YES;

    NSString *replyTemplate = [defaults stringForKey:WCGestureAntiRevokeReplyTemplateKey];
    if (replyTemplate.length == 0) replyTemplate = WCGestureDefaultRevokeReplyTemplate;
    NSString *replyText = WCGestureApplyRevokeTemplate(replyTemplate, operatorName, summary, messageDate);
    id reply = WCGestureNewMessageWrap(1);
    if (!reply) return YES;
    NSString *target = [session containsString:@"@chatroom"] ? session : originalFrom;
    WCGestureSafeSetValue(reply, @"m_nsContent", replyText);
    WCGestureSafeSetValue(reply, @"m_nsFromUsr", selfUsername);
    WCGestureSafeSetValue(reply, @"m_nsToUsr", target);
    WCGestureSafeSetValue(reply, @"m_uiStatus", @4);
    WCGestureSafeSetValue(reply, @"m_uiCreateTime", @((NSUInteger)[NSDate date].timeIntervalSince1970));
    WCGestureSendMessage(messageManager, target, reply);
    WCLog(@"已向撤回者发送提示（会话：%@）", target);
    return YES;
}


BOOL WCGestureAntiRevokeHandle(id manager, id incomingMessage) {
    @try {
        return WCHandleRevokeMessage(manager, incomingMessage);
    } @catch (NSException *exception) {
        WCLog(@"防撤回回退原逻辑：%@", exception.name);
        return NO;
    }
}

NSArray<NSDictionary *> *WCGestureAntiRevokeRecords(void) {
    @synchronized (WCGestureAntiRevokeMemoryRecords()) {
        return [WCGestureAntiRevokeMemoryRecords() copy];
    }
}
NSString *WCGestureAntiRevokeDefaultTemplate(BOOL reply) {
    return reply ? WCGestureDefaultRevokeReplyTemplate : WCGestureDefaultLocalRevokeTemplate;
}

NSString *WCGestureAntiRevokeMessageTypeName(NSUInteger type) {
    return WCGestureMessageTypeName(type);
}
