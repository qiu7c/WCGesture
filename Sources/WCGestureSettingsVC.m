#import "WCGestureSettingsVC.h"
#import "WCGestureConfig.h"
#import <objc/message.h>
#import <objc/runtime.h>

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

static BOOL WCIsSelfActionKey(NSString *key) {
    return [key isEqualToString:WCReplySwipeSelfActionKey] ||
           [key isEqualToString:WCReplySwipeRightSelfActionKey] ||
           [key isEqualToString:WCMessageDoubleTapSelfActionKey] ||
           [key isEqualToString:WCMessageTripleTapSelfActionKey];
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

#pragma mark - Action picker

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

#pragma mark - Trigger distance prompt

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

#pragma mark - Sub-menu for message gestures

static void WCPresentMessageGestureSubmenu(UIViewController *presenter) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:WCReplySwipeEnabledKey];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"消息手势"
        message:enabled ? @"选择要配置的手势" : @"先开启消息手势"
         preferredStyle:UIAlertControllerStyleActionSheet];
    if (!enabled) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"开启消息手势" style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) { WCSetBool(YES, WCReplySwipeEnabledKey); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [presenter presentViewController:sheet animated:YES completion:nil];
        return;
    }

    NSInteger selfSwipe = [defaults integerForKey:WCReplySwipeSelfActionKey];
    NSInteger otherSwipe = [defaults integerForKey:WCReplySwipeOtherActionKey];
    NSInteger selfRight = [defaults integerForKey:WCReplySwipeRightSelfActionKey];
    NSInteger otherRight = [defaults integerForKey:WCReplySwipeRightOtherActionKey];
    NSInteger selfDouble = [defaults integerForKey:WCMessageDoubleTapSelfActionKey];
    NSInteger otherDouble = [defaults integerForKey:WCMessageDoubleTapOtherActionKey];
    NSInteger selfTriple = [defaults integerForKey:WCMessageTripleTapSelfActionKey];
    NSInteger otherTriple = [defaults integerForKey:WCMessageTripleTapOtherActionKey];
    double distance = [defaults doubleForKey:WCReplySwipeTriggerDistanceKey];

    NSArray<NSDictionary *> *rows = @[
        @{ @"title": [NSString stringWithFormat:@"左滑·自己：%@", WCActionName(selfSwipe, YES)],
           @"key": WCReplySwipeSelfActionKey, @"self": @YES },
        @{ @"title": [NSString stringWithFormat:@"左滑·对方：%@", WCActionName(otherSwipe, NO)],
           @"key": WCReplySwipeOtherActionKey, @"self": @NO },
        @{ @"title": [NSString stringWithFormat:@"右滑·自己：%@", WCActionName(selfRight, YES)],
           @"key": WCReplySwipeRightSelfActionKey, @"self": @YES },
        @{ @"title": [NSString stringWithFormat:@"右滑·对方：%@", WCActionName(otherRight, NO)],
           @"key": WCReplySwipeRightOtherActionKey, @"self": @NO },
        @{ @"title": [NSString stringWithFormat:@"双击·自己：%@", WCActionName(selfDouble, YES)],
           @"key": WCMessageDoubleTapSelfActionKey, @"self": @YES },
        @{ @"title": [NSString stringWithFormat:@"双击·对方：%@", WCActionName(otherDouble, NO)],
           @"key": WCMessageDoubleTapOtherActionKey, @"self": @NO },
        @{ @"title": [NSString stringWithFormat:@"三击·自己：%@", WCActionName(selfTriple, YES)],
           @"key": WCMessageTripleTapSelfActionKey, @"self": @YES },
        @{ @"title": [NSString stringWithFormat:@"三击·对方：%@", WCActionName(otherTriple, NO)],
           @"key": WCMessageTripleTapOtherActionKey, @"self": @NO },
        @{ @"title": [NSString stringWithFormat:@"触发距离：%.0f", distance], @"key": @"__distance__", @"self": @NO },
    ];

    __weak UIAlertController *weakSheet = sheet;
    for (NSDictionary *row in rows) {
        [sheet addAction:[UIAlertAction actionWithTitle:row[@"title"] style:UIAlertActionStyleDefault
            handler:^(__unused UIAlertAction *action) {
                [weakSheet dismissViewControllerAnimated:YES completion:^{
                    UIViewController *top = WCTopViewController();
                    NSString *key = row[@"key"];
                    if ([key isEqualToString:@"__distance__"]) {
                        WCPresentTriggerDistanceEditor(top);
                    } else {
                        WCPresentActionPicker(top, row[@"title"], [row[@"self"] boolValue], key);
                    }
                }];
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"关闭消息手势" style:UIAlertActionStyleDestructive
        handler:^(__unused UIAlertAction *action) { WCSetBool(NO, WCReplySwipeEnabledKey); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Top-level settings

void WCGesturePresentSettings(UIViewController *presenter) {
    if (!presenter) presenter = WCTopViewController();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL master = [defaults boolForKey:WCGestureEnabledKey];
    BOOL msgGesture = [defaults boolForKey:WCReplySwipeEnabledKey];
    BOOL inputSwipe = [defaults boolForKey:WCInputSwipeActionsEnabledKey];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"微信手势"
        message:master ? @"WCGesture 设置" : @"手势总开关已关闭"
         preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:master ? @"关闭手势总开关" : @"开启手势总开关"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            WCSetBool(!master, WCGestureEnabledKey);
        }]];

    if (master) {
        [sheet addAction:[UIAlertAction actionWithTitle:msgGesture ? @"消息手势：开" : @"消息手势：关"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                if (msgGesture) WCSetBool(NO, WCReplySwipeEnabledKey);
                else WCPresentMessageGestureSubmenu(WCTopViewController());
            }]];
        if (msgGesture) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"消息手势详细设置"
                style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                    WCPresentMessageGestureSubmenu(WCTopViewController());
                }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:inputSwipe ? @"输入框滑动：开" : @"输入框滑动：关"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                WCSetBool(!inputSwipe, WCInputSwipeActionsEnabledKey);
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Entry registration

static UIViewController *WCFindWeChatRootController(void) {
    Class rootVCClass = NSClassFromString(@"RootViewController");
    UIViewController *root = WCActiveWindow().rootViewController;
    if (rootVCClass && [root isKindOfClass:rootVCClass]) return root;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

void WCGestureRegisterEntry(void) {
    // Try WCPluginsMgr registration first (WCAtlas-style), else no-op:
    // the Me-page hook in Tweak.x adds a cell when this fails.
    Class mgrClass = NSClassFromString(@"WCPluginsMgr");
    if (!mgrClass) return;
    SEL sharedSelector = sel_registerName("sharedInstance");
    if (![mgrClass respondsToSelector:sharedSelector]) return;
    id mgr = ((id (*)(id, SEL))objc_msgSend)(mgrClass, sharedSelector);
    SEL registerSelector = sel_registerName("registerPlugin:identifier:title:icon:");
    if (!mgr || ![mgr respondsToSelector:registerSelector]) return;
    NSDictionary *info = @{
        @"title": @"微信手势",
        @"identifier": @"com.qiu7c.wcgesture",
        @"iconName": @"hand.draw",
    };
    ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(mgr, registerSelector,
        info, info[@"identifier"], info[@"title"], info[@"iconName"]);
}
