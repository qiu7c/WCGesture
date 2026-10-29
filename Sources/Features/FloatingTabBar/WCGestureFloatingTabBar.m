#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

// Geometry/styles: WeChatX 2.4-5, IMPs 0x3fd0fc, 0x3fce0c.
// Native bar ownership and navigation transitions remain with WeChat.
static char WCFloatStateKey;
static NSHashTable<UITabBar *> *WCFloatBars;
static BOOL WCFloatLoaded;
static struct {
    BOOL enabled, noMask, stereo, glow, longPress, pan, hideDot, hideBadge, hideText;
    NSInteger style, animation;
    CGFloat width, y, height, alpha, maskAlpha, radius;
} WCFloat;

static void WCFloatReadSettings(void) {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    WCFloat.enabled = [d boolForKey:WCGestureEnabledKey] && [d boolForKey:WCGestureFloatingTabBarEnabledKey];
    WCFloat.noMask = [d boolForKey:WCGestureFloatingTabBarNoMaskKey];
    WCFloat.stereo = [d boolForKey:WCGestureFloatingTabBarStereoKey];
    WCFloat.glow = [d boolForKey:WCGestureFloatingTabBarMaskGlowKey];
    WCFloat.longPress = [d boolForKey:WCGestureFloatingTabBarLongPressKey];
    WCFloat.pan = [d boolForKey:WCGestureFloatingTabBarPanKey];
    WCFloat.hideDot = [d boolForKey:WCGestureFloatingTabBarHideDotKey];
    WCFloat.hideBadge = [d boolForKey:WCGestureFloatingTabBarHideBadgeKey];
    WCFloat.hideText = [d boolForKey:WCGestureFloatingTabBarHideTextKey];
    WCFloat.style = [d integerForKey:WCGestureFloatingTabBarStyleKey];
    WCFloat.animation = [d integerForKey:WCGestureFloatingTabBarAnimationKey];
    // Defaults/imports are the external boundary; validate numeric preferences once.
    NSArray *keys = @[WCGestureFloatingTabBarWidthKey, WCGestureFloatingTabBarYKey,
        WCGestureFloatingTabBarHeightKey, WCGestureFloatingTabBarAlphaKey,
        WCGestureFloatingTabBarMaskAlphaKey, WCGestureFloatingTabBarRadiusKey];
    CGFloat *values[] = {&WCFloat.width, &WCFloat.y, &WCFloat.height, &WCFloat.alpha, &WCFloat.maskAlpha, &WCFloat.radius};
    const double minimum[] = {-50,-40,-40,0,0,-50}, maximum[] = {50,40,40,100,100,50}, fallback[] = {-1,-4,12,100,100,-1};
    for (NSUInteger i = 0; i < keys.count; i++) {
        id value = [d objectForKey:keys[i]];
        double number = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback[i];
        *values[i] = isfinite(number) ? MAX(minimum[i], MIN(maximum[i], number)) : fallback[i];
    }
    WCFloatLoaded = YES;
}

@interface WCFloatSurface : UIView
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *selection;
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIVisualEffectView *selectionBlur;
- (CGRect)configureWithCount:(NSUInteger)count index:(NSUInteger)index dark:(BOOL)dark;
@end
@implementation WCFloatSurface
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        _card = [UIView new]; _selection = [UIView new];
        _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:(UIBlurEffectStyle)6]];
        _selectionBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:(UIBlurEffectStyle)7]];
        [self addSubview:_card]; [self addSubview:_selection];
        [_card addSubview:_blur]; [_selection addSubview:_selectionBlur];
        _blur.clipsToBounds = YES; _selectionBlur.clipsToBounds = YES;
    }
    return self;
}
- (CGRect)configureWithCount:(NSUInteger)count index:(NSUInteger)index dark:(BOOL)dark {
    CGFloat scale = WCGestureLayoutScaleFactor();
    CGFloat inset = (30 - WCFloat.width) * scale;
    // Keep a usable item area on narrow windows; normal settings use the source formula.
    inset = MIN(inset, (self.bounds.size.width - count * 24 * scale) / 2);
    CGRect rect = CGRectMake(inset, (WCFloat.y - 12) * scale, self.bounds.size.width - 2 * inset, (WCFloat.height + 58) * scale);
    CGFloat radius = MAX(0, rect.size.height / 2 + WCFloat.radius * scale);
    self.card.frame = rect; self.card.layer.cornerRadius = radius;
    BOOL blurred = WCFloat.style == 1 || (WCFloat.style == 2 && dark);
    self.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    UIColor *base = dark ? [UIColor colorWithRed:.15 green:.16 blue:.15 alpha:1] : [UIColor colorWithWhite:.95 alpha:.98];
    UIColor *mask = dark ? [UIColor colorWithRed:.25 green:.25 blue:.27 alpha:1] : UIColor.whiteColor;
    if (WCFloat.style == 3) {
        NSString *baseKey = dark ? WCGestureFloatingTabBarBackgroundDarkKey : WCGestureFloatingTabBarBackgroundLightKey;
        NSString *otherBase = dark ? WCGestureFloatingTabBarBackgroundLightKey : WCGestureFloatingTabBarBackgroundDarkKey;
        NSString *maskKey = dark ? WCGestureFloatingTabBarMaskDarkKey : WCGestureFloatingTabBarMaskLightKey;
        NSString *otherMask = dark ? WCGestureFloatingTabBarMaskLightKey : WCGestureFloatingTabBarMaskDarkKey;
        base = WCGestureColorForDefaultsKey(baseKey, WCGestureColorForDefaultsKey(otherBase, base));
        mask = WCGestureColorForDefaultsKey(maskKey, WCGestureColorForDefaultsKey(otherMask, mask));
    }
    self.card.backgroundColor = blurred ? UIColor.clearColor : [base colorWithAlphaComponent:CGColorGetAlpha(base.CGColor) * WCFloat.alpha / 100];
    self.blur.hidden = !blurred; self.blur.alpha = WCFloat.alpha / 100;
    self.blur.frame = self.card.bounds; self.blur.layer.cornerRadius = radius;
    self.card.layer.borderWidth = blurred ? .5 : 0;
    self.card.layer.borderColor = [UIColor colorWithWhite:.6 alpha:.2].CGColor;
    self.card.layer.shadowColor = (dark ? UIColor.whiteColor : UIColor.blackColor).CGColor;
    self.card.layer.shadowRadius = 7 * scale;
    self.card.layer.shadowOffset = CGSizeMake(0, WCFloat.stereo ? (dark ? 2 : 4) * scale : 0);
    self.card.layer.shadowOpacity = WCFloat.stereo ? (blurred ? .12 : .15) : 0;
    self.card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.card.bounds cornerRadius:radius].CGPath;
    CGRect selection = CGRectMake(rect.origin.x + rect.size.width / count * index, rect.origin.y, rect.size.width / count, rect.size.height);
    self.selection.frame = CGRectInset(selection, 3 * scale, 3 * scale);
    self.selection.layer.cornerRadius = MAX(0, radius - 3 * scale);
    self.selection.hidden = WCFloat.noMask;
    self.selection.alpha = WCFloat.maskAlpha / 100;
    self.selection.backgroundColor = blurred ? (dark ? UIColor.clearColor : [UIColor colorWithWhite:1 alpha:.25]) : mask;
    self.selectionBlur.hidden = !blurred; self.selectionBlur.alpha = WCFloat.alpha / 100;
    self.selectionBlur.frame = self.selection.bounds;
    self.selectionBlur.layer.cornerRadius = self.selection.layer.cornerRadius;
    self.selection.layer.borderWidth = blurred ? .5 : 0;
    self.selection.layer.borderColor = [UIColor colorWithWhite:1 alpha:.3].CGColor;
    self.selection.layer.shadowColor = (dark ? [UIColor colorWithWhite:1 alpha:.25] : [UIColor colorWithWhite:0 alpha:.12]).CGColor;
    self.selection.layer.shadowOpacity = WCFloat.glow ? 1 : 0;
    self.selection.layer.shadowRadius = 7 * scale;
    self.selection.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.selection.bounds cornerRadius:self.selection.layer.cornerRadius].CGPath;
    return rect;
}
@end

// These snapshots only cover properties this feature changes. Restored before
// each native layout/selection so new native geometry and images remain authoritative.
@interface WCFloatSavedView : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic) BOOL hidden;
@property (nonatomic) CGFloat alpha;
@property (nonatomic) BOOL colored;
@property (nonatomic, strong) UIColor *tint;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIImage *image;
@end
@implementation WCFloatSavedView
@end

@interface WCFloatBarState : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UITabBar *bar;
@property (nonatomic, strong) WCFloatSurface *surface;
@property (nonatomic, strong) NSMapTable<UIView *, WCFloatSavedView *> *saved;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *appearance;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, strong) UILongPressGestureRecognizer *press;
@property (nonatomic, copy) NSArray<UIView *> *items;
@property (nonatomic, copy) NSArray<UIControl *> *buttons;
@property (nonatomic) BOOL inLayout;
@property (nonatomic) BOOL writingAppearance;
@property (nonatomic) BOOL appearanceApplied;
@property (nonatomic) BOOL dragging;
@property (nonatomic) NSUInteger index;
@property (nonatomic) NSUInteger dragIndex;
@property (nonatomic) CGFloat dragOffset;
@property (nonatomic) CGFloat startX;
- (void)pan:(UIPanGestureRecognizer *)gesture;
- (void)press:(UILongPressGestureRecognizer *)gesture;
@end

static WCFloatSavedView *WCFloatRemember(WCFloatBarState *state, UIView *view) {
    if (!view) return nil;
    WCFloatSavedView *existing = [state.saved objectForKey:view];
    if (existing) return existing;
    WCFloatSavedView *saved = [WCFloatSavedView new];
    saved.frame = view.frame; saved.hidden = view.hidden; saved.alpha = view.alpha; saved.tint = view.tintColor;
    if ([view isKindOfClass:UILabel.class]) saved.textColor = ((UILabel *)view).textColor;
    if ([view isKindOfClass:UIImageView.class]) saved.image = ((UIImageView *)view).image;
    [state.saved setObject:saved forKey:view];
    return saved;
}
static void WCFloatRestoreViews(WCFloatBarState *state) {
    for (UIView *view in state.saved) {
        WCFloatSavedView *saved = [state.saved objectForKey:view];
        view.frame = saved.frame;
        // Badge visibility belongs to native unread updates; we only change its frame.
        if (![view isKindOfClass:NSClassFromString(@"MMBadgeView")]) {
            view.hidden = saved.hidden; view.alpha = saved.alpha;
        }
        if (saved.colored) {
            view.tintColor = saved.tint;
            if ([view isKindOfClass:UILabel.class]) ((UILabel *)view).textColor = saved.textColor;
            if ([view isKindOfClass:UIImageView.class]) ((UIImageView *)view).image = saved.image;
        }
    }
    [state.saved removeAllObjects];
}
static WCFloatBarState *WCFloatState(UITabBar *bar, BOOL create) {
    WCFloatBarState *state = objc_getAssociatedObject(bar, &WCFloatStateKey);
    if (!state && create) {
        state = [WCFloatBarState new]; state.bar = bar;
        state.saved = [NSMapTable weakToStrongObjectsMapTable];
        state.appearance = [NSMutableDictionary dictionary];
        state.appearance[NSStringFromSelector(@selector(setBackgroundColor:))] = bar.backgroundColor ?: NSNull.null;
        state.appearance[NSStringFromSelector(@selector(setBarTintColor:))] = bar.barTintColor ?: NSNull.null;
        state.appearance[NSStringFromSelector(@selector(setBackgroundImage:))] = bar.backgroundImage ?: NSNull.null;
        state.appearance[NSStringFromSelector(@selector(setShadowImage:))] = bar.shadowImage ?: NSNull.null;
        state.appearance[NSStringFromSelector(@selector(setStandardAppearance:))] = [bar.standardAppearance copy];
        if (@available(iOS 15.0, *)) state.appearance[@"setScrollEdgeAppearance:"] = [bar.scrollEdgeAppearance copy] ?: NSNull.null;
        objc_setAssociatedObject(bar, &WCFloatStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
static WCFloatBarState *WCFloatStateForView(UIView *view) {
    for (UIView *parent = view.superview; parent; parent = parent.superview)
        if ([parent isKindOfClass:NSClassFromString(@"MMTabBar")]) return WCFloatState((UITabBar *)parent, NO);
    return nil;
}
static void WCFloatRestoreAppearance(WCFloatBarState *state) {
    state.writingAppearance = YES;
    UITabBar *bar = state.bar;
    bar.backgroundColor = [state.appearance[@"setBackgroundColor:"] isEqual:NSNull.null] ? nil : state.appearance[@"setBackgroundColor:"];
    bar.barTintColor = [state.appearance[@"setBarTintColor:"] isEqual:NSNull.null] ? nil : state.appearance[@"setBarTintColor:"];
    bar.backgroundImage = [state.appearance[@"setBackgroundImage:"] isEqual:NSNull.null] ? nil : state.appearance[@"setBackgroundImage:"];
    bar.shadowImage = [state.appearance[@"setShadowImage:"] isEqual:NSNull.null] ? nil : state.appearance[@"setShadowImage:"];
    bar.standardAppearance = state.appearance[@"setStandardAppearance:"];
    if (@available(iOS 15.0, *)) bar.scrollEdgeAppearance = [state.appearance[@"setScrollEdgeAppearance:"] isEqual:NSNull.null] ? nil : state.appearance[@"setScrollEdgeAppearance:"];
    state.writingAppearance = NO;
}

id WCGestureFloatingTabBarAppearance(UITabBar *bar, SEL setter, id value) {
    if (!WCFloatLoaded) WCFloatReadSettings();
    WCFloatBarState *state = WCFloatState(bar, NO);
    if (!state || state.writingAppearance) return value;
    state.appearance[NSStringFromSelector(setter)] = [value conformsToProtocol:@protocol(NSCopying)] ? [value copy] : (value ?: NSNull.null);
    if (!WCFloat.enabled) return value;
    if (setter == @selector(setBackgroundImage:) || setter == @selector(setShadowImage:)) return [UIImage new];
    if (setter == @selector(setStandardAppearance:) || [NSStringFromSelector(setter) isEqualToString:@"setScrollEdgeAppearance:"]) {
        UITabBarAppearance *appearance = value ? [value copy] : [UITabBarAppearance new];
        [appearance configureWithTransparentBackground]; return appearance;
    }
    return UIColor.clearColor;
}

// scrollEdgeAppearance was introduced in iOS 15; install only where the
// actual selector exists instead of making an iOS 14 Logos hook for it.
extern void MSHookMessageEx(Class, SEL, IMP, IMP *);
static void (*WCFloatOriginalScrollEdge)(UITabBar *, SEL, UITabBarAppearance *);
static void WCFloatSetScrollEdge(UITabBar *bar, SEL selector, UITabBarAppearance *appearance) {
    UITabBarAppearance *adjusted = WCGestureFloatingTabBarAppearance(bar, selector, appearance);
    WCFloatOriginalScrollEdge(bar, selector, adjusted);
}
void WCGestureFloatingTabBarInstall(void) {
    if (@available(iOS 15.0, *)) {
        Class cls = NSClassFromString(@"MMTabBar"); SEL selector = @selector(setScrollEdgeAppearance:);
        if (class_getInstanceMethod(cls, selector)) MSHookMessageEx(cls, selector, (IMP)WCFloatSetScrollEdge, (IMP *)&WCFloatOriginalScrollEdge);
    }
}

BOOL WCGestureFloatingTabBarBeginLayout(UITabBar *bar) {
    if (!WCFloatLoaded) WCFloatReadSettings();
    if (!WCFloatBars) WCFloatBars = [NSHashTable weakObjectsHashTable];
    [WCFloatBars addObject:bar];
    WCFloatBarState *state = WCFloatState(bar, WCFloat.enabled);
    if (!state || state.inLayout || (!WCFloat.enabled && !state.surface)) return NO;
    state.inLayout = YES;
    [UIView performWithoutAnimation:^{ WCFloatRestoreViews(state); }];
    if (!WCFloat.enabled) {
        state.dragging = NO;
        [state.surface removeFromSuperview]; state.surface = nil;
        if (state.pan) [bar removeGestureRecognizer:state.pan]; state.pan = nil;
        [state.press.view removeGestureRecognizer:state.press]; state.press = nil;
        WCFloatRestoreAppearance(state);
    }
    return YES;
}

void WCGestureFloatingTabBarPrepareForDisplay(UITabBar *bar) {
    if (!WCFloatLoaded) WCFloatReadSettings();
    if (!WCFloat.enabled || WCFloatState(bar, NO).inLayout) return;
    [UIView performWithoutAnimation:^{
        [bar setNeedsLayout];
        [bar layoutIfNeeded];
    }];
}

void WCGestureFloatingTabBarEndLayout(UITabBar *bar) {
    WCFloatBarState *state = WCFloatState(bar, NO);
    if (!WCFloat.enabled) {
        state.inLayout = NO;
        objc_setAssociatedObject(bar, &WCFloatStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    MMTabBar *native = (MMTabBar *)bar;
    state.items = [native.tabBarItemViews copy];
    if (!state.items.count) { state.surface.hidden = YES; state.inLayout = NO; return; }
    if (!state.surface) {
        state.surface = [[WCFloatSurface alloc] initWithFrame:bar.bounds];
        [bar insertSubview:state.surface atIndex:0];
    }
    state.surface.hidden = NO; state.surface.frame = bar.bounds;
    for (UIView *item in state.items) {
        if ([item isKindOfClass:NSClassFromString(@"MMTabBarItemView")] && [(MMTabBarItemView *)item isSelectedState]) state.index = [state.items indexOfObjectIdenticalTo:item];
    }
    state.index = MIN(state.index, state.items.count - 1);
    CGFloat dragCenter = state.surface.selection.center.x;
    CGRect rect = [state.surface configureWithCount:state.items.count index:state.index dark:WCGestureHomePageIsDark(bar)];
    CGFloat step = rect.size.width / state.items.count, height = MIN(49 * WCGestureLayoutScaleFactor(), rect.size.height);
    if (state.dragging) state.surface.selection.center = CGPointMake(MAX(rect.origin.x + step / 2, MIN(CGRectGetMaxX(rect) - step / 2, dragCenter)), state.surface.selection.center.y);
    NSMutableArray<UIControl *> *buttons = [NSMutableArray array];
    for (UIView *view in bar.subviews) {
        if ([NSStringFromClass(view.class) containsString:@"UIBarBackground"] || view == native.backgroundView) {
            WCFloatRemember(state, view); view.hidden = YES;
        }
        if ([NSStringFromClass(view.class) isEqualToString:@"UITabBarButton"] && [view isKindOfClass:UIControl.class]) [buttons addObject:(UIControl *)view];
    }
    [buttons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) { return a.center.x < b.center.x ? NSOrderedAscending : (a.center.x > b.center.x ? NSOrderedDescending : NSOrderedSame); }];
    state.buttons = buttons;
    // Public UIControls retain native target/actions. Move their hit areas along
    // with the corresponding native item, without reparenting either view.
    if (buttons.count == state.items.count) for (NSUInteger i = 0; i < buttons.count; i++) {
        WCFloatRemember(state, buttons[i]);
        buttons[i].frame = CGRectMake(rect.origin.x + i * step, rect.origin.y + (rect.size.height - height) / 2, step, height);
    }
    for (NSUInteger i = 0; i < state.items.count; i++) {
        UIView *item = state.items[i]; WCFloatRemember(state, item);
        CGRect frame = CGRectMake(rect.origin.x + i * step, rect.origin.y + (rect.size.height - height) / 2, step, height);
        item.frame = [bar convertRect:frame toView:item.superview];
        [item setNeedsLayout];
    }
    if (!state.appearanceApplied) {
        state.writingAppearance = YES;
        bar.backgroundColor = UIColor.clearColor; bar.barTintColor = UIColor.clearColor;
        bar.backgroundImage = [UIImage new]; bar.shadowImage = [UIImage new];
        UITabBarAppearance *appearance = [state.appearance[@"setStandardAppearance:"] copy];
        [appearance configureWithTransparentBackground]; bar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) bar.scrollEdgeAppearance = appearance;
        state.writingAppearance = NO; state.appearanceApplied = YES;
    }
    if (!state.pan) {
        state.pan = [[UIPanGestureRecognizer alloc] initWithTarget:state action:@selector(pan:)];
        state.pan.cancelsTouchesInView = NO; state.pan.delegate = state; [bar addGestureRecognizer:state.pan];
    }
    state.pan.enabled = WCFloat.pan && !WCFloat.noMask;
    if (!state.pan.enabled) state.dragging = NO;
    if (WCFloat.longPress && state.items.count > 1) {
        if (!state.press) {
            state.press = [[UILongPressGestureRecognizer alloc] initWithTarget:state action:@selector(press:)];
            state.press.minimumPressDuration = .5;
        }
        UIView *target = state.buttons.count == state.items.count ? state.buttons[1] : state.items[1];
        if (state.press.view != target) [target addGestureRecognizer:state.press];
    } else { [state.press.view removeGestureRecognizer:state.press]; state.press = nil; }
    state.inLayout = NO;
    for (UIView *item in state.items) WCGestureFloatingTabBarItemLayout(item);
    for (UIView *button in state.buttons) WCGestureFloatingTabBarButtonLayout(button);
}

void WCGestureFloatingTabBarButtonLayout(UIView *button) {
    WCFloatBarState *state = WCFloatStateForView(button);
    if (!WCFloat.enabled || !state.surface || state.inLayout) return;
    for (UIView *view in button.subviews) {
        if ([view isKindOfClass:UILabel.class]) {
            WCFloatRemember(state, view); view.hidden = YES; view.alpha = 0;
        } else if ([view isKindOfClass:UIImageView.class]) {
            WCFloatRemember(state, view);
            CGPoint center = view.center; center.y = CGRectGetMidY(button.bounds); view.center = center;
        }
    }
}

static CGFloat WCFloatContentOffset(CGRect icon, CGRect title, CGRect bounds) {
    CGRect content=CGRectIsNull(title)?icon:CGRectUnion(icon,title);
    return CGRectGetMidY(bounds)-CGRectGetMidY(content);
}

void WCGestureFloatingTabBarItemLayout(UIView *view) {
    WCFloatBarState *state = WCFloatStateForView(view);
    if (!WCFloat.enabled || !state.surface || state.inLayout || ![view isKindOfClass:NSClassFromString(@"MMTabBarItemView")]) return;
    MMTabBarItemView *item = (MMTabBarItemView *)view;
    if (WCFloat.hideText) {
        WCFloatRemember(state, item.textLabel); item.textLabel.hidden = YES; item.textLabel.alpha = 0;
    }
    UIView *icon=item.customIconView;
    if (!icon.superview || icon.hidden || CGRectIsEmpty(icon.bounds)) icon=item.imageView;
    if (icon.superview && !CGRectIsEmpty(icon.bounds)) {
        UILabel *title=item.textLabel;
        BOOL showsTitle=!WCFloat.hideText && title.superview && !title.hidden && title.text.length && !CGRectIsEmpty(title.bounds);
        WCFloatSavedView *iconState=WCFloatRemember(state,icon);
        if (CGRectIsEmpty(iconState.frame)) iconState.frame=icon.frame;
        CGRect iconRect=[icon.superview convertRect:iconState.frame toView:item];
        CGRect titleRect=CGRectNull;
        if (showsTitle) {
            WCFloatSavedView *titleState=WCFloatRemember(state,title);
            if (CGRectIsEmpty(titleState.frame)) titleState.frame=title.frame;
            titleRect=[title.superview convertRect:titleState.frame toView:item];
        }
        CGFloat contentOffset=WCFloatContentOffset(iconRect,titleRect,item.bounds);
        // Always derive placement from native snapshots, so nested layoutIcon /
        // relayoutIconAndBadge callbacks cannot repeatedly add this offset.
        iconRect.origin.x=CGRectGetMidX(item.bounds)-iconRect.size.width/2;
        iconRect.origin.y+=contentOffset;
        if (showsTitle) {
            titleRect.size.width=MIN(titleRect.size.width,item.bounds.size.width);
            titleRect.origin.x=CGRectGetMidX(item.bounds)-titleRect.size.width/2;
        }
        [UIView performWithoutAnimation:^{
            icon.frame=[item convertRect:iconRect toView:icon.superview];
            if (showsTitle) title.frame=[item convertRect:CGRectOffset(titleRect,0,contentOffset) toView:title.superview];
        }];
    }
    NSString *hex = [NSUserDefaults.standardUserDefaults stringForKey:WCGestureFloatingTabBarSelectedColorKey];
    if ([item isSelectedState] && hex.length) {
        UIColor *color = WCGestureColorForDefaultsKey(WCGestureFloatingTabBarSelectedColorKey, item.tintColor);
        WCFloatSavedView *label = WCFloatRemember(state, item.textLabel);
        if (!label.colored) label.textColor = item.textLabel.textColor;
        label.colored = YES; item.textLabel.textColor = color;
        UIView *icons[] = {item.imageView, item.customIconView};
        for (NSUInteger i = 0; i < 2; i++) {
            UIView *icon = icons[i]; if (![icon isKindOfClass:UIImageView.class]) continue;
            WCFloatSavedView *saved = WCFloatRemember(state, icon); UIImageView *image = (UIImageView *)icon;
            if (!saved.colored) { saved.image = image.image; saved.tint = image.tintColor; }
            saved.colored = YES;
            image.image = [image.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]; image.tintColor = color;
        }
    }
    UIView *badge = item.badgeView;
    if (badge) {
        WCFloatSavedView *saved = [state.saved objectForKey:badge];
        CGRect nativeFrame = saved ? saved.frame : badge.frame;
        WCFloatRemember(state, badge); badge.frame = WCGestureFloatingTabBarBadgeFrame(badge, nativeFrame);
    }
}

void WCGestureFloatingTabBarItemWillSelect(UIView *item) {
    WCFloatBarState *state = WCFloatStateForView(item);
    if (!state || state.inLayout) return;
    // A native selected-image update must start with the native rendering mode.
    if ([item isKindOfClass:NSClassFromString(@"MMTabBarItemView")]) {
        MMTabBarItemView *native = (MMTabBarItemView *)item;
        UIView *views[] = {native.imageView, native.customIconView, native.textLabel};
        for (NSUInteger i = 0; i < 3; i++) {
            UIView *view = views[i]; if (!view) continue;
            WCFloatSavedView *saved = [state.saved objectForKey:view];
            if (saved.colored) {
                view.tintColor = saved.tint;
                if ([view isKindOfClass:UIImageView.class]) ((UIImageView *)view).image = saved.image;
                if ([view isKindOfClass:UILabel.class]) ((UILabel *)view).textColor = saved.textColor;
                saved.colored = NO;
            }
        }
    }
}
static void WCFloatAnimateIcon(UIView *icon) {
    if (!icon || WCFloat.animation == 0) return;
    if (WCFloat.animation == 1) {
        icon.transform = CGAffineTransformMakeScale(.75, .75);
        [UIView animateWithDuration:.4 delay:0 usingSpringWithDamping:.5 initialSpringVelocity:1 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{ icon.transform = CGAffineTransformIdentity; } completion:nil];
    } else {
        NSArray *values; NSString *path; NSTimeInterval duration = .45;
        switch (WCFloat.animation) {
            case 2: path = @"transform.rotation.z"; values = @[@0,@(-M_PI/8),@(M_PI/8),@(-M_PI/16),@(M_PI/16),@0]; break;
            case 3: path = @"transform.scale.x"; values = @[@1,@1.25,@0.85,@1.05,@0.95,@1]; break;
            case 4: path = @"transform.scale"; values = @[@1,@1.3,@0.85,@1.05,@0.95]; duration = .5; break;
            default: path = @"transform.translation.y"; values = @[@0,@(-12),@2,@(-4),@0]; break;
        }
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:path];
        animation.values = values; animation.duration = duration;
        if (WCFloat.animation == 2) animation.keyTimes = @[@0,@0.2,@0.4,@0.6,@0.8,@1];
        if (WCFloat.animation == 4) animation.keyTimes = @[@0,@0.3,@0.5,@0.7,@1];
        if (WCFloat.animation == 5) animation.keyTimes = @[@0,@0.3,@0.6,@0.8,@1];
        // Even spacing fixes only the source jelly's six-values/five-keyTimes mismatch.
        [icon.layer addAnimation:animation forKey:@"onewx.floating-tab.selection"];
    }
}

void WCGestureFloatingTabBarItemDidSelect(UIView *item, BOOL selected) {
    WCGestureFloatingTabBarItemLayout(item);
    WCFloatBarState *state = WCFloatStateForView(item);
    if (!selected || !WCFloat.enabled || !state.surface || state.inLayout) return;
    NSUInteger index = [state.items indexOfObjectIdenticalTo:item];
    if (index == NSNotFound) return;
    state.index = index;
    CGRect rect = state.surface.card.frame;
    CGRect target = CGRectInset(CGRectMake(rect.origin.x + rect.size.width / state.items.count * index, rect.origin.y, rect.size.width / state.items.count, rect.size.height), 3 * WCGestureLayoutScaleFactor(), 3 * WCGestureLayoutScaleFactor());
    if (!state.dragging) [UIView animateWithDuration:.3 delay:0 usingSpringWithDamping:.8 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{ state.surface.selection.frame = target; } completion:nil];
    MMTabBarItemView *native = (MMTabBarItemView *)item;
    UIView *icon = native.customIconView && !native.customIconView.hidden ? native.customIconView : native.imageView;
    WCFloatAnimateIcon(icon);
}

CGRect WCGestureFloatingTabBarBadgeFrame(UIView *badge, CGRect frame) {
    if (!WCFloat.enabled) return frame;
    WCFloatBarState *state = WCFloatStateForView(badge);
    if (!state.surface || state.inLayout) return frame;
    WCFloatSavedView *saved = WCFloatRemember(state, badge);
    saved.frame = frame;
    NSString *text = ((MMBadgeView *)badge).badgeLabel.text;
    if (text.length ? WCFloat.hideBadge : WCFloat.hideDot) frame.size = CGSizeZero;
    return frame;
}
UIView *WCGestureFloatingTabBarHitTest(UITabBar *bar, CGPoint point, UIView *original) {
    WCFloatBarState *state = WCFloatState(bar, NO);
    if (!WCFloat.enabled || !state.surface || !state.buttons.count || bar.hidden || bar.alpha < .01) return original;
    CGRect rect = state.surface.card.frame;
    if (!CGRectContainsPoint(CGRectInset(rect, -15, -15), point)) return original;
    NSInteger index = MIN((NSInteger)state.buttons.count - 1, MAX(0, (NSInteger)floor((point.x - rect.origin.x) / rect.size.width * state.buttons.count)));
    return state.buttons[index];
}

@implementation WCFloatBarState
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture != self.pan) return YES;
    CGPoint velocity = [self.pan velocityInView:self.bar];
    return WCFloat.enabled && !WCFloat.noMask && self.buttons.count == self.items.count && self.items.count > 0
        && fabs(velocity.x) > fabs(velocity.y) && CGRectContainsPoint(CGRectInset(self.surface.card.frame, -30, -30), [gesture locationInView:self.bar]);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
- (void)pan:(UIPanGestureRecognizer *)gesture {
    CGFloat x = [gesture locationInView:self.bar].x;
    CGRect rect = self.surface.card.frame;
    CGFloat step = rect.size.width / self.items.count;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.dragging = YES; self.startX = x; self.dragOffset = self.surface.selection.center.x - x;
        self.dragIndex = (NSUInteger)MAX(0, MIN((NSInteger)self.items.count-1, (NSInteger)floor((x-rect.origin.x)/step)));
    } else if (gesture.state == UIGestureRecognizerStateChanged && self.dragging) {
        CGFloat center = MAX(rect.origin.x + step / 2, MIN(CGRectGetMaxX(rect) - step / 2, x + self.dragOffset));
        self.surface.selection.center = CGPointMake(center, self.surface.selection.center.y);
        NSUInteger index = MIN(self.items.count - 1, (NSUInteger)MAX(0, floor((center - rect.origin.x) / step)));
        if (index != self.dragIndex) { self.dragIndex = index; WCPlayConfiguredHaptic(); }
    } else if ((gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) && self.dragging) {
        self.dragging = NO;
        NSUInteger index = self.index;
        if (gesture.state == UIGestureRecognizerStateEnded) {
            CGFloat projected = self.surface.selection.center.x + [gesture velocityInView:self.bar].x * .15;
            NSInteger nearest = (NSInteger)floor((projected - rect.origin.x) / step);
            index = MIN(self.items.count - 1, (NSUInteger)MAX(0, nearest));
            if (index == self.index && fabs(x - self.startX) > step * .15) index = (NSUInteger)MAX(0, MIN((NSInteger)self.items.count - 1, (NSInteger)self.index + (x > self.startX ? 1 : -1)));
            [self.buttons[index] sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        [self.bar setNeedsLayout];
    }
}
- (void)press:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIViewController *settings = WCGestureCreateFloatingTabBarSettingsController();
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [WCRootTopController() presentViewController:navigation animated:YES completion:nil];
}
@end

void WCGestureFloatingTabBarSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.interface.floating-tab."] && ![key isEqual:WCGestureEnabledKey]
        && ![key isEqual:WCGesturePageScaleEnabledKey] && ![key isEqual:WCGesturePageScalePercentKey]) return;
    WCFloatReadSettings();
    for (UITabBar *bar in WCFloatBars.allObjects) [bar setNeedsLayout];
}
void WCGestureFloatingTabBarThemeChanged(void) {
    for (UITabBar *bar in WCFloatBars.allObjects) [bar setNeedsLayout];
}

@interface WCFloatPreviewButton : UIButton
@property (nonatomic, strong) UILabel *badge;
@end
@implementation WCFloatPreviewButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _badge = [UILabel new]; _badge.font = [UIFont systemFontOfSize:10]; _badge.textColor = UIColor.whiteColor;
        _badge.backgroundColor = UIColor.systemRedColor; _badge.textAlignment = NSTextAlignmentCenter; _badge.clipsToBounds = YES;
        [self addSubview:_badge];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat size = 24 * WCGestureLayoutScaleFactor();
    CGRect icon=CGRectMake((self.bounds.size.width-size)/2,0,size,size);
    CGRect title=WCFloat.hideText?CGRectNull:CGRectMake(0,size+2,self.bounds.size.width,14);
    CGFloat offset=WCFloatContentOffset(icon,title,self.bounds);
    self.imageView.frame=CGRectOffset(icon,0,offset);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.titleLabel.hidden = WCFloat.hideText;
    if (!WCFloat.hideText) self.titleLabel.frame=CGRectOffset(title,0,offset);
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    BOOL dot = self.tag == 2;
    self.badge.text = dot ? @"" : @"1";
    self.badge.hidden = (self.tag != 0 && !dot) || (dot ? WCFloat.hideDot : WCFloat.hideBadge);
    CGFloat badgeSize = dot ? 7 : 15;
    self.badge.frame = CGRectMake(CGRectGetMaxX(self.imageView.frame)-2, CGRectGetMinY(self.imageView.frame)-4, badgeSize, badgeSize);
    self.badge.layer.cornerRadius = badgeSize/2;
}
@end

@interface WCFloatPreview : UIView
@property (nonatomic, strong) WCFloatSurface *surface;
@property (nonatomic, copy) NSArray<UIButton *> *buttons;
@property (nonatomic) NSUInteger index;
@end
@implementation WCFloatPreview
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.systemGroupedBackgroundColor;
        _surface = [WCFloatSurface new]; [self addSubview:_surface];
        NSMutableArray *buttons = [NSMutableArray array];
        NSArray *titles = @[@"微信",@"通讯录",@"发现",@"我"], *symbols = @[@"bubble.left.and.bubble.right",@"person.2",@"safari",@"person"];
        for (NSUInteger i = 0; i < titles.count; i++) {
            UIButton *button = [[WCFloatPreviewButton alloc] initWithFrame:CGRectZero]; button.tag = i;
            [button setImage:[UIImage systemImageNamed:symbols[i]] forState:UIControlStateNormal]; [button setTitle:titles[i] forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont systemFontOfSize:10];
            [button addTarget:self action:@selector(selected:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button]; [buttons addObject:button];
        }
        _buttons = buttons;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:WCGestureDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (CGSize)sizeThatFits:(CGSize)size {
    if (!WCFloatLoaded) WCFloatReadSettings();
    return CGSizeMake(size.width, MAX(158, 66 + (WCFloat.y + WCFloat.height + 46) * WCGestureLayoutScaleFactor() + 16));
}
- (void)changed:(NSNotification *)note { WCGestureFloatingTabBarSettingsChanged(note.object); [self setNeedsLayout]; }
- (void)selected:(UIButton *)button { self.index = button.tag; WCFloatAnimateIcon(button.imageView); [self setNeedsLayout]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!WCFloatLoaded) WCFloatReadSettings();
    self.surface.frame = CGRectMake(0, 66, self.bounds.size.width, 84);
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGRect rect = [self.surface configureWithCount:self.buttons.count index:self.index dark:dark];
    for (NSUInteger i = 0; i < self.buttons.count; i++) {
        UIButton *button = self.buttons[i];
        CGRect frame = CGRectMake(rect.origin.x + i * rect.size.width / 4, rect.origin.y + 66, rect.size.width / 4, rect.size.height);
        button.frame = frame;
        UIColor *color = i == self.index ? WCGestureColorForDefaultsKey(WCGestureFloatingTabBarSelectedColorKey, UIColor.systemGreenColor) : UIColor.secondaryLabelColor;
        button.tintColor = color; [button setTitleColor:color forState:UIControlStateNormal];
        [button setNeedsLayout];
    }
}
@end
UIView *WCGestureCreateFloatingTabBarPreview(void) { return [WCFloatPreview new]; }
