#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import <stdlib.h>
#import "Sources/API/WCGestureInternal.h"

// WeChatX descriptor table 0x784688; dispatcher 0x223dcc.
typedef struct { const char *className; const char *selector; unsigned kind; BOOL meta; } WCAdDescriptor;
@interface WCAdHook : NSObject
@property (nonatomic, assign) Class host;
@property (nonatomic) SEL selector;
@property (nonatomic) IMP original;
@property (nonatomic) IMP replacement;
@end
@implementation WCAdHook
@end
static NSMutableArray<WCAdHook *> *WCAdHooks;
static BOOL WCAdApplied;
BOOL WCGestureAdBlockerEnabled(void) { return WCGestureEnabled(WCGestureAdBlockerEnabledKey); }
static IMP WCAdOriginal(id object, SEL selector) {
    for (Class cls=object_getClass(object);cls;cls=class_getSuperclass(cls))
        for (WCAdHook *hook in WCAdHooks) if (hook.host==cls && hook.selector==selector) return hook.original;
    return NULL;
}
static NSArray<NSString *> *WCAdEventNames(void) {
    static NSArray *names;static dispatch_once_t once;
    dispatch_once(&once,^{names=@[@"adDataReport",@"getAdIdInfo",@"showSplashAd",@"shouldShowSplashAd",@"custom_event_wxAdDelayReport",@"openADCanvas",@"handleAdAction",@"getadvert",@"getAdPreloadData"];});return names;
}
static NSString *WCAdText(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSURL.class]) return [value absoluteString];
    if ([value isKindOfClass:NSDictionary.class]) {
        for(NSString *key in @[@"name",@"event",@"eventName",@"apiName",@"functionName",@"reqUrl"])
            if([value[key] isKindOfClass:NSString.class])return value[key];
    }
    // The sample's nine selector candidates, not inferred property names.
    for(NSString *name in WCAdEventNames()) {
        SEL selector=NSSelectorFromString(name);Method getter=class_getInstanceMethod(object_getClass(value),selector);
        if(!getter || method_getNumberOfArguments(getter)!=2)continue;
        char type[2]={0};method_getReturnType(getter,type,sizeof(type));if(type[0]!='@')continue;
        id text=((id(*)(id,SEL))objc_msgSend)(value,selector);if([text isKindOfClass:NSString.class])return text;
    }return nil;
}
static BOOL WCAdContains(NSString *text, NSArray<NSString *> *markers) {
    if (!text) return NO;
    for (NSString *marker in markers) if ([text rangeOfString:marker options:NSCaseInsensitiveSearch].location!=NSNotFound) return YES;
    return NO;
}
NSString *WCGestureAdBlockerRewrittenURLString(NSString *value) {
    if (!WCGestureAdBlockerEnabled()) return value;
    return WCAdContains(value,@[@"about:blank",@"mp/getappmsgad",@"/ad.wx.com",@"ad_data",@"/wxfile://usr/ad/",@"advert_group"])?nil:value;
}
static BOOL WCAdEvent(id value) {
    NSString *text=WCAdText(value);return text && [WCAdEventNames() containsObject:text];
}
static BOOL WCAdWebText(id value) {
    return WCAdContains(WCAdText(value),@[@"mp/getappmsgad",@"mp/appmsgreport",@"mp/wapcommreport",@"ad_slot_data",@"adData:",@"advertisement"]);
}
static BOOL WCAdScript(id value) {
    NSString *text=WCAdText(value);if (!text || [text hasPrefix:@"this.__wxLibrary"]) return NO;
    return WCAdContains(text,@[@"getadvert",@"getAdPreloadData",@"_ads_",@"/ads_",@"advert_group",@"advertisement_",@"ad_posid",@"custom_event_wxAdDelayReport"])
        || [text isEqual:@"adDataReport"] || [text isEqual:@"shouldShowSplashAd"];
}
static id WCAdCleanJS(id value, NSUInteger depth) {
    // Limit comes from original helper 0x2265ac.
    if (depth>=17) return nil;
    if ([value isKindOfClass:NSString.class]) {
        if ([value hasPrefix:@"this.__wxLibrary"]) return value;
        static NSRegularExpression *regex;static dispatch_once_t once;
        dispatch_once(&once,^{regex=[NSRegularExpression regularExpressionWithPattern:@"advert_group|getadvert|getAdPreloadData|ad_posid|_ads_|/ads_|advertisement_" options:0 error:nil];});
        NSRange match=[regex rangeOfFirstMatchInString:value options:0 range:NSMakeRange(0,[value length])];
        return match.location==NSNotFound?value:[value stringByReplacingOccurrencesOfString:[value substringWithRange:match] withString:@"orz"];
    }
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *array=[NSMutableArray array];for (id item in value) [array addObject:WCAdCleanJS(item,depth+1) ?: NSNull.null];return array;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *dictionary=[NSMutableDictionary dictionary];for (id key in value) dictionary[key]=WCAdCleanJS(value[key],depth+1) ?: NSNull.null;return dictionary;
    }
    return value;
}
static BOOL WCAdHasField(id item, NSString *field) { SEL selector=NSSelectorFromString(field);return [item respondsToSelector:selector] && ((id(*)(id,SEL))objc_msgSend)(item,selector)!=nil; }
static id WCAdCommentFilter(id value) {
    if (![value isKindOfClass:NSArray.class]) return WCAdHasField(value,@"advertisementInfo")?nil:value;
    NSMutableArray *items=[NSMutableArray array];for (id item in value) if (!WCAdHasField(item,@"advertisementInfo")) [items addObject:item];return items;
}
static BOOL WCAdIsFinderAd(id item) {
    SEL selector=NSSelectorFromString(@"isAd");return [item respondsToSelector:selector] && ((BOOL(*)(id,SEL))objc_msgSend)(item,selector);
}
static void WCAdNoop(id object, SEL selector) { (void)object;(void)selector; }
static uintptr_t WCAdZero(id object, SEL selector) { (void)object;(void)selector;return 0; }
static double WCAdFloatZero(id object, SEL selector) { (void)object;(void)selector;return 0; }
static uintptr_t WCAdOne(id object, SEL selector) { (void)object;(void)selector;return 1; }
static id WCAdEmptyArray(id object, SEL selector) { (void)object;(void)selector;return [NSMutableArray array]; }
static id WCAdEmptyData(id object, SEL selector) { (void)object;(void)selector;return [NSData data]; }
static void WCAdSetZero(id object, SEL selector, uintptr_t value) { (void)value;((void(*)(id,SEL,uintptr_t))WCAdOriginal(object,selector))(object,selector,0); }
static void WCAdSetOne(id object, SEL selector, uintptr_t value) { (void)value;((void(*)(id,SEL,uintptr_t))WCAdOriginal(object,selector))(object,selector,1); }
static void WCAdSetObjectNil(id object, SEL selector, id value) { (void)value;((void(*)(id,SEL,id))WCAdOriginal(object,selector))(object,selector,nil); }
static void WCAdSetDoubleZero(id object, SEL selector, double value) { (void)value;((void(*)(id,SEL,double))WCAdOriginal(object,selector))(object,selector,0); }
static id WCAdFinderFactory(id object, SEL selector, id value) {
    id result=((id(*)(id,SEL,id))WCAdOriginal(object,selector))(object,selector,value);
    if (WCAdHasField(value,@"adInfo")) return nil;
    NSString *className=NSStringFromClass([result class]);
    for(NSString *marker in @[@"Advertise",@"Advertisement",@"FinderObjectAdInfo",@"WCFinderAd",@"WCAd",@"AdInfo"]) if([className containsString:marker])return nil;
    return result;
}
static id WCAdGetComments(id object, SEL selector) { return WCAdCommentFilter(((id(*)(id,SEL))WCAdOriginal(object,selector))(object,selector)); }
static void WCAdSetComments(id object, SEL selector, id value) { ((void(*)(id,SEL,id))WCAdOriginal(object,selector))(object,selector,WCAdCommentFilter(value)); }
static void WCAdCall3(id object, SEL selector, id event, id a, id b) { if (!WCAdEvent(event)) ((void(*)(id,SEL,id,id,id))WCAdOriginal(object,selector))(object,selector,event,a,b); }
static void WCAdCall2(id object, SEL selector, id event, id a) { if (!WCAdEvent(event)) ((void(*)(id,SEL,id,id))WCAdOriginal(object,selector))(object,selector,event,a); }

// Init wrappers preserve the native +1 return convention. Trailing arguments
// are accepted only for ARM64 general-register types, never floats/structs.
// Init self is consumed, including early nil returns (Clang ARC init family).
typedef id (*WCAdInit1IMP)(__attribute__((ns_consumed)) id,SEL,id) __attribute__((ns_returns_retained));
typedef id (*WCAdInit2IMP)(__attribute__((ns_consumed)) id,SEL,id,uintptr_t) __attribute__((ns_returns_retained));
typedef id (*WCAdInit3IMP)(__attribute__((ns_consumed)) id,SEL,id,uintptr_t,uintptr_t) __attribute__((ns_returns_retained));
typedef id (*WCAdInit4IMP)(__attribute__((ns_consumed)) id,SEL,id,uintptr_t,uintptr_t,uintptr_t) __attribute__((ns_returns_retained));
static id WCAdBridgeInit(__attribute__((ns_consumed)) id object,SEL selector,id event,id context) NS_RETURNS_RETAINED;
static id WCAdBridgeInit(__attribute__((ns_consumed)) id object,SEL selector,id event,id context) {
    BOOL blocked=WCAdEvent(event);return ((WCAdInit2IMP)WCAdOriginal(object,selector))(object,selector,blocked?nil:event,blocked?0:(uintptr_t)(__bridge void *)context);
}
static id WCAdEventInit(__attribute__((ns_consumed)) id object,SEL selector,id delegate,id parameters) NS_RETURNS_RETAINED;
static id WCAdEventInit(__attribute__((ns_consumed)) id object,SEL selector,id delegate,id parameters) {
    if ([parameters respondsToSelector:@selector(objectForKey:)])
        for (NSString *key in @[@"name",@"event",@"eventName",@"apiName",@"functionName",@"reqUrl",@"ad_slot_data"])
            if (WCAdWebText([parameters objectForKey:key])) return nil;
    return ((WCAdInit2IMP)WCAdOriginal(object,selector))(object,selector,delegate,(uintptr_t)(__bridge void *)parameters);
}
static id WCAdFunctionDef(id object,SEL selector,id function,uintptr_t a,uintptr_t b,uintptr_t c,uintptr_t d) {
    if (WCAdWebText(function)) return nil;
    return ((id(*)(id,SEL,id,uintptr_t,uintptr_t,uintptr_t,uintptr_t))WCAdOriginal(object,selector))(object,selector,function,a,b,c,d);
}
static id WCAdInvokeContext(id object,SEL selector,id context) {
    Class cls=NSClassFromString(@"JSContext");SEL args=NSSelectorFromString(@"currentArguments");
    NSArray *arguments=[cls respondsToSelector:args]?((id(*)(id,SEL))objc_msgSend)(cls,args):nil;
    for (id argument in arguments) if (WCAdScript([argument description])) { context=nil;break; }
    return ((id(*)(id,SEL,id))WCAdOriginal(object,selector))(object,selector,context);
}
static id WCAdJSInit(__attribute__((ns_consumed)) id object,SEL selector,id target,id function,id args) NS_RETURNS_RETAINED;
static id WCAdJSInit(__attribute__((ns_consumed)) id object,SEL selector,id target,id function,id args) {
    id clean=[args isKindOfClass:NSArray.class]?WCAdCleanJS(args,0):@[];
    return ((WCAdInit3IMP)WCAdOriginal(object,selector))(object,selector,target,(uintptr_t)(__bridge void *)function,(uintptr_t)(__bridge void *)clean);
}
static id WCAdScriptInit(__attribute__((ns_consumed)) id object,SEL selector,id script) NS_RETURNS_RETAINED;
static id WCAdScriptInit(__attribute__((ns_consumed)) id object,SEL selector,id script) { return ((WCAdInit1IMP)WCAdOriginal(object,selector))(object,selector,WCAdScript(script)?nil:script); }
static id WCAdFinderInit4(__attribute__((ns_consumed)) id object,SEL selector,id item,uintptr_t a,uintptr_t b,uintptr_t c) NS_RETURNS_RETAINED;
static id WCAdFinderInit4(__attribute__((ns_consumed)) id object,SEL selector,id item,uintptr_t a,uintptr_t b,uintptr_t c) { return WCAdIsFinderAd(item)?nil:((WCAdInit4IMP)WCAdOriginal(object,selector))(object,selector,item,a,b,c); }
static id WCAdFinderInit3(__attribute__((ns_consumed)) id object,SEL selector,id item,uintptr_t a,uintptr_t b) NS_RETURNS_RETAINED;
static id WCAdFinderInit3(__attribute__((ns_consumed)) id object,SEL selector,id item,uintptr_t a,uintptr_t b) { return WCAdIsFinderAd(item)?nil:((WCAdInit3IMP)WCAdOriginal(object,selector))(object,selector,item,a,b); }
static id WCAdFinderInit2(__attribute__((ns_consumed)) id object,SEL selector,id item,uintptr_t a) NS_RETURNS_RETAINED;
static id WCAdFinderInit2(__attribute__((ns_consumed)) id object,SEL selector,id item,uintptr_t a) { return WCAdIsFinderAd(item)?nil:((WCAdInit2IMP)WCAdOriginal(object,selector))(object,selector,item,a); }
static id WCAdPlugins(id object,SEL selector) {
    id result=((id(*)(id,SEL))WCAdOriginal(object,selector))(object,selector);
    if (![result isKindOfClass:NSArray.class]) return result;
    NSMutableArray *items=[NSMutableArray array];for (id plugin in result) if (![NSStringFromClass([plugin class]) containsString:@"MagicSclBrandAdFlutterPlugin"]) [items addObject:plugin];return items;
}
static id WCAdFormInit(__attribute__((ns_consumed)) id object,SEL selector,id a,uintptr_t b,uintptr_t c,uintptr_t d) NS_RETURNS_RETAINED;
static id WCAdFormInit(__attribute__((ns_consumed)) id object,SEL selector,id a,uintptr_t b,uintptr_t c,uintptr_t d) { (void)a;(void)b;(void)c;(void)d;return ((WCAdInit4IMP)WCAdOriginal(object,selector))(object,selector,nil,0,0,0); }
static id WCAdNilInit(__attribute__((ns_consumed)) id object,SEL selector) NS_RETURNS_RETAINED;
static id WCAdNilInit(__attribute__((ns_consumed)) id object,SEL selector) { (void)object;(void)selector;return nil; }
static id WCAdPackageInit(__attribute__((ns_consumed)) id object,SEL selector,id a) NS_RETURNS_RETAINED;
static id WCAdPackageInit(__attribute__((ns_consumed)) id object,SEL selector,id a) { (void)a;return ((WCAdInit1IMP)WCAdOriginal(object,selector))(object,selector,nil); }
static char WCAdType(Method method, NSInteger index) {
    char type[128]={0};if (index<0) method_getReturnType(method,type,sizeof(type));else method_getArgumentType(method,(unsigned)index,type,sizeof(type));
    const char *p=type;while (*p && strchr("rnNoORV",*p)) p++;return *p;
}
static IMP WCAdImplementation(unsigned kind, Method method) {
    unsigned count=method_getNumberOfArguments(method);char ret=WCAdType(method,-1),arg=count>2?WCAdType(method,2):0;
    if (kind>=5) for (unsigned i=3;i<count;i++) if (!strchr("@#:^*cCsSiIlLqQB",WCAdType(method,i))) return NULL;
    switch (kind) {
        case 0:case 1:case 3:if(ret=='v')return (IMP)WCAdNoop;if(ret=='f'||ret=='d')return (IMP)WCAdFloatZero;return ret&&strchr("@#cCsSiIlLqQB^*",ret)?(IMP)WCAdZero:NULL;
        case 2:return ret&&strchr("cCsSiIlLqQB^*",ret)?(IMP)WCAdOne:NULL;
        case 4:return ret=='@'?(IMP)WCAdEmptyArray:NULL;
        case 5:case 6:return ret=='v'&&count==3&&arg&&strchr("cCsSiIlLqQB^*",arg)?(kind==5?(IMP)WCAdSetZero:(IMP)WCAdSetOne):NULL;
        case 7:if(ret!='v'||count!=3)return NULL;return arg=='@'||arg=='#'?(IMP)WCAdSetObjectNil:(arg&&strchr("cCsSiIlLqQB^*",arg)?(IMP)WCAdSetZero:NULL);
        case 8:return ret=='v'&&arg=='d'&&count==3?(IMP)WCAdSetDoubleZero:NULL;
        case 9:return ret=='@'&&arg=='@'&&count==3?(IMP)WCAdFinderFactory:NULL;
        case 10:return ret=='@'&&count==2?(IMP)WCAdGetComments:NULL;
        case 11:return ret=='v'&&arg=='@'&&count==3?(IMP)WCAdSetComments:NULL;
        case 12:return NULL; // Single existing NSURL Logos hook owns this pair.
        case 13:case 16:return ret=='v'&&arg=='@'&&count==5?(IMP)WCAdCall3:NULL;
        case 14:return ret=='@'&&arg=='@'&&count==4?(IMP)WCAdBridgeInit:NULL;
        case 15:return ret=='v'&&arg=='@'&&count==4?(IMP)WCAdCall2:NULL;
        case 17:return ret=='@'&&arg=='@'&&count==4?(IMP)WCAdEventInit:NULL;
        case 18:return ret=='@'&&arg=='@'&&count==7?(IMP)WCAdFunctionDef:NULL;
        case 19:return ret=='@'&&arg=='@'&&count==3?(IMP)WCAdInvokeContext:NULL;
        case 20:return ret=='@'&&arg=='@'&&count==5?(IMP)WCAdJSInit:NULL;
        case 21:return ret=='@'&&arg=='@'&&count==3?(IMP)WCAdScriptInit:NULL;
        case 22:return ret=='@'&&arg=='@'&&count==6?(IMP)WCAdFinderInit4:NULL;
        case 23:return ret=='@'&&arg=='@'&&count==5?(IMP)WCAdFinderInit3:NULL;
        case 24:return ret=='@'&&arg=='@'&&count==4?(IMP)WCAdFinderInit2:NULL;
        case 25:return ret=='@'&&count==2?(IMP)WCAdPlugins:NULL;
        case 26:return ret=='@'&&arg=='@'&&count==6?(IMP)WCAdFormInit:NULL;
        case 27:return ret=='@'&&count==2?(IMP)WCAdEmptyData:NULL;
        case 28:return ret=='@'&&count==2?(IMP)WCAdNilInit:NULL;
        case 29:return ret=='@'&&arg=='@'&&count==3?(IMP)WCAdPackageInit:NULL;
    }return NULL;
}
static const WCAdDescriptor WCAdDescriptors[] = {
    {"WebviewJSEventHandler_adDataReport","handleJSEvent:HandlerFacade:ExtraData:",0,NO},
    {"WebviewJSEventHandler_getAdIdInfo","handleJSEvent:HandlerFacade:ExtraData:",0,NO},
    {"WebviewJSEventHandler_getAdIdInfo","checkUrlValid",1,NO},
    {"WAJSEventHandler_showSplashAd","handleJSEvent:",0,NO},
    {"WAJSEventHandler_showSplashAdMenu","handleJSEvent:",0,NO},
    {"WAJSEventHandler_showSplashAdMenu","handleJSEvent:HandlerFacade:ExtraData:",0,NO},
    {"WAJSEventHandler_adOperateWXData","handleJSEvent:HandlerFacade:ExtraData:",0,NO},
    {"BrandTLExptConfig","isExptNotShowAd",2,NO},
    {"BrandTLFlutterViewController","enableAd",1,NO},
    {"BrandTLFlutterViewController","reportAdBrandCardOnClick",0,NO},
    {"BrandTLCanvasCardMgr","isAdRequestOpen",1,YES},
    {"BrandTLCanvasCardMgr","isAdCardOpen",1,YES},
    {"BrandTLCanvasCardMgr","handleBizAdNotifyNewXml:",0,NO},
    {"BSTLExptConfig","isExptNotShowAd",2,NO},
    {"BrandTimelineMsgMgr","isExptNotShowAd",2,NO},
    {"BoxBrandTimelineMsgMgr","isExptNotShowAd",2,NO},
    {"BrandTimelineMsgMgr","getAdCardExposeRealQuota",1,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposeRealQuota",1,NO},
    {"BrandTimelineMsgMgr","getAdCardExposeQuotaFromServerConfig",1,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposeQuotaFromServerConfig",1,NO},
    {"BrandTimelineMsgMgr","getAdCardExposeRealQuotaFromServerConfig",1,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposeRealQuotaFromServerConfig",1,NO},
    {"BrandTimelineMsgMgr","setAdCardExposeQuotaFromServerConfig:",0,NO},
    {"BoxBrandTimelineMsgMgr","setAdCardExposeQuotaFromServerConfig:",0,NO},
    {"BrandTimelineMsgMgr","getAdCardExposeQuotaFromPrefetch",1,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposeQuotaFromPrefetch",1,NO},
    {"BrandTimelineMsgMgr","setAdCardExposeQuotaFromPrefetch:",0,NO},
    {"BoxBrandTimelineMsgMgr","setAdCardExposeQuotaFromPrefetch:",0,NO},
    {"BrandTimelineMsgMgr","getAdCardExposedJsonInfoInToday",3,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposedJsonInfoInToday",3,NO},
    {"BrandTimelineMsgMgr","getAdCardExposeCountInToday",1,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposeCountInToday",1,NO},
    {"BrandTimelineMsgMgr","getAdCardExposeInToday",3,NO},
    {"BoxBrandTimelineMsgMgr","getAdCardExposeInToday",3,NO},
    {"BrandTimelineMsgMgr","getInsertedAdCardListWithLimit:",4,NO},
    {"BoxBrandTimelineMsgMgr","getInsertedAdCardListWithLimit:",4,NO},
    {"BrandTimelineMsgMgr","isAdDataLegal:",1,NO},
    {"BoxBrandTimelineMsgMgr","isAdDataLegal:",1,NO},
    {"BoxBrandTLFlutterViewController","enableAd",1,NO},
    {"BSTimelineFlutterViewController","enableAd",1,NO},
    {"BrandTLFlutterViewController","setEnableAd:",5,NO},
    {"BoxBrandTLFlutterViewController","setEnableAd:",5,NO},
    {"BSTimelineFlutterViewController","setEnableAd:",5,NO},
    {"BoxBrandTLFlutterViewController","reportAdBrandCardOnClick",0,NO},
    {"BSTimelineFlutterViewController","reportAdBrandCardOnClick",0,NO},
    {"MagicAdPushMgrService","onServiceInit",0,NO},
    {"MagicAdPushMgrService","handleAdMsg:",0,NO},
    {"MagicAdPushMgrService","OnGetNewXmlMsg:Type:MsgWrap:",0,NO},
    {"MagicAdPushMgrService","getSpecificSlotMsg:withBizName:",3,NO},
    {"MagicAdPushMgrService","clearSpecificSlotMsg:withBizName:",2,NO},
    {"WeChat.MagicAdBrandService","getAppConfigWithBizName:",3,NO},
    {"_TtC6WeChat19MagicAdBrandService","getAppConfigWithBizName:",3,NO},
    {"WeChat.MagicAdBrandService","onServiceInit",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","onServiceInit",0,NO},
    {"WeChat.MagicAdBrandService","createBrandServiceBizWithScene:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","createBrandServiceBizWithScene:",0,NO},
    {"WeChat.MagicAdBrandService","recreateBrandServiceBizWithScene:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","recreateBrandServiceBizWithScene:",0,NO},
    {"WeChat.MagicAdBrandService","destroyBrandServiceBizWithScene:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","destroyBrandServiceBizWithScene:",0,NO},
    {"WeChat.MagicAdBrandService","notifyAdServerInfoEventWithFeedsType:adInfo:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","notifyAdServerInfoEventWithFeedsType:adInfo:",0,NO},
    {"WeChat.MagicAdBrandService","notifyFrameSetInfoWithMsgId:frameSetName:frameSetData:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","notifyFrameSetInfoWithMsgId:frameSetName:frameSetData:",0,NO},
    {"WeChat.MagicAdBrandService","notifyStateChangeWithEventName:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","notifyStateChangeWithEventName:",0,NO},
    {"WeChat.MagicAdBrandService","notifyResortStatusWithTaskId:scene:event:bizTLResortEventInfo:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","notifyResortStatusWithTaskId:scene:event:bizTLResortEventInfo:",0,NO},
    {"WeChat.MagicAdBrandService","getDynamicCardType",1,NO},
    {"_TtC6WeChat19MagicAdBrandService","getDynamicCardType",1,NO},
    {"WeChat.MagicAdBrandService","shouldPreLayoutWhenExpose",1,NO},
    {"_TtC6WeChat19MagicAdBrandService","shouldPreLayoutWhenExpose",1,NO},
    {"WeChat.MagicAdBrandService","isBrandTimelineOpen",1,NO},
    {"_TtC6WeChat19MagicAdBrandService","isBrandTimelineOpen",1,NO},
    {"WeChat.MagicAdBrandServiceBiz","onJSException:msg:extra:",0,NO},
    {"_TtC6WeChat22MagicAdBrandServiceBiz","onJSException:msg:extra:",0,NO},
    {"WeChat.MagicAdBrandServiceBiz","onMainScriptInjected:",0,NO},
    {"_TtC6WeChat22MagicAdBrandServiceBiz","onMainScriptInjected:",0,NO},
    {"WeChat.MagicAdPublicService","provideConfig:",3,NO},
    {"_TtC6WeChat20MagicAdPublicService","provideConfig:",3,NO},
    {"WeChat.MagicAdPublicService","onJSException:msg:extra:",0,NO},
    {"_TtC6WeChat20MagicAdPublicService","onJSException:msg:extra:",0,NO},
    {"WeChat.MagicAdPublicService","onDestroy:",0,NO},
    {"_TtC6WeChat20MagicAdPublicService","onDestroy:",0,NO},
    {"WeChat.MagicAdPublicService","onMainScriptInjected:",0,NO},
    {"_TtC6WeChat20MagicAdPublicService","onMainScriptInjected:",0,NO},
    {"WCAdFinderInfo","isValid",1,NO},
    {"WeChat.MBJsEventOnFinderMediaAdPreload","startPreloadAdMedia",3,YES},
    {"_TtC6WeChat31MBJsEventOnFinderMediaAdPreload","startPreloadAdMedia",3,YES},
    {"FinderObjectAdInfo","adDesc",3,NO},
    {"FinderObjectAdInfo","adH5",3,NO},
    {"FinderObjectAdInfo","adLeadLink",3,NO},
    {"FinderObjectAdInfo","adMiniApp",3,NO},
    {"FinderObjectAdInfo","adItems",3,NO},
    {"WCFinderRouterHelper","pushFinderAdPageViewControllerWithEncrytedObjectidTid:nonceId:currentNavController:enterScene:customParam:reportModel:cardType:requestScene:functionalParams:",0,YES},
    {"WCFinderDataItem","finderDataItemFromObject:",9,YES},
    {"WAAppTask","isSplashADFinished",2,NO},
    {"WAAppTaskSplashADConfig","canShowSplashADWindow",1,NO},
    {"WAAppTaskSplashADConfig","canHotStartShowSplashAD",1,NO},
    {"WAAppTaskSplashADConfig","splashADHasContent",1,NO},
    {"WAAppTaskSplashADConfig","setSplashADEnableNumber:",7,NO},
    {"WAAppTaskSplashADConfig","setAdWorkerEnableNumber:",7,NO},
    {"WAAppTaskSplashADConfig","setSplashADMenuParams:",7,NO},
    {"WAAppTaskSplashADConfig","setSplashADWindow:",7,NO},
    {"WAAppTaskSplashADConfig","setSplashADViewController:",7,NO},
    {"WAAppTaskSplashADConfig","setAdOperateCallClientCostTime:",8,NO},
    {"WAAppTaskSplashADConfig","setAdOperateCallTime:",8,NO},
    {"WASplashADWindow","setAdRootViewController:",0,NO},
    {"WAJSEventHandler_enableSplashAdHotStart","handleJSEvent:",0,NO},
    {"WAJSEventHandler_getAdPushMsg","handleJSEvent:",0,NO},
    {"WAJSEventHandler_clearAdPushMsg","handleJSEvent:",0,NO},
    {"WAAppTask","splashAD_sendShouldShowIfAllowed",1,NO},
    {"WAAppTask","splashAd_checkForceShowSplashAdWhenHotStart",1,NO},
    {"WAAppTask","splashAD_handleShouldShowEvent",0,NO},
    {"WAAppTask","splashAD_handleSplashADContainerIsPreload:",5,NO},
    {"WAAppTask","mainThread_splashAD_handleSplashADContainerIsPreload:",5,NO},
    {"WAAppTask","splashAD_createSplashADWindow",0,NO},
    {"WAAppTask","splashAD_setAllowHotStartSplashAD:interval:",0,NO},
    {"WAAppTask","setIsSplashADFinished:",6,NO},
    {"WAAppTaskSplashADConfig","splashADEnableNumber",3,NO},
    {"WAAppTaskSplashADConfig","adWorkerEnableNumber",3,NO},
    {"WAAppTaskSplashADConfig","splashADAllowNoPreloadNumber",3,NO},
    {"WAAppTaskSplashADConfig","splashADAllowGameNumber",3,NO},
    {"WAAppTaskSplashADConfig","splashADMenuParams",3,NO},
    {"WAAppTaskSplashADConfig","splashADWindow",3,NO},
    {"WAAppTaskSplashADConfig","splashADViewController",3,NO},
    {"WAAppTaskSplashADConfig","launchShow",1,NO},
    {"WAAppTaskSplashADConfig","launchDidAppear",1,NO},
    {"WAAppTaskSplashADConfig","isHotStart",1,NO},
    {"WAAppTaskSplashADConfig","isPreloaded",1,NO},
    {"WAAppTaskSplashADConfig","injectFinishedWhenSendSholdShowSplashAD",1,NO},
    {"WAAppTaskSplashADConfig","setSplashADHasContent:",5,NO},
    {"WAAppTaskSplashADConfig","setCanShowSplashADWindow:",5,NO},
    {"WAAppTaskSplashADConfig","setCanHotStartShowSplashAD:",5,NO},
    {"WAAppTaskSplashADConfig","setLaunchShow:",5,NO},
    {"WAAppTaskSplashADConfig","setLaunchDidAppear:",5,NO},
    {"WAAppTaskSplashADConfig","setIsHotStart:",5,NO},
    {"WAAppTaskSplashADConfig","setIsPreloaded:",5,NO},
    {"WAAppTaskSplashADConfig","setInjectFinishedWhenSendSholdShowSplashAD:",5,NO},
    {"WAAppTaskSplashADConfig","setSplashADAllowNoPreloadNumber:",7,NO},
    {"WAAppTaskSplashADConfig","setSplashADAllowGameNumber:",7,NO},
    {"WAJSEventHandler_adOperateWXData","handleJSEvent:",0,NO},
    {"MBEventHandler_getAdPushMsg","invoke:",0,NO},
    {"MBEventHandler_getOldAdInfo","invoke:",0,NO},
    {"MBEventHandler_setAdCardRequestInfo","invoke:",0,NO},
    {"MBEventHandler_setAdRequestInfo","invoke:",0,NO},
    {"MBEventHandler_setFeedsAdRequestInfo","invoke:",0,NO},
    {"WCAdvertiseDataHelper","saveAdvertiseMsgXmlDatas",0,NO},
    {"WCAdvertiseDataHelper","saveAdPullCompareInfo:",0,NO},
    {"WCAdvertiseDataHelper","saveAdvertiseDatas",0,NO},
    {"WCAdvertiseDataHelper","reuseAdvertiseData:extInfo:",0,NO},
    {"WCAdvertiseDataHelper","reuseAdvertiseData:isFromServerPush:",0,NO},
    {"WCAdvertiseDataHelper","addAdvertiseDataList:",0,NO},
    {"WCAdvertiseDataHelper","LL_addAdvertiseData:IsAtFriend:needUpdateCreateTime:",0,NO},
    {"WCAdvertiseDataHelper","addAdvertiseData:needUpdateCreateTime:",0,NO},
    {"WCAdvertiseDataHelper","updateAdvertiseData:",0,NO},
    {"WCAdvertiseDataHelper","updateAdvertiseDataList:",0,NO},
    {"WCAdvertiseDataHelper","updateAdvertiseDataExceptCreateTime:",0,NO},
    {"WCAdvertiseDataHelper","updateAdvertiseDataWithClickTimestamp:",0,NO},
    {"WCAdvertiseDataHelper","getAdvertiseDataByCurMinTime:MaxTime:",4,NO},
    {"WCAdvertiseDataHelper","getAdvertiseDataByCurMinTime:MaxTime:checkDataValid:",4,NO},
    {"WCAdvertiseDataHelper","getTopAdvertiseDataByTopNumber:",4,NO},
    {"WCAdvertiseDataHelper","getAdvertiseItemByID:",3,NO},
    {"WCAdvertiseDataHelper","isAdvertiseItemExistsWithID:",1,NO},
    {"WCAdvertiseDataHelper","getAdvertiseMsgXmlList",4,NO},
    {"WCAdvertiseDataHelper","addAdvertiseMsgXml:",0,NO},
    {"WCAdvertiseDataHelper","fetchAdPullCompareInfo:",3,NO},
    {"WCAdvertiseDataHelper","tryToStoreWuidFromHistoryAd",0,NO},
    {"WCAdvertiseDataHelper","tryLoadAdvertiseData",0,NO},
    {"WCAdvertiseDataHelper","IsAdvertiseDataValid:dataItem:",1,NO},
    {"WCAdvertiseDataHelper","IsAdvertiseDataCanBeReused:dataItem:",1,NO},
    {"WCAdvertiseDataHelper","isAdPreviewExpired:",2,NO},
    {"WCAdvertisePushService","handlePushMsg:",0,NO},
    {"WCCanvasDynamicDataLoader","handleAdCanvasInfoResponse:",0,NO},
    {"SnsTimeLineResponse","advertiseList",4,NO},
    {"SnsTimeLineResponse","advertiseCount",1,NO},
    {"SnsTimeLineResponse","adOpList",4,NO},
    {"SnsTimeLineResponse","advertiseOperationCount",1,NO},
    {"SnsAdPullResponse","advertiseList",4,NO},
    {"SnsAdStorageManager","querySnsAdInfoByTimeSync:endTime:",4,NO},
    {"SnsAdStorageManager","querySnsAdInfoByTimelineList:isDelContinuousAd:",4,NO},
    {"SnsAdStorageManager","getSnsAdInfoById:",3,NO},
    {"SnsAdStorageManager","getAdCanvasInfo:",3,NO},
    {"SnsAdStorageManager","getAdCanvasKey:uxinfo:capability:canvasDynamicInfo:vangoghLibVersion:",3,NO},
    {"WCAdCanvasLoadParams","cacheKey",3,NO},
    {"WCAdCanvasLoadParams","canvasId",3,NO},
    {"WCAdCanvasLoadParams","canvasDynamicInfo",3,NO},
    {"WCAdCanvasLoadParams","dynamicCanvasLibVersion",3,NO},
    {"WCADPageWrap","adID",3,NO},
    {"WCADPageWrap","miniShopRequestId",3,NO},
    {"WCADPageWrap","uxInfo",3,NO},
    {"WCADPageWrap","adType",1,NO},
    {"WCAdSearchH5Info","isValid",1,NO},
    {"WCAdSearchH5Info","fromXML:",3,YES},
    {"WCAdvertiseInfo","h5PageWrap",3,NO},
    {"WCAdvertiseInfo","poiH5PageWrap",3,NO},
    {"WCAdvertiseInfo","setItem:value:forDynamic:",0,YES},
    {"WCAdvertiseInfo","dictionaryFromADDynamicInfo:",3,YES},
    {"WCAdvertiseInfo","adType",1,NO},
    {"WCAdvertiseInfo","adExpired",2,NO},
    {"WCAdvertiseInfo","previewExpiredTime",1,NO},
    {"BrandAdDataParser","adInfoDicForContent:",3,YES},
    {"BrandAdDataParser","adInfoDicForMsgWrap:",3,YES},
    {"BrandAdDataParser","adDataItemForContent:",3,YES},
    {"BrandAdDataParser","adDataItemForMsgWrap:",3,YES},
    {"BrandAdDataParser","bizTypeForAdInfoDic:",3,YES},
    {"BrandAdDataParser","traceIdForAdInfoDic:",3,YES},
    {"BrandAdDataItem","dicAdInfo",3,NO},
    {"BrandAdDataItem","content",3,NO},
    {"WCAdXmlParser","ExtractRecommendAdInfo:ByAdMsgXml:",1,YES},
    {"WCAdXmlParser","setAdCanvasPage:byXmlNode:withSizeType:basicWidth:basicRootFontSize:widthRoundingType:heightRoundingType:",0,YES},
    {"WCAdXmlParser","setAdCanvasInfo:byXmlNode:",0,YES},
    {"WCAdXmlParser","SetAdvertiseXml:ByAdXml:",1,YES},
    {"WCAdXmlParser","setSKAdItems:byXmlNode:",1,YES},
    {"WCAdXmlParser","setAdCanvasExtXml:ByXmlNode:",1,YES},
    {"WCAdXmlParser","SetAdvertiseInfo:ByAdInfoXml:",1,YES},
    {"WCAdXmlParser","SetAdvertiseInfo:ByAdInfo:",1,YES},
    {"ObjectAdItem","adDesc",3,NO},
    {"ObjectAdItem","adH5",3,NO},
    {"ObjectAdItem","adLeadLink",3,NO},
    {"ObjectAdItem","adMiniApp",3,NO},
    {"WCUserComment","adExtInfo",3,NO},
    {"WCUserComment","setAdExtInfo:",7,NO},
    {"WCUserComment","isAdvertiserComment",1,NO},
    {"WCUserComment","setIsAdvertiserComment:",5,NO},
    {"WCUserComment","isRefAdvertiserComment",1,NO},
    {"WCUserComment","setIsRefAdvertiserComment:",5,NO},
    {"WCUserComment","isAdPreferInfo",1,NO},
    {"WCUserComment","setIsAdPreferInfo:",5,NO},
    {"WCUserComment","isAtedAdvertiserComment",1,NO},
    {"WCUserComment","isAdBossFirstComment",1,NO},
    {"WCUserComment","isAdBossFirstLike",1,NO},
    {"WCUserComment","fetchAdFirstCommentQueryForName:",3,NO},
    {"WCUserComment","setAdPreferNickName:",7,NO},
    {"WCUserComment","setAdPreferHeadUrl:",7,NO},
    {"WCUserComment","adAdvertiserFirstCommentDisplayTime",1,NO},
    {"WCUserComment","setAdAdvertiserFirstCommentDisplayTime:",7,NO},
    {"FinderGetBulletCommentResponse","advertisementInfo",3,NO},
    {"FinderPostBulletCommentResponse","advertisementInfo",3,NO},
    {"MegaVideoGetBulletCommentResponse","advertisementInfo",3,NO},
    {"FinderCommentResponse","advertisementInfo",3,NO},
    {"FinderObject","advertisementInfo",3,NO},
    {"WCFinderDataItem","advertisementInfo",3,NO},
    {"WCFinderFeedCommentListObject","advertisementInfo",3,NO},
    {"FinderGetBulletCommentResponse","setAdvertisementInfo:",7,NO},
    {"FinderPostBulletCommentResponse","setAdvertisementInfo:",7,NO},
    {"MegaVideoGetBulletCommentResponse","setAdvertisementInfo:",7,NO},
    {"FinderCommentResponse","setAdvertisementInfo:",7,NO},
    {"FinderObject","setAdvertisementInfo:",7,NO},
    {"WCFinderDataItem","setAdvertisementInfo:",7,NO},
    {"WCFinderFeedCommentListObject","setAdvertisementInfo:",7,NO},
    {"FinderGetBulletCommentResponse","commentInfo",10,NO},
    {"FinderPostBulletCommentResponse","commentInfo",10,NO},
    {"MegaVideoGetBulletCommentResponse","commentInfo",10,NO},
    {"FinderCommentResponse","commentInfo",10,NO},
    {"FinderObject","commentInfo",10,NO},
    {"WCFinderDataItem","commentInfo",10,NO},
    {"WCFinderFeedCommentListObject","commentInfo",10,NO},
    {"FinderGetBulletCommentResponse","setCommentInfo:",11,NO},
    {"FinderPostBulletCommentResponse","setCommentInfo:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setCommentInfo:",11,NO},
    {"FinderCommentResponse","setCommentInfo:",11,NO},
    {"FinderObject","setCommentInfo:",11,NO},
    {"WCFinderDataItem","setCommentInfo:",11,NO},
    {"WCFinderFeedCommentListObject","setCommentInfo:",11,NO},
    {"FinderGetBulletCommentResponse","descComment",10,NO},
    {"FinderPostBulletCommentResponse","descComment",10,NO},
    {"MegaVideoGetBulletCommentResponse","descComment",10,NO},
    {"FinderCommentResponse","descComment",10,NO},
    {"FinderObject","descComment",10,NO},
    {"WCFinderDataItem","descComment",10,NO},
    {"WCFinderFeedCommentListObject","descComment",10,NO},
    {"FinderGetBulletCommentResponse","setDescComment:",11,NO},
    {"FinderPostBulletCommentResponse","setDescComment:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setDescComment:",11,NO},
    {"FinderCommentResponse","setDescComment:",11,NO},
    {"FinderObject","setDescComment:",11,NO},
    {"WCFinderDataItem","setDescComment:",11,NO},
    {"WCFinderFeedCommentListObject","setDescComment:",11,NO},
    {"FinderGetBulletCommentResponse","emojiDescComments",10,NO},
    {"FinderPostBulletCommentResponse","emojiDescComments",10,NO},
    {"MegaVideoGetBulletCommentResponse","emojiDescComments",10,NO},
    {"FinderCommentResponse","emojiDescComments",10,NO},
    {"FinderObject","emojiDescComments",10,NO},
    {"WCFinderDataItem","emojiDescComments",10,NO},
    {"WCFinderFeedCommentListObject","emojiDescComments",10,NO},
    {"FinderGetBulletCommentResponse","setEmojiDescComments:",11,NO},
    {"FinderPostBulletCommentResponse","setEmojiDescComments:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setEmojiDescComments:",11,NO},
    {"FinderCommentResponse","setEmojiDescComments:",11,NO},
    {"FinderObject","setEmojiDescComments:",11,NO},
    {"WCFinderDataItem","setEmojiDescComments:",11,NO},
    {"WCFinderFeedCommentListObject","setEmojiDescComments:",11,NO},
    {"FinderGetBulletCommentResponse","descComments",10,NO},
    {"FinderPostBulletCommentResponse","descComments",10,NO},
    {"MegaVideoGetBulletCommentResponse","descComments",10,NO},
    {"FinderCommentResponse","descComments",10,NO},
    {"FinderObject","descComments",10,NO},
    {"WCFinderDataItem","descComments",10,NO},
    {"WCFinderFeedCommentListObject","descComments",10,NO},
    {"FinderGetBulletCommentResponse","setDescComments:",11,NO},
    {"FinderPostBulletCommentResponse","setDescComments:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setDescComments:",11,NO},
    {"FinderCommentResponse","setDescComments:",11,NO},
    {"FinderObject","setDescComments:",11,NO},
    {"WCFinderDataItem","setDescComments:",11,NO},
    {"WCFinderFeedCommentListObject","setDescComments:",11,NO},
    {"FinderGetBulletCommentResponse","descCommentInfo",10,NO},
    {"FinderPostBulletCommentResponse","descCommentInfo",10,NO},
    {"MegaVideoGetBulletCommentResponse","descCommentInfo",10,NO},
    {"FinderCommentResponse","descCommentInfo",10,NO},
    {"FinderObject","descCommentInfo",10,NO},
    {"WCFinderDataItem","descCommentInfo",10,NO},
    {"WCFinderFeedCommentListObject","descCommentInfo",10,NO},
    {"FinderGetBulletCommentResponse","setDescCommentInfo:",11,NO},
    {"FinderPostBulletCommentResponse","setDescCommentInfo:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setDescCommentInfo:",11,NO},
    {"FinderCommentResponse","setDescCommentInfo:",11,NO},
    {"FinderObject","setDescCommentInfo:",11,NO},
    {"WCFinderDataItem","setDescCommentInfo:",11,NO},
    {"WCFinderFeedCommentListObject","setDescCommentInfo:",11,NO},
    {"FinderGetBulletCommentResponse","commentList",10,NO},
    {"FinderPostBulletCommentResponse","commentList",10,NO},
    {"MegaVideoGetBulletCommentResponse","commentList",10,NO},
    {"FinderCommentResponse","commentList",10,NO},
    {"FinderObject","commentList",10,NO},
    {"WCFinderDataItem","commentList",10,NO},
    {"WCFinderFeedCommentListObject","commentList",10,NO},
    {"FinderGetBulletCommentResponse","setCommentList:",11,NO},
    {"FinderPostBulletCommentResponse","setCommentList:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setCommentList:",11,NO},
    {"FinderCommentResponse","setCommentList:",11,NO},
    {"FinderObject","setCommentList:",11,NO},
    {"WCFinderDataItem","setCommentList:",11,NO},
    {"WCFinderFeedCommentListObject","setCommentList:",11,NO},
    {"FinderGetBulletCommentResponse","exposedComment",10,NO},
    {"FinderPostBulletCommentResponse","exposedComment",10,NO},
    {"MegaVideoGetBulletCommentResponse","exposedComment",10,NO},
    {"FinderCommentResponse","exposedComment",10,NO},
    {"FinderObject","exposedComment",10,NO},
    {"WCFinderDataItem","exposedComment",10,NO},
    {"WCFinderFeedCommentListObject","exposedComment",10,NO},
    {"FinderGetBulletCommentResponse","setExposedComment:",11,NO},
    {"FinderPostBulletCommentResponse","setExposedComment:",11,NO},
    {"MegaVideoGetBulletCommentResponse","setExposedComment:",11,NO},
    {"FinderCommentResponse","setExposedComment:",11,NO},
    {"FinderObject","setExposedComment:",11,NO},
    {"WCFinderDataItem","setExposedComment:",11,NO},
    {"WCFinderFeedCommentListObject","setExposedComment:",11,NO},
    {"WCAdFormWebViewJSLogic","initWithWebView:pageInfo:componentId:qrExtInfo:",26,NO},
    {"BrandTLFlutterViewController","getMagicBrushFlutterPlugins",25,NO},
    {"_TtC6WeChat33MagicAdPublicServicePkgManagement","initWithInstanceName:",29,NO},
    {"WeChat.MagicAdPublicServicePkgManagement","initWithInstanceName:",29,NO},
    {"_TtC6WeChat28MagicSclBrandAdFlutterPlugin","onAttachedToViewController:",0,NO},
    {"_TtC6WeChat28MagicSclBrandAdFlutterPlugin","onDetachedFromEngine:",0,NO},
    {"_TtC6WeChat28MagicSclBrandAdFlutterPlugin","onAttachedToEngine:",0,NO},
    {"WeChat.MagicSclBrandAdFlutterPlugin","onAttachedToViewController:",0,NO},
    {"WeChat.MagicSclBrandAdFlutterPlugin","onDetachedFromEngine:",0,NO},
    {"WeChat.MagicSclBrandAdFlutterPlugin","onAttachedToEngine:",0,NO},
    {"_TtC6WeChat19MagicAdBrandService","requestPreLayoutWhenExposeWithStrategy:",0,NO},
    {"WCAdDB","createPullRecordTable",0,NO},
    {"WCAdDB","createTables",0,NO},
    {"WCAdDB","initDB",0,NO},
    {"AdPushMsgDBMgr","initDB",0,NO},
    {"AdPushMsgDBMgr","insertNewPushMsg:",0,NO},
    {"WCAdvertiseStatMgr","getAdvertiseInfoForItem:",29,NO},
    {"WCAdvertiseStatMgr","logSphereViewWithSphereReportInfo:dataItem:scene:",0,NO},
    {"WCAdvertiseStatMgr","logSphereViewInDetailWithWrapInfo:dataItem:",0,NO},
    {"WCAdvertiseStatMgr","logSphereViewInTimeLineWithWrapInfo:dataItem:",0,NO},
    {"WCAdvertiseStatMgr","logHeadImageH5:",0,NO},
    {"WCAdvertiseStatMgr","logADBrandProfile:",0,NO},
    {"WCAdvertiseStatMgr","logADFloatView:",0,NO},
    {"WCAdvertiseStatMgr","logADPoiH5:",0,NO},
    {"WCAdvertiseStatMgr","logADH5:withUserInfo:reportType:",0,NO},
    {"WCAdvertiseStatMgr","logADH5:",0,NO},
    {"WCAdvertiseStatMgr","logADDetail:dataItem:",0,NO},
    {"WCAdvertiseStatMgr","logADCommentLog:",0,NO},
    {"WCAdvertiseStatMgr","logADBodyLog:",0,NO},
    {"WCAdvertiseStatMgr","reportAllFeedsADLog",0,NO},
    {"WCAdvertiseStorage","PBArrayAdd_oAdvertiseData",0,YES},
    {"WCAdvertiseStorage","PBArrayAdd_uiAdDisplayTime",0,YES},
    {"WCAdvertiseStorage","PBArrayAdd_uiAdCreateTime",0,YES},
    {"WCAdvertiseStorage","PBArrayAdd_nsUsername",0,YES},
    {"WCAdvertiseStorage","PBArrayAdd_nsAdvertiseID",0,YES},
    {"WCAdvertiseStorage","oAdvertiseData",27,NO},
    {"WCAdvertiseDataHelper","m_advertiseList",0,NO},
    {"WCAdvertiseDataHelper","m_advertiseMsgXmlList",0,NO},
    {"WCAdvertiseDataHelper","m_bLoaded",0,NO},
    {"WCAdvertisePushService","OnGetNewXmlMsg:Type:MsgWrap:",0,NO},
    {"WCAdDynamicCanvasServerData","isValid",0,NO},
    {"WCAdDynamicCanvasServerData","fromPBCodingBuffer:",0,YES},
    {"WCAdDynamicCanvasServerData","toPBCodingBuffer",0,NO},
    {"WCAdDynamicCanvasServerData","getPBPropertyTable",0,NO},
    {"WCAdDynamicCanvasPageInfo","fetchRealUxInfo",0,NO},
    {"WCAdDynamicCanvasPageInfo","fetchPageInfoExtraDic",0,NO},
    {"WCAdDynamicCanvasPageInfo","fetchPageInfoDic",0,NO},
    {"WCAdDynamicCanvasPageInfo","fetchLaunchString",0,NO},
    {"WCFinderFeedContentVM","initWithDataItem:scene:dataScene:sessionExtraKey:",22,NO},
    {"WCFinderFeedContentVM","initWithDataItem:scene:dataScene:isFinderIdentity:",22,NO},
    {"WCFinderFeedContentVM","initWithDataItem:scene:dataScene:",23,NO},
    {"WCFinderFeedContentVM","initWithDataItem:scene:sessionExtraKey:",23,NO},
    {"WCFinderFeedContentVM","initWithDataItem:scene:isFinderIdentity:",23,NO},
    {"WCFinderFeedContentVM","initWithDataItem:scene:",24,NO},
    {"WAJSInvoker","invokeInJsContext:",19,NO},
    {"WCJSInvoker","initWithObj:Func:Args:",20,NO},
    {"WCJSInvoker","initWithJavascript:",21,NO},
    {"WCADCanvasInfo","init",28,NO},
    {"WCADBodyWrap","init",28,NO},
    {"ObjectAdContentH5","url",0,NO},
    {"ObjectAdItem","uxinfo",0,NO},
    {"NSURL","URLWithString:",12,YES},
    {"WXSearchJSLogicImpl","functionCall:withParams:withCallbackID:",13,NO},
    {"LocalJSEventHandler_WebAPIBridge","initWithEvent:context:",14,NO},
    {"LocalJSEventHandler_WebAPIBridge","sendEventToJSBridge:Param:",15,NO},
    {"LocalJSLogicBase","sendEvent:handler:result:",16,NO},
    {"FlutterBrandTLApiImplementation","createMagicAdBrandServiceScene:error:",3,NO},
    {"JSEvent","initWithDelegate:parameters:",17,NO},
    {"JSFunctionDef","FuncDefWithFunc:Selector:FuncType:PermissionByteIndex:RunInWebViewType:",18,YES},
    {"JSFunctionDef","FuncDefWithFunc:Selector:FuncType:PermissionBitSet3:RunInWebViewType:",18,YES},
    {"JSFunctionDef","FuncDefWithFunc:Selector:FuncType:PermissionBitSet2:RunInWebViewType:",18,YES},
    {"JSFunctionDef","FuncDefWithFunc:Selector:FuncType:PermissionBitSet:RunInWebViewType:",18,YES},
};

void WCGestureAdBlockerInstallOptionalHooks(void) {
    if (!WCAdHooks) {
        WCAdHooks=[NSMutableArray array];
        for (NSUInteger i=0;i<sizeof(WCAdDescriptors)/sizeof(WCAdDescriptors[0]);i++) {
            WCAdDescriptor row=WCAdDescriptors[i];Class cls=objc_getClass(row.className);if(row.meta)cls=object_getClass(cls);
            SEL selector=sel_registerName(row.selector);Method method=cls?class_getInstanceMethod(cls,selector):NULL;if(!method)continue;
            BOOL duplicate=NO;for(WCAdHook *existing in WCAdHooks) if(existing.host==cls && existing.selector==selector){duplicate=YES;break;}
            if(duplicate)continue;
            unsigned ownCount=0;Method *ownMethods=class_copyMethodList(cls,&ownCount);BOOL own=NO;
            for(unsigned j=0;j<ownCount;j++) if(method_getName(ownMethods[j])==selector){own=YES;break;}
            free(ownMethods);
            if(!own && row.kind!=13 && row.kind!=15 && row.kind!=16 && row.kind!=19)continue;
            IMP replacement=WCAdImplementation(row.kind,method);if(!replacement)continue;
            WCAdHook *hook=[WCAdHook new];hook.host=cls;hook.selector=selector;hook.original=method_getImplementation(method);hook.replacement=replacement;[WCAdHooks addObject:hook];
        }
    }
    BOOL enabled=WCGestureAdBlockerEnabled();if(enabled==WCAdApplied)return;
    // Capture the whole chain before modifying parents/children. Inherited
    // JS methods must never capture one of our already-installed replacements.
    if(enabled)for(WCAdHook *hook in WCAdHooks)hook.original=method_getImplementation(class_getInstanceMethod(hook.host,hook.selector));
    for (WCAdHook *hook in WCAdHooks) {
        Method method=class_getInstanceMethod(hook.host,hook.selector);IMP target=enabled?hook.replacement:hook.original;
        if (!class_addMethod(hook.host,hook.selector,target,method_getTypeEncoding(method))) method_setImplementation(class_getInstanceMethod(hook.host,hook.selector),target);
    }
    WCAdApplied=enabled;
}
void WCGestureAdBlockerSettingsChanged(NSString *key) { if (!key || [key isEqual:WCGestureAdBlockerEnabledKey] || [key isEqual:WCGestureEnabledKey]) WCGestureAdBlockerInstallOptionalHooks(); }
