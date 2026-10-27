#import <stdatomic.h>
#import <float.h>
#import <math.h>
#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

static const NSUInteger WCGestureVirtualLocationPresetLimit = 20;
static _Atomic(double) WCGestureVirtualLocationPickingDeadline;

/// A picker that goes away without either of its callbacks must not leave the
/// spoof switched off for the rest of the session, so the gate always expires.
static const NSTimeInterval WCGestureVirtualLocationPickingTimeout = 300.0;

#pragma mark - Switches

BOOL WCGestureVirtualLocationEnabled(void) {
    return WCGestureEnabled(WCGestureVirtualLocationEnabledKey);
}

BOOL WCGestureVirtualLocationMomentsEnabled(void) {
    return WCGestureEnabled(WCGestureVirtualLocationMomentsEnabledKey);
}

#pragma mark - Selection

BOOL WCGestureVirtualLocationCoordinateIsValid(CLLocationCoordinate2D coordinate) {
    if (!isfinite(coordinate.latitude) || !isfinite(coordinate.longitude)) return NO;
    if (fabs(coordinate.latitude) > 90.0 || fabs(coordinate.longitude) > 180.0) return NO;
    // A cleared pair of doubles reads back as 0, 0, which is a legal coordinate
    // in the Gulf of Guinea but never a place someone picked.
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return NO;
    return YES;
}

CLLocationCoordinate2D WCGestureVirtualLocationCoordinate(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    @synchronized (defaults) {
        coordinate.latitude = [defaults doubleForKey:WCGestureVirtualLocationLatitudeKey];
        coordinate.longitude = [defaults doubleForKey:WCGestureVirtualLocationLongitudeKey];
    }
    return coordinate;
}

BOOL WCGestureVirtualLocationHasSelection(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:WCGestureVirtualLocationLatitudeKey] == nil) return NO;
    if ([defaults objectForKey:WCGestureVirtualLocationLongitudeKey] == nil) return NO;
    return WCGestureVirtualLocationCoordinateIsValid(WCGestureVirtualLocationCoordinate());
}

void WCGestureVirtualLocationSetCoordinate(CLLocationCoordinate2D coordinate, NSString *name) {
    if (!WCGestureVirtualLocationCoordinateIsValid(coordinate)) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    @synchronized (defaults) {
        [defaults setDouble:coordinate.latitude forKey:WCGestureVirtualLocationLatitudeKey];
        [defaults setDouble:coordinate.longitude forKey:WCGestureVirtualLocationLongitudeKey];
        if (name.length > 0) {
            [defaults setObject:name forKey:WCGestureVirtualLocationNameKey];
        } else {
            [defaults removeObjectForKey:WCGestureVirtualLocationNameKey];
        }
    }
    WCGestureSettingsPostChange(WCGestureVirtualLocationLatitudeKey);
}

void WCGestureVirtualLocationClear(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    @synchronized (defaults) {
        [defaults removeObjectForKey:WCGestureVirtualLocationLatitudeKey];
        [defaults removeObjectForKey:WCGestureVirtualLocationLongitudeKey];
        [defaults removeObjectForKey:WCGestureVirtualLocationNameKey];
    }
    WCGestureSettingsPostChange(WCGestureVirtualLocationLatitudeKey);
}

void WCGestureVirtualLocationNudge(double latitudeDelta, double longitudeDelta) {
    if (!WCGestureVirtualLocationHasSelection()) return;
    CLLocationCoordinate2D coordinate = WCGestureVirtualLocationCoordinate();
    CLLocationCoordinate2D moved = coordinate;
    moved.latitude += latitudeDelta;
    moved.longitude += longitudeDelta;
    if (!WCGestureVirtualLocationCoordinateIsValid(moved)) return;
    WCGestureVirtualLocationSetCoordinate(moved, [NSUserDefaults.standardUserDefaults stringForKey:WCGestureVirtualLocationNameKey]);
}

NSString *WCGestureVirtualLocationCoordinateText(void) {
    if (!WCGestureVirtualLocationHasSelection()) return @"未选择";
    CLLocationCoordinate2D coordinate = WCGestureVirtualLocationCoordinate();
    return [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
}

NSString *WCGestureVirtualLocationSummary(void) {
    if (!WCGestureVirtualLocationHasSelection()) return @"未选择";
    NSString *name = [NSUserDefaults.standardUserDefaults stringForKey:WCGestureVirtualLocationNameKey];
    NSString *coordinates = WCGestureVirtualLocationCoordinateText();
    return name.length > 0 ? [NSString stringWithFormat:@"%@（%@）", name, coordinates] : coordinates;
}

#pragma mark - Hook entry point

void WCGestureVirtualLocationSetPicking(BOOL picking) {
    double deadline = picking ? NSDate.date.timeIntervalSince1970 + WCGestureVirtualLocationPickingTimeout : 0.0;
    atomic_store(&WCGestureVirtualLocationPickingDeadline, deadline);
}

BOOL WCGestureVirtualLocationIsPicking(void) {
    double deadline = atomic_load(&WCGestureVirtualLocationPickingDeadline);
    if (deadline <= 0.0) return NO;
    if (NSDate.date.timeIntervalSince1970 > deadline) {
        atomic_store(&WCGestureVirtualLocationPickingDeadline, 0.0);
        return NO;
    }
    return YES;
}

static _Atomic(BOOL) WCVirtualLocationMomentsSurface;

void WCGestureVirtualLocationSurfaceChanged(UIViewController *controller) {
    if (!NSThread.isMainThread) return;
    if ([controller isKindOfClass:UINavigationController.class]) controller = ((UINavigationController *)controller).visibleViewController;
    if ([controller isKindOfClass:UITabBarController.class]) controller = ((UITabBarController *)controller).selectedViewController;
    BOOL moments = NO;
    for (UIViewController *current = controller; current; current = current.parentViewController) {
        NSString *name = NSStringFromClass(current.class).lowercaseString;
        for (NSString *word in @[@"moments", @"sns", @"timeline", @"wcstory", @"sight"]) {
            if ([name containsString:word]) { moments = YES; break; }
        }
        if (moments) break;
    }
    atomic_store(&WCVirtualLocationMomentsSurface, moments);
}

CLLocationCoordinate2D WCGestureVirtualLocationSpoofedCoordinate(CLLocationCoordinate2D original) {
    if (!WCGestureVirtualLocationEnabled()) return original;
    if (WCGestureVirtualLocationIsPicking()) return original;
    if (!WCGestureVirtualLocationHasSelection()) return original;
    if (atomic_load(&WCVirtualLocationMomentsSurface) && !WCGestureVirtualLocationMomentsEnabled()) return original;
    CLLocationCoordinate2D spoofed = WCGestureVirtualLocationCoordinate();
    if (!WCGestureVirtualLocationCoordinateIsValid(spoofed)) return original;
    return spoofed;
}

#pragma mark - Saved places

NSArray<NSDictionary<NSString *, id> *> *WCGestureVirtualLocationPresets(void) {
    NSArray *stored = [NSUserDefaults.standardUserDefaults arrayForKey:WCGestureVirtualLocationPresetsKey];
    NSMutableArray<NSDictionary<NSString *, id> *> *presets = [NSMutableArray array];
    for (id entry in stored) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *preset = entry;
        id latitude = preset[@"latitude"];
        id longitude = preset[@"longitude"];
        if (![latitude respondsToSelector:@selector(doubleValue)]) continue;
        if (![longitude respondsToSelector:@selector(doubleValue)]) continue;
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([latitude doubleValue], [longitude doubleValue]);
        if (!WCGestureVirtualLocationCoordinateIsValid(coordinate)) continue;
        NSString *name = [preset[@"name"] isKindOfClass:NSString.class] ? preset[@"name"] : @"";
        [presets addObject:@{@"name": name, @"latitude": @(coordinate.latitude), @"longitude": @(coordinate.longitude)}];
        if (presets.count == WCGestureVirtualLocationPresetLimit) break;
    }
    return [presets copy];
}

void WCGestureVirtualLocationAddPreset(NSString *name, CLLocationCoordinate2D coordinate) {
    if (!WCGestureVirtualLocationCoordinateIsValid(coordinate)) return;
    if (name.length == 0) name = WCGestureVirtualLocationCoordinateText();
    NSMutableArray *presets = [WCGestureVirtualLocationPresets() mutableCopy];
    NSDictionary *entry = @{ @"name": name,
                             @"latitude": @(coordinate.latitude),
                             @"longitude": @(coordinate.longitude) };
    [presets removeObject:entry];
    [presets insertObject:entry atIndex:0];
    while (presets.count > WCGestureVirtualLocationPresetLimit) {
        [presets removeLastObject];
    }
    [NSUserDefaults.standardUserDefaults setObject:presets forKey:WCGestureVirtualLocationPresetsKey];
    WCGestureSettingsPostChange(WCGestureVirtualLocationPresetsKey);
}

void WCGestureVirtualLocationRemovePresetAtIndex(NSUInteger index) {
    NSMutableArray *presets = [WCGestureVirtualLocationPresets() mutableCopy];
    if (index >= presets.count) return;
    [presets removeObjectAtIndex:index];
    [NSUserDefaults.standardUserDefaults setObject:presets forKey:WCGestureVirtualLocationPresetsKey];
    WCGestureSettingsPostChange(WCGestureVirtualLocationPresetsKey);
}
