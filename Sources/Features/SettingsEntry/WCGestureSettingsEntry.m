#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCEntryCellKey, WCEntryBusyKey, WCEntryPageKey;
static NSHashTable<UIViewController *> *WCEntryPages(void) {
    static NSHashTable *pages; static dispatch_once_t once;
    dispatch_once(&once, ^{ pages = [NSHashTable weakObjectsHashTable]; }); return pages;
}
static NSString *WCEntryName(void) {
    NSString *name = [NSUserDefaults.standardUserDefaults stringForKey:WCPluginNameKey];
    return name.length ? name : @"One Wx";
}
static id WCEntryManager(void) {
    @try {
        Class cls = NSClassFromString(@"WCPluginsMgr"); SEL shared = NSSelectorFromString(@"sharedInstance");
        return [cls respondsToSelector:shared] ? ((id (*)(id,SEL))objc_msgSend)(cls,shared) : nil;
    } @catch (__unused NSException *exception) { return nil; }
}
BOOL WCGestureSettingsEntryManagerAvailable(void) {
    return [WCEntryManager() respondsToSelector:NSSelectorFromString(@"registerControllerWithTitle:version:controller:")];
}
WCGestureSettingsEntryLocation WCGestureSettingsEntryResolvedLocation(void) {
    NSInteger value = [NSUserDefaults.standardUserDefaults integerForKey:WCGestureSettingsEntryLocationKey];
    BOOL available = WCGestureSettingsEntryManagerAvailable();
    if (value < 0 || value > 2) return available ? WCGestureSettingsEntryManager : WCGestureSettingsEntryMe;
    if (value == WCGestureSettingsEntryManager && !available) return WCGestureSettingsEntryMe;
    return value;
}
static void WCEntrySyncManager(void) {
    @try {
        id manager = WCEntryManager();
        id plugins = WCTweakSafeValue(manager,@"plugins");
        NSString *controllerName = NSStringFromClass(WCGestureSettingsController.class);
        BOOL selected = WCGestureSettingsEntryResolvedLocation() == WCGestureSettingsEntryManager;
        // WCPluginsMgr has neither unregister nor duplicate protection. Only
        // remove this plugin's model, identified by its controller/key.
        if ([plugins isKindOfClass:NSMutableArray.class]) {
            NSMutableArray *list = plugins; id kept = nil;
            for (id model in list.copy) {
                BOOL own = [WCTweakSafeValue(model,@"controller") isEqual:controllerName]
                    || [WCTweakSafeValue(model,@"key") isEqual:WCReplySwipeEnabledKey];
                if (!own) continue;
                if (selected && !kept && [WCTweakSafeValue(model,@"controller") isEqual:controllerName]) {
                    kept = model; [model setValue:WCEntryName() forKey:@"title"]; [model setValue:@"1.0.0" forKey:@"version"];
                } else [list removeObjectIdenticalTo:model];
            }
            if (kept || !selected) return;
        } else if (!selected) return;
        SEL reg = NSSelectorFromString(@"registerControllerWithTitle:version:controller:");
        if ([manager respondsToSelector:reg])
            ((void (*)(id,SEL,id,id,id))objc_msgSend)(manager,reg,WCEntryName(),@"1.0.0",controllerName);
    } @catch (NSException *exception) { WCLog(@"设置入口：插件管理同步失败 %@",exception.name); }
}
static id WCEntryTableManager(UIViewController *controller) {
    for (NSString *key in @[@"m_tableViewMgr",@"_tableViewMgr",@"m_tableMgr",@"_tableMgr"]) {
        id manager = WCTweakSafeValue(controller,key);
        if ([manager respondsToSelector:NSSelectorFromString(@"getSectionAt:")]) return manager;
    }
    return nil;
}
static UIImage *WCEntryIcon(void) {
    // The same bundled asset used by the supplied plugin manager's Me-page row.
    UIImage *image = [UIImage imageNamed:@"WeChat_Lab_Logo_light_small"];
    if (image) return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *symbol = [UIImage systemImageNamed:@"puzzlepiece.extension.fill"];
    if (!symbol) symbol = [UIImage systemImageNamed:@"gearshape.fill"];
    return [symbol imageWithTintColor:UIColor.systemBlueColor renderingMode:UIImageRenderingModeAlwaysOriginal];
}
static id WCEntryMakeCell(UIViewController *controller) {
    Class cls = NSClassFromString(@"WCTableViewCellManager");
    SEL factory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:WithDisclosureIndicator:");
    SEL action = NSSelectorFromString(@"wc_pushGestureSettings");
    UIImage *icon = WCEntryIcon();
    NSString *name = WCEntryName();
    id cell = nil;
    if ([cls respondsToSelector:factory]) {
        cell = ((id (*)(id,SEL,SEL,id,id,id,BOOL))objc_msgSend)(cls,factory,action,controller,icon,name,YES);
    }
    if (!cell) {
        // Current WeChat exposes a normal-cell factory that takes the image
        // explicitly. Do not fall back to the old text-only row.
        Class normalClass = NSClassFromString(@"WCTableViewNormalCellManager");
        SEL imageFactory = NSSelectorFromString(@"normalCellForSel:target:title:detail:image:accessoryType:");
        if ([normalClass respondsToSelector:imageFactory])
            cell = ((id (*)(id,SEL,SEL,id,id,id,id,long long))objc_msgSend)(normalClass,imageFactory,action,controller,name,nil,icon,1LL);
    }
    if (!cell) {
        // The supplied manager uses this compatibility variant on newer builds.
        SEL imageFactory = NSSelectorFromString(@"normalCellForSel:target:leftImage:title:pathKey:");
        if ([cls respondsToSelector:imageFactory])
            cell = ((id (*)(id,SEL,SEL,id,id,id,id))objc_msgSend)(cls,imageFactory,action,controller,icon,name,nil);
    }
    if (cell) objc_setAssociatedObject(cell,&WCEntryCellKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return cell;
}
void WCGestureSettingsEntryRefresh(UIViewController *controller, WCGestureSettingsEntryLocation page) {
    if (!controller || [objc_getAssociatedObject(controller,&WCEntryBusyKey) boolValue]) return;
    [WCEntryPages() addObject:controller];
    objc_setAssociatedObject(controller,&WCEntryPageKey,@(page),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller,&WCEntryBusyKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        WCEntrySyncManager();
        id manager = WCEntryTableManager(controller);
        id sections = WCTweakSafeValue(manager,@"getAllSections") ?: WCTweakSafeValue(manager,@"sections");
        if (![sections isKindOfClass:NSArray.class] || ![sections count]) return;
        // Remove by our marker, never by title, to preserve other plugins.
        for (id section in [sections copy]) {
            id cells = WCTweakSafeValue(section,@"getAllCells") ?: WCTweakSafeValue(section,@"cells");
            if (![cells isKindOfClass:NSArray.class]) continue;
            for (NSInteger i=(NSInteger)[cells count]-1;i>=0;i--) {
                if (![objc_getAssociatedObject(cells[i],&WCEntryCellKey) boolValue]) continue;
                SEL remove = NSSelectorFromString(@"removeCellAt:");
                if ([section respondsToSelector:remove]) ((void (*)(id,SEL,unsigned long long))objc_msgSend)(section,remove,(unsigned long long)i);
            }
        }
        if (WCGestureSettingsEntryResolvedLocation() == page) {
            NSUInteger index = page == WCGestureSettingsEntryMe ? MIN(2,(NSUInteger)[sections count]-1) : 0;
            id section = sections[index], cell = WCEntryMakeCell(controller);
            SEL add = NSSelectorFromString(@"addCell:");
            if (cell && [section respondsToSelector:add]) ((void (*)(id,SEL,id))objc_msgSend)(section,add,cell);
        }
        SEL reload = NSSelectorFromString(@"reloadTableView");
        if ([manager respondsToSelector:reload]) ((void (*)(id,SEL))objc_msgSend)(manager,reload);
    } @catch (NSException *exception) { WCLog(@"设置入口：页面同步失败 %@",exception.name); }
    @finally { objc_setAssociatedObject(controller,&WCEntryBusyKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
}
void WCGestureSettingsEntrySettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureSettingsEntryLocationKey] && ![key isEqualToString:WCPluginNameKey]) return;
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ WCGestureSettingsEntrySettingsChanged(key); }); return; }
    WCEntrySyncManager();
    for (UIViewController *controller in WCEntryPages().allObjects) {
        NSNumber *page = objc_getAssociatedObject(controller,&WCEntryPageKey);
        if (page) WCGestureSettingsEntryRefresh(controller,page.integerValue);
    }
    // A manager page may remain under One Wx in the navigation stack. Refresh
    // its cached cells too, so returning does not leave a stale duplicate row.
    NSHashTable *refreshed = [NSHashTable weakObjectsHashTable];
    Class managerPageClass = NSClassFromString(@"WCPluginsViewController");
    SEL reload = NSSelectorFromString(@"reloadTableData");
    for (UIViewController *owner in WCEntryPages().allObjects) {
        for (UIViewController *page in owner.navigationController.viewControllers) {
            if (!managerPageClass || ![page isKindOfClass:managerPageClass] || !page.isViewLoaded || [refreshed containsObject:page]) continue;
            [refreshed addObject:page];
            @try { if ([page respondsToSelector:reload]) ((void (*)(id,SEL))objc_msgSend)(page,reload); }
            @catch (NSException *exception) { WCLog(@"设置入口：管理页刷新失败 %@",exception.name); }
        }
    }
}
void WCGestureRegisterEntry(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            WCGestureSettingsEntrySettingsChanged(nil);
        }];
    });
    dispatch_async(dispatch_get_main_queue(), ^{ WCGestureSettingsEntrySettingsChanged(nil); });
}
