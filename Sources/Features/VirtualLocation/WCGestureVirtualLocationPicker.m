#import <objc/message.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

@interface WCVirtualLocationPickerBridge : NSObject
@property (nonatomic, weak) UIViewController *picker;
@property (nonatomic, weak) UIViewController *presentingController;
@end

static WCVirtualLocationPickerBridge *WCVirtualLocationBridge;

// Invoke only the verified object / two-double coordinate ABIs.
static BOOL WCVirtualLocationReadCoordinate(id object, CLLocationCoordinate2D *result, NSUInteger depth) {
    if (!object || depth > 2) return NO;
    SEL latitudeSelector = NSSelectorFromString(@"latitude"), longitudeSelector = NSSelectorFromString(@"longitude");
    NSMethodSignature *latitude = [object methodSignatureForSelector:latitudeSelector];
    NSMethodSignature *longitude = [object methodSignatureForSelector:longitudeSelector];
    if (latitude.numberOfArguments == 2 && longitude.numberOfArguments == 2 &&
        strcmp(latitude.methodReturnType, @encode(double)) == 0 && strcmp(longitude.methodReturnType, @encode(double)) == 0) {
        double lat = ((double (*)(id, SEL))objc_msgSend)(object, latitudeSelector);
        double lon = ((double (*)(id, SEL))objc_msgSend)(object, longitudeSelector);
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lon);
        if (WCGestureVirtualLocationCoordinateIsValid(coordinate)) { *result = coordinate; return YES; }
    }
    for (NSString *name in @[@"getLocationPOIItem", @"currLocation", @"location", @"coordinate", @"coordinate2D"]) {
        SEL selector = NSSelectorFromString(name);
        if (![object respondsToSelector:selector]) continue;
        NSMethodSignature *signature = [object methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 2) continue;
        const char *type = signature.methodReturnType;
        if (strcmp(type, @encode(CLLocationCoordinate2D)) == 0) {
            CLLocationCoordinate2D coordinate = ((CLLocationCoordinate2D (*)(id, SEL))objc_msgSend)(object, selector);
            if (WCGestureVirtualLocationCoordinateIsValid(coordinate)) { *result = coordinate; return YES; }
        } else if (type[0] == '@') {
            id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
            if (value != object && WCVirtualLocationReadCoordinate(value, result, depth + 1)) return YES;
        }
    }
    return NO;
}

static void WCVirtualLocationFinishPicker(void) {
    WCGestureVirtualLocationSetPicking(NO);
    WCVirtualLocationBridge = nil;
}

@implementation WCVirtualLocationPickerBridge
- (id)onGetRightBarButton {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(saveFromPicker:)];
}
- (void)closePicker {
    UIViewController *picker = self.picker;
    UINavigationController *navigation = picker.navigationController;
    if (navigation.topViewController == picker && navigation.viewControllers.count > 1)
        [navigation popViewControllerAnimated:YES];
    else if (navigation.presentingViewController) [navigation dismissViewControllerAnimated:YES completion:nil];
    WCVirtualLocationFinishPicker();
}
- (void)saveFromPicker:(__unused id)sender {
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    BOOL valid = NO;
    @try { valid = WCVirtualLocationReadCoordinate(self.picker, &coordinate, 0); }
    @catch (__unused NSException *exception) {}
    if (!valid) { WCShowToast(@"未读取到选中位置，请重新选点或手动输入坐标"); return; }
    WCGestureVirtualLocationSetCoordinate(coordinate, nil);
    [self closePicker];
}
- (void)onFinishSelectedLocation { [self saveFromPicker:nil]; }
- (void)onCancelSeletctedLocation { [self closePicker]; }
@end

BOOL WCGestureVirtualLocationPresentPicker(UIViewController *presenter) {
    if (!NSThread.isMainThread || !presenter.view.window || presenter.presentedViewController || WCVirtualLocationBridge) return NO;
    Class pickerClass = NSClassFromString(@"MMPickLocationViewController");
    SEL initializer = NSSelectorFromString(@"initWithSceneType:OnlyUseUserLocation:");
    if (!pickerClass || ![pickerClass isSubclassOfClass:UIViewController.class] ||
        ![pickerClass instancesRespondToSelector:initializer] || ![pickerClass instancesRespondToSelector:@selector(setDelegate:)]) return NO;
    WCGestureVirtualLocationSetPicking(YES);
    @try {
        // WeChat 8.0.79: unsigned int sceneType, BOOL onlyUseUserLocation.
        id value = ((id (*)(id, SEL, unsigned int, BOOL))objc_msgSend)([pickerClass alloc], initializer, 0, NO);
        if (![value isKindOfClass:UIViewController.class]) { WCVirtualLocationFinishPicker(); return NO; }
        UIViewController *picker = value; picker.hidesBottomBarWhenPushed = YES;
        WCVirtualLocationPickerBridge *bridge = [WCVirtualLocationPickerBridge new];
        bridge.picker = picker; bridge.presentingController = presenter;
        WCVirtualLocationBridge = bridge;
        ((void (*)(id, SEL, id))objc_msgSend)(picker, @selector(setDelegate:), bridge);
        if (presenter.navigationController) [presenter.navigationController pushViewController:picker animated:YES];
        else [presenter presentViewController:[[UINavigationController alloc] initWithRootViewController:picker] animated:YES completion:nil];
        return YES;
    } @catch (__unused NSException *exception) {
        WCVirtualLocationFinishPicker(); return NO;
    }
}

void WCGestureVirtualLocationPickerDisappeared(UIViewController *picker) {
    if (WCVirtualLocationBridge.picker != picker) return;
    UINavigationController *navigation = picker.navigationController;
    if (picker.isMovingFromParentViewController || picker.isBeingDismissed || navigation.isBeingDismissed ||
        (!picker.presentingViewController && (!navigation || ![navigation.viewControllers containsObject:picker])))
        WCVirtualLocationFinishPicker();
}
