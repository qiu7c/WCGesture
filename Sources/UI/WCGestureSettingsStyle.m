#import "Sources/API/WCGestureInternal.h"

UIImage *WCGestureSettingsBackImage(void) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightSemibold];
    return [UIImage systemImageNamed:@"chevron.left" withConfiguration:configuration];
}

void WCGestureSettingsConfigureNavigation(UIViewController *controller) {
    UINavigationItem *item = controller.navigationItem;
    item.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    item.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    BOOL transparentHome = [controller isKindOfClass:WCGestureSettingsController.class];
    UINavigationBar *bar = controller.navigationController.navigationBar;
    // Scope appearances to our item; the host WeChat navigation bar is shared.
    NSArray *sources = @[
        bar.standardAppearance ?: [UINavigationBarAppearance new],
        bar.scrollEdgeAppearance ?: bar.standardAppearance ?: [UINavigationBarAppearance new],
        bar.compactAppearance ?: bar.standardAppearance ?: [UINavigationBarAppearance new]
    ];
    NSMutableArray *appearances = [NSMutableArray array];
    for (UINavigationBarAppearance *source in sources) {
        UINavigationBarAppearance *appearance = [source copy];
        NSMutableDictionary *titleAttributes = [appearance.titleTextAttributes mutableCopy] ?: [NSMutableDictionary dictionary];
        titleAttributes[NSFontAttributeName] = [UIFont systemFontOfSize:17 * WCGestureSettingsScaleFactor() weight:UIFontWeightSemibold];
        appearance.titleTextAttributes = titleAttributes;
        if (transparentHome) {
            [appearance configureWithTransparentBackground];
            appearance.backgroundEffect = nil;
            appearance.backgroundColor = UIColor.clearColor;
            appearance.shadowColor = UIColor.clearColor;
        }
        UIImage *image = WCGestureSettingsBackImage();
        [appearance setBackIndicatorImage:image transitionMaskImage:image];
        // Also suppress a host-owned previous item's title on the home page.
        for (UIBarButtonItemStateAppearance *state in @[
            appearance.backButtonAppearance.normal, appearance.backButtonAppearance.highlighted,
            appearance.backButtonAppearance.disabled, appearance.backButtonAppearance.focused
        ]) state.titlePositionAdjustment = UIOffsetMake(-1000, 0);
        [appearances addObject:appearance];
    }
    item.standardAppearance = appearances[0];
    item.scrollEdgeAppearance = appearances[1];
    item.compactAppearance = appearances[2];
    if (@available(iOS 15.0, *)) {
        item.compactScrollEdgeAppearance = appearances[2];
    }
}

CGFloat WCGestureSettingsScaleFactor(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:WCGesturePageScalePluginUIKey]
        ? WCGestureLayoutScaleFactor() : 1.0;
}

void WCGestureSettingsPostChange(NSString *key) {
    if ([key isEqualToString:WCGestureAntiRevokePersistRecordsKey]) {
        WCGestureAntiRevokeSetPersistenceEnabled([NSUserDefaults.standardUserDefaults boolForKey:key]);
    }
    [NSNotificationCenter.defaultCenter postNotificationName:WCGestureDidChangeNotification object:key];
}


UIView *WCGestureSettingsSearchHeader(UITextField *field, CGFloat width) {
    CGFloat scale = WCGestureSettingsScaleFactor();
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 72 * scale)];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    field.layer.cornerRadius = 16 * scale;
    field.layer.cornerCurve = kCACornerCurveContinuous;
    field.font = [UIFont systemFontOfSize:16 * scale];
    field.textColor = UIColor.labelColor;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.returnKeyType = UIReturnKeySearch;
    UIView *iconWrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 44 * scale, 48 * scale)];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    icon.tintColor = UIColor.secondaryLabelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.frame = CGRectMake(16 * scale, 15 * scale, 18 * scale, 18 * scale);
    [iconWrap addSubview:icon];
    field.leftView = iconWrap;
    field.leftViewMode = UITextFieldViewModeAlways;
    [header addSubview:field];
    [NSLayoutConstraint activateConstraints:@[
        [field.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [field.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [field.topAnchor constraintEqualToAnchor:header.topAnchor constant:8 * scale],
        [field.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8 * scale],
    ]];
    return header;
}

// All sections on a settings page form one continuous inset card.
@interface WCSettingsCardCell : UITableViewCell
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UIView *pressedSurface;
@property (nonatomic) CACornerMask cardCorners;
@property (nonatomic, strong) UIImageView *disclosure;
@end
@implementation WCSettingsCardCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self=[super initWithStyle:style reuseIdentifier:identifier])) {
        self.backgroundColor=UIColor.clearColor;self.backgroundView=[UIView new];
        self.surface=[UIView new];self.surface.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
        self.surface.layer.cornerCurve=kCACornerCurveContinuous;self.surface.clipsToBounds=YES;
        [self.backgroundView addSubview:self.surface];
        self.selectedBackgroundView=[UIView new];self.selectedBackgroundView.backgroundColor=UIColor.clearColor;
        self.pressedSurface=[UIView new];self.pressedSurface.backgroundColor=UIColor.tertiarySystemFillColor;
        self.pressedSurface.layer.cornerCurve=kCACornerCurveContinuous;self.pressedSurface.clipsToBounds=YES;
        [self.selectedBackgroundView addSubview:self.pressedSurface];
    }
    return self;
}
- (void)setAccessoryType:(UITableViewCellAccessoryType)type {
    [super setAccessoryType:type];
    if (type==UITableViewCellAccessoryDisclosureIndicator) {
        if (!self.disclosure) {
            self.disclosure=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightRegular]]];
            self.disclosure.tintColor=UIColor.tertiaryLabelColor;
            self.disclosure.contentMode=UIViewContentModeScaleAspectFit;
            self.disclosure.frame=CGRectMake(0,0,12,16);
        }
        // A custom accessory uses the same absolute inset as switches/fold arrows.
        self.accessoryView=self.disclosure;
    } else if (self.accessoryView==self.disclosure) self.accessoryView=nil;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset=16;
    for (UIView *surface in @[self.surface,self.pressedSurface]) {
        surface.frame=CGRectInset(self.bounds,inset,0);
        surface.layer.cornerRadius=self.cardCorners?16:0;
        surface.layer.maskedCorners=self.cardCorners;
    }
    CGFloat trailing=inset;
    if (self.accessoryView) {
        CGRect accessory=self.accessoryView.frame;
        accessory.origin.x=CGRectGetWidth(self.bounds)-2*inset-CGRectGetWidth(accessory);
        accessory.origin.y=(CGRectGetHeight(self.bounds)-CGRectGetHeight(accessory))/2;
        self.accessoryView.frame=accessory;
        trailing=CGRectGetWidth(accessory)+3*inset;
    } else if (self.accessoryType!=UITableViewCellAccessoryNone) trailing=3*inset;
    self.contentView.frame=CGRectMake(inset,0,MAX(0,CGRectGetWidth(self.bounds)-inset-trailing),CGRectGetHeight(self.bounds));
}
@end
UITableViewCell *WCGestureSettingsCardCell(UITableView *table, NSString *identifier, UITableViewCellStyle style, NSIndexPath *path) {
    WCSettingsCardCell *cell=identifier.length?[table dequeueReusableCellWithIdentifier:identifier]:nil;
    if (!cell) cell=[[WCSettingsCardCell alloc] initWithStyle:style reuseIdentifier:identifier.length?identifier:nil];
    BOOL first=path.section==0 && path.row==0;
    BOOL last=path.section==table.numberOfSections-1 && path.row==[table numberOfRowsInSection:path.section]-1;
    cell.cardCorners=(first?(kCALayerMinXMinYCorner|kCALayerMaxXMinYCorner):0)
        |(last?(kCALayerMinXMaxYCorner|kCALayerMaxXMaxYCorner):0);
    [cell setNeedsLayout];return cell;
}
