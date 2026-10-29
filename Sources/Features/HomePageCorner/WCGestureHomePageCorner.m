#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

static char WCHomeCornerStateKey, WCHomeCornerGroupSurfaceKey;
static __weak UIViewController *WCHomeCornerController;
static __weak UITableView *WCHomeCornerTable;
static NSHashTable<UIView *> *WCHomeCornerViews;
static BOOL WCHomeCornerLoaded, WCHomeCornerEnabled;
static CGFloat WCHomeCornerRadius, WCHomeCornerInset, WCHomeCornerGap;

static void WCHomeCornerReadSettings(void) {
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    WCHomeCornerEnabled=[d boolForKey:WCGestureEnabledKey] && [d boolForKey:WCGestureHomePageCornerEnabledKey];
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
    if (WCGestureHomePageIsDark(view)) return [UIColor colorWithWhite:surface?0.11:0.04 alpha:1];
    return surface?UIColor.whiteColor:[UIColor colorWithWhite:0.95 alpha:1];
}
CGFloat WCGestureHomePageCornerInset(void) {
    return WCHomeCornerInset;
}
CGFloat WCGestureHomePageCornerGap(void) {
    return WCHomeCornerGap;
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
    NSInteger count=[WCHomeCornerTable numberOfRowsInSection:path.section];
    UIRectCorner corners=(path.row==0?(UIRectCornerTopLeft|UIRectCornerTopRight):0)
        | (path.row==count-1?(UIRectCornerBottomLeft|UIRectCornerBottomRight):0);
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
void WCGestureHomePageCornerLayoutTable(UITableView *table) {
    if (!table || table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return;
    WCHomeCornerColorView(table,WCGestureHomePageCornerColor(table,NO));
    WCHomeCornerHideNativeBackground(table.backgroundView);
    WCHomeCornerState *state=WCHomeCornerStateForView(table);
    if (!state.managesSeparator) { state.separator=table.separatorStyle;state.managesSeparator=YES; }
    table.separatorStyle=UITableViewCellSeparatorStyleNone;
    for (UITableViewCell *cell in table.visibleCells) WCGestureHomePageCornerLayoutCell(cell);
}
void WCGestureHomePageCornerLayoutGroup(UIView *banner, CGFloat nativeHeight, CGFloat height) {
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
    WCHomeCornerMask(surface,UIRectCornerAllCorners);
}
CGFloat WCGestureHomePageCornerHeaderHeight(UITableView *table, NSInteger section, CGFloat original) {
    if (table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled() || section==0 || ![table numberOfRowsInSection:section]) return original;
    BOOL previousContent=NO;
    for (NSInteger previous=0;previous<section;previous++) if ([table numberOfRowsInSection:previous]) { previousContent=YES;break; }
    if (!previousContent) return original;
    return MAX(original,WCHomeCornerGap);
}
UIView *WCGestureHomePageCornerHeaderView(UITableView *table, NSInteger section, UIView *original) {
    if (table!=WCHomeCornerTable || !WCGestureHomePageCornerEnabled()) return original;
    UIView *header=original;
    CGFloat gap=WCGestureHomePageCornerHeaderHeight(table,section,0);
    if (!header && gap>0) header=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,gap)];
    WCHomeCornerColorView(header,WCGestureHomePageCornerColor(table,NO));
    return header;
}
void WCGestureHomePageCornerAttach(UIViewController *controller) {
    UITableView *table=WCTweakSafeValue(controller,@"m_tableView");
    if (![table isKindOfClass:UITableView.class]) return;
    WCHomeCornerController=controller;WCHomeCornerTable=table;
    WCGestureHomePageCornerLayoutTable(table);
}
void WCGestureHomePageCornerSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.home.corner."] && ![key isEqual:WCGestureEnabledKey]
        && ![key isEqual:WCGesturePageScaleEnabledKey] && ![key isEqual:WCGesturePageScalePercentKey]) return;
    WCHomeCornerReadSettings();
    if (!WCHomeCornerController) return;
    for (UIView *view in WCHomeCornerViews.allObjects) WCHomeCornerRestore(view);
    WCGestureHomeGroupsRefreshAppearance();
    [WCHomeCornerTable reloadData];
    WCGestureHomePageCornerLayoutTable(WCHomeCornerTable);
}
void WCGestureHomePageCornerThemeChanged(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        WCGestureHomeGroupsRefreshAppearance();
        [WCHomeCornerTable setNeedsLayout];
        for (UITableViewCell *cell in WCHomeCornerTable.visibleCells) [cell setNeedsLayout];
        WCGestureHomePageCornerLayoutTable(WCHomeCornerTable);
    });
}
