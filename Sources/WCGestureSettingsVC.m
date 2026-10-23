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

static WCRow *WCInputActionRow(NSString *title, NSString *key) {
    WCRow *row = [WCRow new];
    row.title = title;
    row.defaultsKey = key;
    row.kind = WCRowKindInputAction;
    return row;
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
        case WCRowKindDistance: {
            double v = [d doubleForKey:WCReplySwipeTriggerDistanceKey];
            return [NSString stringWithFormat:@"%.0f", v <= 0 ? 56.0 : v];
        }
    }
    return @"";
}

#pragma mark - Settings controller (registered with WCPluginsMgr)

@interface WCSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, copy) NSArray<WCRow *> *headerRows;   // always-visible rows
@property (nonatomic, copy) NSArray<WCRow *> *detailRows;   // shown when expanded
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, copy) NSString *collapseKey;          // NSUserDefaults key for collapse state
@end
@implementation WCSection
@end

static NSString *kChatPageCollapseKey = @"com.qiu7c.wcgesture.settings.collapse.chatpage";
static NSString *kOtherCollapseKey = @"com.qiu7c.wcgesture.settings.collapse.other";

@interface WCGestureSettingsController ()
@property (nonatomic, copy) NSArray<WCSection *> *sections;
@end

@implementation WCGestureSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"WCGesture";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48;
    [self rebuildSections];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(settingsDidChange:) name:WCGestureDidChangeNotification object:nil];
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) [self rebuildSections];
    return self;
}

- (instancetype)init {
    return [self initWithStyle:UITableViewStyleInsetGrouped];
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

    // ── 聊天页手势 ──
    BOOL msgGesture = [d boolForKey:WCReplySwipeEnabledKey];
    BOOL inputGesture = [d boolForKey:WCInputGestureEnabledKey];
    NSMutableArray *chatHeader = [NSMutableArray array];
    [chatHeader addObject:WCSwitchRow(@"消息手势", WCReplySwipeEnabledKey)];
    [chatHeader addObject:WCSwitchRow(@"输入框手势", WCInputGestureEnabledKey)];

    NSMutableArray *chatDetail = [NSMutableArray array];
    if (msgGesture) {
        [chatDetail addObject:WCActionRow(@"左滑 · 自己", WCReplySwipeSelfActionKey, YES)];
        [chatDetail addObject:WCActionRow(@"左滑 · 对方", WCReplySwipeOtherActionKey, NO)];
        [chatDetail addObject:WCActionRow(@"右滑 · 自己", WCReplySwipeRightSelfActionKey, YES)];
        [chatDetail addObject:WCActionRow(@"右滑 · 对方", WCReplySwipeRightOtherActionKey, NO)];
        [chatDetail addObject:WCActionRow(@"双击 · 自己", WCMessageDoubleTapSelfActionKey, YES)];
        [chatDetail addObject:WCActionRow(@"双击 · 对方", WCMessageDoubleTapOtherActionKey, NO)];
        [chatDetail addObject:WCActionRow(@"三击 · 自己", WCMessageTripleTapSelfActionKey, YES)];
        [chatDetail addObject:WCActionRow(@"三击 · 对方", WCMessageTripleTapOtherActionKey, NO)];
        [chatDetail addObject:WCDistanceRow(@"触发距离")];
    }
    if (inputGesture) {
        [chatDetail addObject:WCInputActionRow(@"左滑动作", WCInputSwipeLeftActionKey)];
        [chatDetail addObject:WCInputActionRow(@"右滑动作", WCInputSwipeRightActionKey)];
        [chatDetail addObject:WCInputActionRow(@"双击动作", WCInputDoubleTapActionKey)];
        [chatDetail addObject:WCInputActionRow(@"三击动作", WCInputTripleTapActionKey)];
    }

    WCSection *chat = [WCSection new];
    chat.title = @"聊天页手势";
    chat.headerRows = chatHeader;
    chat.detailRows = chatDetail;
    chat.collapseKey = kChatPageCollapseKey;
    chat.expanded = ![d boolForKey:chat.collapseKey];

    // ── 其他手势 ──
    NSMutableArray *otherHeader = [NSMutableArray array];
    [otherHeader addObject:WCSwitchRow(@"朋友圈双击点赞", WCMomentsDoubleTapLikeKey)];

    NSMutableArray *otherDetail = [NSMutableArray array];
    if ([d boolForKey:WCMomentsDoubleTapLikeKey]) {
        [otherDetail addObject:WCSwitchRow(@"点赞触感反馈", WCMomentsLikeHapticKey)];
    }

    WCSection *other = [WCSection new];
    other.title = @"其他手势";
    other.headerRows = otherHeader;
    other.detailRows = otherDetail;
    other.collapseKey = kOtherCollapseKey;
    other.expanded = ![d boolForKey:other.collapseKey];

    self.sections = @[chat, other];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    WCSection *sec = self.sections[section];
    NSUInteger count = sec.headerRows.count;
    if (sec.expanded) count += sec.detailRows.count;
    return count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    WCSection *sec = self.sections[section];
    UIButton *header = [UIButton buttonWithType:UIButtonTypeSystem];
    header.frame = CGRectMake(0, 0, tableView.bounds.size.width, 44);
    [header setTitle:[NSString stringWithFormat:@"  %@  %@", sec.title, sec.expanded ? @"▾" : @"▸"]
           forState:UIControlStateNormal];
    header.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    header.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [header setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
    header.tag = section;
    [header addTarget:self action:@selector(toggleSection:) forControlEvents:UIControlEventTouchUpInside];
    return header;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(__unused NSInteger)section {
    return 44;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCSection *sec = self.sections[indexPath.section];
    WCRow *row;
    if ((NSUInteger)indexPath.row < sec.headerRows.count) {
        row = sec.headerRows[indexPath.row];
    } else {
        NSUInteger detailIdx = (NSUInteger)indexPath.row - sec.headerRows.count;
        if (detailIdx < sec.detailRows.count) row = sec.detailRows[detailIdx];
    }
    NSString *cellId = @"WCGestureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
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

- (void)toggleSection:(UIButton *)header {
    NSInteger section = header.tag;
    if (section < 0 || section >= (NSInteger)self.sections.count) return;
    WCSection *sec = self.sections[section];
    sec.expanded = !sec.expanded;
    [[NSUserDefaults standardUserDefaults] setBool:!sec.expanded forKey:sec.collapseKey];
    [self.tableView reloadData];
}

- (void)handleSwitch:(UISwitch *)sw {
    NSInteger section = sw.tag / 10000;
    NSInteger rowIdx = sw.tag % 10000;
    if (section < 0 || section >= (NSInteger)self.sections.count) return;
    WCSection *sec = self.sections[section];
    WCRow *row;
    if ((NSUInteger)rowIdx < sec.headerRows.count) row = sec.headerRows[rowIdx];
    else {
        NSUInteger detailIdx = (NSUInteger)rowIdx - sec.headerRows.count;
        if (detailIdx < sec.detailRows.count) row = sec.detailRows[detailIdx];
    }
    if (row) WCSetBool(sw.on, row.defaultsKey);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    WCSection *sec = self.sections[indexPath.section];
    WCRow *row;
    if ((NSUInteger)indexPath.row < sec.headerRows.count) row = sec.headerRows[indexPath.row];
    else {
        NSUInteger detailIdx = (NSUInteger)indexPath.row - sec.headerRows.count;
        if (detailIdx < sec.detailRows.count) row = sec.detailRows[detailIdx];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!row) return;
    switch (row.kind) {
        case WCRowKindSwitch:
            break;
        case WCRowKindActionDetail:
            WCPresentActionPicker(self, row.title, row.selfMessage, row.defaultsKey);
            break;
        case WCRowKindInputAction:
            WCPresentInputSwipeActionPicker(self, row.title, row.defaultsKey);
            break;
        case WCRowKindDistance:
            WCPresentTriggerDistanceEditor(self);
            break;
    }
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForFooterInSection:(__unused NSInteger)section {
    return (NSInteger)section == (NSInteger)self.sections.count - 1 ? 100 : 0;
}

- (UIView *)tableView:(__unused UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section != (NSInteger)self.sections.count - 1) return nil;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 100)];
    UILabel *version = [[UILabel alloc] init];
    version.text = @"版本 1.0.0";
    version.font = [UIFont systemFontOfSize:13];
    version.textColor = [UIColor tertiaryLabelColor];
    version.textAlignment = NSTextAlignmentCenter;
    UILabel *author = [[UILabel alloc] init];
    author.text = @"联系作者：占位符";
    author.font = [UIFont systemFontOfSize:13];
    author.textColor = [UIColor tertiaryLabelColor];
    author.textAlignment = NSTextAlignmentCenter;
    UILabel *brand = [[UILabel alloc] init];
    brand.text = @"WCGesture by Cc";
    brand.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    brand.textColor = [UIColor secondaryLabelColor];
    brand.textAlignment = NSTextAlignmentCenter;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[version, author, brand]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 4;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:footer.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
    ]];
    return footer;
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
    // by the class name string we pass here.
    SEL registerController = sel_registerName("registerControllerWithTitle:version:controller:");
    if ([mgr respondsToSelector:registerController]) {
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(mgr, registerController,
            @"微信手势", @"1.0.0", NSStringFromClass([WCGestureSettingsController class]));
        return;
    }

    // Older API: a single switch row controlling message gestures.
    SEL registerSwitch = sel_registerName("registerSwitchWithTitle:key:");
    if ([mgr respondsToSelector:registerSwitch]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(mgr, registerSwitch,
            @"微信手势", WCReplySwipeEnabledKey);
    }
}
