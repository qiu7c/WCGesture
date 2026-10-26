#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#import "Sources/API/WCGestureInternal.h"

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

static UIViewController *WCTopViewController(void) {
    UIViewController *root = WCActiveWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

static void WCPostChange(NSString *key) {
    WCGestureSettingsPostChange(key);
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
                          message:nil
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
                        message:nil
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
    BOOL isFontLevel = [defaultsKey isEqualToString:WCChatLayoutFontLevelKey];
    BOOL isPageScale = [defaultsKey isEqualToString:WCGesturePageScalePercentKey];
    BOOL isMomentsCorner = [defaultsKey isEqualToString:WCGestureMomentsImageCornerRadiusKey];
    BOOL isAvatarCorner = [defaultsKey isEqualToString:WCGestureGlobalAvatarCornerPercentKey];
    BOOL isTimeSize = [defaultsKey isEqualToString:WCGestureMessageTimeFontSizeKey];
    BOOL isRounding = [defaultsKey isEqualToString:WCGestureChatInputInnerRadiusKey]
        || [defaultsKey isEqualToString:WCGestureChatInputOuterRadiusKey];
    BOOL isScale = [defaultsKey isEqualToString:WCMomentsHeightScaleKey];
    BOOL isSendConfirmationPause = [defaultsKey isEqualToString:WCGestureSendConfirmationPauseSecondsKey];
    BOOL isReminderInterval = [defaultsKey isEqualToString:WCGestureMomentsReminderIntervalKey];
    double minValue = isPageScale ? 70.0 : (isFontLevel ? 1.0 : (isScale ? 100.0 : (isWidth ? 0.0 : (isOffset ? -400.0 : 20.0))));
    double maxValue = isPageScale ? 100.0 : (isFontLevel ? 8.0 : (isScale ? 160.0 : (isWidth ? 1000.0 : (isOffset ? 400.0 : 200.0))));
    if (isReminderInterval) { minValue = 30; maxValue = 3600; }
    if (isSendConfirmationPause) { minValue = 5; maxValue = 3600; }
    if (isAvatarCorner) { minValue = 0; maxValue = 100; }
    if (isTimeSize) { minValue = 8.0; maxValue = 18.0; }
    if (isRounding || isMomentsCorner) { minValue = 0.0; maxValue = 40.0; }
    NSString *placeholder;
    if (isSendConfirmationPause) {
        placeholder = @"5 - 3600 秒（默认 60）";
    } else if (isReminderInterval) {
        placeholder = @"30 - 3600 秒";
    } else if (isMomentsCorner) {
        placeholder = @"0 - 40（默认 8）";
    } else if (isAvatarCorner) {
        placeholder = @"0 - 100（默认 100）";
    } else if (isRounding) {
        placeholder = @"0 - 40";
    } else if (isTimeSize) {
        placeholder = @"8 - 18（默认 10）";
    } else if (isPageScale) {
        placeholder = @"70 - 100（默认 90）";
    } else if (isWidth) {
        placeholder = @"0 = 满宽";
    } else if (isFontLevel) {
        placeholder = @"1 - 8";
    } else if (isScale) {
        placeholder = @"100 - 160";
    } else if (isOffset) {
        placeholder = @"-400 - 400";
    } else {
        placeholder = @"20 - 200";
    }
    NSString *text = [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:defaultsKey]];
    [WCPopup showInputWithTitle:title
                        message:nil
                           text:text
                    placeholder:placeholder
                       keyboard:(isOffset ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDecimalPad)
                     completion:^(NSString *value) {
        double d = [value doubleValue];
        if (!isfinite(d)) return;
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
                          message:nil
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
                          message:nil
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
                        message:nil
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
                          message:nil
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
                        message:nil
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
    double value = [defaults doubleForKey:defaultsKey];
    [WCPopup showInputWithTitle:title
                        message:nil
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
                        message:nil
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
                          message:nil
                          options:options
                         selected:@(current)
                       completion:^(id value) {
        if (!value) return;
        WCSetInteger([value integerValue], WCGestureHapticStyleKey);
    }];
}

static void WCPresentPluginNameEditor(__unused UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *name = [defaults stringForKey:WCPluginNameKey] ?: @"One Wx";
    [WCPopup showInputWithTitle:@"插件名称"
                        message:nil
                           text:name
                    placeholder:@"One Wx"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *value) {
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0) text = @"One Wx";
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
                          message:nil
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
                          message:nil
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
                          message:nil
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
                                  NSString *title,
                                  NSString *defaultsKey, NSString *placeholder) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = [defaults stringForKey:defaultsKey] ?: @"";
    [WCPopup showInputWithTitle:title
                        message:nil
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
                              message:nil
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
                          message:nil
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
                        message:nil
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
                        message:nil
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
                          message:nil
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
                        message:nil
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
                       message:nil
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
    NSMutableDictionary *keys = [@{
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
    } mutableCopy];
    NSArray<NSString *> *additional = @[
        WCGestureHideGroupTitleTailKey,
        WCGestureHideScreenshotForwardKey,
        WCGestureHideMeFinderKey,
        WCGestureHideMeCardsKey,
        WCGestureHideMeEmoticonsKey,
        WCGestureMomentsImageCornerEnabledKey,
        WCGestureMomentsImageCornerRadiusKey,
        WCGestureChatSearchEnabledKey,
        WCGestureQuoteJumpEnabledKey,
        WCGestureQuoteJumpImageKey,
        WCGestureQuoteJumpVideoKey,
        WCGestureMessageRepeatMenuEnabledKey,
        WCGestureMomentsTimeEnabledKey,
        WCGestureMomentsTimeFormatKey,
        WCGestureAutoOriginalEnabledKey,
        WCGestureVoiceTranscriptionEnabledKey,
        WCGestureVoiceTranscriptionIgnoreGroupKey,
        WCGestureVoiceTranscriptionIgnorePrivateKey,
        WCGestureVoiceTranscriptionIgnoreSelfKey,
        WCGestureMessageTimeBelowAvatarKey,
        WCGestureMessageTimeBubbleSideKey,
        WCGestureMessageTimeColorKey,
        WCGestureMessageTimeLightColorKey,
        WCGestureMessageTimeDarkColorKey,
        WCGestureMessageTimeAvatarSpacingKey,
        WCGestureAntiRevokeNotifySenderKey,
        WCGestureAntiRevokeLocalTemplateKey,
        WCGestureAntiRevokeReplyTemplateKey,
        WCGestureAntiRevokeTimeFilterKey,
        WCGestureAntiRevokePromptStyleKey,
        WCGestureAntiRevokeSideTextKey,
        WCGestureAntiRevokeSideOffsetXKey,
        WCGestureAntiRevokeSideOffsetYKey,
        WCGestureAntiRevokeLocalTextColorKey,
        WCGestureAntiRevokeSideTextColorKey,
        WCGestureAntiRevokeLocalLightTextColorKey,
        WCGestureAntiRevokeLocalDarkTextColorKey,
        WCGestureAntiRevokeSideLightTextColorKey,
        WCGestureAntiRevokeSideDarkTextColorKey,
        WCGestureAntiRevokePersistRecordsKey,
        WCGesturePageScalePluginUIKey,
        WCGestureMessageTimeOffsetXKey,
        WCGestureMessageTimeOffsetYKey,
        WCGesturePageScaleEnabledKey,
        WCGestureGlobalAvatarRoundingEnabledKey,
        WCGestureGlobalAvatarCornerPercentKey,
        WCGestureChatInputRoundingEnabledKey,
        WCGestureChatInputInnerRoundingKey,
        WCGestureChatInputOuterRoundingKey,
        WCGestureChatInputInnerRadiusKey,
        WCGestureChatInputOuterRadiusKey,
        WCGestureAntiRevokeEnabledKey,
        WCGestureVoiceForwardEnabledKey,
        WCGestureLongPressMenuEnabledKey,
        WCGestureLongPressMenuHiddenTitlesKey,
        WCGestureLongPressMenuPreferredOrderKey,
        WCGestureLongPressMenuTitleMapKey,
        WCGestureLongPressMenuManualTitlesKey,
        WCGestureMessageTimeEnabledKey,
        WCGestureMessageTimeFormatKey,
        WCGestureMessageTimeFontSizeKey,
        WCGestureMessageTimeBoldKey,
        WCGestureMessageTimePositionKey,
        WCGesturePageScalePercentKey,
        WCGestureChatTopBarCapsuleEnabledKey,
        WCGestureChatGlassStyleKey,
        WCGestureEmoticonCornerEnabledKey,
        WCGestureEmoticonCornerRadiusKey,
        WCGestureChatImageCornerEnabledKey,
        WCGestureChatImageCornerRadiusKey,

        WCGestureChatGlassTransparencyKey,
        WCGestureChatTopBarShellScaleKey,
        WCGestureChatTopBarIconSizeKey,

        WCGestureChatGlassBlurIntensityKey,
        WCGestureChatTopBarAvatarSizeKey,
        WCGestureChatTopBarNicknameSizeKey,
        WCGestureCallConfirmEnabledKey,
        WCGestureContactInfoCardEnabledKey,
        WCGestureAutoCombineSendEnabledKey,
        WCGestureSendConfirmationEnabledKey,
        WCGestureSendConfirmationUsersKey,
        WCGestureSendConfirmationPauseSecondsKey,
        WCGestureSendConfirmationProfileSwitchEnabledKey,
        WCGestureImageEditQuickSendEnabledKey,
        WCGestureAutoSpeakerphoneEnabledKey,
        WCGestureSettingsEntryLocationKey,
        WCGestureAutoStatusEnabledKey,
        WCGestureAutoStatusHourKey,
        WCGestureAutoStatusIconTypeKey,
        WCGestureAutoStatusIconIDKey,
        WCGestureAutoStatusIconDescriptionKey,
        WCGestureAutoStatusTextModeKey,
        WCGestureAutoStatusTextKey,
        WCGestureAutoStatusTextURLKey,
        WCGestureAutoStatusMediaModeKey,
        WCGestureAutoStatusImageURLKey,
        WCGestureAutoStatusVideoURLKey,
        WCGestureAutoDeviceLoginEnabledKey,
        WCGestureNotificationDirectChatEnabledKey,
        WCGestureBackgroundKeepAliveEnabledKey,
        WCGestureAdBlockerEnabledKey,
        WCGestureMomentsInteractionReminderEnabledKey,
        WCGestureMomentsInteractionReminderDetailsEnabledKey,
        WCGestureMomentsReminderEnabledKey,
        WCGestureMomentsReminderUsersKey,
        WCGestureMomentsReminderIntervalKey,
        WCGestureMomentsReminderForwardEnabledKey,
        WCGestureMomentsReminderForwardTargetKey,
        WCGestureMomentsReminderForwardImagesKey,
        WCGestureMomentsReminderForwardVideosKey,
    ];
    for (NSString *key in additional) keys[[@"setting:" stringByAppendingString:key]] = key;
    return keys;
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
                       message:nil
                          text:WCConfigExportCode()];
}

static void WCPresentImportConfig(__unused UIViewController *presenter) {
    [WCPopup showInputWithTitle:@"导入配置"
                        message:nil
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
                          message:nil
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
    WCRowKindMomentsReminderUsers,
    WCRowKindSendConfirmationUsers,
    WCRowKindMomentsReminderForwardTarget,
    WCRowKindSectionTitle,  // section header with no setting value
    WCRowKindGroupToggle,   // tap → fold/unfold the rows below it
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
    WCRowKindEntryLocation, // three-way entry location selector
    WCRowKindPluginName,    // tap → plugin name editor
    WCRowKindHapticStyle,   // tap → haptic style picker
    WCRowKindCustomPages, // tap → custom page class name editor
    WCRowKindTranslateEngine,     // tap → translation engine picker
    WCRowKindTranslatePair,       // tap → 中文 ↔ language picker
    WCRowKindTranslateTest,       // tap → test translation engine
    WCRowKindExport,         // tap → export config
    WCRowKindImport,        // tap → import config
    WCRowKindChatOption,
};

@interface WCRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, assign) WCRowKind kind;
@property (nonatomic, copy) NSString *defaultsKey;   // nil for non-persisted
@property (nonatomic, assign) BOOL selfMessage;      // action picker variant
@property (nonatomic, assign) NSInteger presetIndex;// AI preset this row manages
@property (nonatomic, assign) NSUInteger indentationDepth;
@property (nonatomic, copy) NSDictionary *chatOption;
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

static NSArray<NSDictionary *> *WCGlobalActionOptions(void) {
    return @[
        @{ @"title": @"不设置", @"value": @(WCGlobalActionNone) },
        @{ @"title": @"扫一扫", @"value": @(WCGlobalActionScanQR) },
        @{ @"title": @"朋友圈", @"value": @(WCGlobalActionMoments) },
        @{ @"title": @"添加朋友", @"value": @(WCGlobalActionAddFriend) },
        @{ @"title": @"我的二维码", @"value": @(WCGlobalActionMyQRCode) },
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
                          message:nil
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
        case WCRowKindEntryLocation: return @"";
        case WCRowKindChatOption: return WCGestureChatOptionDetail(row.chatOption);
        case WCRowKindSwitch:
            return [d boolForKey:row.defaultsKey] ? @"开" : @"关";
        case WCRowKindActionDetail:
            return WCActionName([d integerForKey:row.defaultsKey], row.selfMessage);
        case WCRowKindInputAction:
            return WCInputActionName([d integerForKey:row.defaultsKey]);
        case WCRowKindGlobalAction:
            return WCGlobalActionName([d integerForKey:row.defaultsKey]);
        case WCRowKindPluginName:
            return [d stringForKey:WCPluginNameKey] ?: @"One Wx";
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
            if ([row.defaultsKey isEqualToString:WCGestureSendConfirmationPauseSecondsKey])
                return [NSString stringWithFormat:@"%ld 秒", (long)[d integerForKey:row.defaultsKey]];
            if ([row.defaultsKey isEqualToString:WCMomentsHeightScaleKey] ||
                [row.defaultsKey isEqualToString:WCGesturePageScalePercentKey] ||
                [row.defaultsKey isEqualToString:WCGestureGlobalAvatarCornerPercentKey]) {
                return [NSString stringWithFormat:@"%.0f%%", [d doubleForKey:row.defaultsKey]];
            }
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
        case WCRowKindSendConfirmationUsers:
            return [NSString stringWithFormat:@"%lu 个", (unsigned long)WCGestureSendConfirmationProtectedConversations().count];
        case WCRowKindMomentsReminderUsers:
            return [NSString stringWithFormat:@"%lu 位", (unsigned long)WCGestureMomentsReminderUsers().count];
        case WCRowKindMomentsReminderForwardTarget:
            return [d integerForKey:WCGestureMomentsReminderForwardTargetKey] == 1 ? @"文件传输助手" : @"自己的聊天框";
        case WCRowKindSectionTitle:
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
    WCGestureSettingsConfigureNavigation(self);
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
                        message:nil
                           text:existingName
                    placeholder:@"例如：扫一扫"
                       keyboard:UIKeyboardTypeDefault
                     completion:^(NSString *name) {
        NSString *remark = name.length > 0 ? name : @"自定义页面";
        [WCPopup showInputWithTitle:@"页面类名"
                            message:nil
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
                                  message:nil
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
@property (nonatomic, assign) BOOL searchIndexMode;
@property (nonatomic, copy) NSDictionary *pendingSearchResult;
@end

@implementation WCGestureDetailController

- (instancetype)initWithCategory:(NSInteger)category {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _category = category;
        switch (category) {
            case WCGestureCategoryChat: self.title = @"聊天类功能"; break;
            case WCGestureCategoryGestures: self.title = @"手势类功能"; break;
            case WCGestureCategoryMoments: self.title = @"朋友圈功能"; break;
            case WCGestureCategoryInterface: self.title = @"界面类功能"; break;
            case WCGestureCategoryDisabled: self.title = @"禁用类功能"; break;
            case WCGestureCategoryEnhancements: self.title = @"增强类功能"; break;
            default: self.title = @"插件类配置"; break;
        }
        [self rebuildRows];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self);
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

+ (NSArray<NSDictionary *> *)searchEntries {
    NSMutableArray *entries = [NSMutableArray array];
    for (NSInteger category = WCGestureCategoryChat; category < WCGestureCategoryCount; category++) {
        WCGestureDetailController *detail = [[self alloc] initWithCategory:category];
        detail.searchIndexMode = YES;
        [detail rebuildRows];
        for (NSUInteger section = 0; section < detail.sections.count; section++) {
            NSArray<WCRow *> *rows = detail.sections[section];
            NSString *groupKey = @"";
            for (WCRow *row in rows) {
                if (row.indentationDepth > 0) continue;
                if (row.kind == WCRowKindGroupToggle) groupKey = row.defaultsKey;
                [entries addObject:@{ @"title": row.title, @"category": @(category),
                    @"categoryTitle": detail.title, @"sectionTitle": rows.firstObject.title,
                    @"sectionKey": detail.collapseKeys[section], @"groupKey": groupKey }];
            }
        }
    }
    return entries;
}

- (void)focusSearchResult:(NSDictionary *)result {
    self.pendingSearchResult = result;
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:result[@"sectionKey"]];
    NSString *groupKey = result[@"groupKey"];
    if (groupKey.length) [NSUserDefaults.standardUserDefaults setBool:YES forKey:groupKey];
    [self rebuildRows];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSDictionary *result = self.pendingSearchResult;
    if (!result) return;
    self.pendingSearchResult = nil;
    NSUInteger section = [self.collapseKeys indexOfObject:result[@"sectionKey"]];
    if (section == NSNotFound) return;
    NSArray<WCRow *> *rows = self.sections[section];
    NSUInteger row = [rows indexOfObjectPassingTest:^BOOL(WCRow *item, NSUInteger idx, BOOL *stop) {
        return [item.title isEqualToString:result[@"title"]];
    }];
    if (row == NSNotFound) {
        row = 0;
        WCShowToast(@"请先开启对应功能或子开关，再设置该选项");
    }
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]
        atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)settingsDidChange:(__unused NSNotification *)note {
    [self rebuildRows];
    self.tableView.estimatedRowHeight = 48 * WCGestureSettingsScaleFactor();
    [self.tableView reloadData];
}

- (void)rebuildRows {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *collapsible = [NSMutableArray array];
    NSMutableArray *collapseKeys = [NSMutableArray array];
    NSString *prefix = @"com.qiu7c.onewx.collapse";
    if (self.category == WCGestureCategoryChat) {
        NSArray *masters = @[WCGestureAntiRevokeEnabledKey, WCGestureMessageTimeEnabledKey];
        NSArray *names = @[@"防撤回", @"消息时间"];
        NSArray *suffixes = @[@".chat.anti-revoke", @".chat.message-time"];
        for (NSUInteger i = 0; i < masters.count; i++) {
            NSMutableArray *rows = [NSMutableArray arrayWithObject:WCSwitchRow(names[i], masters[i])];
            for (NSDictionary *option in WCGestureChatOptions(i == 0, self.searchIndexMode)) {
                WCRow *row = [option[@"type"] isEqualToString:@"bool"]
                    ? WCSwitchRow(option[@"title"], option[@"key"]) : WCPlainRow(option[@"title"], WCRowKindChatOption);
                row.chatOption = option;
                [rows addObject:row];
            }
            [sections addObject:rows];
            [collapsible addObject:@YES];
            [collapseKeys addObject:[prefix stringByAppendingString:suffixes[i]]];
        }
        [sections addObject:@[WCSwitchRow(@"通知直达聊天", WCGestureNotificationDirectChatEnabledKey)]];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.notification-direct-chat"]];
        [sections addObject:@[WCSwitchRow(@"语音转发", WCGestureVoiceForwardEnabledKey)]];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.voice-forward"]];
        [sections addObject:@[WCSwitchRow(@"聊天记录搜索", WCGestureChatSearchEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.search"]];
        [sections addObject:@[WCSwitchRow(@"引用消息定位", WCGestureQuoteJumpEnabledKey),
            WCSwitchRow(@"定位图片引用", WCGestureQuoteJumpImageKey), WCSwitchRow(@"定位视频引用", WCGestureQuoteJumpVideoKey)]];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.quote-jump"]];
        [sections addObject:@[WCSwitchRow(@"长按菜单消息 +1", WCGestureMessageRepeatMenuEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.repeat-menu"]];
        [sections addObject:@[WCSwitchRow(@"通话气泡二次确认", WCGestureCallConfirmEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.call-confirm"]];
        [sections addObject:@[WCSwitchRow(@"指定会话发送前确认", WCGestureSendConfirmationEnabledKey),
            WCPlainRow(@"需要确认的会话", WCRowKindSendConfirmationUsers),
            WCNumberRow(@"临时放行时长", WCGestureSendConfirmationPauseSecondsKey),
            WCSwitchRow(@"资料页快捷开关", WCGestureSendConfirmationProfileSwitchEnabledKey)]];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.send-confirmation"]];
        [sections addObject:@[WCSwitchRow(@"图片编辑快捷发送", WCGestureImageEditQuickSendEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.image-edit-quick-send"]];
        [sections addObject:@[WCSwitchRow(@"通话接通自动扬声器", WCGestureAutoSpeakerphoneEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.auto-speakerphone"]];
        [sections addObject:@[WCSwitchRow(@"自动勾选合并发送", WCGestureAutoCombineSendEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.auto-combine-send"]];
        [sections addObject:@[WCSwitchRow(@"自动勾选原图", WCGestureAutoOriginalEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.auto-original"]];
        [sections addObject:@[WCSwitchRow(@"语音自动转文字", WCGestureVoiceTranscriptionEnabledKey),
            WCSwitchRow(@"忽略群聊语音", WCGestureVoiceTranscriptionIgnoreGroupKey),
            WCSwitchRow(@"忽略私聊语音", WCGestureVoiceTranscriptionIgnorePrivateKey),
            WCSwitchRow(@"忽略自己发送", WCGestureVoiceTranscriptionIgnoreSelfKey)]];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".chat.voice-transcription"]];
    } else if (self.category == WCGestureCategoryGestures) {
        NSMutableArray *msg = [NSMutableArray array];
        [msg addObject:WCSwitchRow(@"消息手势", WCReplySwipeEnabledKey)];
        if ((self.searchIndexMode || [d boolForKey:WCReplySwipeEnabledKey])) {
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
        if ((self.searchIndexMode || [d boolForKey:WCInputGestureEnabledKey])) {
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
        if ((self.searchIndexMode || [d boolForKey:WCKeyboardEnhanceEnabledKey])) {
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
            if (self.searchIndexMode || signature.length > 0) {
                // Folded by default for the same reason as the strip geometry.
                NSString *signatureKey = [prefix stringByAppendingString:@".chat.keyboard.signature.expanded"];
                [keyboard addObject:WCGroupRow(@"签名参数", signatureKey)];
                if ((self.searchIndexMode || [d boolForKey:signatureKey])) {
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
            if ((self.searchIndexMode || [d boolForKey:geometryKey])) {
                // One shared set by default; turn this on to tune the
                // third-party keyboard separately.
                [keyboard addObject:WCSwitchRow(@"第三方单独调节", WCKeyboardStripSeparateAdjustKey)];
                if ((self.searchIndexMode || [d boolForKey:WCKeyboardStripSeparateAdjustKey])) {
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
        NSMutableArray *global = [NSMutableArray array];
        [global addObject:WCSwitchRow(@"全局手势", WCGlobalGestureEnabledKey)];
        if ((self.searchIndexMode || [d boolForKey:WCGlobalGestureEnabledKey])) {
            [global addObject:WCSwitchRow(@"震动", WCGlobalGestureHapticKey)];
            [global addObject:WCGlobalActionRow(@"双指长按", WCGlobalTwoFingerActionKey)];
            [global addObject:WCGlobalActionRow(@"三指长按", WCGlobalThreeFingerActionKey)];
            [global addObject:WCPlainRow(@"自定义页面", WCRowKindCustomPages)];
        }
        [sections addObject:global];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".global"]];
    } else if (self.category == WCGestureCategoryMoments) {
        NSMutableArray *moments = [NSMutableArray array];
        [moments addObject:WCSwitchRow(@"朋友圈双击点赞", WCMomentsDoubleTapLikeKey)];
        if ((self.searchIndexMode || [d boolForKey:WCMomentsDoubleTapLikeKey])) {
            [moments addObject:WCSwitchRow(@"震动", WCMomentsLikeHapticKey)];
        }
        [sections addObject:moments];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".other.moments"]];
        WCRow *timeFormat = WCPlainRow(@"朋友圈日期格式", WCRowKindChatOption);
        timeFormat.chatOption = @{ @"title": timeFormat.title, @"type": @"format", @"key": WCGestureMomentsTimeFormatKey };
        [sections addObject:@[WCSwitchRow(@"朋友圈精确发布时间", WCGestureMomentsTimeEnabledKey), timeFormat]];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".moments.precise-time"]];
        NSMutableArray *reminders = [NSMutableArray arrayWithObjects:
            WCSwitchRow(@"朋友圈特别关心", WCGestureMomentsReminderEnabledKey),
            WCPlainRow(@"特别关心好友", WCRowKindMomentsReminderUsers),
            WCNumberRow(@"检测间隔（秒）", WCGestureMomentsReminderIntervalKey),
            WCSwitchRow(@"转发到聊天", WCGestureMomentsReminderForwardEnabledKey), nil];
        if (self.searchIndexMode || [d boolForKey:WCGestureMomentsReminderForwardEnabledKey]) {
            NSString *forwardGroup = [prefix stringByAppendingString:@".moments.reminder.forward.expanded"];
            [reminders addObject:WCGroupRow(@"转发选项", forwardGroup)];
            if (self.searchIndexMode || [d boolForKey:forwardGroup]) {
                [reminders addObject:WCPlainRow(@"转发目标", WCRowKindMomentsReminderForwardTarget)];
                [reminders addObject:WCSwitchRow(@"同时转发图片", WCGestureMomentsReminderForwardImagesKey)];
                [reminders addObject:WCSwitchRow(@"同时转发视频", WCGestureMomentsReminderForwardVideosKey)];
            }
        }
        [sections addObject:reminders];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".moments.reminder"]];
        [sections addObject:@[WCSwitchRow(@"朋友圈互动通知", WCGestureMomentsInteractionReminderEnabledKey),
            WCSwitchRow(@"显示详细信息", WCGestureMomentsInteractionReminderDetailsEnabledKey)]];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".moments.interaction-reminder"]];

    } else if (self.category == WCGestureCategoryInterface) {
        NSMutableArray *enhance = [NSMutableArray array];
        [enhance addObject:WCSwitchRow(@"界面大小", WCGesturePageScaleEnabledKey)];
        [enhance addObject:WCNumberRow(@"界面比例 (%)", WCGesturePageScalePercentKey)];
        [enhance addObject:WCSwitchRow(@"包含插件界面", WCGesturePageScalePluginUIKey)];
        if (![d boolForKey:WCGesturePageScaleEnabledKey]) {
            // Only expose already-enabled legacy settings for adjustment or
            // disabling; new users get one interface-size entry.
            if ((self.searchIndexMode || [d boolForKey:WCChatLayoutEnabledKey])) {
                [enhance addObject:WCSwitchRow(@"旧版聊天字号定制", WCChatLayoutEnabledKey)];
                [enhance addObject:WCNumberRow(@"字号级别", WCChatLayoutFontLevelKey)];
            }
            if ((self.searchIndexMode || [d boolForKey:WCMomentsLayoutEnabledKey])) {
                [enhance addObject:WCSwitchRow(@"旧版朋友圈高度补偿", WCMomentsLayoutEnabledKey)];
                [enhance addObject:WCNumberRow(@"高度比例 (%)", WCMomentsHeightScaleKey)];
            }
        }
        [sections addObject:enhance];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".enhance.layout"]];
        [sections addObject:@[WCSwitchRow(@"资料信息卡片", WCGestureContactInfoCardEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".interface.contact-info-card"]];
        WCRow *topPreview = WCPlainRow(@"整页顶栏预览与调节", WCRowKindChatOption);
        topPreview.chatOption = @{ @"title": topPreview.title, @"type": @"top-bar-position", @"key": @"" };
        [sections addObject:@[WCSwitchRow(@"胶囊顶栏", WCGestureChatTopBarCapsuleEnabledKey), topPreview]];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".interface.chat-top-bar"]];
        WCRow *corners = WCPlainRow(@"圆角设置", WCRowKindChatOption);
        corners.chatOption = @{ @"title":corners.title, @"type":@"corner-settings", @"key":@"" };
        [sections addObject:@[corners]]; [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".interface.corners"]];
    } else if (self.category == WCGestureCategoryDisabled) {
        [sections addObject:@[WCSwitchRow(@"广告精简", WCGestureAdBlockerEnabledKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".interface.ad-blocker"]];
        [sections addObject:@[WCSwitchRow(@"隐藏群标题尾部", WCGestureHideGroupTitleTailKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".interface.group-title"]];
        [sections addObject:@[WCSwitchRow(@"隐藏截屏分享浮层", WCGestureHideScreenshotForwardKey)]];
        [collapsible addObject:@NO]; [collapseKeys addObject:[prefix stringByAppendingString:@".interface.screenshot"]];
        [sections addObject:@[WCPlainRow(@"我的页面入口管理", WCRowKindSectionTitle),
            WCSwitchRow(@"隐藏作品入口", WCGestureHideMeFinderKey),
            WCSwitchRow(@"隐藏小店与卡包", WCGestureHideMeCardsKey),
            WCSwitchRow(@"隐藏表情入口", WCGestureHideMeEmoticonsKey)]];
        [collapsible addObject:@YES]; [collapseKeys addObject:[prefix stringByAppendingString:@".interface.me-menu"]];
        WCRow *menu = WCPlainRow(@"隐藏、排序与重命名", WCRowKindChatOption);
        menu.chatOption = @{ @"title": menu.title, @"type": @"long-press-menu", @"key": @"" };
        [sections addObject:@[WCSwitchRow(@"长按菜单管理", WCGestureLongPressMenuEnabledKey), menu]];
        [collapsible addObject:@YES];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.long-press-menu"]];
        [sections addObject:@[WCSwitchRow(@"去除所有分割线", WCHideSeparatorLinesKey)]];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".enhance.separators"]];
    } else if (self.category == WCGestureCategoryEnhancements) {
        [sections addObject:@[WCSwitchRow(@"自动确认登录", WCGestureAutoDeviceLoginEnabledKey)]];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".automation.device-login"]];
        WCRow *autoStatus = WCPlainRow(@"自动更新微信状态", WCRowKindChatOption);
        autoStatus.chatOption = @{@"title":autoStatus.title, @"type":@"auto-status", @"key":@""};
        [sections addObject:@[autoStatus]];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".automation.auto-status"]];
        [sections addObject:@[WCSwitchRow(@"后台保活", WCGestureBackgroundKeepAliveEnabledKey)]];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".background.keep-alive"]];
        WCRow *clearProfile = WCPlainRow(@"清空地区与性别信息", WCRowKindChatOption);
        clearProfile.chatOption = @{@"title":clearProfile.title, @"type":@"clear-profile", @"key":@""};
        [sections addObject:@[clearProfile]]; [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".profile.clear-region-gender"]];
    } else {
        // Plugin configuration only; functional enhancements have their own category.
        NSMutableArray *plugin = [NSMutableArray array];
        [plugin addObject:WCPlainRow(@"设置入口", WCRowKindEntryLocation)];
        [plugin addObject:WCPlainRow(@"插件名称", WCRowKindPluginName)];
        [plugin addObject:WCPlainRow(@"震感强度", WCRowKindHapticStyle)];
        [sections addObject:plugin];
        [collapsible addObject:@NO];
        [collapseKeys addObject:[prefix stringByAppendingString:@".plugin"]];
        NSMutableArray *ai = [NSMutableArray array];
        [ai addObject:WCSwitchRow(@"AI 配置", WCGestureAIEnabledKey)];
        if ((self.searchIndexMode || [d boolForKey:WCGestureAIEnabledKey])) {
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
        [translate addObject:WCSwitchRow(@"翻译配置", WCTranslateEnabledKey)];
        if ((self.searchIndexMode || [d boolForKey:WCTranslateEnabledKey])) {
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
    // Section children sit one level in; rows inside a nested foldable group
    // sit another level in. Every rebuild also resets depth after folding.
    for (NSUInteger sectionIndex = 0; sectionIndex < sections.count; sectionIndex++) {
        NSArray<WCRow *> *rows = sections[sectionIndex];
        // A single setting has no children to expand, even if its saved fold state exists.
        BOOL hasHeader = [collapsible[sectionIndex] boolValue] && rows.count > 1;
        collapsible[sectionIndex] = @(hasHeader);
        BOOL insideGroup = NO;
        for (NSUInteger rowIndex = 0; rowIndex < rows.count; rowIndex++) {
            WCRow *row = rows[rowIndex];
            NSUInteger baseDepth = hasHeader && rowIndex > 0 ? 1 : 0;
            if (row.kind == WCRowKindGroupToggle) {
                row.indentationDepth = baseDepth;
                insideGroup = YES;
            } else {
                row.indentationDepth = baseDepth + (insideGroup ? 1 : 0);
                NSString *key = row.chatOption[@"key"];
                if ([key isEqualToString:WCGestureAntiRevokeTimeFilterKey] ||
                    [key isEqualToString:WCGestureAntiRevokeReplyTemplateKey]) row.indentationDepth++;
            }
        }
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

    }
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.text = row.title;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.text = row.kind == WCRowKindSwitch ? @"" : WCRowDetailText(row);
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    BOOL collapsible = [self sectionCollapsible:section];
    BOOL isHeaderRow = collapsible && rowIdx == 0;
    BOOL isGroupRow = row.kind == WCRowKindGroupToggle;
    BOOL isChild = row.indentationDepth > 0;

    // Reset reuse state.
    cell.indentationLevel = 0;
    cell.indentationWidth = 0;
    cell.imageView.image = nil;

    CGFloat scale = WCGestureSettingsScaleFactor();
    cell.textLabel.font = [UIFont systemFontOfSize:(isChild ? 15 : 17) * scale weight:UIFontWeightRegular];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 * scale];
    if (isChild) {
        cell.indentationLevel = row.indentationDepth;
        cell.indentationWidth = 18 * scale;
    }
    UIImageView *foldArrow = nil;
    if (isHeaderRow || isGroupRow) {
        BOOL collapsed = isHeaderRow ? [self sectionCollapsed:section]
            : ![NSUserDefaults.standardUserDefaults boolForKey:row.defaultsKey];
        foldArrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:collapsed ? @"chevron.right" : @"chevron.down"]];
        foldArrow.tintColor = UIColor.tertiaryLabelColor;
        foldArrow.contentMode = UIViewContentModeScaleAspectFit;
        foldArrow.frame = CGRectMake(0, 0, 12 * scale, 16 * scale);
    }
    if (row.kind == WCRowKindEntryLocation) {
        UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:@[@"我的页面", @"插件管理", @"微信设置"]];
        segments.frame = CGRectMake(0,0,240 * scale,32 * scale);
        [segments setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12 * scale]} forState:UIControlStateNormal];
        [segments setEnabled:WCGestureSettingsEntryManagerAvailable() forSegmentAtIndex:1];
        segments.selectedSegmentIndex = WCGestureSettingsEntryResolvedLocation();
        [segments addTarget:self action:@selector(entryLocationChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = segments;
    } else if (row.kind == WCRowKindSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = UIColor.systemBlueColor;
        [sw addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];
        sw.tag = section * 10000 + rowIdx;
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:row.defaultsKey];
        sw.transform = CGAffineTransformMakeScale(scale, scale);
        if (foldArrow) {
            UIView *accessory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 82 * scale, 32 * scale)];
            foldArrow.center = CGPointMake(6 * scale, 16 * scale);
            sw.center = CGPointMake(56 * scale, 16 * scale);
            [accessory addSubview:foldArrow]; [accessory addSubview:sw];
            cell.accessoryView = accessory;
        } else cell.accessoryView = sw;
    } else if (isGroupRow || isHeaderRow) {
        cell.accessoryView = foldArrow;
        cell.detailTextLabel.text = @"";
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if (row.kind != WCRowKindSectionTitle) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)entryLocationChanged:(UISegmentedControl *)segments {
    NSInteger location = segments.selectedSegmentIndex;
    if (location < 0 || location > 2) return;
    if (location == WCGestureSettingsEntryManager && !WCGestureSettingsEntryManagerAvailable()) {
        location = WCGestureSettingsEntryMe; segments.selectedSegmentIndex = location;
    }
    WCSetInteger(location, WCGestureSettingsEntryLocationKey);
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
        case WCRowKindEntryLocation: break;
        case WCRowKindSendConfirmationUsers:
            [self.navigationController pushViewController:WCGestureCreateSendConfirmationPicker() animated:YES];
            break;
        case WCRowKindMomentsReminderUsers:
            [self.navigationController pushViewController:WCGestureCreateMomentsFriendPicker() animated:YES];
            break;
        case WCRowKindMomentsReminderForwardTarget:
            [WCPopup showOptionsWithTitle:@"转发目标" message:nil
                options:@[[WCPopupOption optionWithTitle:@"自己的聊天框" value:@0],
                          [WCPopupOption optionWithTitle:@"文件传输助手" value:@1]]
                selected:@([NSUserDefaults.standardUserDefaults integerForKey:WCGestureMomentsReminderForwardTargetKey])
                completion:^(id value) { if (value) WCSetInteger([value integerValue], WCGestureMomentsReminderForwardTargetKey); }];
            break;
        case WCRowKindChatOption:
            WCGestureEditChatOption(self, row.chatOption);
            break;
        case WCRowKindSwitch:
        case WCRowKindSectionTitle:
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
                WCGestureAIBaseURLKey,
                fallback.length > 0 ? fallback : @"https://api.example.com/v1");
            break;
        }
        case WCRowKindAIModel: {
            NSInteger provider = [[NSUserDefaults standardUserDefaults] integerForKey:WCGestureAIProviderKey];
            NSString *fallback = WCGestureAIProviderDefaultModel(provider);
            WCPresentAITextEditor(self, @"AI 模型",
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
