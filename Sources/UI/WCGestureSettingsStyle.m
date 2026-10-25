#import "Sources/API/WCGestureInternal.h"

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
