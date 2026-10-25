#import <QuartzCore/QuartzCore.h>
#import <math.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Keyboard bottom gesture strip

static void WCKeyboardEnhancePerform(NSString *actionKey) {
    WCInputAction action = (WCInputAction)[[NSUserDefaults standardUserDefaults] integerForKey:actionKey];
    if (action == WCInputActionNone) return;
    MMGrowTextView *view = WCFirstResponderGrowTextView();
    if (!view) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardHapticKey]) WCPlayConfiguredHaptic();
    WCPerformInputAction(view, action);
}

@interface WCKeyboardEnhanceController : NSObject
+ (instancetype)sharedController;
@end

@implementation WCKeyboardEnhanceController

+ (instancetype)sharedController {
    static WCKeyboardEnhanceController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ controller = [WCKeyboardEnhanceController new]; });
    return controller;
}

- (void)handleSwipeLeft:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) WCKeyboardEnhancePerform(WCKeyboardSwipeLeftActionKey);
}

- (void)handleSwipeRight:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) WCKeyboardEnhancePerform(WCKeyboardSwipeRightActionKey);
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) return;
    NSString *key = recognizer.numberOfTapsRequired >= 3 ? WCKeyboardTripleTapActionKey : WCKeyboardDoubleTapActionKey;
    WCKeyboardEnhancePerform(key);
}

// The strip is a dead zone for the keyboard itself, so a long press there
// cannot collide with any system keyboard behavior.
- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        WCKeyboardEnhancePerform(WCKeyboardLongPressActionKey);
    }
}

@end

// The system keyboard lives in UIRemoteKeyboardWindow at level ~10,000,000,
// far above UIWindowLevelAlert (2000). A plain overlay window is therefore
// hidden *behind* the keyboard and never receives touches — which is why the
// strip did nothing. Attaching the strip inside the keyboard window made it
// appear briefly and then vanish when the keyboard re-added its own views, so
// the strip now uses an overlay window whose windowLevel getter returns a level
// above the keyboard (iOS 11+ clamps assignments to the setter, not the getter).
@interface WCKeyboardOverlayWindow : UIWindow
@property (nonatomic, assign) CGFloat wcOverrideLevel;
@end

@implementation WCKeyboardOverlayWindow
- (UIWindowLevel)windowLevel {
    return self.wcOverrideLevel > 0.0 ? (UIWindowLevel)self.wcOverrideLevel : [super windowLevel];
}
@end

static UIWindow *WCKeyboardEnhanceWindow = nil;
static UIView *WCKeyboardEnhanceContainer = nil;
static UIView *WCKeyboardEnhanceView = nil;
// Optional caption drawn inside the strip (a short signature). Non-interactive,
// so it never blocks the strip's gesture recognizers.
static UILabel *WCKeyboardEnhanceSignatureLabel = nil;
// Last attributed caption pushed into the label, so the re-assert timer does
// not rebuild and reassign the same string every tick.
static NSString *WCKeyboardSignatureRenderedText = nil;
static NSInteger WCKeyboardSignatureRenderedFont = -1;
static NSInteger WCKeyboardSignatureRenderedDecoration = -1;
static CGFloat WCKeyboardSignatureRenderedSize = 0.0;
static NSString *WCKeyboardSignatureRenderedColor = nil;
// The debug caption lives at the top of the screen rather than inside the
// strip, so it never hides the band the user is trying to position.
static UIView *WCKeyboardEnhanceHintView = nil;
static UILabel *WCKeyboardEnhanceHintLabel = nil;
static CGRect WCKeyboardEnhanceLastFrame = {0};
static BOOL WCKeyboardEnhanceLastFrameValid = NO;
static NSTimer *WCKeyboardEnhanceReassertTimer = nil;
static __weak UIWindow *WCCapturedKeyboardWindow = nil;
static __weak UIView *WCCapturedKeyboardDockView = nil;
static BOOL WCKeyboardEnhanceDockRejected = NO;

// Strip geometry, measured from the keyboard's bottom edge. Fixed values
// instead of safe-area math so the strip sits at the same height whether the
// dock or the keyboard window hosts it. 键盘小增强 uses bottom 20 / height 40
// for the row it builds inside the dock.
static const CGFloat WCKeyboardEnhanceBandBottomMargin = 14.0;
// Lift above the measured key-row bottom: key frames carry ~6-8pt of padding
// below the visible key caps, so a small overlap is still blank.
static const CGFloat WCKeyboardEnhanceBandRaise = 14.0;
// Third-party keyboards draw their keys right to the frame edge, so the strip
// may only overlap by a couple of points.
static const CGFloat WCKeyboardEnhanceThirdPartyBandRaise = 2.0;
// With the shared (non-separate) geometry set, third-party keyboards need the
// strip raised relative to the system keyboard because their key rows sit at a
// different height. Measured on an iPhone 14 Pro (the 393pt reference width).
static const CGFloat WCKeyboardEnhanceThirdPartyOffsetDelta = 90.0;

// User-tunable geometry (settings → 键盘底部手势). Width 0 = full keyboard width;
// the offsets move the strip from its default spot (positive X = right,
// positive Y = up). Values are in points, tuned on an iPhone 14 Pro (393pt
// wide), and are scaled by the actual keyboard width at layout time so other
// screen sizes keep the same proportions (the factor is 1.0 on the 14 Pro).
//
// Third-party keyboards keep a second set of values: their key rows do not sit
// where the system keyboard's do, so one set cannot fit both.
static const CGFloat WCKeyboardEnhanceReferenceWidth = 393.0;

static CGFloat WCKeyboardEnhanceScale(CGFloat hostWidth) {
    if (hostWidth <= 0.0) return 1.0;
    return hostWidth / WCKeyboardEnhanceReferenceWidth;
}

static NSString *WCKeyboardStripKey(NSString *systemKey, NSString *thirdPartyKey, BOOL thirdParty) {
    return thirdParty ? thirdPartyKey : systemKey;
}

// Third-party keyboards get their own four values only when the user turned on
// 分开调节; otherwise both keyboards share the system set.
static BOOL WCKeyboardEnhanceUsesThirdPartySet(BOOL thirdParty) {
    if (!thirdParty) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardStripSeparateAdjustKey];
}

static CGFloat WCKeyboardEnhanceConfiguredWidth(CGFloat hostWidth, CGFloat scale, BOOL thirdParty) {
    NSString *key = WCKeyboardStripKey(WCKeyboardStripWidthKey, WCKeyboardStripWidthKeyThirdParty,
                                       WCKeyboardEnhanceUsesThirdPartySet(thirdParty));
    CGFloat configured = [[NSUserDefaults standardUserDefaults] doubleForKey:key];
    if (configured <= 0.0) return hostWidth;
    return MIN(configured * scale, hostWidth);
}

static CGFloat WCKeyboardEnhanceConfiguredHeight(CGFloat hostHeight, CGFloat scale, BOOL thirdParty) {
    NSString *key = WCKeyboardStripKey(WCKeyboardStripHeightKey, WCKeyboardStripHeightKeyThirdParty,
                                       WCKeyboardEnhanceUsesThirdPartySet(thirdParty));
    CGFloat configured = [[NSUserDefaults standardUserDefaults] doubleForKey:key] * scale;
    if (configured < 20.0) configured = 20.0;
    if (hostHeight > 0.0 && configured > hostHeight) configured = hostHeight;
    return configured;
}

static CGFloat WCKeyboardEnhanceHorizontalOffset(BOOL thirdParty) {
    NSString *key = WCKeyboardStripKey(WCKeyboardStripOffsetXKey, WCKeyboardStripOffsetXKeyThirdParty,
                                       WCKeyboardEnhanceUsesThirdPartySet(thirdParty));
    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}

static CGFloat WCKeyboardEnhanceVerticalOffset(BOOL thirdParty) {
    BOOL ownSet = WCKeyboardEnhanceUsesThirdPartySet(thirdParty);
    NSString *key = WCKeyboardStripKey(WCKeyboardStripOffsetYKey, WCKeyboardStripOffsetYKeyThirdParty, ownSet);
    CGFloat offset = [[NSUserDefaults standardUserDefaults] doubleForKey:key];
    // Shared set: a third-party keyboard needs a higher band than the system
    // keyboard for the same visual position.
    if (thirdParty && !ownSet) offset += WCKeyboardEnhanceThirdPartyOffsetDelta;
    return offset;
}

static void WCKeyboardEnhanceStartReassertTimer(void);
static void WCKeyboardEnhanceStopReassertTimer(void);
static BOOL WCKeyboardEnhanceApplyInDock(UIView *dock);

// The keyboard window is not always listed in UIApplication/scene windows
// (iOS 16+ hides it), so capture the instance the moment it becomes visible.
static void WCCaptureKeyboardWindow(UIWindow *window) {
    if (![window isKindOfClass:[UIWindow class]]) return;
    if (![NSStringFromClass(window.class) containsString:@"Keyboard"]) return;
    WCCapturedKeyboardWindow = window;
}

static void WCAddInstanceMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    *original = method_getImplementation(method);
    // class_addMethod only succeeds when the class does not implement the
    // selector itself; otherwise modify its own method. Never touch an
    // inherited Method, which would affect every UIView/UIWindow.
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
        method_setImplementation(method, replacement);
    }
}

void WCInstallKeyboardWindowCapture(void) {
    Class cls = NSClassFromString(@"UIRemoteKeyboardWindow");
    if (!cls) return;
    static IMP originalDidMove = NULL;
    static IMP originalSetHidden = NULL;
    if (!originalDidMove) {
        WCAddInstanceMethod(cls, @selector(didMoveToWindow),
                            imp_implementationWithBlock(^(UIWindow *window) {
            ((void (*)(id, SEL))originalDidMove)(window, @selector(didMoveToWindow));
            WCCaptureKeyboardWindow(window);
        }), &originalDidMove);
    }
    if (!originalSetHidden) {
        WCAddInstanceMethod(cls, @selector(setHidden:),
                            imp_implementationWithBlock(^(UIWindow *window, BOOL hidden) {
            ((void (*)(id, SEL, BOOL))originalSetHidden)(window, @selector(setHidden:), hidden);
            if (!hidden) WCCaptureKeyboardWindow(window);
        }), &originalSetHidden);
    }
}

// A dock only counts as a host when the user can actually see it: iOS keeps
// hidden UIKeyboardDockView instances around (iPad dock, hardware-keyboard
// dock), and attaching there makes the strip invisible.
static BOOL WCViewHierarchyVisible(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        if (v.hidden || v.alpha <= 0.01) return NO;
    }
    return YES;
}

// The reliable way to float content over the keyboard (as used by working dock
// tweaks): become a subview of UIKeyboardDockView. The dock is laid out by the
// keyboard itself every time it appears, so the strip rides along and nothing
// can cover or remove it when the keyboard finishes presenting.
void WCInstallKeyboardDockHook(void) {
    Class cls = NSClassFromString(@"UIKeyboardDockView");
    if (!cls) return;
    static IMP originalLayoutSubviews = NULL;
    if (originalLayoutSubviews) return;
    WCAddInstanceMethod(cls, @selector(layoutSubviews),
                        imp_implementationWithBlock(^(UIView *dock) {
        ((void (*)(id, SEL))originalLayoutSubviews)(dock, @selector(layoutSubviews));
        if (dock.window == nil || !WCViewHierarchyVisible(dock)) return;
        WCCapturedKeyboardDockView = dock;
        WCKeyboardEnhanceApplyInDock(dock);
    }), &originalLayoutSubviews);
}

static UIView *WCKeyboardDockViewInWindow(UIWindow *window) {
    if (!window) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([NSStringFromClass(view.class) isEqualToString:@"UIKeyboardDockView"] &&
            WCViewHierarchyVisible(view) && CGRectGetWidth(view.bounds) > 100.0) {
            return view;
        }
        [stack addObjectsFromArray:view.subviews];
    }
    return nil;
}

static UIWindow *WCSystemKeyboardWindow(void) {
    UIWindow *appWindow = WCActiveWindow();
    UIWindow *captured = WCCapturedKeyboardWindow;
    if (captured && !captured.hidden && captured.alpha > 0.0 &&
        CGRectGetHeight(captured.bounds) > 0.0) {
        BOOL sameScene = YES;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *appScene = appWindow.windowScene;
            UIWindowScene *capturedScene = captured.windowScene;
            if (appScene && capturedScene && capturedScene != appScene) sameScene = NO;
        }
        if (sameScene) return captured;
    }
    NSMutableArray<UIWindow *> *candidates = [NSMutableArray array];
    UIWindow *best = nil;
    CGFloat bestLevel = -1.0;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            [candidates addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    id all = WCTweakSafeValue(UIApplication.sharedApplication, @"windows");
    if ([all isKindOfClass:[NSArray class]]) [candidates addObjectsFromArray:(NSArray *)all];
    for (UIWindow *window in candidates) {
        if (![window isKindOfClass:[UIWindow class]]) continue;
        if (![NSStringFromClass(window.class) containsString:@"Keyboard"]) continue;
        if (window.windowLevel < UIWindowLevelAlert) continue;
        // Skip stale, torn-down keyboard windows: only a visible, laid-out
        // window can be the one the user is typing on.
        if (window.hidden || window.alpha <= 0.0) continue;
        if (CGRectGetHeight(window.bounds) <= 0.0) continue;
        if (window.windowLevel >= bestLevel) { best = window; bestLevel = window.windowLevel; }
    }
    return best;
}

// The debug caption sits at the top of the app window (under the status bar),
// so it never covers the strip while its geometry is being tuned.
static void WCKeyboardEnhanceHideHint(void) {
    WCKeyboardEnhanceHintView.hidden = YES;
}

void WCKeyboardEnhanceHide(void) {
    WCKeyboardEnhanceLastFrameValid = NO;
    WCKeyboardEnhanceStopReassertTimer();
    WCKeyboardEnhanceView.hidden = YES;
    WCKeyboardEnhanceWindow.hidden = YES;
    WCKeyboardEnhanceHideHint();
}

static void WCKeyboardEnhanceEnsureView(void) {
    if (WCKeyboardEnhanceView) return;
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = UIColor.clearColor;
    view.clipsToBounds = NO;
    // The keyboard's own content can be re-added above our strip when the
    // keyboard finishes presenting. zPosition is independent of subview
    // order, so the strip stays rendered on top.
    view.layer.zPosition = 10000.0;

    WCKeyboardEnhanceController *controller = [WCKeyboardEnhanceController sharedController];
    UISwipeGestureRecognizer *left = [[UISwipeGestureRecognizer alloc] initWithTarget:controller action:@selector(handleSwipeLeft:)];
    left.direction = UISwipeGestureRecognizerDirectionLeft;
    left.cancelsTouchesInView = NO;
    [view addGestureRecognizer:left];
    UISwipeGestureRecognizer *right = [[UISwipeGestureRecognizer alloc] initWithTarget:controller action:@selector(handleSwipeRight:)];
    right.direction = UISwipeGestureRecognizerDirectionRight;
    right.cancelsTouchesInView = NO;
    [view addGestureRecognizer:right];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(handleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.cancelsTouchesInView = NO;
    [view addGestureRecognizer:doubleTap];
    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(handleTap:)];
    tripleTap.numberOfTapsRequired = 3;
    tripleTap.cancelsTouchesInView = NO;
    [view addGestureRecognizer:tripleTap];
    [doubleTap requireGestureRecognizerToFail:tripleTap];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
        initWithTarget:controller action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.45;
    longPress.allowableMovement = 12.0;
    longPress.cancelsTouchesInView = NO;
    [view addGestureRecognizer:longPress];

    UILabel *signature = [[UILabel alloc] initWithFrame:CGRectZero];
    signature.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    signature.textColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
    signature.textAlignment = NSTextAlignmentCenter;
    signature.numberOfLines = 1;
    signature.adjustsFontSizeToFitWidth = YES;
    signature.minimumScaleFactor = 0.5;
    signature.userInteractionEnabled = NO;
    signature.hidden = YES;
    signature.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view addSubview:signature];
    WCKeyboardEnhanceSignatureLabel = signature;

    WCKeyboardEnhanceView = view;
}

// iOS ships several Chinese faces; `fontWithName:` accepts the family or the
// PostScript name, so try both and fall back to the system font when a face is
// missing (e.g. on a non-Chinese device).
static UIFont *WCKeyboardSignatureNamedFont(NSArray<NSString *> *names, CGFloat size) {
    for (NSString *name in names) {
        UIFont *font = [UIFont fontWithName:name size:size];
        if (font) return font;
    }
    return nil;
}

static UIFont *WCKeyboardSignatureFont(CGFloat size, NSInteger face) {
    UIFont *named = nil;
    switch (face) {
        case WCKeyboardSignatureFontKaiti:
            named = WCKeyboardSignatureNamedFont(@[@"Kaiti SC", @"KaitiSC-Regular", @"STKaiti"], size);
            break;
        case WCKeyboardSignatureFontXingkai:
            named = WCKeyboardSignatureNamedFont(@[@"Xingkai SC", @"XingkaiSC-Regular", @"STXingkai"], size);
            break;
        case WCKeyboardSignatureFontSongti:
            named = WCKeyboardSignatureNamedFont(@[@"Songti SC", @"SongtiSC-Regular", @"STSongti-SC-Regular"], size);
            break;
        case WCKeyboardSignatureFontYuanti:
            named = WCKeyboardSignatureNamedFont(@[@"Yuanti SC", @"YuantiSC-Regular", @"STYuanti-SC-Regular"], size);
            break;
        case WCKeyboardSignatureFontHannotate:
            named = WCKeyboardSignatureNamedFont(@[@"Hannotate SC", @"HannotateSC-W5", @"HanziPen SC", @"HanziPenSC-W3"], size);
            break;
        case WCKeyboardSignatureFontWawati:
            named = WCKeyboardSignatureNamedFont(@[@"Wawati SC", @"WawatiSC-Regular"], size);
            break;
        default:
            break;
    }
    if (named) return named;
    UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    if (@available(iOS 13.0, *)) {
        // Latin-only fallback with the same flavor as the missing CJK face.
        UIFontDescriptorSystemDesign design = nil;
        if (face == WCKeyboardSignatureFontYuanti) {
            design = UIFontDescriptorSystemDesignRounded;
        } else if (face == WCKeyboardSignatureFontSongti) {
            design = UIFontDescriptorSystemDesignSerif;
        }
        if (design) {
            UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithDesign:design];
            if (descriptor) font = [UIFont fontWithDescriptor:descriptor size:size];
        }
    }
    return font;
}

// "#RRGGBB" → UIColor. Anything malformed returns nil so the default color is
// used instead of rendering the caption invisible.
static UIColor *WCKeyboardSignatureColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    NSString *value = [hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([value hasPrefix:@"#"]) value = [value substringFromIndex:1];
    if (value.length != 6) return nil;
    NSScanner *scanner = [NSScanner scannerWithString:value];
    unsigned int rgb = 0;
    if (![scanner scanHexInt:&rgb] || !scanner.isAtEnd) return nil;
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:0.85];
}

static UIColor *WCKeyboardSignatureColor(void) {
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:WCKeyboardSignatureColorKey];
    return WCKeyboardSignatureColorFromHex(hex) ?: [UIColor.labelColor colorWithAlphaComponent:0.5];
}

// Signature text is user-supplied and may be empty: then the label stays
// hidden. `scale` follows the keyboard width so the type keeps its relative
// size on other screens.
static void WCKeyboardEnhanceUpdateSignature(CGFloat scale) {
    UILabel *label = WCKeyboardEnhanceSignatureLabel;
    if (!label) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = [defaults stringForKey:WCKeyboardSignatureTextKey] ?: @"";
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0) {
        if (!label.hidden) label.hidden = YES;
        return;
    }
    NSInteger face = [defaults integerForKey:WCKeyboardSignatureFontKey];
    NSInteger decoration = [defaults integerForKey:WCKeyboardSignatureDecorationKey];
    CGFloat size = [defaults doubleForKey:WCKeyboardSignatureSizeKey];
    if (size < 6.0) size = 6.0;
    size *= (scale > 0.0 ? scale : 1.0);

    // Ornament styles wrap the user's words in marks that every CJK font
    // covers, so nothing renders as a missing-glyph box.
    NSString *display = text;
    switch (decoration) {
        case WCKeyboardSignatureDecorationDivider:
            display = [NSString stringWithFormat:@"— %@ —", text];
            break;
        case WCKeyboardSignatureDecorationDiamond:
            display = [NSString stringWithFormat:@"◇ %@ ◇", text];
            break;
        case WCKeyboardSignatureDecorationDot:
            display = [NSString stringWithFormat:@"· %@ ·", text];
            break;
        case WCKeyboardSignatureDecorationStar:
            display = [NSString stringWithFormat:@"✦ %@ ✦", text];
            break;
        case WCKeyboardSignatureDecorationQuote:
            display = [NSString stringWithFormat:@"「%@」", text];
            break;
        default:
            break;
    }

    NSString *colorHex = [defaults stringForKey:WCKeyboardSignatureColorKey] ?: @"";
    BOOL unchanged = [WCKeyboardSignatureRenderedText isEqualToString:display]
        && WCKeyboardSignatureRenderedFont == face
        && WCKeyboardSignatureRenderedDecoration == decoration
        && fabs(WCKeyboardSignatureRenderedSize - size) < 0.1
        && [WCKeyboardSignatureRenderedColor isEqualToString:colorHex];
    if (!unchanged) {
        UIColor *color = WCKeyboardSignatureColor();
        NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:display];
        NSRange range = NSMakeRange(0, display.length);
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = NSTextAlignmentCenter;
        paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
        [attributed addAttribute:NSParagraphStyleAttributeName value:paragraph range:range];
        [attributed addAttribute:NSFontAttributeName value:WCKeyboardSignatureFont(size, face) range:range];
        [attributed addAttribute:NSForegroundColorAttributeName value:color range:range];
        if (decoration == WCKeyboardSignatureDecorationSpaced) {
            [attributed addAttribute:NSKernAttributeName
                               value:@(MAX(1.0, size * 0.12)) range:range];
        } else if (decoration == WCKeyboardSignatureDecorationOutline) {
            // Negative width fills and strokes; a clear fill leaves a hollow,
            // engraved-looking glyph.
            [attributed addAttribute:NSStrokeWidthAttributeName value:@(-2.0) range:range];
            [attributed addAttribute:NSStrokeColorAttributeName value:color range:range];
            [attributed addAttribute:NSForegroundColorAttributeName value:UIColor.clearColor range:range];
        }
        label.attributedText = attributed;
        WCKeyboardSignatureRenderedText = display;
        WCKeyboardSignatureRenderedFont = face;
        WCKeyboardSignatureRenderedDecoration = decoration;
        WCKeyboardSignatureRenderedSize = size;
        WCKeyboardSignatureRenderedColor = colorHex;
    }

    // Keep the caption filling the strip so adjustsFontSizeToFitWidth has a
    // width to work with; the fine position offsets move the centered text
    // without changing its layout width. Positive Y = up, like the strip.
    // Compare bounds, not frame: the translation below makes frame differ from
    // the host even when the layout already matches.
    UIView *host = label.superview;
    if (host && !CGRectEqualToRect(label.bounds, host.bounds)) {
        label.transform = CGAffineTransformIdentity;
        label.frame = host.bounds;
    }
    CGFloat offsetX = [defaults doubleForKey:WCKeyboardSignatureOffsetXKey];
    CGFloat offsetY = [defaults doubleForKey:WCKeyboardSignatureOffsetYKey];
    offsetX = MAX(-60.0, MIN(60.0, offsetX));
    offsetY = MAX(-60.0, MIN(60.0, offsetY));
    label.transform = CGAffineTransformMakeTranslation(offsetX, -offsetY);
    if (label.hidden) label.hidden = NO;
}

static void WCKeyboardEnhanceUpdateDebugStyle(BOOL debug) {
    if (!WCKeyboardEnhanceView) return;
    // Touching CALayer/UIView appearance on every re-assert makes the
    // translucent debug band flash. Only write these when the state changed.
    if (WCKeyboardEnhanceView.layer.borderWidth != (debug ? 1.0 : 0.0)) {
        WCKeyboardEnhanceView.backgroundColor = debug
            ? [UIColor.systemRedColor colorWithAlphaComponent:0.35] : UIColor.clearColor;
        WCKeyboardEnhanceView.layer.borderWidth = debug ? 1.0 : 0.0;
        WCKeyboardEnhanceView.layer.borderColor = debug
            ? UIColor.systemRedColor.CGColor : UIColor.clearColor.CGColor;
    }
    // The caption is shown at the top of the screen, not inside the strip, and
    // follows the "显示触发范围" switch.
    if (!debug) WCKeyboardEnhanceHideHint();
}

static void WCKeyboardEnhanceSetDebugText(NSString *text) {
    BOOL debug = [[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardDebugFrameKey];
    if (!debug) { WCKeyboardEnhanceHideHint(); return; }
    UIWindow *window = WCActiveWindow();
    if (!window) return;
    if (!WCKeyboardEnhanceHintView) {
        UIView *box = [[UIView alloc] initWithFrame:CGRectZero];
        box.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
        box.layer.cornerRadius = 10.0;
        box.layer.zPosition = 10000.0;
        box.userInteractionEnabled = NO;
        box.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [box addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:10.0],
            [label.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-10.0],
            [label.topAnchor constraintEqualToAnchor:box.topAnchor constant:5.0],
            [label.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-5.0],
        ]];
        WCKeyboardEnhanceHintView = box;
        WCKeyboardEnhanceHintLabel = label;
    }
    if (WCKeyboardEnhanceHintView.superview != window) {
        [WCKeyboardEnhanceHintView removeFromSuperview];
        [window addSubview:WCKeyboardEnhanceHintView];
        [NSLayoutConstraint activateConstraints:@[
            [WCKeyboardEnhanceHintView.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
            [WCKeyboardEnhanceHintView.topAnchor
                constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:6.0],
        ]];
    }
    if (![WCKeyboardEnhanceHintLabel.text isEqualToString:text]) {
        WCKeyboardEnhanceHintLabel.text = text;
    }
    WCKeyboardEnhanceHintView.hidden = NO;
}

// The strip should sit right under the keyboard's key rows: as high as it can
// without covering a key, and as thick as fits in the blank band that is left.
// Keys are individual UIKBKeyView instances; container views (key planes) span
// the whole keyboard and would give a useless answer.
static BOOL WCViewIsSystemKeyboardKey(UIView *view) {
    Class keyView = NSClassFromString(@"UIKBKeyView");
    if (keyView && [view isKindOfClass:keyView]) return YES;
    Class keyButton = NSClassFromString(@"UIKBKeyButton");
    if (keyButton && [view isKindOfClass:keyButton]) return YES;
    // Name check restricted to UIKit's own keyboard classes: third-party
    // keyboards often name their views "...KeyView" too.
    NSString *className = NSStringFromClass(view.class);
    if (![className hasPrefix:@"UIKB"]) return NO;
    return [className containsString:@"KeyView"] || [className containsString:@"KeyButton"];
}

// Third-party keyboards (搜狗/百度/讯飞…) do not use UIKBKeyView at all, so
// matching class names alone found no key and the strip fell back to the window
// bottom — which made it sit lower than with the system keyboard. Their keys
// are ordinary controls, so fall back to those, but only when the system keys
// are absent (so the system keyboard keeps its exact current placement) and
// only for key-sized controls (a full-bleed background control would otherwise
// drag the strip to the bottom edge).
static CGFloat WCKeyboardEnhanceLowestKeyBottom(UIView *host, UIView *scanRoot, BOOL *systemKeyOut) {
    if (!host || !scanRoot) return 0.0;
    CGFloat systemLowest = 0.0;
    CGFloat controlLowest = 0.0;
    CGFloat hostWidth = CGRectGetWidth(host.bounds);
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:scanRoot];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (view.hidden || view.alpha <= 0.01) continue;
        BOOL isSystemKey = WCViewIsSystemKeyboardKey(view);
        if (!CGRectIsEmpty(view.bounds) && (isSystemKey || [view isKindOfClass:[UIControl class]])) {
            CGRect rect = [view convertRect:view.bounds toView:host];
            CGFloat w = CGRectGetWidth(rect);
            CGFloat h = CGRectGetHeight(rect);
            if (w > 12.0 && h > 12.0) {
                if (isSystemKey) {
                    systemLowest = MAX(systemLowest, CGRectGetMaxY(rect));
                } else if (h <= 90.0 && w <= hostWidth * 0.95) {
                    controlLowest = MAX(controlLowest, CGRectGetMaxY(rect));
                }
            }
        }
        [stack addObjectsFromArray:view.subviews];
    }
    if (systemLowest > 0.0) {
        if (systemKeyOut) *systemKeyOut = YES;
        return systemLowest;
    }
    if (systemKeyOut) *systemKeyOut = NO;
    return controlLowest;
}

// Geometry of the strip inside `host` (dock or keyboard window). Placed right
// below the lowest visible key when that can be measured; otherwise anchored to
// the bottom edge using the shared constants. `scanRoot` is the keyboard window
// to look for keys in (the dock may only cover part of it).
static CGRect WCKeyboardEnhanceStripFrame(UIView *host, UIView *scanRoot,
                                          CGFloat *keyBottomOut, BOOL *thirdPartyOut) {
    CGFloat height = CGRectGetHeight(host.bounds);
    CGFloat width = CGRectGetWidth(host.bounds);
    BOOL systemKey = NO;
    CGFloat keyBottom = WCKeyboardEnhanceLowestKeyBottom(host, scanRoot, &systemKey);
    // No system key views anywhere means a third-party keyboard (or a layout
    // UIKit renders differently); pick that keyboard's own geometry set. The
    // system keyboard always exposes UIKBKeyView, so this is safe.
    BOOL thirdParty = !systemKey;
    if (keyBottomOut) *keyBottomOut = keyBottom;
    if (thirdPartyOut) *thirdPartyOut = thirdParty;
    CGFloat scale = WCKeyboardEnhanceScale(width);
    CGFloat band = WCKeyboardEnhanceConfiguredHeight(height, scale, thirdParty);

    CGFloat top = MAX(0.0, height - WCKeyboardEnhanceBandBottomMargin - band);
    if (keyBottom > 0.0 && keyBottom <= height + 1.0) {
        // Start at the measured key-row bottom, lifted by the padding overlap.
        // Third-party key views have no padding below their caps, so only a
        // hair of overlap is safe there.
        CGFloat raise = systemKey ? WCKeyboardEnhanceBandRaise : WCKeyboardEnhanceThirdPartyBandRaise;
        CGFloat raisedTop = keyBottom - raise;
        if (raisedTop >= 0.0) top = raisedTop;
    }
    top -= WCKeyboardEnhanceVerticalOffset(thirdParty) * scale;
    if (top < 0.0) top = 0.0;
    if (top + band > height - 4.0) top = MAX(0.0, height - 4.0 - band);

    CGFloat stripWidth = WCKeyboardEnhanceConfiguredWidth(width, scale, thirdParty);
    CGFloat x = (width - stripWidth) / 2.0 + WCKeyboardEnhanceHorizontalOffset(thirdParty) * scale;
    if (x < 0.0) x = 0.0;
    if (x + stripWidth > width) x = MAX(0.0, width - stripWidth);
    return CGRectMake(x, top, stripWidth, band);
}

// Dock-hosted variant (0x4da4 in 键盘小增强): the strip lives in the keyboard's
// bottom dock row, so the system's own layout keeps it on screen. Geometry is
// the same bottom safe-area band, expressed in dock coordinates.
static BOOL WCKeyboardEnhanceApplyInDock(UIView *dock) {
    if (!dock || dock.window == nil) return NO;
    // LastFrameValid is cleared by UIKeyboardWillHideNotification, which is
    // what keeps the dismissing keyboard from flashing the strip back in.
    if (!WCKeyboardEnhanceLastFrameValid) return NO;
    if (!WCGestureEnabled(WCKeyboardEnhanceEnabledKey)) { WCKeyboardEnhanceHide(); return YES; }

    UIWindow *appWindow = WCActiveWindow();
    CGFloat safeBottom = dock.window.safeAreaInsets.bottom;
    if (appWindow) safeBottom = MAX(safeBottom, appWindow.safeAreaInsets.bottom);
    if (safeBottom <= 0.0) return NO;
    CGFloat dockHeight = CGRectGetHeight(dock.bounds);
    // If the dock is not tall enough to contain the bottom safe-area band, it
    // does not cover the blank strip under the globe/mic keys. Leave the work
    // to the keyboard-window fallback so we never sit on top of the keys.
    if (dockHeight <= safeBottom) return NO;
    // The band math below assumes the dock's bottom edge is the keyboard's
    // bottom edge. Some builds place the dock above the safe-area band; if so,
    // our coordinates would drift up into the key row, so fall back instead.
    CGRect dockInWindow = [dock convertRect:dock.bounds toView:dock.window];
    CGFloat windowHeight = CGRectGetHeight(dock.window.bounds);
    CGFloat bottomDelta = CGRectGetMaxY(dockInWindow) - windowHeight;
    if (bottomDelta < -1.0 || bottomDelta > 1.0) return NO;
    if (!WCViewHierarchyVisible(dock)) return NO;
    if (CGRectGetWidth(dock.bounds) < 100.0) return NO;
    // Never host inside a dock that belongs to a *different* keyboard window
    // (e.g. an inactive or lower-level one), or the strip renders off-screen.
    UIWindow *topKeyboardWindow = WCSystemKeyboardWindow();
    if (topKeyboardWindow && dock.window != topKeyboardWindow) return NO;

    WCKeyboardEnhanceEnsureView();
    BOOL debug = [[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardDebugFrameKey];
    WCKeyboardEnhanceUpdateDebugStyle(debug);

    if (WCKeyboardEnhanceView.superview != dock) {
        [WCKeyboardEnhanceView removeFromSuperview];
        [dock addSubview:WCKeyboardEnhanceView];
    }
    WCCapturedKeyboardDockView = dock;

    CGFloat keyBottom = 0.0;
    BOOL thirdParty = NO;
    CGRect target = WCKeyboardEnhanceStripFrame(dock, dock.window, &keyBottom, &thirdParty);
    if (!CGRectEqualToRect(WCKeyboardEnhanceView.frame, target)) {
        WCKeyboardEnhanceView.frame = target;
    }
    WCKeyboardEnhanceUpdateSignature(WCKeyboardEnhanceScale(CGRectGetWidth(dock.bounds)));

    if (WCKeyboardEnhanceView.hidden) WCKeyboardEnhanceView.hidden = NO;
    if (!WCKeyboardEnhanceWindow.hidden) WCKeyboardEnhanceWindow.hidden = YES;
    // Final safety net: if the dock or one of its ancestors turns out to be
    // invisible, hand the strip back to WCKeyboardEnhanceApply, which falls
    // back to the keyboard window instead of leaving an invisible strip.
    if (WCKeyboardEnhanceView.window == nil || !WCViewHierarchyVisible(WCKeyboardEnhanceView)) {
        [WCKeyboardEnhanceView removeFromSuperview];
        return NO;
    }
    WCKeyboardEnhanceSetDebugText([NSString stringWithFormat:@"触控区 %.0f×%.0f D %.0f 键%.0f%@",
                                   CGRectGetWidth(target), CGRectGetHeight(target), dockHeight,
                                   keyBottom, thirdParty ? @" 三" : @""]);
    WCKeyboardEnhanceStartReassertTimer();
    return YES;
}

// The strip sits in the blank band at the bottom of the keyboard (between the
// globe and mic keys, above the home indicator), i.e. the keyboard's bottom
// safe-area. It never covers any key.
static void WCKeyboardEnhanceApply(CGRect keyboardFrame) {
    if (!WCGestureEnabled(WCKeyboardEnhanceEnabledKey)) { WCKeyboardEnhanceHide(); return; }
    UIWindow *appWindow = WCActiveWindow();
    if (!appWindow) { WCKeyboardEnhanceHide(); return; }

    UIWindow *keyboardWindow = WCSystemKeyboardWindow();
    CGFloat safeBottom = appWindow.safeAreaInsets.bottom;
    if (keyboardWindow) {
        safeBottom = MAX(safeBottom, keyboardWindow.safeAreaInsets.bottom);
    }
    if (safeBottom <= 0.0 && appWindow.safeAreaInsets.top > 20.0) safeBottom = 34.0;
    if (safeBottom <= 0.0) { WCKeyboardEnhanceHide(); return; }

    CGFloat screenHeight = appWindow.bounds.size.height;
    if (@available(iOS 13.0, *)) {
        if (appWindow.windowScene) {
            screenHeight = MAX(screenHeight, appWindow.windowScene.screen.bounds.size.height);
        }
    }
    if (CGRectGetMinY(keyboardFrame) >= screenHeight - 1.0) { WCKeyboardEnhanceHide(); return; }

    WCKeyboardEnhanceEnsureView();
    BOOL debug = [[NSUserDefaults standardUserDefaults] boolForKey:WCKeyboardDebugFrameKey];
    WCKeyboardEnhanceUpdateDebugStyle(debug);

    // The band sits in the blank strip under the keyboard's key rows. Both
    // hosts share WCKeyboardEnhanceStripFrame, so the strip does not jump when
    // the host changes.

    // Prefer the keyboard's own dock view; fall back to the keyboard window
    // only when this iOS build has no reachable dock (e.g. hardware keyboard).
    UIView *dock = WCCapturedKeyboardDockView;
    if (!dock || !dock.window) {
        // Class lookup can fail at launch if UIKit loads the dock lazily.
        WCInstallKeyboardDockHook();
        dock = WCKeyboardDockViewInWindow(keyboardWindow);
    }
    if (dock && dock.window && WCKeyboardEnhanceApplyInDock(dock)) return;
    WCKeyboardEnhanceDockRejected = (dock != nil);

    if (keyboardWindow) {
        // ApplyInDock declined to host the strip (geometry guard), so take it
        // back out of any dock before positioning it in window coordinates.
        UIView *host = WCKeyboardEnhanceView.superview;
        Class dockClass = NSClassFromString(@"UIKeyboardDockView");
        if (host && dockClass && [host isKindOfClass:dockClass] && host != keyboardWindow) {
            [WCKeyboardEnhanceView removeFromSuperview];
        }
        // Live inside the keyboard window, which is above every normal window.
        // Only re-parent when the strip is not in that window at all: comparing
        // superviews reparented it whenever the keyboard adopted it into one of
        // its containers, which made the strip blink. zPosition already keeps
        // it above the keyboard's own subviews, so never re-front it here.
        if (WCKeyboardEnhanceView.window != keyboardWindow &&
            WCKeyboardEnhanceView.superview != keyboardWindow) {
            [WCKeyboardEnhanceView removeFromSuperview];
            [keyboardWindow addSubview:WCKeyboardEnhanceView];
        }
        CGRect kb = keyboardWindow.bounds;
        CGFloat keyBottom = 0.0;
        BOOL thirdParty = NO;
        CGRect target = WCKeyboardEnhanceStripFrame(keyboardWindow, keyboardWindow, &keyBottom, &thirdParty);
        if (!CGRectEqualToRect(WCKeyboardEnhanceView.frame, target)) {
            WCKeyboardEnhanceView.frame = target;
        }
        WCKeyboardEnhanceUpdateSignature(WCKeyboardEnhanceScale(CGRectGetWidth(keyboardWindow.bounds)));
        WCKeyboardEnhanceWindow.hidden = YES;
        NSString *labelText = [NSString stringWithFormat:@"触控区 %.0f×%.0f K %.0f 键%.0f%@%@",
                               CGRectGetWidth(kb), CGRectGetHeight(target),
                               keyboardWindow.windowLevel, keyBottom,
                               WCKeyboardEnhanceDockRejected ? @" dock×" : @"",
                               thirdParty ? @" 三" : @""];
        WCKeyboardEnhanceSetDebugText(labelText);
    } else {
        // Fallback: our own window above the keyboard window level.
        CGFloat appWidth = appWindow.bounds.size.width;
        CGFloat keyboardHeight = CGRectGetHeight(keyboardFrame);
        CGFloat scale = WCKeyboardEnhanceScale(appWidth);
        CGFloat band = WCKeyboardEnhanceConfiguredHeight(keyboardHeight > 0.0 ? keyboardHeight : 400.0, scale, NO);
        CGFloat stripWidth = WCKeyboardEnhanceConfiguredWidth(appWidth, scale, NO);
        CGFloat stripX = (appWidth - stripWidth) / 2.0 + WCKeyboardEnhanceHorizontalOffset(NO) * scale;
        if (stripX < 0.0) stripX = 0.0;
        if (stripX + stripWidth > appWidth) stripX = MAX(0.0, appWidth - stripWidth);
        CGRect strip = CGRectMake(stripX,
                                  CGRectGetMaxY(keyboardFrame) - WCKeyboardEnhanceBandBottomMargin
                                      - band - WCKeyboardEnhanceVerticalOffset(NO) * scale,
                                  stripWidth, band);
        CGFloat desiredLevel = 10000001.0;
        if (!WCKeyboardEnhanceWindow) {
            WCKeyboardOverlayWindow *window = nil;
            if (@available(iOS 13.0, *)) {
                UIWindowScene *scene = appWindow.windowScene;
                if (scene) window = [[WCKeyboardOverlayWindow alloc] initWithWindowScene:scene];
            }
            if (!window) window = [[WCKeyboardOverlayWindow alloc] initWithFrame:strip];
            window.backgroundColor = UIColor.clearColor;
            window.hidden = YES;
            UIViewController *root = [UIViewController new];
            UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
            container.backgroundColor = UIColor.clearColor;
            root.view = container;
            window.rootViewController = root;
            WCKeyboardEnhanceWindow = window;
            WCKeyboardEnhanceContainer = container;
        }
        [(WCKeyboardOverlayWindow *)WCKeyboardEnhanceWindow setWcOverrideLevel:desiredLevel];
        WCKeyboardEnhanceWindow.windowLevel = desiredLevel;
        WCKeyboardEnhanceWindow.frame = strip;
        if (WCKeyboardEnhanceView.superview != WCKeyboardEnhanceContainer) {
            [WCKeyboardEnhanceView removeFromSuperview];
            [WCKeyboardEnhanceContainer addSubview:WCKeyboardEnhanceView];
        }
        WCKeyboardEnhanceView.frame = CGRectMake(0, 0, strip.size.width, strip.size.height);
        WCKeyboardEnhanceUpdateSignature(scale);
        WCKeyboardEnhanceWindow.hidden = NO;
        NSString *labelText = [NSString stringWithFormat:@"触控区 %.0f×%.0f W",
                               strip.size.width, strip.size.height];
        WCKeyboardEnhanceSetDebugText(labelText);
    }
    WCKeyboardEnhanceView.hidden = NO;
    WCKeyboardEnhanceStartReassertTimer();
}

void WCKeyboardEnhanceUpdate(NSNotification *note) {
    CGRect frame = CGRectZero;
    id value = note.userInfo[UIKeyboardFrameEndUserInfoKey];
    if ([value isKindOfClass:[NSValue class]]) frame = [(NSValue *)value CGRectValue];
    if (CGRectIsEmpty(frame)) { WCKeyboardEnhanceHide(); return; }
    WCKeyboardEnhanceLastFrame = frame;
    WCKeyboardEnhanceLastFrameValid = YES;
    WCKeyboardEnhanceApply(frame);
}

// Re-applies the strip with the last known keyboard frame, e.g. after toggling
// the debug switch without dismissing the keyboard.
void WCKeyboardEnhanceRefresh(void) {
    if (!WCKeyboardEnhanceLastFrameValid) { WCKeyboardEnhanceHide(); return; }
    WCKeyboardEnhanceApply(WCKeyboardEnhanceLastFrame);
}

// Periodic *check* only: if the strip is already inside the keyboard window
// (or the fallback overlay) do nothing at all. Re-applying unconditionally
// several times a second re-parented/re-fronted the strip and made the
// translucent band visibly flicker.
static void WCKeyboardEnhanceReassertIfDetached(void) {
    UIView *view = WCKeyboardEnhanceView;
    if (!view) return;
    UIView *dock = WCCapturedKeyboardDockView;
    if (dock && dock.window) {
        if (view.superview == dock) return;
        if (WCKeyboardEnhanceApplyInDock(dock)) return;
    }
    UIWindow *keyboardWindow = WCSystemKeyboardWindow();
    if (keyboardWindow) {
        if (view.window == keyboardWindow) return;
    } else if (WCKeyboardEnhanceWindow && view.window == WCKeyboardEnhanceWindow) {
        return;
    }
    WCKeyboardEnhanceApply(WCKeyboardEnhanceLastFrame);
}

static BOOL WCKeyboardEnhanceKeyboardOnScreen(void) {
    if (!WCKeyboardEnhanceLastFrameValid) return NO;
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    UIWindow *appWindow = WCActiveWindow();
    if (!appWindow) return NO;
    CGFloat screenHeight = appWindow.bounds.size.height;
    if (@available(iOS 13.0, *)) {
        if (appWindow.windowScene) {
            screenHeight = MAX(screenHeight, appWindow.windowScene.screen.bounds.size.height);
        }
    }
    return CGRectGetMinY(WCKeyboardEnhanceLastFrame) < screenHeight - 1.0;
}

static void WCKeyboardEnhanceStopReassertTimer(void) {
    [WCKeyboardEnhanceReassertTimer invalidate];
    WCKeyboardEnhanceReassertTimer = nil;
}

// The keyboard window re-installs its own content when it finishes presenting,
// which can remove the strip after UIKeyboardDidShowNotification has already
// passed. Check periodically while the keyboard is up, but only repair an
// actually detached strip (see WCKeyboardEnhanceReassertIfDetached).
static void WCKeyboardEnhanceStartReassertTimer(void) {
    if (WCKeyboardEnhanceReassertTimer) return;
    WCKeyboardEnhanceReassertTimer = [NSTimer scheduledTimerWithTimeInterval:0.4
                                                                     repeats:YES
                                                                       block:^(NSTimer *timer) {
        if (!WCKeyboardEnhanceKeyboardOnScreen()) {
            [timer invalidate];
            WCKeyboardEnhanceReassertTimer = nil;
            return;
        }
        WCKeyboardEnhanceReassertIfDetached();
    }];
    WCKeyboardEnhanceReassertTimer.tolerance = 0.15;
}

