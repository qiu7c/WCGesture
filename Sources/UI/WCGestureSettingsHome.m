#import "Sources/API/WCGestureInternal.h"

@interface WCSettingsHomeCard : UITableViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *iconBackground;
@property (nonatomic, strong) UIImageView *symbol;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *subtitle;
@end

@implementation WCSettingsHomeCard
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self = [super initWithStyle:style reuseIdentifier:identifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _card = [UIView new];
        _card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        _card.layer.cornerRadius = 16;
        _card.layer.cornerCurve = kCACornerCurveContinuous;
        [self.contentView addSubview:_card];
        _iconBackground = [UIView new];
        _iconBackground.layer.cornerRadius = 12;
        [_card addSubview:_iconBackground];
        _symbol = [UIImageView new];
        _symbol.contentMode = UIViewContentModeScaleAspectFit;
        [_iconBackground addSubview:_symbol];
        _heading = [UILabel new];
        _heading.textColor = UIColor.labelColor;
        _subtitle = [UILabel new];
        _subtitle.textColor = UIColor.secondaryLabelColor;
        _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        _chevron.tintColor = UIColor.tertiaryLabelColor;
        _chevron.contentMode = UIViewContentModeScaleAspectFit;
        for (UIView *view in @[_heading, _subtitle, _chevron]) [_card addSubview:view];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat scale = WCGestureSettingsScaleFactor();
    self.card.frame = CGRectInset(self.contentView.bounds, 16, 6 * scale);
    self.iconBackground.frame = CGRectMake(16 * scale, (self.card.bounds.size.height - 40 * scale) / 2, 40 * scale, 40 * scale);
    self.symbol.frame = CGRectMake(10 * scale, 10 * scale, 20 * scale, 20 * scale);
    CGFloat x = CGRectGetMaxX(self.iconBackground.frame) + 12 * scale;
    CGFloat width = MAX(0, self.card.bounds.size.width - x - 38 * scale);
    BOOL subtitle = self.subtitle.text.length > 0;
    self.heading.font = [UIFont systemFontOfSize:17 * scale weight:UIFontWeightSemibold];
    self.subtitle.font = [UIFont systemFontOfSize:12 * scale];
    self.heading.frame = CGRectMake(x, self.card.bounds.size.height / 2 - (subtitle ? 21 : 12) * scale, width, 24 * scale);
    self.subtitle.frame = CGRectMake(x, CGRectGetMaxY(self.heading.frame), width, 18 * scale);
    self.chevron.frame = CGRectMake(self.card.bounds.size.width - 28 * scale, self.card.bounds.size.height / 2 - 7 * scale, 12 * scale, 14 * scale);
}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    self.card.alpha = highlighted ? 0.65 : 1;
}
@end

@interface WCGestureSettingsController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, copy) NSArray<NSDictionary *> *searchIndex;
@property (nonatomic, copy) NSArray<NSDictionary *> *results;
@end

@implementation WCGestureSettingsController
- (instancetype)init {
    return [super initWithStyle:UITableViewStylePlain];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    WCGestureSettingsConfigureNavigation(self);
    self.title = @"One Wx";
    WCRefreshCachedCurrentUser();
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.searchField = [UITextField new];
    self.searchField.placeholder = @"搜索功能或设置";
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(updateSearchResults) forControlEvents:UIControlEventEditingChanged];
    self.tableView.tableHeaderView = WCGestureSettingsSearchHeader(self.searchField, self.view.bounds.size.width);
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 72)];
    footer.numberOfLines = 1;
    footer.text = @"One Wx by Cc";
    footer.textAlignment = NSTextAlignmentCenter;
    footer.font = [UIFont systemFontOfSize:12 * WCGestureSettingsScaleFactor()];
    footer.textColor = UIColor.secondaryLabelColor;
    self.tableView.tableFooterView = footer;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.searchIndex = [WCGestureDetailController searchEntries];
    self.tableView.rowHeight = 88 * WCGestureSettingsScaleFactor();
    self.tableView.tableHeaderView = WCGestureSettingsSearchHeader(self.searchField, self.view.bounds.size.width);
    [self updateSearchResults];
}
- (BOOL)isSearching {
    return [self.searchField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
}
- (BOOL)textFieldShouldReturn:(UITextField *)field {
    [field resignFirstResponder];
    return YES;
}
- (void)updateSearchResults {
    NSString *query = [self.searchField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *results = [NSMutableArray array];
    if (query.length) {
        for (NSDictionary *entry in self.searchIndex) {
            NSString *text = [NSString stringWithFormat:@"%@ %@ %@", entry[@"title"], entry[@"categoryTitle"], entry[@"sectionTitle"]];
            if ([text rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) [results addObject:entry];
        }
    }
    self.results = results;
    UILabel *empty = [UILabel new];
    empty.text = @"没有找到相关设置";
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.secondaryLabelColor;
    self.tableView.backgroundView = query.length && !results.count ? empty : nil;
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isSearching ? 1 : 6;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isSearching ? self.results.count : 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCSettingsHomeCard *cell = [tableView dequeueReusableCellWithIdentifier:@"OneWxHome"];
    if (!cell) cell = [[WCSettingsHomeCard alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"OneWxHome"];
    NSArray *titles = @[@"聊天类功能", @"手势类功能", @"朋友圈功能", @"界面类功能", @"禁用类功能", @"插件类配置"];
    NSArray *symbols = @[@"bubble.left.and.bubble.right", @"hand.tap", @"heart", @"rectangle.3.offgrid", @"nosign", @"gearshape"];
    NSArray *colors = @[UIColor.systemBlueColor, UIColor.systemGreenColor, UIColor.systemPinkColor, UIColor.systemPurpleColor, UIColor.systemRedColor, UIColor.systemOrangeColor];
    NSInteger category = self.isSearching ? [self.results[indexPath.row][@"category"] integerValue] : indexPath.section;
    cell.heading.text = self.isSearching ? self.results[indexPath.row][@"title"] : titles[category];
    cell.subtitle.text = self.isSearching ? [NSString stringWithFormat:@"%@ · %@", titles[category], self.results[indexPath.row][@"sectionTitle"]] : nil;
    cell.symbol.image = [UIImage systemImageNamed:symbols[category]];
    cell.symbol.tintColor = colors[category];
    cell.iconBackground.backgroundColor = [colors[category] colorWithAlphaComponent:0.14];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *result = self.isSearching ? self.results[indexPath.row] : nil;
    NSInteger category = result ? [result[@"category"] integerValue] : indexPath.section;
    WCGestureDetailController *detail = [[WCGestureDetailController alloc] initWithCategory:category];
    if (result) [detail focusSearchResult:result];
    [self.searchField resignFirstResponder];
    [self.navigationController pushViewController:detail animated:YES];
}
@end
