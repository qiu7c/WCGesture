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
