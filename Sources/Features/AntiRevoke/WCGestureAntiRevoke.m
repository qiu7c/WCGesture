#import "Sources/API/WCGestureInternal.h"

// Parse the actual revoke payload instead of matching a displayed phrase.
@interface WCRevokePayload : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *path;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableString *> *fields;
@end

@implementation WCRevokePayload
- (instancetype)init {
    self = [super init];
    if (self) {
        _path = [NSMutableArray array];
        _fields = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)uri
 qualifiedName:(NSString *)qualified attributes:(NSDictionary<NSString *, NSString *> *)attributes {
    [self.path addObject:name];
    if (self.path.count >= 2 && [self.path[self.path.count - 2] isEqualToString:@"revokemsg"] &&
        [@[@"session", @"newmsgid", @"replacemsg"] containsObject:name]) {
        // Duplicate fields are ambiguous; fail back to WeChat.
        if (self.fields[name]) { [parser abortParsing]; return; }
        self.fields[name] = [NSMutableString string];
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)text {
    if (self.path.count >= 2 && [self.path[self.path.count - 2] isEqualToString:@"revokemsg"]) {
        [self.fields[self.path.lastObject] appendString:text];
    }
}
- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)data {
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) [self parser:parser foundCharacters:text];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified {
    [self.path removeLastObject];
}
@end

BOOL WCGestureAntiRevokeHandle(id manager, id incomingMessage) {
    if (!WCGestureEnabled(WCGestureAntiRevokeEnabledKey) || !incomingMessage) return NO;
    @try {
        NSString *xml = WCTweakSafeValue(incomingMessage, @"m_nsContent");
        if (![xml isKindOfClass:NSString.class] || xml.length > 65536 ||
            ![xml containsString:@"revokemsg"]) return NO;
        WCRevokePayload *payload = [WCRevokePayload new];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
        parser.shouldResolveExternalEntities = NO;
        parser.delegate = payload;
        if (![parser parse]) return NO;
        NSString *session = payload.fields[@"session"];
        NSString *identifier = payload.fields[@"newmsgid"];
        NSString *replacement = payload.fields[@"replacemsg"];
        long long serverID = 0;
        NSScanner *scanner = [NSScanner scannerWithString:identifier ?: @""];
        if (!session.length || !replacement.length || ![scanner scanLongLong:&serverID] ||
            !scanner.isAtEnd || serverID <= 0) return NO;
        NSString *selfUser = WCCurrentUserWXID();
        if (!selfUser.length || [replacement hasPrefix:@"你撤回"] || [replacement hasPrefix:@"You recalled"]) return NO;
        if (![manager respondsToSelector:@selector(GetMsg:n64SvrID:)]) return NO;
        id original = [manager GetMsg:session n64SvrID:serverID];
        NSString *from = WCTweakSafeValue(original, @"m_nsFromUsr");
        if (!original || ![from isKindOfClass:NSString.class] || !from.length || [from isEqualToString:selfUser]) return NO;
        // Skip the destructive native handler only after verifying the stored
        // original. No outgoing messages or database writes are needed.
        dispatch_async(dispatch_get_main_queue(), ^{ WCShowToast(@"已保留一条对方撤回的消息"); });
        return YES;
    } @catch (NSException *exception) {
        WCLog(@"防撤回回退原逻辑：%@", exception.name);
        return NO;
    }
}
