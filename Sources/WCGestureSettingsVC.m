#import "WCGestureSettingsVC.h"
#import "WCGestureConfig.h"
#import "WCGestureAccount.h"
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
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            NSString *className = NSStringFromClass(window.class);
            if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal &&
                ![className containsString:@"iConsole"]) return window;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            NSString *className = NSStringFromClass(window.class);
            if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal &&
                ![className containsString:@"iConsole"]) return window;
        }
    }
    return nil;
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

#pragma mark - Action picker sheet

static void WCPresentActionPicker(UIViewController *presenter, NSString *title,
                                  BOOL selfMessage, NSString *defaultsKey) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger current = [defaults integerForKey:defaultsKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
        message:selfMessage ? @"选择自己消息触发的动作" : @"选择对方消息触发的动作；不支持撤回"
         preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *option in WCActionOptions(selfMessage)) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *label = value == current ? [@"✓  " stringByAppendingString:option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCSetInteger(value, defaultsKey);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
}

static void WCPresentTriggerDistanceEditor(UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"触发距离"
        message:@"输入 36 到 100 之间的数值；越小越容易触发"
         preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = [NSString stringWithFormat:@"%.0f", [defaults doubleForKey:WCReplySwipeTriggerDistanceKey]];
        field.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSString *text = alert.textFields.firstObject.text;
            double value = [text doubleValue];
            if (value < 36.0) value = 36.0;
            if (value > 100.0) value = 100.0;
            [defaults setDouble:value forKey:WCReplySwipeTriggerDistanceKey];
            WCPostChange(WCReplySwipeTriggerDistanceKey);
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void WCPresentPluginNameEditor(UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"插件名称"
        message:@"设置在微信插件管理页显示的名字"
         preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = [defaults stringForKey:WCPluginNameKey] ?: @"微信手势";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            NSString *text = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (text.length == 0) text = @"微信手势";
            [defaults setObject:text forKey:WCPluginNameKey];
            WCPostChange(WCPluginNameKey);
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
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

static void WCPresentExportConfig(UIViewController *presenter) {
    NSString *code = WCConfigExportCode();
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出配置"
        message:@"复制下方口令，在新设备/新账号导入即可恢复设置"
         preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = code;
        field.userInteractionEnabled = NO;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [UIPasteboard.generalPasteboard setString:code];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void WCPresentImportConfig(UIViewController *presenter) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导入配置"
        message:@"粘贴配置口令"
         preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"WCG1-...";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.text = UIPasteboard.generalPasteboard.string;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSString *text = alert.textFields.firstObject.text;
        if (WCConfigImportCode(text)) {
            WCPostChange(nil);
            UIAlertController *ok = [UIAlertController alertControllerWithTitle:nil message:@"导入成功" preferredStyle:UIAlertControllerStyleAlert];
            [ok addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [presenter presentViewController:ok animated:YES completion:nil];
        } else {
            UIAlertController *fail = [UIAlertController alertControllerWithTitle:nil message:@"口令格式错误" preferredStyle:UIAlertControllerStyleAlert];
            [fail addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [presenter presentViewController:fail animated:YES completion:nil];
        }
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Input action options

static NSArray<NSDictionary *> *WCInputActionOptions(void) {
    return @[
        @{ @"title": @"不设置", @"value": @(WCInputActionNone) },
        @{ @"title": @"清空", @"value": @(WCInputActionClear) },
        @{ @"title": @"粘贴", @"value": @(WCInputActionPaste) },
        @{ @"title": @"复制", @"value": @(WCInputActionCopy) },
        @{ @"title": @"剪切", @"value": @(WCInputActionCut) },
    ];
}

static NSString *WCInputActionName(NSInteger action) {
    for (NSDictionary *option in WCInputActionOptions()) {
        if ([option[@"value"] integerValue] == action) return option[@"title"];
    }
    return @"清空";
}

#pragma mark - Input action picker

static void WCPresentInputSwipeActionPicker(UIViewController *presenter, NSString *title, NSString *defaultsKey) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger current = [defaults integerForKey:defaultsKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
        message:@"选择触发动作"
         preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *option in WCInputActionOptions()) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *label = value == current ? [@"✓  " stringByAppendingString:option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCSetInteger(value, defaultsKey);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Row model

typedef NS_ENUM(NSInteger, WCRowKind) {
    WCRowKindSwitch,        // toggle
    WCRowKindActionDetail,  // tap → message action picker
    WCRowKindInputAction,   // tap → input swipe action picker
    WCRowKindGlobalAction,  // tap → global action picker
    WCRowKindDistance,      // tap → number editor
    WCRowKindPluginName,    // tap → plugin name editor
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
        @{ @"title": @"截图", @"value": @(WCGlobalActionScreenshot) },
        @{ @"title": @"返回上一页", @"value": @(WCGlobalActionBack) },
        @{ @"title": @"回到首页", @"value": @(WCGlobalActionLockScreen) },
        @{ @"title": @"扫一扫", @"value": @(WCGlobalActionScanQR) },
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

static void WCPresentGlobalActionPicker(UIViewController *presenter, NSString *title, NSString *defaultsKey) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger current = [defaults integerForKey:defaultsKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
        message:@"选择触发动作" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *option in WCGlobalActionOptions()) {
        NSInteger value = [option[@"value"] integerValue];
        NSString *label = value == current ? [@"✓  " stringByAppendingString:option[@"title"]] : option[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                WCSetInteger(value, defaultsKey);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
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
        case WCRowKindExport:
        case WCRowKindImport:
            return @"";
        case WCRowKindDistance: {
            double v = [d doubleForKey:WCReplySwipeTriggerDistanceKey];
            return [NSString stringWithFormat:@"%.0f", v <= 0 ? 56.0 : v];
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
    UIView *otherCard = WCMakeCard(@"其他手势",
        @"heart", UIColor.systemPinkColor, UIColor.secondarySystemGroupedBackgroundColor);
    UIView *globalCard = WCMakeCard(@"全局手势",
        @"hand.tap", UIColor.systemGreenColor, UIColor.secondarySystemGroupedBackgroundColor);
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
    otherCard.tag = WCGestureCategoryOther;
    globalCard.tag = WCGestureCategoryGlobal;
    pluginCard.tag = WCGestureCategoryPlugin;
    for (UIView *v in @[chatCard, otherCard, globalCard, pluginCard, versionLabel, authorCard, brandLabel]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:v];
    }
    // Tappable
    chatCard.userInteractionEnabled = YES;
    otherCard.userInteractionEnabled = YES;
    globalCard.userInteractionEnabled = YES;
    pluginCard.userInteractionEnabled = YES;
    [chatCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCategory:)]];
    [otherCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCategory:)]];
    [globalCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCategory:)]];
    [pluginCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCategory:)]];

    [NSLayoutConstraint activateConstraints:@[
        [chatCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:margin],
        [chatCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [chatCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [chatCard.heightAnchor constraintEqualToConstant:76],
        [otherCard.topAnchor constraintEqualToAnchor:chatCard.bottomAnchor constant:margin],
        [otherCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [otherCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [otherCard.heightAnchor constraintEqualToConstant:76],
        [globalCard.topAnchor constraintEqualToAnchor:otherCard.bottomAnchor constant:margin],
        [globalCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [globalCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [globalCard.heightAnchor constraintEqualToConstant:76],
        [pluginCard.topAnchor constraintEqualToAnchor:globalCard.bottomAnchor constant:margin],
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

#pragma mark - Detail controller

@interface WCGestureDetailController ()
@property (nonatomic, assign) NSInteger category;
@property (nonatomic, copy) NSArray<NSArray<WCRow *> *> *sections;
@property (nonatomic, copy) NSArray<NSString *> *sectionTitles;
@property (nonatomic, copy) NSArray<NSString *> *collapseKeys;
@end

@implementation WCGestureDetailController

- (instancetype)initWithCategory:(NSInteger)category {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _category = category;
        self.title = (category == WCGestureCategoryChat) ? @"聊天页手势"
            : (category == WCGestureCategoryOther) ? @"其他手势" : @"全局手势";
        [self rebuildRows];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
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
    NSMutableArray *titles = [NSMutableArray array];
    NSMutableArray *collapseKeys = [NSMutableArray array];
    NSString *prefix = @"com.qiu7c.wcgesture.collapse";
    if (self.category == WCGestureCategoryChat) {
        NSMutableArray *msg = [NSMutableArray array];
        [msg addObject:WCSwitchRow(@"消息手势", WCReplySwipeEnabledKey)];
        if ([d boolForKey:WCReplySwipeEnabledKey]) {
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
        [titles addObject:@"消息手势"];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.msg"]];
        NSMutableArray *input = [NSMutableArray array];
        [input addObject:WCSwitchRow(@"输入框手势", WCInputGestureEnabledKey)];
        if ([d boolForKey:WCInputGestureEnabledKey]) {
            [input addObject:WCInputActionRow(@"左滑动作", WCInputSwipeLeftActionKey)];
            [input addObject:WCInputActionRow(@"右滑动作", WCInputSwipeRightActionKey)];
            [input addObject:WCInputActionRow(@"双击动作", WCInputDoubleTapActionKey)];
            [input addObject:WCInputActionRow(@"三击动作", WCInputTripleTapActionKey)];
        }
        [sections addObject:input];
        [titles addObject:@"输入框手势"];
        [collapseKeys addObject:[prefix stringByAppendingString:@".chat.input"]];
    } else if (self.category == WCGestureCategoryOther) {
        NSMutableArray *moments = [NSMutableArray array];
        [moments addObject:WCSwitchRow(@"朋友圈双击点赞", WCMomentsDoubleTapLikeKey)];
        if ([d boolForKey:WCMomentsDoubleTapLikeKey]) {
            [moments addObject:WCSwitchRow(@"点赞触感反馈", WCMomentsLikeHapticKey)];
        }
        [sections addObject:moments];
        [titles addObject:@"朋友圈"];
        [collapseKeys addObject:[prefix stringByAppendingString:@".other.moments"]];
    } else if (self.category == WCGestureCategoryGlobal) {
        NSMutableArray *global = [NSMutableArray array];
        [global addObject:WCSwitchRow(@"全局手势", WCGlobalGestureEnabledKey)];
        if ([d boolForKey:WCGlobalGestureEnabledKey]) {
            [global addObject:WCGlobalActionRow(@"双指长按", WCGlobalTwoFingerActionKey)];
            [global addObject:WCGlobalActionRow(@"三指长按", WCGlobalThreeFingerActionKey)];
        }
        [sections addObject:global];
        [titles addObject:@"全局手势"];
        [collapseKeys addObject:[prefix stringByAppendingString:@".global"]];
    } else {
        // 插件设置
        NSMutableArray *plugin = [NSMutableArray array];
        [plugin addObject:WCPlainRow(@"插件名称", WCRowKindPluginName)];
        [sections addObject:plugin];
        [titles addObject:@"插件"];
        [collapseKeys addObject:[prefix stringByAppendingString:@".plugin"]];
        NSMutableArray *config = [NSMutableArray array];
        [config addObject:WCPlainRow(@"导出配置", WCRowKindExport)];
        [config addObject:WCPlainRow(@"导入配置", WCRowKindImport)];
        [sections addObject:config];
        [titles addObject:@"配置"];
        [collapseKeys addObject:[prefix stringByAppendingString:@".config"]];
    }
    self.sections = sections;
    self.sectionTitles = titles;
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

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger total = self.sections[section].count;
    // 折叠时只保留第 0 行(大开关),子设置项收起
    if ([self sectionCollapsed:section]) return MIN(1, total);
    return total;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = (section < (NSInteger)self.sectionTitles.count) ? self.sectionTitles[section] : @"";
    BOOL collapsed = [self sectionCollapsed:section];
    UIButton *header = [UIButton buttonWithType:UIButtonTypeSystem];
    header.frame = CGRectMake(0, 0, tableView.bounds.size.width, 40);
    [header setTitle:[NSString stringWithFormat:@"  %@  %@", title, collapsed ? @"▸" : @"▾"]
           forState:UIControlStateNormal];
    header.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    header.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [header setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
    header.tag = section;
    [header addTarget:self action:@selector(toggleSection:) forControlEvents:UIControlEventTouchUpInside];
    return header;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(__unused NSInteger)section {
    return 40;
}

- (void)toggleSection:(UIButton *)header {
    NSInteger section = header.tag;
    if (section < 0 || section >= (NSInteger)self.collapseKeys.count) return;
    NSString *key = self.collapseKeys[section];
    BOOL now = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    [[NSUserDefaults standardUserDefaults] setBool:!now forKey:key];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section]
              withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCRow *row = self.sections[indexPath.section][indexPath.row];
    NSString *cellId = @"WCGestureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = WCRowDetailText(row);
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (row.kind == WCRowKindSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];
        sw.tag = (NSInteger)indexPath.section * 10000 + (NSInteger)indexPath.row;
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
    WCRow *row = self.sections[indexPath.section][indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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
        case WCRowKindExport:
            WCPresentExportConfig(self);
            break;
        case WCRowKindImport:
            WCPresentImportConfig(self);
            break;
        case WCRowKindDistance:
            WCPresentTriggerDistanceEditor(self);
            break;
    }
}

@end

#pragma mark - ActionSheet fallback entry (used by Me-page hook)

void WCGesturePresentSettings(UIViewController *presenter) {
    // Push the real controller when we have a navigation context; otherwise
    // fall back to an ActionSheet-style quick toggle.
    if (presenter.navigationController) {
        WCGestureSettingsController *vc = [WCGestureSettingsController new];
        [presenter.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (!presenter) presenter = WCTopViewController();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL msgGesture = [defaults boolForKey:WCReplySwipeEnabledKey];
    BOOL inputGesture = [defaults boolForKey:WCInputGestureEnabledKey];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"微信手势"
        message:@"WCGesture 设置"
         preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:msgGesture ? @"消息手势：开" : @"消息手势：关"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            WCSetBool(!msgGesture, WCReplySwipeEnabledKey);
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:inputGesture ? @"输入框手势：开" : @"输入框手势：关"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            WCSetBool(!inputGesture, WCInputGestureEnabledKey);
        }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
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
