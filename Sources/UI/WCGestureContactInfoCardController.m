#import "Sources/API/WCGestureInternal.h"

@interface WCContactInfoCardController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *cardTitle;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *rows;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UITableView *table;
@end

@implementation WCContactInfoCardController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    UIButton *dimming = [UIButton buttonWithType:UIButtonTypeCustom];
    dimming.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.35];
    dimming.accessibilityLabel = @"关闭资料信息";
    [dimming addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    self.panel = [UIView new];
    self.panel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.panel.layer.cornerRadius = 24; self.panel.layer.cornerCurve = kCACornerCurveContinuous;
    self.panel.clipsToBounds = YES; self.panel.accessibilityViewIsModal = YES;
    UIView *avatar = WCGestureContactAvatarView(self.userName);
    WCGestureExcludeHeadViewFromGlobalAvatarRounding(avatar);
    avatar.layer.cornerRadius = 26; avatar.clipsToBounds = YES; avatar.userInteractionEnabled = NO;
    UILabel *title = [UILabel new]; title.text = self.cardTitle;
    title.font = [UIFont systemFontOfSize:15]; title.textColor = UIColor.secondaryLabelColor;
    UILabel *name = [UILabel new]; name.text = self.displayName;
    name.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:17] maximumPointSize:22];
    name.textColor = UIColor.labelColor; name.lineBreakMode = NSLineBreakByTruncatingTail;
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = UIColor.secondaryLabelColor; close.accessibilityLabel = @"关闭";
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource = self; self.table.delegate = self;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = UITableViewAutomaticDimension; self.table.estimatedRowHeight = 60;
    self.table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    for (UIView *view in @[dimming, self.panel]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:view]; }
    for (UIView *view in @[avatar, title, name, close, self.table]) { view.translatesAutoresizingMaskIntoConstraints = NO; [self.panel addSubview:view]; }
    NSLayoutConstraint *halfHeight = [self.panel.heightAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor multiplier:0.52];
    halfHeight.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *minimumHeight = [self.panel.heightAnchor constraintGreaterThanOrEqualToConstant:240];
    minimumHeight.priority = UILayoutPriorityDefaultHigh - 1;
    NSLayoutConstraint *preferredWidth = [self.panel.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.9];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [dimming.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [dimming.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dimming.topAnchor constraintEqualToAnchor:self.view.topAnchor], [dimming.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.panel.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [self.panel.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        preferredWidth, [self.panel.widthAnchor constraintLessThanOrEqualToConstant:440],
        [self.panel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-24],
        halfHeight, minimumHeight, [self.panel.heightAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor constant:-24],
        [avatar.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:20], [avatar.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:20],
        [avatar.widthAnchor constraintEqualToConstant:52], [avatar.heightAnchor constraintEqualToConstant:52],
        [close.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:8], [close.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-8],
        [close.widthAnchor constraintEqualToConstant:44], [close.heightAnchor constraintEqualToConstant:44],
        [title.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:12], [title.topAnchor constraintEqualToAnchor:avatar.topAnchor constant:2],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:close.leadingAnchor constant:-4],
        [name.leadingAnchor constraintEqualToAnchor:title.leadingAnchor], [name.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [name.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-20],
        [self.table.topAnchor constraintEqualToAnchor:avatar.bottomAnchor constant:12],
        [self.table.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor], [self.table.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor],
        [self.table.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-12],
    ]];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)accessibilityPerformEscape { [self close]; return YES; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxContactInfo"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"OneWxContactInfo"];
        cell.backgroundColor = UIColor.clearColor;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        cell.textLabel.textColor = UIColor.secondaryLabelColor;
        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.detailTextLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.numberOfLines = 0;
        cell.textLabel.adjustsFontForContentSizeCategory = YES; cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    }
    NSDictionary *row = self.rows[path.row];
    cell.textLabel.text = row[@"title"]; cell.detailTextLabel.text = row[@"value"];
    cell.accessibilityHint = @"复制内容";
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    UIPasteboard.generalPasteboard.string = self.rows[path.row][@"value"];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"已复制");
}
@end

UIViewController *WCGestureCreateContactInfoCard(NSString *title, NSString *name, NSString *userName, NSArray<NSDictionary<NSString *,NSString *> *> *rows) {
    WCContactInfoCardController *card = [WCContactInfoCardController new];
    card.cardTitle = title; card.displayName = name; card.userName = userName; card.rows = rows;
    card.modalPresentationStyle = UIModalPresentationOverFullScreen;
    card.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return card;
}
