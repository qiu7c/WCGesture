#import "WCGestureSettingsVC.h"
#import "WCGestureConfig.h"
#import "WCGestureAccount.h"
#import "WCGestureTranslate.h"
#import "WCPopup.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Helpers

static NSArray<NSDictionary *> *WCActionOptions(BOOL selfMessage) {
    NSMutableArray *options = [NSMutableArray array];
    [options addObject:@{ @"title": @"不设置", @"value": @(WCReplySwipeActionNone) }];
    [options addObject:@{ @"title": @"引用", @"value": @(WCReplySwipeActionQuote) }];
    if (selfMessage) [options addObject:@{ @"title": @"撤回", @"value": @(WCReplySwipeActionRevoke) }];
    [options addObject:@{ @"title": @"复制", @"value": @(WCReplySwipeActionCopy) }];
    [options addObject:@{ @"title": @"删除", @"value": @(WCReplySwipeActionDelete) }];
    [options addObject:@{ @"title": @"复读", @"value": @(WCReplySwipeActionRepeat) }];
    [options addObject:@{ @"title": @"转发", @"value": @(WCReplySwipeActionForward) }];
    [options addObject:@{ @"title": @"收藏", @"value": @(WCReplySwipeActionFavorite) }];
    [options addObject:@{ @"title": @"消息处理（转文字翻译）", @"value": @(WCReplySwipeActionTranslate) }];
    [options addObject:@{ @"title": @"朗读", @"value": @(WCReplySwipeActionSpeak) }];
    return options;
}

static NSString *WCActionName(NSInteger action, BOOL selfMessage) {
    NSArray<NSDictionary *> *options = WCActionOptions(selfMessage);
    for (NSDictionary *option in options) {
        if ([option[@"value"] integerValue] == action) return option[@"title"];
    }
    return @"不设置";
}

static UIWindow *WCActiveWindow(void) {
    NSArray<UIWindow *> *windows = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        windows = ((UIWindowScene *)scene).windows;
        if (windows.count) break;
    }
    if (windows.count == 0) {
        id all = nil;
        @try { all = [UIApplication.sharedApplication valueForKey:@"windows"]; }
        @catch (__unused NSException *exception) {}
        if ([all isKindOfClass:[NSArray class]]) windows = all;
    }
    for (UIWindow *window in windows) {
        if (window.isKeyWindow && !window.hidden && window.alpha > 0.0) return window;
    }
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.rootViewController) return window;
    }
    return windows.firstObject;
}

static UIViewController *WCTopViewController(void) {
    UIViewController *root = WCActiveWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

static void WCPostChange(NSString *key) {
    [[NSNotificationCenter defaultCenter] postNotificationName:WCGestureDidChangeNotification object:key];
}

static void WCSetBool(BOOL value, NSString *key) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    WCPostChange(key);
}

static void WCSetInteger(NSInteger value, NSString *key) {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:key];
    WCPostChange(key);
}

#pragma mark - Pickers (custom popup)

static void WCPresentActionPicker(__unused UIViewController *presenter, NSString *title,
                                  BOOL selfMessage, NSString *defaultsKey) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:defaultsKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCActionOptions(selfMessage)) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:title
                          message:(selfMessage ? @"选择自己消息触发的动作" : @"选择对方消息触发的动作；不支持撤回")
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], defaultsKey);
    }];
}

static void WCPresentTriggerDistanceEditor(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCReplySwipeTriggerDistanceKey]];
    [WCPopup showInputWithTitle:@"触发距离"
                        message:@"输入 36 到 100 之间的数值；越小越容易触发"
                           text:text
                    placeholder:@"36 - 100"
                       keyboard:UIKeyboardTypeDecimalPad
                     completion:^(NSString *value) {
        double d = [value doubleValue];
        if (d < 36.0) d = 36.0;
        if (d > 100.0) d = 100.0;
        [defaults setDouble:d forKey:WCReplySwipeTriggerDistanceKey];
        WCPostChange(WCReplySwipeTriggerDistanceKey);
    }];
}

// Quick editor for the keyboard strip geometry, so the band can be tuned by
// typing numbers instead of rebuilding: width 0 = full keyboard width, X
// offset positive = right, Y offset positive = up.
static void WCPresentKeyboardNumberEditor(__unused UIViewController *presenter,
                                         NSString *title, NSString *defaultsKey) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isWidth = [defaultsKey isEqualToString:WCKeyboardStripWidthKey];
    BOOL isOffset = [defaultsKey isEqualToString:WCKeyboardStripOffsetXKey]
        || [defaultsKey isEqualToString:WCKeyboardStripOffsetYKey];
    double minValue = isWidth ? 0.0 : (isOffset ? -400.0 : 20.0);
    double maxValue = isWidth ? 1000.0 : (isOffset ? 400.0 : 200.0);
    NSString *message;
    NSString *placeholder;
    if (isWidth) {
        message = @"输入 0 到 1000；0 表示与键盘同宽";
        placeholder = @"0 = 满宽";
    } else if (isOffset) {
        message = @"输入 -400 到 400；正数向右、向上";
        placeholder = @"-400 - 400";
    } else {
        message = @"输入 20 到 200 之间的数值";
        placeholder = @"20 - 200";
    }
    NSString *text = [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:defaultsKey]];
    [WCPopup showInputWithTitle:title
                        message:message
                           text:text
                    placeholder:placeholder
                       keyboard:(isOffset ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDecimalPad)
                     completion:^(NSString *value) {
        double d = [value doubleValue];
        if (d < minValue) d = minValue;
        if (d > maxValue) d = maxValue;
        [defaults setDouble:d forKey:defaultsKey];
        WCPostChange(defaultsKey);
    }];
}

#pragma mark - Haptic style options

static NSArray<NSDictionary *> *WCHapticStyleOptions(void) {
    return @[
        @{ @"title": @"轻柔", @"value": @(WCHapticStyleLight) },
        @{ @"title": @"中等", @"value": @(WCHapticStyleMedium) },
        @{ @"title": @"强烈", @"value": @(WCHapticStyleHeavy) },
        @{ @"title": @"柔和", @"value": @(WCHapticStyleSoft) },
        @{ @"title": @"干脆", @"value": @(WCHapticStyleRigid) },
    ];
}

static NSString *WCHapticStyleName(NSInteger style) {
    for (NSDictionary *option in WCHapticStyleOptions()) {
        if ([option[@"value"] integerValue] == style) return option[@"title"];
    }
    return @"中等";
}

static void WCPresentHapticStylePicker(__unused UIViewController *presenter) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:WCGestureHapticStyleKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCHapticStyleOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:@"震感强度"
                          message:@"选择触感反馈强度"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], WCGestureHapticStyleKey);
    }];
}

static void WCPresentPluginNameEditor(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *name = [defaults stringForKey:WCPluginNameKey] ?: @"微信手势";
    [WCPopup showInputWithTitle:@"插件名称"
                        message:@"设置在微信插件管理页显示的名字"
                           text:name
                    placeholder:@"微信手势"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0) text = @"微信手势";
        [defaults setObject:text forKey:WCPluginNameKey];
        WCPostChange(WCPluginNameKey);
    }];
}

#pragma mark - Translation engine

static NSArray<NSDictionary *> *WCTranslateEngineOptions(void) {
    return @[
        @{ @"title": @"微软翻译", @"value": @(WCTranslateEngineEdge) },
        @{ @"title": @"MyMemory", @"value": @(WCTranslateEngineMyMemory) },
        @{ @"title": @"自定义接口", @"value": @(WCTranslateEngineCustom) },
    ];
}

static NSString *WCTranslateEngineName(NSInteger engine) {
    for (NSDictionary *option in WCTranslateEngineOptions()) {
        if ([option[@"value"] integerValue] == engine) return option[@"title"];
    }
    return @"微软翻译";
}

static void WCPresentTranslateEnginePicker(__unused UIViewController *presenter) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:WCTranslateEngineKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCTranslateEngineOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:@"翻译引擎"
                          message:@"微软翻译与 MyMemory 免费且无需 key；自定义接口需 OpenAI 兼容地址"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], WCTranslateEngineKey);
    }];
}

static void WCPresentTranslateTextEditor(__unused UIViewController *presenter,
                                         NSString *title, NSString *message,
                                         NSString *defaultsKey, NSString *placeholder) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = [defaults stringForKey:defaultsKey] ?: @"";
    [WCPopup showInputWithTitle:title
                        message:message
                           text:text
                    placeholder:placeholder
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        [defaults setObject:trimmed forKey:defaultsKey];
        WCPostChange(defaultsKey);
    }];
}

static void WCPresentTranslateTest(__unused UIViewController *presenter) {
    NSString *engineName = WCTranslateEngineName(
        [[NSUserDefaults standardUserDefaults] integerForKey:WCTranslateEngineKey]);
    WCGestureTranslateText(@"你好世界", YES, ^(NSString *translated, NSString *errorMessage) {
        if (translated.length > 0) {
            [WCPopup showMessage:[NSString stringWithFormat:@"翻译测试成功 · %@", engineName]
                         message:[NSString stringWithFormat:@"%@ → %@", @"你好世界", translated]];
        } else {
            [WCPopup showMessage:[NSString stringWithFormat:@"翻译测试失败 · %@", engineName]
                         message:errorMessage ?: @"未知错误"];
        }
    });
}

#pragma mark - Config export/import (compact share code)

// Short alias → full defaults key. Only these keys are exported; defaults are
// omitted so the code stays short. Version "v" field supports future additions.
static NSDictionary<NSString *, NSString *> *WCConfigShareKeys(void) {
    return @{
        @"a": WCReplySwipeEnabledKey,
        @"b": WCReplySwipeSelfActionKey,
        @"c": WCReplySwipeOtherActionKey,
        @"d": WCReplySwipeRightSelfActionKey,
        @"e": WCReplySwipeRightOtherActionKey,
        @"f": WCReplySwipeTriggerDistanceKey,
        @"g": WCMessageDoubleTapSelfActionKey,
        @"h": WCMessageDoubleTapOtherActionKey,
        @"i": WCMessageTripleTapSelfActionKey,
        @"j": WCMessageTripleTapOtherActionKey,
        @"k": WCInputGestureEnabledKey,
        @"l": WCInputSwipeLeftActionKey,
        @"m": WCInputSwipeRightActionKey,
        @"n": WCInputDoubleTapActionKey,
        @"o": WCInputTripleTapActionKey,
        @"p": WCMomentsDoubleTapLikeKey,
        @"q": WCMomentsLikeHapticKey,
        @"r": WCGlobalGestureEnabledKey,
        @"s": WCGlobalTwoFingerActionKey,
        @"t": WCGlobalThreeFingerActionKey,
        @"u": WCPluginNameKey,
        @"v": WCMessageGestureHapticKey,
        @"w": WCInputGestureHapticKey,
        @"x": WCGlobalGestureHapticKey,
        @"y": WCGestureHapticStyleKey,
        @"z": WCCustomPagesKey,
        @"A": WCHideSeparatorLinesKey,
        @"B": WCKeyboardEnhanceEnabledKey,
        @"C": WCKeyboardSwipeLeftActionKey,
        @"D": WCKeyboardSwipeRightActionKey,
        @"E": WCKeyboardDoubleTapActionKey,
        @"F": WCKeyboardTripleTapActionKey,
        @"G": WCKeyboardHapticKey,
    };
}

// 编码:JSON → Base64 → 拼前缀标记。只导出已设置的非空值,口令尽量短。
// 不带版本号:按短别名匹配,对得上的键才写入,对不上就跳过,天然兼容未来增删字段。
static NSString *WCConfigExportCode(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [WCConfigShareKeys() enumerateKeysAndObjectsUsingBlock:^(NSString *alias, NSString *key, __unused BOOL *stop) {
        id value = [d objectForKey:key];
        if (value) dict[alias] = value;
    }];
    NSData *json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (!json) return @"";
    NSString *base64 = [json base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"WCG1-%@", base64];
}

static BOOL WCConfigImportCode(NSString *code) {
    NSString *prefix = @"WCG1-";
    if (![code hasPrefix:prefix]) return NO;
    NSString *base64 = [code substringFromIndex:prefix.length];
    NSData *json = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    if (!json) return NO;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *aliasMap = WCConfigShareKeys();
    [dict enumerateKeysAndObjectsUsingBlock:^(id alias, id value, __unused BOOL *stop) {
        if (![alias isKindOfClass:[NSString class]]) return;
        NSString *key = aliasMap[alias];
        // 对得上的键才写入;对不上(未来新增字段或旧版本)就跳过
        if (key) [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    }];
    return YES;
}

static void WCPresentExportConfig(__unused UIViewController *presenter) {
    [WCPopup showTextWithTitle:@"导出配置"
                       message:@"复制下方口令，在新设备/新账号导入即可恢复设置"
                          text:WCConfigExportCode()];
}

static void WCPresentImportConfig(__unused UIViewController *presenter) {
    [WCPopup showInputWithTitle:@"导入配置"
                        message:@"粘贴配置口令"
                           text:UIPasteboard.generalPasteboard.string
                    placeholder:@"WCG1-..."
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *text) {
        if (WCConfigImportCode(text)) {
            WCPostChange(nil);
            [WCPopup showMessage:@"导入成功" message:nil];
        } else {
            [WCPopup showMessage:@"导入失败" message:@"口令格式错误"];
        }
    }];
}

#pragma mark - Input action options

static NSArray<NSDictionary *> *WCInputActionOptions(void) {
    return @[
        @{ @"title": @"不设置", @"value": @(WCInputActionNone) },
        @{ @"title": @"清空", @"value": @(WCInputActionClear) },
        @{ @"title": @"粘贴", @"value": @(WCInputActionPaste) },
        @{ @"title": @"复制", @"value": @(WCInputActionCopy) },
        @{ @"title": @"剪切", @"value": @(WCInputActionCut) },
        @{ @"title": @"翻译 · 中译英", @"value": @(WCInputActionTranslateToEnglish) },
        @{ @"title": @"翻译 · 英译中", @"value": @(WCInputActionTranslateToChinese) },
        @{ @"title": @"转大写", @"value": @(WCInputActionUppercase) },
        @{ @"title": @"转小写", @"value": @(WCInputActionLowercase) },
        @{ @"title": @"去空格换行", @"value": @(WCInputActionTrim) },
    ];
}

static NSString *WCInputActionName(NSInteger action) {
    for (NSDictionary *option in WCInputActionOptions()) {
        if ([option[@"value"] integerValue] == action) return option[@"title"];
    }
    return @"清空";
}

#pragma mark - Input action picker

static void WCPresentInputSwipeActionPicker(__unused UIViewController *presenter, NSString *title, NSString *defaultsKey) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:defaultsKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCInputActionOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:title
                          message:@"选择触发动作"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], defaultsKey);
    }];
}

#pragma mark - Row model

typedef NS_ENUM(NSInteger, WCRowKind) {
    WCRowKindSwitch,        // toggle
    WCRowKindActionDetail,  // tap → message action picker
    WCRowKindInputAction,   // tap → input swipe action picker
    WCRowKindGlobalAction,  // tap → global action picker
    WCRowKindDistance,      // tap → number editor
    WCRowKindKeyboardNumber,// tap → number editor for the keyboard strip geometry
    WCRowKindPluginName,    // tap → plugin name editor
    WCRowKindHapticStyle,   // tap → haptic style picker
    WCRowKindCustomPages, // tap → custom page class name editor
    WCRowKindTranslateEngine,     // tap → translation engine picker
    WCRowKindTranslateCustomURL,  // tap → custom endpoint editor
    WCRowKindTranslateCustomKey,  // tap → custom API key editor
    WCRowKindTranslateCustomModel,// tap → custom model editor
    WCRowKindTranslateTest,       // tap → test translation engine
    WCRowKindExport,         // tap → export config
    WCRowKindImport,        // tap → import config
};

@interface WCRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, assign) WCRowKind kind;
@property (nonatomic, copy) NSString *defaultsKey;   // nil for non-persisted
@property (nonatomic, assign) BOOL selfMessage;      // action picker variant
@end
@implementation WCRow
@end

static WCRow *WCSwitchRow(NSString *title, NSString *key) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.defaultsKey = key;
    row.kind = WCRowKindSwitch;
    return row;
}

static WCRow *WCActionRow(NSString *title, NSString *key, BOOL selfMessage) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.defaultsKey = key;
    row.selfMessage = selfMessage;
    row.kind = WCRowKindActionDetail;
    return row;
}

static WCRow *WCDistanceRow(NSString *title) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.kind = WCRowKindDistance;
    return row;
}

static WCRow *WCNumberRow(NSString *title, NSString *key) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.defaultsKey = key;
    row.kind = WCRowKindKeyboardNumber;
    return row;
}

static WCRow *WCInputActionRow(NSString *title, NSString *key) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.defaultsKey = key;
    row.kind = WCRowKindInputAction;
    return row;
}

static WCRow *WCGlobalActionRow(NSString *title, NSString *key) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.defaultsKey = key;
    row.kind = WCRowKindGlobalAction;
    return row;
}

static WCRow *WCPlainRow(NSString *title, WCRowKind kind) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.kind = kind;
    return row;
}

static NSArray<NSDictionary *> *WCGlobalActionOptions(void) {
    return @[
        @{ @"title": @"不设置", @"value": @(WCGlobalActionNone) },
        @{ @"title": @"扫一扫", @"value": @(WCGlobalActionScanQR) },
        @{ @"title": @"朋友圈", @"value": @(WCGlobalActionMoments) },
        @{ @"title": @"添加朋友", @"value": @(WCGlobalActionAddFriend) },
        @{ @"title": @"我的二维码", @"value": @(WCGlobalActionMyQRCode) },
        @{ @"title": @"付款码", @"value": @(WCGlobalActionPayCode) },
        @{ @"title": @"自定义页面", @"value": @(WCGlobalActionCustomPage) },
        @{ @"title": @"截图", @"value": @(WCGlobalActionScreenshot) },
        @{ @"title": @"返回上一页", @"value": @(WCGlobalActionBack) },
        @{ @"title": @"回到首页", @"value": @(WCGlobalActionLockScreen) },
        @{ @"title": @"快捷菜单", @"value": @(WCGlobalActionMenu) },
        @{ @"title": @"跳转设置页", @"value": @(WCGlobalActionJump) },
    ];
}

static NSString *WCGlobalActionName(NSInteger action) {
    for (NSDictionary *option in WCGlobalActionOptions()) {
        if ([option[@"value"] integerValue] == action) return option[@"title"];
    }
    return @"不设置";
}

static void WCPresentGlobalActionPicker(__unused UIViewController *presenter, NSString *title, NSString *defaultsKey) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:defaultsKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCGlobalActionOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:title
                          message:@"选择触发动作"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], defaultsKey);
    }];
}

static NSString *WCRowDetailText(WCRow *row) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    switch (row.kind) {
        case WCRowKindSwitch:
            return [d boolForKey:row.defaultsKey] ? @"开" : @"关";
        case WCRowKindActionDetail:
            return WCActionName([d integerForKey:row.defaultsKey], row.selfMessage);
        case WCRowKindInputAction:
            return WCInputActionName([d integerForKey:row.defaultsKey]);
        case WCRowKindGlobalAction:
            return WCGlobalActionName([d integerForKey:row.defaultsKey]);
        case WCRowKindPluginName:
            return [d stringForKey:WCPluginNameKey] ?: @"微信手势";
        case WCRowKindHapticStyle:
            return WCHapticStyleName([d integerForKey:WCGestureHapticStyleKey]);
        case WCRowKindCustomPages: {
            NSArray *pages = [d arrayForKey:WCCustomPagesKey];
            NSUInteger count = [pages isKindOfClass:[NSArray class]] ? pages.count : 0;
            return count > 0 ? [NSString stringWithFormat:@"%lu 个", (unsigned long)count] : @"未添加";
        }
        case WCRowKindTranslateEngine:
            return WCTranslateEngineName([d integerForKey:WCTranslateEngineKey]);
        case WCRowKindTranslateCustomURL: {
            NSString *url = [d stringForKey:WCTranslateCustomURLKey];
            return url.length > 0 ? url : @"未设置";
        }
        case WCRowKindTranslateCustomKey: {
            NSString *key = [d stringForKey:WCTranslateCustomKeyKey];
            if (key.length == 0) return @"未设置";
            return [NSString stringWithFormat:@"已设置(%lu 位)", (unsigned long)key.length];
        }
        case WCRowKindTranslateCustomModel: {
            NSString *model = [d stringForKey:WCTranslateCustomModelKey];
            return model.length > 0 ? model : @"gpt-4o-mini";
        }
        case WCRowKindTranslateTest:
            return @"";
        case WCRowKindExport:
        case WCRowKindImport:
            return @"";
        case WCRowKindDistance: {
            double v = [d doubleForKey:WCReplySwipeTriggerDistanceKey];
            return [NSString stringWithFormat:@"%.0f", v <= 0 ? 56.0 : v];
        }
        case WCRowKindKeyboardNumber: {
            if ([row.defaultsKey isEqualToString:WCKeyboardStripWidthKey]) {
                double w = [d doubleForKey:WCKeyboardStripWidthKey];
                return w > 0 ? [NSString stringWithFormat:@"%.0f", w] : @"满宽";
            }
            return [NSString stringWithFormat:@"%.0f", [d doubleForKey:row.defaultsKey]];
        }
    }
    return @"";
}

#pragma mark - Card view helper

static UIView *WCMakeCard(NSString *title, NSString *symbol, UIColor *accent, UIColor *bg) {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = bg;
    card.layer.cornerRadius = 16;
    card.layer.masksToBounds = YES;
    UIView *iconWrap = [[UIView alloc] init];
    iconWrap.backgroundColor = [accent colorWithAlphaComponent:0.14];
    iconWrap.layer.cornerRadius = 12;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:symbol
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]]
        imageWithTintColor:accent renderingMode:UIImageRenderingModeAlwaysOriginal]];
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.labelColor;
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium]]];
    chevron.tintColor = UIColor.tertiaryLabelColor;
    for (UIView *v in @[iconWrap, icon, titleLabel, chevron]) v.translatesAutoresizingMaskIntoConstraints = NO;
    [iconWrap addSubview:icon];
    [card addSubview:iconWrap];
    [card addSubview:titleLabel];
    [card addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[
        [iconWrap.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [iconWrap.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [iconWrap.widthAnchor constraintEqualToConstant:40],
        [iconWrap.heightAnchor constraintEqualToConstant:40],
        [icon.centerXAnchor constraintEqualToAnchor:iconWrap.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconWrap.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconWrap.trailingAnchor constant:12],
        [titleLabel.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],
        [chevron.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:12],
        [chevron.heightAnchor constraintEqualToConstant:12],
    ]];
    [chevron setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [chevron setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    return card;
}

#pragma mark - Home controller (registered with WCPluginsMgr)

typedef NS_ENUM(NSInteger, WCGestureCategory) {
    WCGestureCategoryChat = 0,
    WCGestureCategoryOther = 1,
    WCGestureCategoryGlobal = 2,
    WCGestureCategoryPlugin = 3,
    WCGestureCategoryEnhance = 4,
};

@interface WCGestureSettingsController ()
@end

@implementation WCGestureSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"WCGesture";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    WCRefreshCachedCurrentUser();

    CGFloat margin = 16;
    UIView *chatCard = WCMakeCard(@"聊天页手势",
        @"bubble.left", UIColor.systemBlueColor, UIColor.secondarySystemGroupedBackgroundColor);
    UIView *globalCard = WCMakeCard(@"全局手势",
        @"hand.tap", UIColor.systemGreenColor, UIColor.secondarySystemGroupedBackgroundColor);
    UIView *otherCard = WCMakeCard(@"其他手势",
        @"heart", UIColor.systemPinkColor, UIColor.secondarySystemGroupedBackgroundColor);
    UIView *enhanceCard = WCMakeCard(@"拓展设置",
        @"wand.and.stars", UIColor.systemPurpleColor, UIColor.secondarySystemGroupedBackgroundColor);
    UIView *pluginCard = WCMakeCard(@"插件设置",
        @"gearshape", UIColor.systemOrangeColor, UIColor.secondarySystemGroupedBackgroundColor);

    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = @"版本 1.0.0";
    versionLabel.font = [UIFont systemFontOfSize:13];
    versionLabel.textColor = UIColor.tertiaryLabelColor;
    versionLabel.textAlignment = NSTextAlignmentCenter;

    UIView *authorCard = [[UIView alloc] init];
    authorCard.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    authorCard.layer.cornerRadius = 12;
    authorCard.layer.masksToBounds = YES;
    UILabel *authorLabel = [[UILabel alloc] init];
    authorLabel.text = @"联系作者：Cc";
    authorLabel.font = [UIFont systemFontOfSize:14];
    authorLabel.textColor = UIColor.secondaryLabelColor;
    authorLabel.textAlignment = NSTextAlignmentCenter;
    authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [authorCard addSubview:authorLabel];
    [NSLayoutConstraint activateConstraints:@[
        [authorLabel.leadingAnchor constraintEqualToAnchor:authorCard.leadingAnchor constant:16],
        [authorLabel.trailingAnchor constraintEqualToAnchor:authorCard.trailingAnchor constant:-16],
        [authorLabel.centerYAnchor constraintEqualToAnchor:authorCard.centerYAnchor],
        [authorLabel.heightAnchor constraintEqualToConstant:44],
    ]];

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @"WCGesture by Cc";
    brandLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    brandLabel.textColor = UIColor.tertiaryLabelColor;
    brandLabel.textAlignment = NSTextAlignmentCenter;

    chatCard.tag = WCGestureCategoryChat;
    globalCard.tag = WCGestureCategoryGlobal;
    otherCard.tag = WCGestureCategoryOther;
    enhanceCard.tag = WCGestureCategoryEnhance;
    pluginCard.tag = WCGestureCategoryPlugin;
    for (UIView *v in @[chatCard, globalCard, otherCard, enhanceCard, pluginCard, versionLabel, authorCard, brandLabel]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:v];
    }
    // Tappable
    for (UIView *card in @[chatCard, globalCard, otherCard, enhanceCard, pluginCard]) {
        card.userInteractionEnabled = YES;
        [card addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCategory:)]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [chatCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:margin],
        [chatCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [chatCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [chatCard.heightAnchor constraintEqualToConstant:76],
        [globalCard.topAnchor constraintEqualToAnchor:chatCard.bottomAnchor constant:margin],
        [globalCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [globalCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [globalCard.heightAnchor constraintEqualToConstant:76],
        [otherCard.topAnchor constraintEqualToAnchor:globalCard.bottomAnchor constant:margin],
        [otherCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [otherCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [otherCard.heightAnchor constraintEqualToConstant:76],
        [enhanceCard.topAnchor constraintEqualToAnchor:otherCard.bottomAnchor constant:margin],
        [enhanceCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [enhanceCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [enhanceCard.heightAnchor constraintEqualToConstant:76],
        [pluginCard.topAnchor constraintEqualToAnchor:enhanceCard.bottomAnchor constant:margin],
        [pluginCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [pluginCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [pluginCard.heightAnchor constraintEqualToConstant:76],
        // 版权信息固定在页面视觉最底部
        [brandLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-margin],
        [brandLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [brandLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [authorCard.bottomAnchor constraintEqualToAnchor:brandLabel.topAnchor constant:-8],
        [authorCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [authorCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [versionLabel.bottomAnchor constraintEqualToAnchor:authorCard.topAnchor constant:-8],
        [versionLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [versionLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
    ]];
}

- (void)openCategory:(UITapGestureRecognizer *)recognizer {
    WCGestureDetailController *vc = [[WCGestureDetailController alloc] initWithCategory:recognizer.view.tag];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

#pragma mark - Custom pages editor

@interface WCCustomPagesController : UITableViewController
@end

@interface WCCustomPagesController ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *pages;
@end

@implementation WCCustomPagesController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"自定义页面";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addPage)];
    [self reloadPages];
}

- (void)reloadPages {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:WCCustomPagesKey];
    self.pages = [stored isKindOfClass:[NSArray class]] ? [stored mutableCopy] : [NSMutableArray array];
    [self.tableView reloadData];
}

- (void)savePages {
    [[NSUserDefaults standardUserDefaults] setObject:[self.pages copy] forKey:WCCustomPagesKey];
    WCPostChange(WCCustomPagesKey);
}

- (void)addPage { [self editPageAtIndex:-1]; }

- (void)editPageAtIndex:(NSInteger)index {
    NSDictionary *existing = (index >= 0 && index < (NSInteger)self.pages.count) ? self.pages[index] : nil;
    NSString *existingName = [existing[@"name"] isKindOfClass:[NSString class]] ? existing[@"name"] : nil;
    NSString *existingClass = [existing[@"class"] isKindOfClass:[NSString class]] ? existing[@"class"] : nil;
    [WCPopup showInputWithTitle:@"页面备注"
                        message:@"给这个页面起个名字，显示在列表里"
                           text:existingName
                    placeholder:@"例如：扫一扫"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *name) {
        NSString *remark = name.length > 0 ? name : @"自定义页面";
        [WCPopup showInputWithTitle:@"页面类名"
                            message:@"可直接 init 的 UIViewController 类名"
                               text:existingClass
                        placeholder:@"ViewControllerClassName"
                           keyboard:UIKeyboardTypeASCIICapable
                         completion:^(NSString *className) {
            if (className.length == 0) return;
            NSDictionary *entry = @{ @"name": remark, @"class": className };
            NSMutableArray *pages = [self.pages mutableCopy];
            if (index >= 0 && index < (NSInteger)pages.count) pages[index] = entry;
            else [pages addObject:entry];
            self.pages = pages;
            [self savePages];
            [self.tableView reloadData];
        }];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView { return 1; }

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.pages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"WCCustomPageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    }
    NSDictionary *entry = self.pages[indexPath.row];
    cell.textLabel.text = [entry[@"name"] isKindOfClass:[NSString class]] ? entry[@"name"] : @"自定义页面";
    cell.detailTextLabel.text = [entry[@"class"] isKindOfClass:[NSString class]] ? entry[@"class"] : nil;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self editPageAtIndex:indexPath.row];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
        title:@"删除" handler:^(__unused UIContextualAction *action, __unused UIView *view, void (^completion)(BOOL)) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { completion(NO); return; }
        if (indexPath.row < (NSInteger)strongSelf.pages.count) {
            [strongSelf.pages removeObjectAtIndex:indexPath.row];
            [strongSelf savePages];
            [strongSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        completion(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

@end

#pragma mark - Detail controller

@interface WCGestureDetailController ()
@property (nonatomic, assign) NSInteger category;
@property (nonatomic, copy) NSArray<NSArray<WCRow *> *> *sections;
@property (nonatomic, copy) NSArray<NSNumber *> *collapsible;
@property (nonatomic, copy) NSArray<NSString *> *collapseKeys;
@end

@implementation WCGestureDetailController

- (instancetype)initWithCategory:(NSInteger)category {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _category = category;
        switch (category) {
            case WCGestureCategoryChat: self.title = @"聊天页手势"; break;
            case WCGestureCategoryGlobal: self.title = @"全局手势"; break;
            case WCGestureCategoryOther: self.title = @"其他手势"; break;
            case WCGestureCategoryEnhance: self.title = @"拓展设置"; break;
            default: self.title = @"插件设置"; break;
        }
        [self rebuildRows];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48;
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(settingsDidChange:) name:WCGestureDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)settingsDidChange:(__unused NSNotification *)note {
    [self rebuildRows];
    [self.tableView reloadData];
}

- (void)rebuildRows {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *collapsible = [NSMutableArray array];
    NSMutableArray *collapseKeys = [NSMutableArray array];
    NSString *prefix = @"com.qiu7c.wcgesture.collapse";
    if (self.category == WCGestureCategoryChat) {
        NSMutableArray *msg = [NSMutableArray array];
        [msg addObject:WCSwitchRow(@"消息手势", WCReplySwipeEnabledKey)];
        if ([d boolForKey:WCReplySwipeEnabledKey]) {
            [msg addObject:WCSwitchRow(@"震动", WCMessageGestureHapticKey)];
            [msg addObject:WCActionRow(@"左滑 · 自己", WCReplySwipeSelfActionKey, YES)];
            [msg addObject:WCActionRow(@"左滑 · 对方", WCReplySwipeOtherActionKey, NO)];
            [msg addObject:WCActionRow(@"右滑 · 自己", WCReplySwipeRightSelfActionKey, YES)];
            [msg addObject:WCActionRow(@"右滑 · 对方", WCReplySwipeRightOtherActionKey, NO)];
            [msg addObject:WCActionRow(@"双击 · 自己", WCMessageDoubleTapSelfActionKey, YES)];
            [msg addObject:WCActionRow(@"双击 · 对方", WCMessageDoubleTapOtherActionKey, NO)];
            [msg addObject:WCActionRow(@"三击 · 自己", WCMessageTripleTapSelfActionKey, YES)];
            [msg addObject:WCActionRow(@"三击 · 对方", WCMessageTripleTapOtherActionKey, NO)];
            [msg addObject:WCDistanceRow(@"触发距离")];
        }
        [sections addObject:msg];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.msg"]];
        NSMutableArray *input = [NSMutableArray array];
        [input addObject:WCSwitchRow(@"输入框手势", WCInputGestureEnabledKey)];
        if ([d boolForKey:WCInputGestureEnabledKey]) {
            [input addObject:WCSwitchRow(@"震动", WCInputGestureHapticKey)];
            [input addObject:WCInputActionRow(@"左滑动作", WCInputSwipeLeftActionKey)];
            [input addObject:WCInputActionRow(@"右滑动作", WCInputSwipeRightActionKey)];
            [input addObject:WCInputActionRow(@"双击动作", WCInputDoubleTapActionKey)];
            [input addObject:WCInputActionRow(@"三击动作", WCInputTripleTapActionKey)];
        }
        [sections addObject:input];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.input"]];
        NSMutableArray *keyboard = [NSMutableArray array];
        [keyboard addObject:WCSwitchRow(@"键盘增强", WCKeyboardEnhanceEnabledKey)];
        if ([d boolForKey:WCKeyboardEnhanceEnabledKey]) {
            [keyboard addObject:WCSwitchRow(@"震动", WCKeyboardHapticKey)];
            [keyboard addObject:WCInputActionRow(@"左滑动作", WCKeyboardSwipeLeftActionKey)];
            [keyboard addObject:WCInputActionRow(@"右滑动作", WCKeyboardSwipeRightActionKey)];
            [keyboard addObject:WCInputActionRow(@"双击动作", WCKeyboardDoubleTapActionKey)];
            [keyboard addObject:WCInputActionRow(@"三击动作", WCKeyboardTripleTapActionKey)];
            [keyboard addObject:WCSwitchRow(@"显示触发范围", WCKeyboardDebugFrameKey)];
            // Tap to type a value and see the strip move without rebuilding.
            [keyboard addObject:WCNumberRow(@"触控区宽度", WCKeyboardStripWidthKey)];
            [keyboard addObject:WCNumberRow(@"触控区高度", WCKeyboardStripHeightKey)];
            [keyboard addObject:WCNumberRow(@"触控区左右偏移", WCKeyboardStripOffsetXKey)];
            [keyboard addObject:WCNumberRow(@"触控区上下偏移", WCKeyboardStripOffsetYKey)];
        }
        [sections addObject:keyboard];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.keyboard"]];
    } else if (self.category == WCGestureCategoryOther) {
        NSMutableArray *moments = [NSMutableArray array];
        [moments addObject:WCSwitchRow(@"朋友圈双击点赞", WCMomentsDoubleTapLikeKey)];
        if ([d boolForKey:WCMomentsDoubleTapLikeKey]) {
            [moments addObject:WCSwitchRow(@"震动", WCMomentsLikeHapticKey)];
        }
        [sections addObject:moments];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".other.moments"]];
    } else if (self.category == WCGestureCategoryGlobal) {
        NSMutableArray *global = [NSMutableArray array];
        [global addObject:WCSwitchRow(@"全局手势", WCGlobalGestureEnabledKey)];
        if ([d boolForKey:WCGlobalGestureEnabledKey]) {
            [global addObject:WCSwitchRow(@"震动", WCGlobalGestureHapticKey)];
            [global addObject:WCGlobalActionRow(@"双指长按", WCGlobalTwoFingerActionKey)];
            [global addObject:WCGlobalActionRow(@"三指长按", WCGlobalThreeFingerActionKey)];
            [global addObject:WCPlainRow(@"自定义页面", WCRowKindCustomPages)];
        }
        [sections addObject:global];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".global"]];
    } else if (self.category == WCGestureCategoryEnhance) {
        NSMutableArray *enhance = [NSMutableArray array];
        [enhance addObject:WCSwitchRow(@"去除所有分割线", WCHideSeparatorLinesKey)];
        [sections addObject:enhance];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".enhance"]];
    } else {
        // 插件设置
        NSMutableArray *plugin = [NSMutableArray array];
        [plugin addObject:WCPlainRow(@"插件名称", WCRowKindPluginName)];
        [plugin addObject:WCPlainRow(@"震感强度", WCRowKindHapticStyle)];
        [sections addObject:plugin];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".plugin"]];
        NSMutableArray *translate = [NSMutableArray array];
        [translate addObject:WCPlainRow(@"翻译引擎", WCRowKindTranslateEngine)];
        if ([d integerForKey:WCTranslateEngineKey] == WCTranslateEngineCustom) {
            [translate addObject:WCPlainRow(@"接口地址", WCRowKindTranslateCustomURL)];
            [translate addObject:WCPlainRow(@"API Key", WCRowKindTranslateCustomKey)];
            [translate addObject:WCPlainRow(@"模型", WCRowKindTranslateCustomModel)];
        }
        [translate addObject:WCPlainRow(@"测试翻译", WCRowKindTranslateTest)];
        [sections addObject:translate];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".translate"]];
        NSMutableArray *config = [NSMutableArray array];
        [config addObject:WCPlainRow(@"导出配置", WCRowKindExport)];
        [config addObject:WCPlainRow(@"导入配置", WCRowKindImport)];
        [sections addObject:config];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".config"]];
    }
    self.sections = sections;
    self.collapsible = collapsible;
    self.collapseKeys = collapseKeys;
}

- (BOOL)sectionCollapsed:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.collapseKeys.count) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:self.collapseKeys[section]];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return self.sections.count;
}

- (BOOL)sectionCollapsible:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.collapsible.count) return NO;
    return [self.collapsible[section] boolValue];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger total = self.sections[section].count;
    // 折叠时只保留第 0 行(大开关),子设置项收起
    if ([self sectionCollapsible:section] && [self sectionCollapsed:section]) return MIN(1, total);
    return total;
}

- (void)toggleCollapseForSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.collapseKeys.count) return;
    NSString *key = self.collapseKeys[section];
    BOOL now = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    [[NSUserDefaults standardUserDefaults] setBool:!now forKey:key];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section]
              withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger rowIdx = indexPath.row;
    WCRow *row = self.sections[section][rowIdx];
    NSString *cellId = @"WCGestureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UIView *bar = [[UIView alloc] init];
        bar.tag = 9001;
        bar.backgroundColor = UIColor.systemBlueColor;
        bar.layer.cornerRadius = 1.25;
        bar.hidden = YES;
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:bar];
        [NSLayoutConstraint activateConstraints:@[
            [bar.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
            [bar.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [bar.widthAnchor constraintEqualToConstant:2.5],
            [bar.heightAnchor constraintEqualToConstant:20],
        ]];
    }
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = (row.kind == WCRowKindSwitch) ? @"" : WCRowDetailText(row);
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    BOOL collapsible = [self sectionCollapsible:section];
    BOOL isHeaderRow = collapsible && rowIdx == 0;
    BOOL isChild = collapsible && rowIdx > 0;

    // Reset reuse state.
    cell.indentationLevel = 0;
    cell.indentationWidth = 0;
    cell.imageView.image = nil;
    [cell.contentView viewWithTag:9001].hidden = YES;

    if (isHeaderRow) {
        BOOL collapsed = [self sectionCollapsed:section];
        UIImage *chevron = [UIImage systemImageNamed:(collapsed ? @"chevron.right" : @"chevron.down")
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold]];
        cell.imageView.image = [chevron imageWithTintColor:UIColor.secondaryLabelColor
                                            renderingMode:UIImageRenderingModeAlwaysOriginal];
        cell.imageView.contentMode = UIViewContentModeCenter;
    }

    if (isChild) {
        cell.indentationLevel = 1;
        cell.indentationWidth = 14;
        [cell.contentView viewWithTag:9001].hidden = NO;
    }

    if (row.kind == WCRowKindSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];
        sw.tag = section * 10000 + rowIdx;
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:row.defaultsKey];
        cell.accessoryView = sw;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)handleSwitch:(UISwitch *)sw {
    NSInteger section = sw.tag / 10000;
    NSInteger rowIdx = sw.tag % 10000;
    if (section < 0 || section >= (NSInteger)self.sections.count) return;
    NSArray<WCRow *> *rows = self.sections[section];
    if (rowIdx < 0 || rowIdx >= (NSInteger)rows.count) return;
    WCSetBool(sw.on, rows[rowIdx].defaultsKey);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger section = indexPath.section;
    // Tapping the first row (the big switch / section header) collapses or
    // expands the child items.
    if ([self sectionCollapsible:section] && indexPath.row == 0) {
        [self toggleCollapseForSection:section];
        return;
    }
    WCRow *row = self.sections[section][indexPath.row];
    switch (row.kind) {
        case WCRowKindSwitch: break;
        case WCRowKindActionDetail:
            WCPresentActionPicker(self, row.title, row.selfMessage, row.defaultsKey);
            break;
        case WCRowKindInputAction:
            WCPresentInputSwipeActionPicker(self, row.title, row.defaultsKey);
            break;
        case WCRowKindGlobalAction:
            WCPresentGlobalActionPicker(self, row.title, row.defaultsKey);
            break;
        case WCRowKindPluginName:
            WCPresentPluginNameEditor(self);
            break;
        case WCRowKindHapticStyle:
            WCPresentHapticStylePicker(self);
            break;
        case WCRowKindCustomPages:
            [self.navigationController pushViewController:
                [[WCCustomPagesController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
            break;
        case WCRowKindTranslateEngine:
            WCPresentTranslateEnginePicker(self);
            break;
        case WCRowKindTranslateCustomURL:
            WCPresentTranslateTextEditor(self, @"接口地址",
                @"OpenAI 兼容的 chat/completions 地址",
                WCTranslateCustomURLKey, @"https://api.openai.com/v1/chat/completions");
            break;
        case WCRowKindTranslateCustomKey:
            WCPresentTranslateTextEditor(self, @"API Key",
                @"以 Bearer 方式发送；留空则不发送鉴权头",
                WCTranslateCustomKeyKey, @"sk-...");
            break;
        case WCRowKindTranslateCustomModel:
            WCPresentTranslateTextEditor(self, @"模型",
                @"留空默认 gpt-4o-mini",
                WCTranslateCustomModelKey, @"gpt-4o-mini");
            break;
        case WCRowKindTranslateTest:
            WCPresentTranslateTest(self);
            break;
        case WCRowKindExport:
            WCPresentExportConfig(self);
            break;
        case WCRowKindImport:
            WCPresentImportConfig(self);
            break;
        case WCRowKindDistance:
            WCPresentTriggerDistanceEditor(self);
            break;
        case WCRowKindKeyboardNumber:
            WCPresentKeyboardNumberEditor(self, row.title, row.defaultsKey);
            break;
    }
}

@end

#pragma mark - Settings entry

void WCGesturePresentSettings(UIViewController *presenter) {
    if (!presenter) presenter = WCTopViewController();
    WCGestureSettingsController *vc = [WCGestureSettingsController new];
    if (presenter.navigationController) {
        [presenter.navigationController pushViewController:vc animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [presenter presentViewController:nav animated:YES completion:nil];
    }
}

#pragma mark - WCPluginsMgr registration

void WCGestureRegisterEntry(void) {
    Class mgrClass = NSClassFromString(@"WCPluginsMgr");
    if (!mgrClass) return;
    SEL sharedSelector = sel_registerName("sharedInstance");
    if (![mgrClass respondsToSelector:sharedSelector]) return;
    id mgr = ((id (*)(id, SEL))objc_msgSend)(mgrClass, sharedSelector);
    if (!mgr) return;

    // Register a controller-based entry. WeChat instantiates the controller
    // by the class name string we pass here. Title is user-customizable.
    NSString *pluginName = [[NSUserDefaults standardUserDefaults] stringForKey:WCPluginNameKey] ?: @"微信手势";
    SEL registerController = sel_registerName("registerControllerWithTitle:version:controller:");
    if ([mgr respondsToSelector:registerController]) {
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(mgr, registerController,
            pluginName, @"1.0.0", NSStringFromClass([WCGestureSettingsController class]));
        return;
    }

    // Older API: a single switch row controlling message gestures.
    SEL registerSwitch = sel_registerName("registerSwitchWithTitle:key:");
    if ([mgr respondsToSelector:registerSwitch]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(mgr, registerSwitch,
            pluginName, WCReplySwipeEnabledKey);
    }
}
