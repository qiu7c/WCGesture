#import "Sources/API/WCGestureInternal.h"

%hook NSURL

+ (instancetype)URLWithString:(NSString *)URLString {
    NSString *rewritten = WCGestureAdBlockerRewrittenURLString(URLString);
    return %orig(rewritten);
}

%end

%hook WCAdvertiseStatMgr

- (void)logSphereViewWithSphereReportInfo:(id)reportInfo dataItem:(id)dataItem scene:(unsigned int)scene {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(reportInfo, dataItem, scene);
}

- (void)logSphereViewInDetailWithWrapInfo:(id)wrapInfo dataItem:(id)dataItem {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(wrapInfo, dataItem);
}

- (void)logSphereViewInTimeLineWithWrapInfo:(id)wrapInfo dataItem:(id)dataItem {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(wrapInfo, dataItem);
}

- (void)logHeadImageH5:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)logADBrandProfile:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)logADFloatView:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)logADPoiH5:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)logADH5:(id)value withUserInfo:(id)userInfo reportType:(unsigned long long)reportType {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value, userInfo, reportType);
}

- (void)logADH5:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)logADDetail:(id)detail dataItem:(id)dataItem {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(detail, dataItem);
}

- (void)logADCommentLog:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)logADBodyLog:(id)value {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(value);
}

- (void)reportAllFeedsADLog {
    if (WCGestureAdBlockerEnabled()) return;
    %orig;
}

%end

%hook WAAppTaskSplashADConfig

- (BOOL)canShowSplashADWindow {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

- (BOOL)launchShow {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

%end

%hook WAJSEventHandler_showSplashAd

- (void)handleJSEvent:(id)event {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(event);
}

%end

%hook WAJSEventHandler_showSplashAdMenu

- (void)handleJSEvent:(id)event {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(event);
}

%end

%hook BrandTLExptConfig

- (BOOL)isExptNotShowAd {
    if (WCGestureAdBlockerEnabled()) return YES;
    return %orig;
}

%end

%hook BSTLExptConfig

- (BOOL)isExptNotShowAd {
    if (WCGestureAdBlockerEnabled()) return YES;
    return %orig;
}

%end

%hook BrandTLFlutterViewController

- (BOOL)enableAd {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

- (void)setEnableAd:(BOOL)enabled {
    %orig(WCGestureAdBlockerEnabled() ? NO : enabled);
}

%end

%hook BoxBrandTLFlutterViewController

- (BOOL)enableAd {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

- (void)setEnableAd:(BOOL)enabled {
    %orig(WCGestureAdBlockerEnabled() ? NO : enabled);
}

%end

%hook BSTimelineFlutterViewController

- (BOOL)enableAd {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

- (void)setEnableAd:(BOOL)enabled {
    %orig(WCGestureAdBlockerEnabled() ? NO : enabled);
}

%end

%hook _TtC6WeChat19MagicAdBrandService

- (BOOL)isBrandTimelineOpen {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

%end

%hook MagicAdPushMgrService

- (void)handleAdMsg:(id)message {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(message);
}

- (void)OnGetNewXmlMsg:(id)xml Type:(id)type MsgWrap:(id)message {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(xml, type, message);
}

- (id)getSpecificSlotMsg:(id)slot withBizName:(id)bizName {
    if (WCGestureAdBlockerEnabled()) return nil;
    return %orig(slot, bizName);
}

%end


%hook BrandTimelineMsgMgr

- (id)getInsertedAdCardListWithLimit:(unsigned int)limit {
    if (WCGestureAdBlockerEnabled()) return [NSMutableArray array];
    return %orig(limit);
}

- (unsigned long long)isAdDataLegal:(id)data {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig(data);
}

- (BOOL)hasEnoughADCardExposedCountInOneDay {
    if (WCGestureAdBlockerEnabled()) return YES;
    return %orig;
}

%end

%hook BoxBrandTimelineMsgMgr

- (id)getInsertedAdCardListWithLimit:(unsigned int)limit {
    if (WCGestureAdBlockerEnabled()) return [NSMutableArray array];
    return %orig(limit);
}

- (unsigned long long)isAdDataLegal:(id)data {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig(data);
}

- (BOOL)hasEnoughADCardExposedCountInOneDay {
    if (WCGestureAdBlockerEnabled()) return YES;
    return %orig;
}

%end

%hook WAJSEventHandler_adOperateWXData

- (void)handleJSEvent:(id)event {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(event);
}

%end

%hook BrandTLCanvasCardMgr

+ (BOOL)isAdRequestOpen {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

+ (BOOL)isAdCardOpen {
    if (WCGestureAdBlockerEnabled()) return NO;
    return %orig;
}

- (void)handleBizAdNotifyNewXml:(id)xml {
    if (WCGestureAdBlockerEnabled()) return;
    %orig(xml);
}

%end



%hook WCTimelineMgr
// Keep native storage/update bookkeeping intact. Consumers may mutate this list.
- (id)getAdvertiseDataByCurMinTime:(unsigned int)minimum MaxTime:(unsigned int)maximum {
    id items = %orig(minimum, maximum);
    if (WCGestureAdBlockerEnabled()) return [NSMutableArray array];
    return items;
}
%end

%ctor {
    %init;
    WCGestureAdBlockerInstallOptionalHooks();
}
