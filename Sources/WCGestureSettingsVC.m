#import "WCGestureSettingsVC.h"
#import "WCGestureConfig.h"
#import "WCGestureAccount.h"
#import "WCGestureTranslate.h"
#import "WCGestureAI.h"
#import "WCPopup.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

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
    // Replying to your own message makes no sense, so only offer it for the
    // other side's messages.
    if (!selfMessage) [options addObject:@{ @"title": @"AI 回复", @"value": @(WCReplySwipeActionAIReply) }];
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
    BOOL isWidth = [defaultsKey isEqualToString:WCKeyboardStripWidthKey]
        || [defaultsKey isEqualToString:WCKeyboardStripWidthKeyThirdParty];
    BOOL isOffset = [defaultsKey isEqualToString:WCKeyboardStripOffsetXKey]
        || [defaultsKey isEqualToString:WCKeyboardStripOffsetYKey]
        || [defaultsKey isEqualToString:WCKeyboardStripOffsetXKeyThirdParty]
        || [defaultsKey isEqualToString:WCKeyboardStripOffsetYKeyThirdParty];
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

#pragma mark - Keyboard signature

static NSArray<NSDictionary *> *WCSignatureFontOptions(void) {
    return @[
        @{ @"title": @"系统字", @"value": @(WCKeyboardSignatureFontSystem) },
        @{ @"title": @"楷体", @"value": @(WCKeyboardSignatureFontKaiti) },
        @{ @"title": @"行楷", @"value": @(WCKeyboardSignatureFontXingkai) },
        @{ @"title": @"宋体", @"value": @(WCKeyboardSignatureFontSongti) },
        @{ @"title": @"圆体", @"value": @(WCKeyboardSignatureFontYuanti) },
        @{ @"title": @"手写体", @"value": @(WCKeyboardSignatureFontHannotate) },
        @{ @"title": @"娃娃体", @"value": @(WCKeyboardSignatureFontWawati) },
    ];
}

static NSString *WCSignatureFontName(NSInteger face) {
    for (NSDictionary *option in WCSignatureFontOptions()) {
        if ([option[@"value"] integerValue] == face) return option[@"title"];
    }
    return @"系统字";
}

static void WCPresentSignatureFontPicker(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger current = [defaults integerForKey:WCKeyboardSignatureFontKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCSignatureFontOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:@"签名字体"
                          message:@"使用系统自带中文字体；设备缺少该字体时回退为系统字"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], WCKeyboardSignatureFontKey);
    }];
}

static NSArray<NSDictionary *> *WCSignatureDecorationOptions(void) {
    return @[
        @{ @"title": @"无装饰", @"value": @(WCKeyboardSignatureDecorationNone) },
        @{ @"title": @"拉开字距", @"value": @(WCKeyboardSignatureDecorationSpaced) },
        @{ @"title": @"描边空心", @"value": @(WCKeyboardSignatureDecorationOutline) },
        @{ @"title": @"— 横线 —", @"value": @(WCKeyboardSignatureDecorationDivider) },
        @{ @"title": @"◇ 菱形 ◇", @"value": @(WCKeyboardSignatureDecorationDiamond) },
        @{ @"title": @"· 圆点 ·", @"value": @(WCKeyboardSignatureDecorationDot) },
        @{ @"title": @"✦ 星芒 ✦", @"value": @(WCKeyboardSignatureDecorationStar) },
        @{ @"title": @"「引号」", @"value": @(WCKeyboardSignatureDecorationQuote) },
    ];
}

static NSString *WCSignatureDecorationName(NSInteger decoration) {
    for (NSDictionary *option in WCSignatureDecorationOptions()) {
        if ([option[@"value"] integerValue] == decoration) return option[@"title"];
    }
    return @"无装饰";
}

static void WCPresentSignatureDecorationPicker(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger current = [defaults integerForKey:WCKeyboardSignatureDecorationKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCSignatureDecorationOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:@"签名装饰"
                          message:@"装饰符会加在签名两侧，文字本身保持不变"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], WCKeyboardSignatureDecorationKey);
    }];
}

// Empty value = follow the system label color (works in both light and dark).
static NSArray<NSDictionary *> *WCSignatureColorOptions(void) {
    return @[
        @{ @"title": @"跟随系统", @"value": @"" },
        @{ @"title": @"白色", @"value": @"#FFFFFF" },
        @{ @"title": @"黑色", @"value": @"#000000" },
        @{ @"title": @"灰色", @"value": @"#8E8E93" },
        @{ @"title": @"红色", @"value": @"#FF3B30" },
        @{ @"title": @"橙色", @"value": @"#FF9500" },
        @{ @"title": @"黄色", @"value": @"#FFCC00" },
        @{ @"title": @"绿色", @"value": @"#34C759" },
        @{ @"title": @"青色", @"value": @"#32ADE6" },
        @{ @"title": @"蓝色", @"value": @"#007AFF" },
        @{ @"title": @"紫色", @"value": @"#AF52DE" },
        @{ @"title": @"粉色", @"value": @"#FF2D55" },
        @{ @"title": @"自定义 HEX…", @"value": @"#custom" },
    ];
}

static NSString *WCSignatureColorName(NSString *hex) {
    if (hex.length == 0) return @"跟随系统";
    for (NSDictionary *option in WCSignatureColorOptions()) {
        NSString *value = option[@"value"];
        if ([value isEqualToString:@"#custom"]) continue;
        if ([value caseInsensitiveCompare:hex] == NSOrderedSame) return option[@"title"];
    }
    return hex;
}

static BOOL WCIsValidHexColor(NSString *hex) {
    NSString *value = hex;
    if ([value hasPrefix:@"#"]) value = [value substringFromIndex:1];
    if (value.length != 6) return NO;
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    return [value rangeOfCharacterFromSet:nonHex].location == NSNotFound;
}

static void WCPresentSignatureHexEditor(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *current = [defaults stringForKey:WCKeyboardSignatureColorKey] ?: @"";
    [WCPopup showInputWithTitle:@"自定义颜色"
                        message:@"输入 6 位十六进制颜色，例如 #FF8800"
                           text:current
                    placeholder:@"#FF8800"
                       keyboard:UIKeyboardTypeASCIICapable
                     completion:^(NSString *value) {
        NSString *hex = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (![hex hasPrefix:@"#"]) hex = [@"#" stringByAppendingString:hex];
        if (!WCIsValidHexColor(hex)) {
            [WCPopup showMessage:@"颜色格式不正确" message:@"请输入 #RRGGBB，例如 #FF8800"];
            return;
        }
        [defaults setObject:[hex uppercaseString] forKey:WCKeyboardSignatureColorKey];
        WCPostChange(WCKeyboardSignatureColorKey);
    }];
}

static void WCPresentSignatureColorPicker(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *current = [defaults stringForKey:WCKeyboardSignatureColorKey] ?: @"";
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCSignatureColorOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:@"签名颜色"
                          message:@"「跟随系统」会在浅色/深色键盘上自动换成合适的颜色"
                          options:options
                         selected:current
                       completion:^(id value) {
        if (![value isKindOfClass:[NSString class]]) return;
        if ([value isEqualToString:@"#custom"]) {
            WCPresentSignatureHexEditor();
            return;
        }
        [defaults setObject:value forKey:WCKeyboardSignatureColorKey];
        WCPostChange(WCKeyboardSignatureColorKey);
    }];
}

static void WCPresentSignatureEditor(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = [defaults stringForKey:WCKeyboardSignatureTextKey] ?: @"";
    [WCPopup showInputWithTitle:@"触控区签名"
                        message:@"显示在触发范围中间；要关闭请用「清除签名」"
                           text:text
                    placeholder:@"例如：秋 🌾"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        [defaults setObject:trimmed forKey:WCKeyboardSignatureTextKey];
        WCPostChange(WCKeyboardSignatureTextKey);
    }];
}

// "+5" / "-3" for non-zero offsets; "0" when centered.
static NSString *WCSignatureOffsetDescription(double value) {
    if (fabs(value) < 0.5) return @"0";
    return [NSString stringWithFormat:@"%+.0f", value];
}

// Small nudges only: the strip is short, so the useful range is ±60 points.
static void WCPresentSignatureOffsetEditor(__unused UIViewController *presenter,
                                           NSString *title, NSString *defaultsKey) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL horizontal = [defaultsKey isEqualToString:WCKeyboardSignatureOffsetXKey];
    double value = [defaults doubleForKey:defaultsKey];
    [WCPopup showInputWithTitle:title
                        message:(horizontal
                            ? @"输入 -60 到 60；正数向右，0 复位，建议每次调 1~10"
                            : @"输入 -60 到 60；正数向上，0 复位，建议每次调 1~10")
                           text:[NSString stringWithFormat:@"%.0f", value]
                    placeholder:@"-60 - 60"
                       keyboard:UIKeyboardTypeNumbersAndPunctuation
                     completion:^(NSString *text) {
        double d = [text doubleValue];
        if (d < -60.0) d = -60.0;
        if (d > 60.0) d = 60.0;
        [defaults setDouble:d forKey:defaultsKey];
        WCPostChange(defaultsKey);
    }];
}

static void WCPresentSignatureSizeEditor(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCKeyboardSignatureSizeKey]];
    [WCPopup showInputWithTitle:@"签名字号"
                        message:@"输入 6 到 24 之间的数值；会随键盘宽度等比缩放"
                           text:text
                    placeholder:@"6 - 24"
                       keyboard:UIKeyboardTypeDecimalPad
                     completion:^(NSString *value) {
        NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length == 0) return;
        double d = [trimmed doubleValue];
        if (d < 6.0) d = 6.0;
        if (d > 24.0) d = 24.0;
        [defaults setDouble:d forKey:WCKeyboardSignatureSizeKey];
        WCPostChange(WCKeyboardSignatureSizeKey);
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
        @{ @"title": @"已配置的 AI", @"value": @(WCTranslateEngineAI) },
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
                          message:@"微软翻译与 MyMemory 免费且无需 key；「已配置的 AI」使用上方 AI 服务商，按预设提示词翻译"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], WCTranslateEngineKey);
    }];
}

// The pair is 中文 ↔ 目标语言; the single "互译" action detects the direction
// from the text, so only the other side needs to be configured.
static void WCPresentTranslatePairPicker(__unused UIViewController *presenter) {
    NSString *current = WCTranslatePairTargetCode();
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *language in WCTranslateLanguageOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:
            [NSString stringWithFormat:@"中文 ↔ %@", language[@"title"]]
                                                    value:language[@"code"]]];
    }
    [WCPopup showOptionsWithTitle:@"互译语言"
                          message:@"互译动作会自动判断方向：中文换成所选语言，其它语言换成中文"
                          options:options
                         selected:current
                       completion:^(id value) {
        if (![value isKindOfClass:[NSString class]]) return;
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:WCTranslatePairTargetKey];
        WCPostChange(WCTranslatePairTargetKey);
    }];
}

static void WCPresentTranslateTest(__unused UIViewController *presenter) {
    NSString *engineName = WCTranslateEngineName(
        [[NSUserDefaults standardUserDefaults] integerForKey:WCTranslateEngineKey]);
    NSString *targetCode = WCTranslatePairTargetCode();
    NSString *targetName = WCTranslateLanguageName(targetCode);
    WCGestureTranslateText(@"你好世界", targetCode, ^(NSString *translated, NSString *errorMessage) {
        if (translated.length > 0) {
            [WCPopup showMessage:[NSString stringWithFormat:@"翻译测试成功 · %@", engineName]
                         message:[NSString stringWithFormat:@"你好世界 → %@：%@", targetName, translated]];
        } else {
            [WCPopup showMessage:[NSString stringWithFormat:@"翻译测试失败 · %@", engineName]
                         message:errorMessage ?: @"未知错误"];
        }
    });
}

#pragma mark - AI assistant (AI 回复 / 回答 / 润色)

static NSArray<NSDictionary *> *WCAIProviderOptions(void) {
    return @[
        @{ @"title": @"DeepSeek", @"value": @(WCGestureAIProviderDeepSeek) },
        @{ @"title": @"千问", @"value": @(WCGestureAIProviderQwen) },
        @{ @"title": @"百炼", @"value": @(WCGestureAIProviderBailian) },
        @{ @"title": @"硅基流动", @"value": @(WCGestureAIProviderSiliconFlow) },
        @{ @"title": @"自定义", @"value": @(WCGestureAIProviderCustom) },
    ];
}

static void WCPresentAIProviderPicker(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger current = [defaults integerForKey:WCGestureAIProviderKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCAIProviderOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    [WCPopup showOptionsWithTitle:@"AI 服务商"
                          message:@"选择模板会自动填好接口地址和模型；切换后需重新填写对应的 API Key"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        NSInteger provider = [value integerValue];
        [defaults setInteger:provider forKey:WCGestureAIProviderKey];
        // The endpoint/model belong to the template; drop manual overrides so
        // the new provider's defaults take effect.
        [defaults setObject:@"" forKey:WCGestureAIBaseURLKey];
        [defaults setObject:@"" forKey:WCGestureAIModelKey];
        WCPostChange(WCGestureAIProviderKey);
    }];
}

static void WCPresentAITextEditor(__unused UIViewController *presenter,
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

static void WCPresentAIAPIKeyEditor(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [WCPopup showSecureInputWithTitle:@"AI API Key"
                              message:@"输入新的 Key 会覆盖旧值；取消则保持不变"
                                 text:@""
                          placeholder:@"sk-..."
                             keyboard:UIKeyboardTypeDefault
                           completion:^(NSString *value) {
        NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        if (trimmed.length == 0) return;
        [defaults setObject:trimmed forKey:WCGestureAIAPIKeyKey];
        WCPostChange(WCGestureAIAPIKeyKey);
    }];
}

// Presets are user-managed: any number of them, each with a full system
// prompt. An empty prompt keeps the built-in prompt for the chosen task.
static NSArray<NSDictionary *> *WCAIPresetOptions(void) {
    NSMutableArray *options = [NSMutableArray array];
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
    for (NSUInteger i = 0; i < presets.count; i++) {
        [options addObject:@{ @"title": presets[i][@"name"], @"value": @(i) }];
    }
    return options;
}

static void WCPresentAIPresetPicker(__unused UIViewController *presenter,
                                    NSString *title, NSString *defaultsKey) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:defaultsKey];
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    for (NSDictionary *option in WCAIPresetOptions()) {
        [options addObject:[WCPopupOption optionWithTitle:option[@"title"] value:option[@"value"]]];
    }
    if (current < 0 || current >= (NSInteger)options.count) current = 0;
    [WCPopup showOptionsWithTitle:title
                          message:@"方案填了完整提示词就整段替换内置提示词；留空则用内置默认"
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], defaultsKey);
    }];
}

// Updates one preset's name and/or prompt; nil leaves that field untouched.
static void WCAIPresetUpdate(NSInteger index, NSString *name, NSString *prompt) {
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
    if (index < 0 || index >= (NSInteger)presets.count) return;
    NSMutableArray *updated = [presets mutableCopy];
    NSMutableDictionary *entry = [presets[(NSUInteger)index] mutableCopy];
    if (name) entry[@"name"] = name;
    if (prompt) entry[@"prompt"] = prompt;
    updated[(NSUInteger)index] = entry;
    WCGestureAISetPresets(updated);
    WCPostChange(WCGestureAIPresetsKey);
}

static void WCPresentAIPresetPromptEditor(NSInteger index) {
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
    if (index < 0 || index >= (NSInteger)presets.count) return;
    NSDictionary<NSString *, NSString *> *preset = presets[(NSUInteger)index];
    [WCPopup showInputWithTitle:[NSString stringWithFormat:@"%@ · 完整提示词", preset[@"name"]]
                        message:@"这里填整段系统提示词；留空请用「清空提示词」"
                           text:preset[@"prompt"]
                    placeholder:@"例如：你是……，只输出……"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        WCAIPresetUpdate(index, nil, value ?: @"");
    }];
}

static void WCPresentAIPresetRename(NSInteger index) {
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
    if (index < 0 || index >= (NSInteger)presets.count) return;
    NSDictionary<NSString *, NSString *> *preset = presets[(NSUInteger)index];
    [WCPopup showInputWithTitle:@"重命名方案"
                        message:@"输入新的方案名称"
                           text:preset[@"name"]
                    placeholder:@"方案名称"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        if (value.length == 0) return;
        WCAIPresetUpdate(index, value, nil);
    }];
}

static void WCPresentAIPresetActions(NSInteger index) {
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
    if (index < 0 || index >= (NSInteger)presets.count) return;
    NSMutableArray<WCPopupOption *> *options = [NSMutableArray array];
    [options addObject:[WCPopupOption optionWithTitle:@"编辑完整提示词" value:@"edit"]];
    [options addObject:[WCPopupOption optionWithTitle:@"重命名" value:@"rename"]];
    [options addObject:[WCPopupOption optionWithTitle:@"清空提示词（用内置默认）" value:@"clear"]];
    if (presets.count > 1) {
        [options addObject:[WCPopupOption optionWithTitle:@"删除这个方案" value:@"delete"]];
    }
    [WCPopup showOptionsWithTitle:presets[(NSUInteger)index][@"name"]
                          message:@"提示词留空时使用内置默认提示词"
                          options:options
                         selected:nil
                       completion:^(id value) {
        if (![value isKindOfClass:[NSString class]]) return;
        if ([value isEqualToString:@"edit"]) {
            WCPresentAIPresetPromptEditor(index);
        } else if ([value isEqualToString:@"rename"]) {
            WCPresentAIPresetRename(index);
        } else if ([value isEqualToString:@"clear"]) {
            WCAIPresetUpdate(index, nil, @"");
        } else if ([value isEqualToString:@"delete"]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            // Keep the per-task selections pointing at the same presets.
            for (NSString *key in @[WCGestureAIReplyPresetKey,
                                    WCGestureAIAnswerPresetKey,
                                    WCGestureAIPolishPresetKey]) {
                NSInteger selected = [defaults integerForKey:key];
                if (selected == index) [defaults setInteger:0 forKey:key];
                else if (selected > index) [defaults setInteger:selected - 1 forKey:key];
            }
            NSMutableArray *updated = [presets mutableCopy];
            [updated removeObjectAtIndex:(NSUInteger)index];
            WCGestureAISetPresets(updated);
            WCPostChange(WCGestureAIPresetsKey);
        }
    }];
}

static void WCPresentAIPresetAdd(void) {
    NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
    NSString *suggested = [NSString stringWithFormat:@"方案 %lu", (unsigned long)presets.count + 1];
    [WCPopup showInputWithTitle:@"新增方案"
                        message:@"输入方案名称；创建后点它编辑完整提示词"
                           text:suggested
                    placeholder:@"方案名称"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        NSMutableArray *updated = [presets mutableCopy];
        [updated addObject:@{ @"name": value, @"prompt": @"" }];
        WCGestureAISetPresets(updated);
        WCPostChange(WCGestureAIPresetsKey);
    }];
}

static void WCPresentAIPresetReset(void) {
    NSArray *builtIn = @[
        @{ @"name": @"方案 1", @"prompt": @"" },
        @{ @"name": @"方案 2", @"prompt": @"" },
        @{ @"name": @"方案 3", @"prompt": @"" },
    ];
    WCGestureAISetPresets(builtIn);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in @[WCGestureAIReplyPresetKey,
                            WCGestureAIAnswerPresetKey,
                            WCGestureAIPolishPresetKey]) {
        [defaults setInteger:0 forKey:key];
    }
    // Also clear the legacy prompts so the migration path cannot bring them back.
    [defaults setObject:@"" forKey:WCGestureAIPresetPrompt1Key];
    [defaults setObject:@"" forKey:WCGestureAIPresetPrompt2Key];
    [defaults setObject:@"" forKey:WCGestureAIPresetPrompt3Key];
    WCPostChange(WCGestureAIPresetsKey);
}

static void WCPresentAIDefaultPrompts(void) {
    NSString *text = [NSString stringWithFormat:
        @"AI 回复：\n%@\n\nAI 回答：\n%@\n\nAI 润色：\n%@",
        WCGestureAIDefaultPrompt(WCGestureAITaskReply),
        WCGestureAIDefaultPrompt(WCGestureAITaskAnswer),
        WCGestureAIDefaultPrompt(WCGestureAITaskPolish)];
    [WCPopup showTextWithTitle:@"内置提示词"
                       message:@"方案提示词留空时使用；可复制后改成自己的方案"
                          text:text];
}

static void WCPresentAITest(__unused UIViewController *presenter) {
    NSString *providerName = WCGestureAIProviderName(
        [[NSUserDefaults standardUserDefaults] integerForKey:WCGestureAIProviderKey]);
    WCGestureAIPerform(WCGestureAITaskAnswer, @"用一句话介绍你自己", ^(NSString *text, NSString *errorMessage) {
        if (text.length > 0) {
            [WCPopup showMessage:[NSString stringWithFormat:@"AI 测试成功 · %@", providerName]
                         message:text];
        } else {
            [WCPopup showMessage:[NSString stringWithFormat:@"AI 测试失败 · %@", providerName]
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
        @"H": WCKeyboardLongPressActionKey,
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
    // One mutual-translation action: the direction is detected from the input,
    // so it only takes a single gesture slot. The title follows the configured
    // language pair without changing the stored value.
    NSString *targetName = WCTranslateLanguageName(WCTranslatePairTargetCode());
    NSString *translateMutual = [NSString stringWithFormat:@"翻译 · 互译（中文 ↔ %@）", targetName];
    return @[
        @{ @"title": @"不设置", @"value": @(WCInputActionNone) },
        @{ @"title": @"清空", @"value": @(WCInputActionClear) },
        @{ @"title": @"粘贴", @"value": @(WCInputActionPaste) },
        @{ @"title": @"复制", @"value": @(WCInputActionCopy) },
        @{ @"title": @"剪切", @"value": @(WCInputActionCut) },
        @{ @"title": translateMutual, @"value": @(WCInputActionTranslate) },
        @{ @"title": @"转大写", @"value": @(WCInputActionUppercase) },
        @{ @"title": @"转小写", @"value": @(WCInputActionLowercase) },
        @{ @"title": @"去空格换行", @"value": @(WCInputActionTrim) },
        @{ @"title": @"AI 润色", @"value": @(WCInputActionAIPolish) },
        @{ @"title": @"AI 回答", @"value": @(WCInputActionAIAnswer) },
    ];
}

static NSString *WCInputActionName(NSInteger action) {
    // Saved configs may still hold the old "译成中文" value.
    if (action == WCInputActionTranslateLegacy) action = WCInputActionTranslate;
    for (NSDictionary *option in WCInputActionOptions()) {
        if ([option[@"value"] integerValue] == action) return option[@"title"];
    }
    return @"清空";
}

#pragma mark - Input action picker

static void WCPresentInputSwipeActionPicker(__unused UIViewController *presenter, NSString *title, NSString *defaultsKey) {
    NSInteger current = [[NSUserDefaults standardUserDefaults] integerForKey:defaultsKey];
    if (current == WCInputActionTranslateLegacy) current = WCInputActionTranslate;
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
    WCRowKindGroupToggle,   // tap → fold/unfold the rows below it
    WCRowKindHint,          // small gray explanatory text, not tappable
    WCRowKindActionDetail,  // tap → message action picker
    WCRowKindInputAction,   // tap → input swipe action picker
    WCRowKindGlobalAction,  // tap → global action picker
    WCRowKindDistance,      // tap → number editor
    WCRowKindKeyboardNumber,// tap → number editor for the keyboard strip geometry
    WCRowKindSignatureText, // tap → strip signature editor
    WCRowKindSignatureSize, // tap → signature font size editor
    WCRowKindSignatureFont, // tap → signature typeface picker
    WCRowKindSignatureDecoration, // tap → signature ornament picker
    WCRowKindSignatureColor,// tap → signature color picker
    WCRowKindSignatureOffsetX, // tap → nudge the caption left/right
    WCRowKindSignatureOffsetY, // tap → nudge the caption up/down
    WCRowKindSignatureClear,// tap → remove the signature
    WCRowKindAIProvider,    // tap → AI provider template picker
    WCRowKindAIBaseURL,     // tap → OpenAI-compatible endpoint editor
    WCRowKindAIModel,       // tap → model name editor
    WCRowKindAIAPIKey,      // tap → secure API key editor
    WCRowKindAIPreset,        // tap → manage one preset (prompt / rename / delete)
    WCRowKindAIPresetAdd,     // tap → add a new preset
    WCRowKindAIPresetReset,   // tap → restore the built-in three presets
    WCRowKindAIDefaultPrompts,// tap → show the built-in prompts
    WCRowKindAIReplyPreset,   // tap → pick the preset used by AI 回复
    WCRowKindAIAnswerPreset,  // tap → pick the preset used by AI 回答
    WCRowKindAIPolishPreset,  // tap → pick the preset used by AI 润色
    WCRowKindAIReset,       // tap → clear AI endpoint/model/key/presets
    WCRowKindAITest,        // tap → test the AI endpoint
    WCRowKindPluginName,    // tap → plugin name editor
    WCRowKindHapticStyle,   // tap → haptic style picker
    WCRowKindCustomPages, // tap → custom page class name editor
    WCRowKindTranslateEngine,     // tap → translation engine picker
    WCRowKindTranslatePair,       // tap → 中文 ↔ language picker
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
@property (nonatomic, assign) NSInteger presetIndex;// AI preset this row manages
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

static WCRow *WCAIPresetRow(NSString *title, NSInteger index) {
    WCRow *row = WCPlainRow(title, WCRowKindAIPreset);
    row.presetIndex = index;
    return row;
}

// A foldable sub-group inside a section. `key` holds YES once expanded, so an
// untouched install starts folded and the long keyboard section stays compact.
static WCRow *WCGroupRow(NSString *title, NSString *key) {
    WCRow *row = WCPlainRow(title, WCRowKindGroupToggle);
    row.defaultsKey = key;
    return row;
}

static WCRow *WCHintRow(NSString *text) {
    WCRow *row = WCPlainRow(text, WCRowKindHint);
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
        case WCRowKindTranslatePair:
            return [NSString stringWithFormat:@"中文 ↔ %@",
                    WCTranslateLanguageName(WCTranslatePairTargetCode())];
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
            if ([row.defaultsKey isEqualToString:WCKeyboardStripWidthKey]
                || [row.defaultsKey isEqualToString:WCKeyboardStripWidthKeyThirdParty]) {
                double w = [d doubleForKey:row.defaultsKey];
                return w > 0 ? [NSString stringWithFormat:@"%.0f", w] : @"满宽";
            }
            return [NSString stringWithFormat:@"%.0f", [d doubleForKey:row.defaultsKey]];
        }
        case WCRowKindSignatureText: {
            NSString *text = [d stringForKey:WCKeyboardSignatureTextKey] ?: @"";
            return text.length > 0 ? text : @"未设置";
        }
        case WCRowKindSignatureSize:
            return [NSString stringWithFormat:@"%.0f", [d doubleForKey:WCKeyboardSignatureSizeKey]];
        case WCRowKindSignatureFont:
            return WCSignatureFontName([d integerForKey:WCKeyboardSignatureFontKey]);
        case WCRowKindSignatureDecoration:
            return WCSignatureDecorationName([d integerForKey:WCKeyboardSignatureDecorationKey]);
        case WCRowKindSignatureColor:
            return WCSignatureColorName([d stringForKey:WCKeyboardSignatureColorKey] ?: @"");
        case WCRowKindSignatureOffsetX:
            return WCSignatureOffsetDescription([d doubleForKey:WCKeyboardSignatureOffsetXKey]);
        case WCRowKindSignatureOffsetY:
            return WCSignatureOffsetDescription([d doubleForKey:WCKeyboardSignatureOffsetYKey]);
        case WCRowKindSignatureClear:
            return @"";
        case WCRowKindGroupToggle:
            return [d boolForKey:row.defaultsKey] ? @"收起" : @"展开";
        case WCRowKindHint:
            return @"";
        case WCRowKindAIProvider:
            return WCGestureAIProviderName([d integerForKey:WCGestureAIProviderKey]);
        case WCRowKindAIBaseURL:
            return WCGestureAIResolvedBaseURL();
        case WCRowKindAIModel:
            return WCGestureAIResolvedModel();
        case WCRowKindAIAPIKey: {
            NSString *key = [d stringForKey:WCGestureAIAPIKeyKey] ?: @"";
            return key.length > 0
                ? [NSString stringWithFormat:@"已设置(%lu 位)", (unsigned long)key.length]
                : @"未设置";
        }
        case WCRowKindAIPreset: {
            NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
            if (row.presetIndex < 0 || row.presetIndex >= (NSInteger)presets.count) return @"默认";
            NSString *prompt = presets[(NSUInteger)row.presetIndex][@"prompt"];
            if (prompt.length == 0) return @"默认";
            return prompt.length > 16
                ? [[prompt substringToIndex:16] stringByAppendingString:@"…"] : prompt;
        }
        case WCRowKindAIReplyPreset:
            return WCGestureAIPresetName([d integerForKey:WCGestureAIReplyPresetKey]);
        case WCRowKindAIAnswerPreset:
            return WCGestureAIPresetName([d integerForKey:WCGestureAIAnswerPresetKey]);
        case WCRowKindAIPolishPreset:
            return WCGestureAIPresetName([d integerForKey:WCGestureAIPolishPresetKey]);
        case WCRowKindAIPresetAdd:
        case WCRowKindAIPresetReset:
        case WCRowKindAIDefaultPrompts:
        case WCRowKindAIReset:
        case WCRowKindAITest:
            return @"";
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
    NSString *existingMode = [existing[@"mode"] isKindOfClass:[NSString class]] ? existing[@"mode"] : @"full";
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
            NSArray<WCPopupOption *> *modes = @[
                [WCPopupOption optionWithTitle:@"全屏（推入当前导航）" value:@"full"],
                [WCPopupOption optionWithTitle:@"模态（卡片弹出，可下滑关闭）" value:@"modal"],
            ];
            [WCPopup showOptionsWithTitle:@"打开方式"
                                  message:@"有些页面只能模态打开，有些更适合全屏"
                                  options:modes
                                 selected:existingMode
                               completion:^(id value) {
                NSString *mode = [value isKindOfClass:[NSString class]] ? value : @"full";
                NSDictionary *entry = @{ @"name": remark, @"class": className, @"mode": mode };
                NSMutableArray *pages = [self.pages mutableCopy];
                if (index >= 0 && index < (NSInteger)pages.count) pages[index] = entry;
                else [pages addObject:entry];
                self.pages = pages;
                [self savePages];
                [self.tableView reloadData];
            }];
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
    NSString *className = [entry[@"class"] isKindOfClass:[NSString class]] ? entry[@"class"] : @"";
    NSString *mode = [entry[@"mode"] isKindOfClass:[NSString class]] ? entry[@"mode"] : @"";
    NSString *modeName = [mode isEqualToString:@"modal"] ? @"模态" : @"全屏";
    cell.detailTextLabel.text = className.length > 0
        ? [NSString stringWithFormat:@"%@ · %@", className, modeName] : modeName;
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
        [keyboard addObject:WCSwitchRow(@"键盘底部手势", WCKeyboardEnhanceEnabledKey)];
        if ([d boolForKey:WCKeyboardEnhanceEnabledKey]) {
            [keyboard addObject:WCSwitchRow(@"震动", WCKeyboardHapticKey)];
            [keyboard addObject:WCInputActionRow(@"左滑动作", WCKeyboardSwipeLeftActionKey)];
            [keyboard addObject:WCInputActionRow(@"右滑动作", WCKeyboardSwipeRightActionKey)];
            [keyboard addObject:WCInputActionRow(@"双击动作", WCKeyboardDoubleTapActionKey)];
            [keyboard addObject:WCInputActionRow(@"三击动作", WCKeyboardTripleTapActionKey)];
            [keyboard addObject:WCInputActionRow(@"长按动作", WCKeyboardLongPressActionKey)];
            [keyboard addObject:WCSwitchRow(@"显示触发范围", WCKeyboardDebugFrameKey)];
            // Optional caption inside the strip. Its size/style rows only show
            // up once there is text, so the section stays short by default.
            [keyboard addObject:WCPlainRow(@"触控区签名", WCRowKindSignatureText)];
            NSString *signature = [d stringForKey:WCKeyboardSignatureTextKey] ?: @"";
            if (signature.length > 0) {
                // Folded by default for the same reason as the strip geometry.
                NSString *signatureKey = [prefix stringByAppendingString:@".chat.keyboard.signature.expanded"];
                [keyboard addObject:WCGroupRow(@"签名参数", signatureKey)];
                if ([d boolForKey:signatureKey]) {
                    [keyboard addObject:WCPlainRow(@"签名字号", WCRowKindSignatureSize)];
                    [keyboard addObject:WCPlainRow(@"签名字体", WCRowKindSignatureFont)];
                    [keyboard addObject:WCPlainRow(@"签名装饰", WCRowKindSignatureDecoration)];
                    [keyboard addObject:WCPlainRow(@"签名颜色", WCRowKindSignatureColor)];
                    [keyboard addObject:WCPlainRow(@"签名左右位置", WCRowKindSignatureOffsetX)];
                    [keyboard addObject:WCPlainRow(@"签名上下位置", WCRowKindSignatureOffsetY)];
                    // The input popup treats an empty text field as cancel, so
                    // clearing needs its own row.
                    [keyboard addObject:WCPlainRow(@"清除签名", WCRowKindSignatureClear)];
                }
            }
            // Tap to type a value and see the strip move without rebuilding.
            // Folded by default: eight numbers made the section far too long.
            // Two sets: the system keyboard and third-party keyboards.
            NSString *geometryKey = [prefix stringByAppendingString:@".chat.keyboard.geometry.expanded"];
            [keyboard addObject:WCGroupRow(@"触控区参数", geometryKey)];
            if ([d boolForKey:geometryKey]) {
                // One shared set by default; turn this on to tune the
                // third-party keyboard separately.
                [keyboard addObject:WCSwitchRow(@"第三方单独调节", WCKeyboardStripSeparateAdjustKey)];
                [keyboard addObject:WCHintRow(@"第三方键盘可能存在偏移，支持独立调节")];
                if ([d boolForKey:WCKeyboardStripSeparateAdjustKey]) {
                    [keyboard addObject:WCNumberRow(@"触控区宽度（官方）", WCKeyboardStripWidthKey)];
                    [keyboard addObject:WCNumberRow(@"触控区高度（官方）", WCKeyboardStripHeightKey)];
                    [keyboard addObject:WCNumberRow(@"左右偏移（官方）", WCKeyboardStripOffsetXKey)];
                    [keyboard addObject:WCNumberRow(@"上下偏移（官方）", WCKeyboardStripOffsetYKey)];
                    [keyboard addObject:WCNumberRow(@"触控区宽度（第三方）", WCKeyboardStripWidthKeyThirdParty)];
                    [keyboard addObject:WCNumberRow(@"触控区高度（第三方）", WCKeyboardStripHeightKeyThirdParty)];
                    [keyboard addObject:WCNumberRow(@"左右偏移（第三方）", WCKeyboardStripOffsetXKeyThirdParty)];
                    [keyboard addObject:WCNumberRow(@"上下偏移（第三方）", WCKeyboardStripOffsetYKeyThirdParty)];
                } else {
                    [keyboard addObject:WCNumberRow(@"触控区宽度", WCKeyboardStripWidthKey)];
                    [keyboard addObject:WCNumberRow(@"触控区高度", WCKeyboardStripHeightKey)];
                    [keyboard addObject:WCNumberRow(@"左右偏移", WCKeyboardStripOffsetXKey)];
                    [keyboard addObject:WCNumberRow(@"上下偏移", WCKeyboardStripOffsetYKey)];
                }
            }
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
        NSMutableArray *ai = [NSMutableArray array];
        [ai addObject:WCSwitchRow(@"AI 配置", WCGestureAIEnabledKey)];
        if ([d boolForKey:WCGestureAIEnabledKey]) {
            [ai addObject:WCPlainRow(@"AI 服务商", WCRowKindAIProvider)];
            [ai addObject:WCPlainRow(@"接口地址", WCRowKindAIBaseURL)];
            [ai addObject:WCPlainRow(@"模型", WCRowKindAIModel)];
            [ai addObject:WCPlainRow(@"API Key", WCRowKindAIAPIKey)];
            // User-managed prompt presets; each AI action picks one of them.
            NSArray<NSDictionary<NSString *, NSString *> *> *presets = WCGestureAIPresets();
            for (NSUInteger i = 0; i < presets.count; i++) {
                [ai addObject:WCAIPresetRow(presets[i][@"name"], (NSInteger)i)];
            }
            [ai addObject:WCPlainRow(@"新增方案", WCRowKindAIPresetAdd)];
            [ai addObject:WCPlainRow(@"查看内置提示词", WCRowKindAIDefaultPrompts)];
            [ai addObject:WCPlainRow(@"AI 回复方案", WCRowKindAIReplyPreset)];
            [ai addObject:WCPlainRow(@"AI 回答方案", WCRowKindAIAnswerPreset)];
            [ai addObject:WCPlainRow(@"AI 润色方案", WCRowKindAIPolishPreset)];
            [ai addObject:WCPlainRow(@"恢复自带三个方案", WCRowKindAIPresetReset)];
            BOOL aiConfigured = [d stringForKey:WCGestureAIBaseURLKey].length > 0
                || [d stringForKey:WCGestureAIModelKey].length > 0
                || [d stringForKey:WCGestureAIAPIKeyKey].length > 0;
            if (aiConfigured) [ai addObject:WCPlainRow(@"清除 AI 配置", WCRowKindAIReset)];
            [ai addObject:WCPlainRow(@"测试 AI", WCRowKindAITest)];
        }
        [sections addObject:ai];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".ai"]];
        NSMutableArray *translate = [NSMutableArray array];
        [translate addObject:WCSwitchRow(@"翻译", WCTranslateEnabledKey)];
        if ([d boolForKey:WCTranslateEnabledKey]) {
            [translate addObject:WCPlainRow(@"翻译引擎", WCRowKindTranslateEngine)];
            [translate addObject:WCPlainRow(@"互译语言", WCRowKindTranslatePair)];
            [translate addObject:WCPlainRow(@"测试翻译", WCRowKindTranslateTest)];
        }
        [sections addObject:translate];
        [collapsible addObject:@YES];
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
    BOOL isHint = row.kind == WCRowKindHint;
    cell.textLabel.text = row.title;
    // Hint rows read as a footnote, not as a tappable setting.
    cell.textLabel.font = [UIFont systemFontOfSize:(isHint ? 13.0 : 17.0)];
    cell.textLabel.textColor = isHint ? UIColor.secondaryLabelColor : UIColor.labelColor;
    cell.textLabel.numberOfLines = isHint ? 0 : 1;
    cell.detailTextLabel.text = (row.kind == WCRowKindSwitch || isHint) ? @"" : WCRowDetailText(row);
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
    } else if (row.kind != WCRowKindHint) {
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
        case WCRowKindSwitch:
        case WCRowKindHint:
            break;
        case WCRowKindGroupToggle: {
            BOOL expanded = [[NSUserDefaults standardUserDefaults] boolForKey:row.defaultsKey];
            WCSetBool(!expanded, row.defaultsKey);
            break;
        }
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
        case WCRowKindTranslatePair:
            WCPresentTranslatePairPicker(self);
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
        case WCRowKindSignatureText:
            WCPresentSignatureEditor(self);
            break;
        case WCRowKindSignatureSize:
            WCPresentSignatureSizeEditor(self);
            break;
        case WCRowKindSignatureFont:
            WCPresentSignatureFontPicker(self);
            break;
        case WCRowKindSignatureDecoration:
            WCPresentSignatureDecorationPicker(self);
            break;
        case WCRowKindSignatureColor:
            WCPresentSignatureColorPicker(self);
            break;
        case WCRowKindSignatureOffsetX:
            WCPresentSignatureOffsetEditor(self, @"签名左右位置", WCKeyboardSignatureOffsetXKey);
            break;
        case WCRowKindSignatureOffsetY:
            WCPresentSignatureOffsetEditor(self, @"签名上下位置", WCKeyboardSignatureOffsetYKey);
            break;
        case WCRowKindSignatureClear:
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:WCKeyboardSignatureTextKey];
            WCPostChange(WCKeyboardSignatureTextKey);
            break;
        case WCRowKindAIProvider:
            WCPresentAIProviderPicker(self);
            break;
        case WCRowKindAIBaseURL: {
            NSInteger provider = [[NSUserDefaults standardUserDefaults] integerForKey:WCGestureAIProviderKey];
            NSString *fallback = WCGestureAIProviderDefaultBaseURL(provider);
            WCPresentAITextEditor(self, @"AI 接口地址",
                @"OpenAI 兼容地址；取消则保持当前值，切换服务商可恢复模板默认",
                WCGestureAIBaseURLKey,
                fallback.length > 0 ? fallback : @"https://api.example.com/v1");
            break;
        }
        case WCRowKindAIModel: {
            NSInteger provider = [[NSUserDefaults standardUserDefaults] integerForKey:WCGestureAIProviderKey];
            NSString *fallback = WCGestureAIProviderDefaultModel(provider);
            WCPresentAITextEditor(self, @"AI 模型",
                @"填写服务商提供的模型名称；取消则保持当前值",
                WCGestureAIModelKey,
                fallback.length > 0 ? fallback : @"模型名称");
            break;
        }
        case WCRowKindAIAPIKey:
            WCPresentAIAPIKeyEditor(self);
            break;
        case WCRowKindAIPreset:
            WCPresentAIPresetActions(row.presetIndex);
            break;
        case WCRowKindAIPresetAdd:
            WCPresentAIPresetAdd();
            break;
        case WCRowKindAIDefaultPrompts:
            WCPresentAIDefaultPrompts();
            break;
        case WCRowKindAIPresetReset:
            WCPresentAIPresetReset();
            break;
        case WCRowKindAIReplyPreset:
            WCPresentAIPresetPicker(self, @"AI 回复方案", WCGestureAIReplyPresetKey);
            break;
        case WCRowKindAIAnswerPreset:
            WCPresentAIPresetPicker(self, @"AI 回答方案", WCGestureAIAnswerPresetKey);
            break;
        case WCRowKindAIPolishPreset:
            WCPresentAIPresetPicker(self, @"AI 润色方案", WCGestureAIPolishPresetKey);
            break;
        case WCRowKindAIReset: {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:@"" forKey:WCGestureAIBaseURLKey];
            [defaults setObject:@"" forKey:WCGestureAIModelKey];
            [defaults setObject:@"" forKey:WCGestureAIAPIKeyKey];
            WCPresentAIPresetReset();
            WCPostChange(WCGestureAIProviderKey);
            break;
        }
        case WCRowKindAITest:
            WCPresentAITest(self);
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
