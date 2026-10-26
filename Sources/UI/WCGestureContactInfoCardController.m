#import <math.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCInfoAvatarHost : UIView
@property (nonatomic, strong) UIView *source;

- (instancetype)initWithUserName:(NSString *)userName;
@end
@implementation WCInfoAvatarHost
- (instancetype)initWithUserName:(NSString *)userName {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.clipsToBounds = YES; self.layer.cornerCurve = kCACornerCurveContinuous;
    self.source = WCGestureContactUncroppedAvatarView(userName);
    WCGestureExcludeHeadViewFromGlobalAvatarRounding(self.source);
    self.source.userInteractionEnabled = NO;
    [self addSubview:self.source];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.source.frame = self.bounds;
    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    double percent = [NSUserDefaults.standardUserDefaults doubleForKey:WCGestureGlobalAvatarCornerPercentKey];
    CGFloat radius = WCGestureEnabled(WCGestureGlobalAvatarRoundingEnabledKey)
        ? side * 0.5 * (isfinite(percent) ? MIN(100, MAX(0, percent)) / 100 : 1) : 10;
    self.layer.cornerRadius = MIN(side / 2, radius);
}
@end

@interface WCInfoFieldCell : UITableViewCell
@property (nonatomic, strong) UILabel *field;
@property (nonatomic, strong) UILabel *value;
@end
@implementation WCInfoFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self = [super initWithStyle:style reuseIdentifier:identifier];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.field = [UILabel new]; self.value = [UILabel new];
    self.field.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:14] maximumPointSize:19];
    self.value.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:15] maximumPointSize:21];
    self.field.textColor = UIColor.secondaryLabelColor; self.value.textColor = UIColor.labelColor;
    self.field.numberOfLines = 1; self.value.numberOfLines = 1;
    self.value.lineBreakMode = NSLineBreakByTruncatingMiddle; self.value.textAlignment = NSTextAlignmentRight;
    for (UIView *view in @[self.field, self.value]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:view]; }
    [NSLayoutConstraint activateConstraints:@[
        [self.field.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.field.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor multiplier:0.3 constant:-6],
        [self.field.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.field.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:2],
        [self.value.leadingAnchor constraintEqualToAnchor:self.field.trailingAnchor constant:12],
        [self.value.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.value.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.value.topAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor constant:2],

    ]];
    return self;
}
@end

@interface WCContactInfoCardController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *cardTitle;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *rows;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *groups;
@property (nonatomic, assign) BOOL showingGroups;
@property (nonatomic, assign) BOOL groupsFinished;
@property (nonatomic, assign) BOOL groupsAvailable;
@property (nonatomic, strong) id groupRequest;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) WCInfoAvatarHost *avatar;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSLayoutConstraint *panelHeight;
@property (nonatomic, assign) CGFloat fieldRowHeight;
@end

@implementation WCContactInfoCardController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    UIButton *dimming = [UIButton buttonWithType:UIButtonTypeCustom];
    dimming.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
    dimming.accessibilityLabel = @"关闭资料信息";
    [dimming addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    self.panel = [UIView new]; self.panel.backgroundColor = UIColor.clearColor;
    self.panel.layer.cornerRadius = 24; self.panel.layer.cornerCurve = kCACornerCurveContinuous;
    self.panel.layer.borderWidth = 0.5; self.panel.clipsToBounds = YES; self.panel.accessibilityViewIsModal = YES;
    self.glass = [[UIVisualEffectView alloc] initWithEffect:nil]; self.glass.userInteractionEnabled = NO;
    self.avatar = [[WCInfoAvatarHost alloc] initWithUserName:self.userName];
    self.heading = [UILabel new]; self.heading.text = self.cardTitle;
    self.heading.font = [UIFont systemFontOfSize:14]; self.heading.textColor = UIColor.secondaryLabelColor;
    UILabel *name = [UILabel new]; name.text = self.displayName;
    name.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:18] maximumPointSize:23];
    name.textColor = UIColor.labelColor; name.lineBreakMode = NSLineBreakByTruncatingTail;
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = UIColor.secondaryLabelColor; close.accessibilityLabel = @"关闭";
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.backButton setImage:WCGestureSettingsBackImage() forState:UIControlStateNormal];
    self.backButton.accessibilityLabel = @"返回资料"; self.backButton.hidden = YES;
    [self.backButton addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self; self.table.delegate = self; self.table.backgroundColor = UIColor.clearColor;
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = UITableViewAutomaticDimension; self.table.estimatedRowHeight = 52;
    self.table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    for (UIView *view in @[dimming, self.panel]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:view]; }
    for (UIView *view in @[self.glass, self.avatar, self.heading, name, close, self.backButton, self.table]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.panel addSubview:view]; }
    self.panelHeight = [self.panel.heightAnchor constraintEqualToConstant:560];
    self.panelHeight.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *preferredWidth = [self.panel.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.9]; preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [dimming.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [dimming.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dimming.topAnchor constraintEqualToAnchor:self.view.topAnchor], [dimming.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.panel.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor], [self.panel.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        preferredWidth, [self.panel.widthAnchor constraintLessThanOrEqualToConstant:440], [self.panel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-24],
        self.panelHeight, [self.panel.heightAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor constant:-24],
        [self.glass.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor], [self.glass.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor],
        [self.glass.topAnchor constraintEqualToAnchor:self.panel.topAnchor], [self.glass.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor],
        [self.avatar.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:20], [self.avatar.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:22],
        [self.avatar.widthAnchor constraintEqualToConstant:48], [self.avatar.heightAnchor constraintEqualToConstant:48],
        [close.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:6], [close.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-6], [close.widthAnchor constraintEqualToConstant:44], [close.heightAnchor constraintEqualToConstant:44],
        [self.heading.leadingAnchor constraintEqualToAnchor:self.avatar.trailingAnchor constant:14], [self.heading.topAnchor constraintEqualToAnchor:self.avatar.topAnchor], [self.heading.trailingAnchor constraintLessThanOrEqualToAnchor:close.leadingAnchor],
        [name.leadingAnchor constraintEqualToAnchor:self.heading.leadingAnchor], [name.topAnchor constraintEqualToAnchor:self.heading.bottomAnchor constant:6], [name.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-4],
        [self.backButton.centerXAnchor constraintEqualToAnchor:self.avatar.centerXAnchor], [self.backButton.centerYAnchor constraintEqualToAnchor:self.avatar.centerYAnchor], [self.backButton.widthAnchor constraintEqualToConstant:44], [self.backButton.heightAnchor constraintEqualToConstant:44],
        [self.table.topAnchor constraintEqualToAnchor:self.avatar.bottomAnchor constant:18], [self.table.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor], [self.table.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor], [self.table.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-12],
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(styleChanged:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(styleChanged:) name:WCGestureDidChangeNotification object:nil];
    [self updateStyle];
    if (![self.userName hasSuffix:@"@chatroom"]) [self loadGroups];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat safeHeight = CGRectGetHeight(self.view.safeAreaLayoutGuide.layoutFrame);
    if (safeHeight <= 0) return;
    CGFloat maximum = MAX(100, safeHeight - 24);
    CGFloat desired = self.showingGroups ? maximum * 0.82 : 100 + self.displayRows.count * 48;
    CGFloat height = MIN(maximum, MAX(MIN(maximum, safeHeight * 0.72), desired));
    if (fabs(self.panelHeight.constant - height) > 0.5) self.panelHeight.constant = height;
    self.table.scrollEnabled = self.showingGroups;
    if (!self.showingGroups && !CGPointEqualToPoint(self.table.contentOffset, CGPointZero)) self.table.contentOffset = CGPointZero;
    CGFloat rowHeight = MAX(1, MIN(48, CGRectGetHeight(self.table.bounds) / MAX(1, self.displayRows.count)));
    if (!self.showingGroups && fabs(self.fieldRowHeight - rowHeight) > 0.5) { self.fieldRowHeight = rowHeight; [self.table reloadData]; }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path { return self.showingGroups ? UITableViewAutomaticDimension : (self.fieldRowHeight > 0 ? self.fieldRowHeight : 40); }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)updateStyle {
    BOOL reduced = UIAccessibilityIsReduceTransparencyEnabled();
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.glass.effect = reduced ? nil : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.glass.alpha = reduced ? 1 : 0.82;
    // A translucent neutral wash above the material keeps background details
    // from competing with the text. Dark mode uses a dark wash for contrast.
    self.glass.contentView.backgroundColor = reduced ? UIColor.clearColor
        : [UIColor colorWithWhite:dark ? 0.08 : 1.0 alpha:dark ? 0.24 : 0.22];
    self.panel.backgroundColor = reduced ? UIColor.secondarySystemGroupedBackgroundColor : UIColor.clearColor;
    self.panel.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:dark ? 0.16 : 0.45].CGColor;
    [self.avatar setNeedsLayout];
}
- (void)styleChanged:(NSNotification *)note {
    if (!WCGestureEnabled(WCGestureContactInfoCardEnabledKey)) { [self close]; return; }
    [self updateStyle];
    [self.table reloadData]; [self.view setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) [self updateStyle];
}
- (void)close { self.groupRequest = nil; [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)accessibilityPerformEscape { if (self.showingGroups) [self back]; else [self close]; return YES; }
- (void)back { self.showingGroups = NO; self.heading.text = self.cardTitle; self.backButton.hidden = YES; self.avatar.hidden = NO; [self.view setNeedsLayout]; [self updateGroupStatus]; [self.table reloadData]; }
- (void)loadGroups {
    self.groupRequest = nil; self.groupsFinished = NO; self.groupsAvailable = NO; self.groups = @[];
    __weak typeof(self) weakSelf = self;
    self.groupRequest = WCGestureContactInfoCardLoadGroups(self.userName, ^(NSArray *groups, BOOL finished) {
        WCContactInfoCardController *card = weakSelf;
        if (!card) return;
        card.groupsFinished = finished;
        if (groups) { card.groups = groups; card.groupsAvailable = YES; }
        [card updateGroupStatus]; [card.table reloadData]; [card.view setNeedsLayout];
    });
    [self updateGroupStatus];
}
- (void)updateGroupStatus {
    if (!self.showingGroups || self.groups.count) { self.table.backgroundView = nil; return; }
    if (!self.groupsFinished) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [spinner startAnimating]; self.table.backgroundView = spinner;
    } else {
        UIButton *status = [UIButton buttonWithType:UIButtonTypeSystem];
        [status setTitle:self.groupsAvailable ? @"暂无共同群聊" : @"重试读取共同群聊" forState:UIControlStateNormal];
        status.enabled = !self.groupsAvailable;
        [status addTarget:self action:@selector(loadGroups) forControlEvents:UIControlEventTouchUpInside]; self.table.backgroundView = status;
    }
}
- (NSArray *)displayRows {
    if (self.showingGroups) return self.groups ?: @[];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *row in self.rows) if (![row[@"title"] isEqualToString:@"共同群聊"]) [rows addObject:row];
    if (![self.userName hasSuffix:@"@chatroom"]) {
        NSString *value = self.groupsAvailable ? [NSString stringWithFormat:@"%lu 个", (unsigned long)self.groups.count] : (self.groupsFinished ? @"暂不可用" : @"读取中");
        [rows addObject:@{@"title":@"共同群聊", @"value":value, @"action":@"groups"}];
    }
    if (WCGestureEnabled(WCGestureSendConfirmationEnabledKey) &&
        WCGestureEnabled(WCGestureSendConfirmationProfileSwitchEnabledKey) &&
        [self.account isEqualToString:WCCurrentUserWXID()]) {
        [rows addObject:@{@"title":@"发送前确认", @"value":@"", @"action":@"send-confirmation"}];
    }
    return rows;
}
- (void)toggleSendConfirmation:(UISwitch *)sender {
    if (!WCRefreshCachedCurrentUser() || ![self.account isEqualToString:WCCurrentUserWXID()]) {
        [sender setOn:!sender.on animated:YES]; WCShowToast(@"账号已切换，请重新打开资料卡"); return;
    }
    WCGestureSendConfirmationSetProtected(self.userName, sender.on);
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.displayRows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = self.displayRows[path.row];
    if (self.showingGroups) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxRelatedGroup"];
        if (!cell) { cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"OneWxRelatedGroup"]; cell.backgroundColor = UIColor.clearColor; cell.textLabel.font = [UIFont systemFontOfSize:16]; cell.textLabel.numberOfLines = 0; }
        cell.textLabel.text = row[@"title"]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell;
    }
    if ([row[@"action"] isEqualToString:@"send-confirmation"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxInfoSendConfirmation"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"OneWxInfoSendConfirmation"];
        cell.backgroundColor = UIColor.clearColor; cell.textLabel.text = @"发送前确认";
        cell.textLabel.textColor = UIColor.labelColor; cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *toggle = [UISwitch new]; toggle.onTintColor = UIColor.systemBlueColor;
        toggle.on = [WCGestureSendConfirmationProtectedConversations() containsObject:self.userName];
        [toggle addTarget:self action:@selector(toggleSendConfirmation:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }
    WCInfoFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxInfoField"];
    if (!cell) cell = [[WCInfoFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"OneWxInfoField"];
    cell.field.text = row[@"title"]; cell.value.text = row[@"value"];
    cell.value.adjustsFontSizeToFitWidth = YES; cell.value.minimumScaleFactor = 0.7;
    BOOL longValue = [row[@"title"] isEqualToString:@"个性签名"] || [row[@"title"] isEqualToString:@"管理员"] || [row[@"title"] isEqualToString:@"群简介"];
    cell.value.numberOfLines = longValue && self.fieldRowHeight >= 42 ? 2 : 1;
    CGFloat size = MIN(14, MAX(8, self.fieldRowHeight - 6));
    cell.field.font = [UIFont systemFontOfSize:size]; cell.value.font = [UIFont systemFontOfSize:size];
    cell.accessoryType = row[@"action"] ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.accessibilityHint = row[@"action"] ? @"查看共同群聊" : @"复制内容";
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *row = self.displayRows[path.row];
    if (self.showingGroups) {
        NSString *userName = row[@"username"];
        self.groupRequest = nil;
        [self dismissViewControllerAnimated:YES completion:^{ if (!WCGesturePushPrivateChat(userName)) WCShowToast(@"暂时无法打开该群聊"); }];
    } else if ([row[@"action"] isEqualToString:@"groups"]) {
        self.showingGroups = YES; self.heading.text = @"共同群聊"; self.backButton.hidden = NO; self.avatar.hidden = YES;
        [self.view setNeedsLayout]; [self updateGroupStatus]; [self.table reloadData];
    } else if ([row[@"action"] isEqualToString:@"send-confirmation"]) {
        return;
    } else { UIPasteboard.generalPasteboard.string = row[@"value"]; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"已复制"); }
}
@end

UIViewController *WCGestureCreateContactInfoCard(NSString *title, NSString *name, NSString *userName, NSArray<NSDictionary<NSString *,NSString *> *> *rows) {
    WCContactInfoCardController *card = [WCContactInfoCardController new]; card.cardTitle = title; card.displayName = name; card.userName = userName; card.rows = rows;
    if (WCRefreshCachedCurrentUser()) card.account = WCCurrentUserWXID();
    card.modalPresentationStyle = UIModalPresentationOverFullScreen; card.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return card;
}
