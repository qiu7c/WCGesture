#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static char WCHomeCornerStateKey, WCHomeCornerGroupSurfaceKey, WCHomeCornerSearchSurfaceKey;
static __weak UIViewController *WCHomeCornerController;
static __weak UITableView *WCHomeCornerTable;
static __weak UIView *WCHomeCornerSearch;
static NSHashTable<UIView *> *WCHomeCornerViews;
static BOOL WCHomeCornerLoaded, WCHomeCornerEnabled;
static BOOL WCHomeCornerMergePinned;
static CGFloat WCHomeCornerRadius, WCHomeCornerInset, WCHomeCornerGap;

static void WCHomeCornerReadSettings(void) {
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    WCHomeCornerEnabled=[d boolForKey:WCGestureEnabledKey] && [d boolForKey:WCGestureHomePageCornerEnabledKey];
    WCHomeCornerMergePinned=[d boolForKey:WCGestureHomePageCornerMergePinnedKey];
    CGFloat scale=WCGestureLayoutScaleFactor();
    id radiusValue=[d objectForKey:WCGestureHomePageCornerRadiusKey];
    id insetValue=[d objectForKey:WCGestureHomePageCornerInsetKey];
    id gapValue=[d objectForKey:WCGestureHomePageCornerGapKey];
    double radius=[radiusValue isKindOfClass:NSNumber.class]?[radiusValue doubleValue]:16;
    double inset=[insetValue isKindOfClass:NSNumber.class]?[insetValue doubleValue]:16;
    double gap=[gapValue isKindOfClass:NSNumber.class]?[gapValue doubleValue]:8;
    WCHomeCornerRadius=(isfinite(radius)?MAX(0,MIN(48,radius)):16)*scale;
    WCHomeCornerInset=(isfinite(inset)?MAX(0,MIN(32,inset)):16)*scale;
    WCHomeCornerGap=(isfinite(gap)?MAX(0,MIN(24,gap)):8)*scale;
    WCHomeCornerLoaded=YES;
}

@interface WCHomeCornerState : NSObject
@property (nonatomic, strong) UIColor *originalColor;
@property (nonatomic, strong) UIColor *appliedColor;
@property (nonatomic, strong) CALayer *originalMask;
@property (nonatomic, strong) CAShapeLayer *mask;
@property (nonatomic) CGRect maskBounds;
@property (nonatomic) UIRectCorner corners;
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGRect originalFrame;
@property (nonatomic) CGRect appliedFrame;
@property (nonatomic) BOOL managesFrame;
@property (nonatomic) BOOL managesHidden;
@property (nonatomic) BOOL originalHidden;
@property (nonatomic) BOOL managesSeparator;
@property (nonatomic) UITableViewCellSeparatorStyle separator;
@end
@implementation WCHomeCornerState
@end

BOOL WCGestureHomePageCornerEnabled(void) {
    if (!WCHomeCornerLoaded) WCHomeCornerReadSettings();
    return WCHomeCornerEnabled;
}
BOOL WCGestureHomePageIsDark(UIView *view) {
    Class util=NSClassFromString(@"MMDarkModeConfigUtil");
    SEL selector=NSSelectorFromString(@"isDarkMode");
    if ([util respondsToSelector:selector]) return ((BOOL(*)(id,SEL))objc_msgSend)(util,selector);
    return view.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark;
}
UIColor *WCGestureHomePageCornerColor(UIView *view, BOOL surface) {
    if (!surface && !WCGestureHomePageIsDark(view)) return [UIColor colorWithWhite:237.0/255.0 alpha:1];
    if (!surface) {
        // Read the host's current color; never replace its navigation styling.
        id color=WCTweakSafeValue(WCHomeCornerController,@"realNavigationBarBackgroundColor")
            ?: WCTweakSafeValue(WCHomeCornerController,@"navigationBarBackgroundColor");
        if ([color isKindOfClass:UIColor.class]) return color;
    }
    if (WCGestureHomePageIsDark(view)) return [UIColor colorWithWhite:surface?0.11:0.04 alpha:1];
    return surface?UIColor.whiteColor:[UIColor colorWithWhite:237.0/255.0 alpha:1];
}
CGFloat WCGestureHomePageCornerInset(void) {
    return WCHomeCornerInset;
}
CGFloat WCGestureHomePageCornerGap(void) {
    return WCHomeCornerGap;
}
NSInteger WCGestureHomePageCornerMergedSection(UITableView *table) {
    if (!WCGestureHomePageCornerEnabled() || !WCGestureHomeGroupsEnabled()) return NSNotFound;
    // Native homepage sections: auxiliary banners, pinned chats, normal chats.
    id<UITableViewDataSource> source=table.dataSource;
    if (WCHomeCornerMergePinned && [source tableView:table numberOfRowsInSection:1]>0) return 1;
    return [source tableView:table numberOfRowsInSection:0]>0?0:NSNotFound;
}
static WCHomeCornerState *WCHomeCornerStateForView(UIView *view) {
    WCHomeCornerState *state=objc_getAssociatedObject(view,&WCHomeCornerStateKey);
    if (!state) {
        state=[WCHomeCornerState new];
        objc_setAssociatedObject(view,&WCHomeCornerStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!WCHomeCornerViews) WCHomeCornerViews=[NSHashTable weakObjectsHashTable];
        [WCHomeCornerViews addObject:view];
    }
    return state;
}
static void WCHomeCornerColorView(UIView *view, UIColor *color) {
    if (!view) return;
    WCHomeCornerState *state=WCHomeCornerStateForView(view);
    if (!state.appliedColor || ![view.backgroundColor isEqual:state.appliedColor]) state.originalColor=view.backgroundColor;
    state.appliedColor=color;
    if (![view.backgroundColor isEqual:color]) view.backgroundColor=color;
}
static void WCHomeCornerRestore(UIView *view) {
    WCHomeCornerState *state=objc_getAssociatedObject(view,&WCHomeCornerStateKey);
    if (!state) return;
    if (view.layer.mask==state.mask) view.layer.mask=state.originalMask;
    if ([view.backgroundColor isEqual:state.appliedColor]) view.backgroundColor=state.originalColor;
    if (state.managesHidden && view.hidden) view.hidden=state.originalHidden;
    if (state.managesFrame && view.frame.origin.x==state.appliedFrame.origin.x && view.frame.size.width==state.appliedFrame.size.width) {
        CGRect frame=view.frame;frame.origin.x=state.originalFrame.origin.x;frame.size.width=state.originalFrame.size.width;
        view.frame=frame;
    }
    if (state.managesSeparator && [(UITableView *)view separatorStyle]==UITableViewCellSeparatorStyleNone)
        [(UITableView *)view setSeparatorStyle:state.separator];
    objc_setAssociatedObject(view,&WCHomeCornerStateKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void WCHomeCornerHideNativeBackground(UIView *view) {
    if (!view) return;
    WCHomeCornerState *state=WCHomeCornerStateForView(view);
    if (!state.managesHidden) { state.originalHidden=view.hidden;state.managesHidden=YES; }
    view.hidden=YES;
}
static void WCHomeCornerMask(UIView *view, UIRectCorner corners) {
    if (CGRectIsEmpty(view.bounds)) return;
    WCHomeCornerState *state=WCHomeCornerStateForView(view);
    CGFloat radius=WCHomeCornerRadius;
    radius=MIN(radius,MIN(view.bounds.size.width,view.bounds.size.height)/2);
    if (view.layer.mask!=state.mask) state.originalMask=view.layer.mask;
    if (!state.mask) { state.mask=[CAShapeLayer layer];state.mask.fillColor=UIColor.blackColor.CGColor; }
    if (!CGRectEqualToRect(state.maskBounds,view.bounds) || state.corners!=corners || state.radius!=radius || !state.mask.path) {
        [CATransaction begin];[CATransaction setDisableActions:YES];
        state.maskBounds=view.bounds;state.corners=corners;state.radius=radius;
        state.mask.frame=view.bounds;
        state.mask.path=[UIBezierPath bezierPathWithRoundedRect:view.bounds byRoundingCorners:corners cornerRadii:CGSizeMake(radius,radius)].CGPath;
        [CATransaction commit];
    }
    if (view.layer.mask!=state.mask) view.layer.mask=state.mask;
}
static void WCHomeCornerInsetView(UIView *view) {
    CGFloat inset=WCGestureHomePageCornerInset(), width=WCHomeCornerTable.bounds.size.width;
    CGRect frame=view.frame;
    // Apply to full-width native frames, never subtract from our last result.
    if (fabs(frame.origin.x)>0.5 || frame.size.width<width-0.5 || width<=2*inset) return;
    WCHomeCornerState *state=WCHomeCornerStateForView(view);
    if (!state.managesFrame || !CGRectEqualToRect(frame,state.appliedFrame)) state.originalFrame=frame;
    frame.origin.x=inset;frame.size.width=width-2*inset;
    state.managesFrame=YES;state.appliedFrame=frame;
    if (!CGRectEqualToRect(view.frame,frame)) view.frame=frame;
}
void WCGestureHomePageCornerRestoreCell(UITableViewCell *cell) {
    if ([cell isKindOfClass:NSClassFromString(@"NewMainFrameCell")]) {
        WCHomeCornerRestore(WCTweakSafeValue(cell,@"m_backGroundViewOfCell"));
        WCHomeCornerRestore(WCTweakSafeValue(cell,@"m_itemView"));
    }
    WCHomeCornerRestore(cell.backgroundView);WCHomeCornerRestore(cell.contentView);WCHomeCornerRestore(cell);
}
void WCGestureHomePageCornerLayoutCell(UITableViewCell *cell) {
    if (!WCHomeCornerTable || ![cell isDescendantOfView:WCHomeCornerTable]) return;
    if (!WCGestureHomePageCornerEnabled()) { WCGestureHomePageCornerRestoreCell(cell);return; }
    NSIndexPath *path=[WCHomeCornerTable indexPathForCell:cell];
    if (!path) return;
    WCHomeCornerInsetView(cell);
    UIColor *surface=WCGestureHomePageCornerColor(cell,YES);
    WCHomeCornerColorView(cell,surface);WCHomeCornerColorView(cell.contentView,surface);
    if ([cell isKindOfClass:NSClassFromString(@"NewMainFrameCell")]) {
        WCHomeCornerColorView(WCTweakSafeValue(cell,@"m_itemView"),UIColor.clearColor);
        WCHomeCornerHideNativeBackground(WCTweakSafeValue(cell,@"m_backGroundViewOfCell"));
    }
    NSInteger count=[WCHomeCornerTable.dataSource tableView:WCHomeCornerTable numberOfRowsInSection:path.section];
    UIRectCorner corners=(path.row==0?(UIRectCornerTopLeft|UIRectCornerTopRight):0)
        | (path.row==count-1?(UIRectCornerBottomLeft|UIRectCornerBottomRight):0);
    NSInteger merged=WCGestureHomePageCornerMergedSection(WCHomeCornerTable);
    if (merged!=NSNotFound && path.section<=merged)
        corners=path.section==merged && path.row==count-1?(UIRectCornerBottomLeft|UIRectCornerBottomRight):0;
    WCHomeCornerMask(cell,corners);
}
void WCGestureHomePageCornerLayoutChrome(UIView *view) {
    if (!WCGestureHomePageCornerEnabled() || !WCHomeCornerTable || ![view isDescendantOfView:WCHomeCornerTable]) return;
    WCHomeCornerColorView(view,WCGestureHomePageCornerColor(view,YES));
    for (UIView *parent=view.superview;parent && parent!=WCHomeCornerTable;parent=parent.superview) {
        if ([parent isKindOfClass:UITableViewCell.class]) {
            WCGestureHomePageCornerLayoutCell((UITableViewCell *)parent);return;
        }
    }
    WCHomeCornerInsetView(view);WCHomeCornerMask(view,UIRectCornerAllCorners);
}
void WCGestureHomePageCornerLayoutSearch(UIView *view) {
    if (view!=WCHomeCornerSearch || CGRectIsEmpty(view.bounds)) return;
    UIView *surface=objc_getAssociatedObject(view,&WCHomeCornerSearchSurfaceKey);
    UIView *box=WCTweakSafeValue(view,@"searchBoxContainer");
    if (!box) return;
    if (!WCGestureHomePageCornerEnabled() || [WCTweakSafeValue(WCHomeCornerController,@"isSearching") boolValue]) {
        surface.hidden=YES;
        WCHomeCornerRestore(box);WCHomeCornerRestore(view);return;
    }
    // Draw in the outer search bar, outside the native stack's clipping area.
    // Keep native input frames, constraints and placeholder centering intact.
    if (!surface) {
        surface=[UIView new];surface.userInteractionEnabled=NO;
        [view insertSubview:surface atIndex:0];
        objc_setAssociatedObject(view,&WCHomeCornerSearchSurfaceKey,surface,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    surface.hidden=NO;
    WCHomeCornerColorView(view,WCGestureHomePageCornerColor(view,NO));
    WCHomeCornerColorView(box,UIColor.clearColor);
    CGRect cardRect=CGRectInset(WCHomeCornerTable.bounds,WCHomeCornerInset,0);
    CGRect tableRect=[WCHomeCornerTable convertRect:cardRect toView:view];
    CGFloat scale=WCGestureLayoutScaleFactor();
    // Scrolling changes visibility, not the search background's dimensions.
    CGFloat height=40*scale;
    surface.frame=CGRectMake(tableRect.origin.x,CGRectGetMidY(view.bounds)-height/2,tableRect.size.width,height);
    WCHomeCornerColorView(surface,WCGestureHomePageCornerColor(view,YES));
    WCHomeCornerMask(surface,UIRectCornerAllCorners);
}
void WCGestureHomePageCornerLayoutTable(UITableView *table) {
    if (!table || table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return;
    WCHomeCornerColorView(table,WCGestureHomePageCornerColor(table,NO));
    WCHomeCornerHideNativeBackground(table.backgroundView);
    WCHomeCornerState *state=WCHomeCornerStateForView(table);
    if (!state.managesSeparator) { state.separator=table.separatorStyle;state.managesSeparator=YES; }
    if (table.separatorStyle!=UITableViewCellSeparatorStyleNone)
        table.separatorStyle=UITableViewCellSeparatorStyleNone;
    for (UITableViewCell *cell in table.visibleCells) WCGestureHomePageCornerLayoutCell(cell);
}
void WCGestureHomePageCornerLayoutGroup(UIView *banner, CGFloat nativeHeight, CGFloat height, BOOL joined) {
    UIView *surface=objc_getAssociatedObject(banner,&WCHomeCornerGroupSurfaceKey);
    if (!WCGestureHomePageCornerEnabled()) { surface.hidden=YES;return; }
    if (!surface) {
        surface=[UIView new];surface.userInteractionEnabled=NO;
        [banner insertSubview:surface atIndex:0];
        objc_setAssociatedObject(banner,&WCHomeCornerGroupSurfaceKey,surface,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    surface.hidden=NO;
    CGFloat inset=WCGestureHomePageCornerInset();
    surface.frame=CGRectMake(inset,nativeHeight,MAX(0,banner.bounds.size.width-2*inset),height);
    surface.backgroundColor=WCGestureHomePageCornerColor(banner,YES);
    WCHomeCornerMask(surface,joined?(UIRectCornerTopLeft|UIRectCornerTopRight):UIRectCornerAllCorners);
}
CGFloat WCGestureHomePageCornerHeaderHeight(UITableView *table, NSInteger section, CGFloat original) {
    if (table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return original;
    NSInteger merged=WCGestureHomePageCornerMergedSection(table);
    if (merged!=NSNotFound && section<=merged) return 0;
    // Header measurement runs while UITableView builds its row data. Query the
    // data source directly instead of reentering the table's row-data queries.
    id<UITableViewDataSource> source=table.dataSource;
    if (![source tableView:table numberOfRowsInSection:section]) return original;
    BOOL previousContent=NO;
    for (NSInteger previous=0;previous<section;previous++) if ([source tableView:table numberOfRowsInSection:previous]) { previousContent=YES;break; }
    if (!previousContent) return WCGestureHomeGroupsEnabled()?original:MAX(original,WCHomeCornerGap);
    return original;
}
UIView *WCGestureHomePageCornerHeaderView(UITableView *table, NSInteger section, UIView *original) {
    if (table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return original;
    WCHomeCornerColorView(original,WCGestureHomePageCornerColor(table,NO));
    return original;
}
CGFloat WCGestureHomePageCornerFooterHeight(UITableView *table, NSInteger section, CGFloat original) {
    if (table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return original;
    id<UITableViewDataSource> source=table.dataSource;
    if (![source tableView:table numberOfRowsInSection:section]) return original;
    NSInteger merged=WCGestureHomePageCornerMergedSection(table);
    for (NSInteger next=section+1;next<3;next++) {
        if (![source tableView:table numberOfRowsInSection:next]) continue;
        if (merged!=NSNotFound && next<=merged) return 0;
        return MAX(original,WCHomeCornerGap);
    }
    return original;
}
UIView *WCGestureHomePageCornerFooterView(UITableView *table, NSInteger section, UIView *original) {
    if (table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return original;
    CGFloat gap=WCGestureHomePageCornerFooterHeight(table,section,0);
    UIView *footer=original;
    if (!footer && gap>0) footer=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,gap)];
    WCHomeCornerColorView(footer,WCGestureHomePageCornerColor(table,NO));
    return footer;
}
void WCGestureHomePageCornerAttach(UIViewController *controller) {
    UITableView *table=WCTweakSafeValue(controller,@"m_tableView");
    if (![table isKindOfClass:UITableView.class]) return;
    WCHomeCornerController=controller;WCHomeCornerTable=table;
    WCHomeCornerSearch=WCTweakSafeValue(controller,@"searchBar");
    WCGestureHomePageCornerLayoutSearch(WCHomeCornerSearch);
    WCGestureHomePageCornerLayoutTable(table);
}
void WCGestureHomePageCornerSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.home.corner."] && ![key isEqual:WCGestureEnabledKey]
        && ![key isEqual:WCGesturePageScaleEnabledKey] && ![key isEqual:WCGesturePageScalePercentKey]) return;
    WCHomeCornerReadSettings();
    if (!WCHomeCornerController) return;
    for (UIView *view in WCHomeCornerViews.allObjects) WCHomeCornerRestore(view);
    WCGestureHomeGroupsRefreshAppearance();
    WCGestureHomePageCornerAttach(WCHomeCornerController);
    [WCHomeCornerTable reloadData];
    WCGestureHomePageCornerLayoutTable(WCHomeCornerTable);
}
void WCGestureHomePageCornerThemeChanged(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        WCGestureHomeGroupsRefreshAppearance();
        if (WCHomeCornerController) WCGestureHomePageCornerAttach(WCHomeCornerController);
        [WCHomeCornerTable setNeedsLayout];
        for (UITableViewCell *cell in WCHomeCornerTable.visibleCells) [cell setNeedsLayout];
        WCGestureHomePageCornerLayoutTable(WCHomeCornerTable);
    });
}
