#import "Sources/API/WCGestureInternal.h"

@interface WCAutoStatusSettingsController : UITableViewController <UIDocumentPickerDelegate>
@property (nonatomic, copy) NSArray<NSArray<NSDictionary *> *> *sections;
@property (nonatomic, assign) BOOL importingVideo;
@end

static NSDictionary *WCAutoStatusRow(NSString *title, NSString *key, NSString *kind) {
    return @{@"title":title, @"key":key ?: @"", @"kind":kind};
}

@implementation WCAutoStatusSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自动更新微信状态";
    WCGestureSettingsConfigureNavigation(self);
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self rebuild];
}
- (void)rebuild {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *icon = [NSMutableArray arrayWithObject:WCAutoStatusRow(@"状态图标",WCGestureAutoStatusIconTypeKey,@"icon")];
    if ([[d stringForKey:WCGestureAutoStatusIconTypeKey] isEqualToString:@"userdefine"]) {
        [icon addObject:WCAutoStatusRow(@"自定义图标 ID",WCGestureAutoStatusIconIDKey,@"text")];
        [icon addObject:WCAutoStatusRow(@"自定义图标描述",WCGestureAutoStatusIconDescriptionKey,@"text")];
    }
    NSMutableArray *text = [NSMutableArray arrayWithObject:WCAutoStatusRow(@"状态文案",WCGestureAutoStatusTextModeKey,@"text-mode")];
    NSInteger textMode = [d integerForKey:WCGestureAutoStatusTextModeKey];
    if (textMode == 1) [text addObject:WCAutoStatusRow(@"自定义文案",WCGestureAutoStatusTextKey,@"text")];
    if (textMode == 2) [text addObject:WCAutoStatusRow(@"纯文本 API",WCGestureAutoStatusTextURLKey,@"url")];
    NSMutableArray *media = [NSMutableArray arrayWithObject:WCAutoStatusRow(@"状态背景",WCGestureAutoStatusMediaModeKey,@"media-mode")];
    NSInteger mode = [d integerForKey:WCGestureAutoStatusMediaModeKey];
    if (mode == 1) [media addObject:WCAutoStatusRow(@"图片 API",WCGestureAutoStatusImageURLKey,@"url")];
    else if (mode == 2) [media addObject:WCAutoStatusRow(@"视频 API",WCGestureAutoStatusVideoURLKey,@"url")];
    else {
        [media addObject:WCAutoStatusRow(@"导入本地图片",nil,@"image")];
        [media addObject:WCAutoStatusRow(@"导入本地视频",nil,@"video")];
        [media addObject:WCAutoStatusRow(@"清除本地背景",nil,@"clear-media")];
    }
    self.sections = @[
        @[WCAutoStatusRow(@"自动更新",WCGestureAutoStatusEnabledKey,@"switch"),WCAutoStatusRow(@"每天更新时间",WCGestureAutoStatusHourKey,@"hour")],
        icon,text,media,@[WCAutoStatusRow(@"立即更新",nil,@"publish")]
    ];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.sections[section].count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path { return 52; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *row = self.sections[path.section][path.row];
    NSString *kind = row[@"kind"], *key = row[@"key"];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.textLabel.text = row[@"title"]; cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.indentationLevel = path.row ? 1 : 0; cell.indentationWidth = 18;
    if ([kind isEqualToString:@"switch"]) {
        UISwitch *toggle = [UISwitch new]; toggle.onTintColor = UIColor.systemBlueColor;
        toggle.on = [d boolForKey:key]; [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if ([kind isEqualToString:@"hour"]) cell.detailTextLabel.text = [NSString stringWithFormat:@"%02ld:00",(long)[d integerForKey:key]];
        else if ([kind isEqualToString:@"icon"]) { NSString *value = [d stringForKey:key]; cell.detailTextLabel.text = [value isEqualToString:@"userdefine"] ? @"自定义" : value; }
        else if ([kind isEqualToString:@"text-mode"]) cell.detailTextLabel.text = @[@"不添加文案",@"自定义",@"API"][MIN(2,MAX(0,[d integerForKey:key]))];
        else if ([kind isEqualToString:@"media-mode"]) cell.detailTextLabel.text = @[@"本地背景",@"图片 API",@"视频 API"][MIN(2,MAX(0,[d integerForKey:key]))];
        else if ([kind isEqualToString:@"image"] || [kind isEqualToString:@"video"]) {
            NSString *file = WCGestureAutoStatusMediaPath([kind isEqualToString:@"video"]);
            cell.detailTextLabel.text = [NSFileManager.defaultManager fileExistsAtPath:file] ? @"已导入" : @"未导入";
        } else if (key.length) cell.detailTextLabel.text = [d stringForKey:key];
    }
    return cell;
}
- (void)toggled:(UISwitch *)toggle {
    [NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:WCGestureAutoStatusEnabledKey];
    WCGestureSettingsPostChange(WCGestureAutoStatusEnabledKey);
}
- (void)save:(id)value key:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    WCGestureSettingsPostChange(key); [self rebuild];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *row = self.sections[path.section][path.row];
    NSString *kind = row[@"kind"], *key = row[@"key"], *title = row[@"title"];
    if ([kind isEqualToString:@"switch"]) return;
    if ([kind isEqualToString:@"publish"]) { WCGestureAutoStatusPublishNow(); return; }
    if ([kind isEqualToString:@"clear-media"]) {
        NSError *error = nil;
        for (NSNumber *video in @[@NO,@YES]) {
            NSString *path = WCGestureAutoStatusMediaPath(video.boolValue);
            if ([NSFileManager.defaultManager fileExistsAtPath:path]) [NSFileManager.defaultManager removeItemAtPath:path error:&error];
        }
        WCShowToast(error.localizedDescription ?: @"本地背景已清除"); [self rebuild]; return;
    }
    if ([kind isEqualToString:@"image"] || [kind isEqualToString:@"video"]) {
        self.importingVideo = [kind isEqualToString:@"video"];
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[self.importingVideo ? @"public.movie" : @"public.image"] inMode:UIDocumentPickerModeImport];
        picker.delegate = self; picker.allowsMultipleSelection = NO;
        [self presentViewController:picker animated:YES completion:nil]; return;
    }
    __weak WCAutoStatusSettingsController *weakSelf = self;
    if ([kind isEqualToString:@"icon"] || [kind hasSuffix:@"-mode"]) {
        NSMutableArray *options = [NSMutableArray array];
        if ([kind isEqualToString:@"icon"]) {
            for (NSDictionary *icon in WCGestureAutoStatusIconOptions()) [options addObject:[WCPopupOption optionWithTitle:icon[@"title"] value:icon[@"value"]]];
            [options addObject:[WCPopupOption optionWithTitle:@"自定义" value:@"userdefine"]];
        } else {
            NSArray *titles = [kind isEqualToString:@"text-mode"] ? @[@"不添加文案",@"自定义",@"API"] : @[@"本地背景",@"图片 API",@"视频 API"];
            for (NSUInteger i=0;i<titles.count;i++) [options addObject:[WCPopupOption optionWithTitle:titles[i] value:@(i)]];
        }
        [WCPopup showOptionsWithTitle:title message:nil options:options selected:[NSUserDefaults.standardUserDefaults objectForKey:key] completion:^(id value) { if(value) [weakSelf save:value key:key]; }]; return;
    }
    BOOL hour = [kind isEqualToString:@"hour"];
    NSString *value = hour ? [NSString stringWithFormat:@"%ld",(long)[NSUserDefaults.standardUserDefaults integerForKey:key]] : [NSUserDefaults.standardUserDefaults stringForKey:key];
    [WCPopup showInputWithTitle:title message:nil text:value placeholder:hour ? @"0–23" : ([kind isEqualToString:@"url"] ? @"https://" : title) keyboard:hour ? UIKeyboardTypeNumberPad : ([kind isEqualToString:@"url"] ? UIKeyboardTypeURL : UIKeyboardTypeDefault) completion:^(NSString *input) {
        if (hour) {
            NSScanner *scanner = [NSScanner scannerWithString:input]; NSInteger h;
            if (![scanner scanInteger:&h] || !scanner.isAtEnd || h<0 || h>23) { WCShowToast(@"请输入 0–23 的整数"); return; }
            [weakSelf save:@(h) key:key];
        } else [weakSelf save:input ?: @"" key:key];
    }];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject; if (!url) return;
    BOOL scoped = [url startAccessingSecurityScopedResource];
    BOOL video = self.importingVideo;
    self.view.userInteractionEnabled = NO;
    __weak WCAutoStatusSettingsController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        NSError *error = nil;
        BOOL imported = WCGestureAutoStatusImportMedia(url,video,&error);
        if (scoped) [url stopAccessingSecurityScopedResource];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.view.userInteractionEnabled = YES;
            WCShowToast(imported ? @"背景已导入" : (error.localizedDescription ?: @"导入失败")); [weakSelf rebuild];
        });
    });
}
@end

UIViewController *WCGestureCreateAutoStatusSettingsController(void) { return [WCAutoStatusSettingsController new]; }
