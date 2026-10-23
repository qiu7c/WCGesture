#import "WCGestureSettingsVC.h"
#import "WCGestureConfig.h"
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

#pragma mark - Row model

typedef NS_ENUM(NSInteger, WCRowKind) {
    WCRowKindSwitch,        // toggle
    WCRowKindActionDetail,  // tap → action picker
    WCRowKindDistance,      // tap → number editor
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

static NSString *WCRowDetailText(WCRow *row) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    switch (row.kind) {
        case WCRowKindSwitch:
            return [d boolForKey:row.defaultsKey] ? @"开" : @"关";
        case WCRowKindActionDetail:
            return WCActionName([d integerForKey:row.defaultsKey], row.selfMessage);
        case WCRowKindDistance: {
            double v = [d doubleForKey:WCReplySwipeTriggerDistanceKey];
            return [NSString stringWithFormat:@"%.0f", v <= 0 ? 56.0 : v];
        }
    }
    return @"";
}

#pragma mark - Settings controller (registered with WCPluginsMgr)

@interface WCGestureSettingsController ()
@property (nonatomic, copy) NSArray<NSArray<WCRow *> *> *sections;
@end

@implementation WCGestureSettingsController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"微信手势";
        [self rebuildSections];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(settingsDidChange:) name:WCGestureDidChangeNotification object:nil];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)settingsDidChange:(__unused NSNotification *)note {
    [self rebuildSections];
    [self.tableView reloadData];
}

- (void)rebuildSections {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL msgGesture = [d boolForKey:WCReplySwipeEnabledKey];
    NSMutableArray<WCRow *> *general = [NSMutableArray array];
    [general addObject:WCSwitchRow(@"手势总开关", WCGestureEnabledKey)];

    NSMutableArray<WCRow *> *msg = [NSMutableArray array];
    [msg addObject:WCSwitchRow(@"消息手势", WCReplySwipeEnabledKey)];
    if (msgGesture) {
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

    NSMutableArray<WCRow *> *input = [NSMutableArray array];
    [input addObject:WCSwitchRow(@"输入框滑动", WCInputSwipeActionsEnabledKey)];

    self.sections = @[general, msg, input];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCRow *row = self.sections[indexPath.section][indexPath.row];
    NSString *cellId = @"WCGestureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = WCRowDetailText(row);
    if (row.kind == WCRowKindSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(handleSwitch:) forControlEvents:UIControlEventValueChanged];
        sw.tag = (NSInteger)indexPath.section * 10000 + (NSInteger)indexPath.row;
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:row.defaultsKey];
        cell.accessoryView = sw;
    } else {
        cell.accessoryView = nil;
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
    WCRow *row = rows[rowIdx];
    WCSetBool(sw.on, row.defaultsKey);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    WCRow *row = self.sections[indexPath.section][indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (row.kind) {
        case WCRowKindSwitch:
            break;
        case WCRowKindActionDetail:
            WCPresentActionPicker(self, row.title, row.selfMessage, row.defaultsKey);
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
        WCGestureSettingsController *vc = [[WCGestureSettingsController alloc] initWithStyle:UITableViewStyleGrouped];
        [presenter.navigationController pushViewController:vc animated:YES];
        return;
    }
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
                WCSetBool(!msgGesture, WCReplySwipeEnabledKey);
            }]];
        [sheet addAction:[UIAlertAction actionWithTitle:inputSwipe ? @"输入框滑动：开" : @"输入框滑动：关"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                WCSetBool(!inputSwipe, WCInputSwipeActionsEnabledKey);
            }]];
    }
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
    // by the class name string we pass here.
    SEL registerController = sel_registerName("registerControllerWithTitle:version:controller:");
    if ([mgr respondsToSelector:registerController]) {
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(mgr, registerController,
            @"微信手势", @"1.0.0", NSStringFromClass([WCGestureSettingsController class]));
        return;
    }

    // Older API: a single switch row.
    SEL registerSwitch = sel_registerName("registerSwitchWithTitle:key:");
    if ([mgr respondsToSelector:registerSwitch]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(mgr, registerSwitch,
            @"微信手势", WCGestureEnabledKey);
    }
}
