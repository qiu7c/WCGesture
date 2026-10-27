#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN
BOOL WCGestureVirtualLocationEnabled(void);
BOOL WCGestureVirtualLocationMomentsEnabled(void);
BOOL WCGestureVirtualLocationHasSelection(void);
BOOL WCGestureVirtualLocationCoordinateIsValid(CLLocationCoordinate2D coordinate);
CLLocationCoordinate2D WCGestureVirtualLocationCoordinate(void);
CLLocationCoordinate2D WCGestureVirtualLocationSpoofedCoordinate(CLLocationCoordinate2D original);
void WCGestureVirtualLocationSetCoordinate(CLLocationCoordinate2D coordinate, NSString * _Nullable name);
void WCGestureVirtualLocationClear(void);
void WCGestureVirtualLocationNudge(double latitudeDelta, double longitudeDelta);
NSString *WCGestureVirtualLocationCoordinateText(void);
NSString *WCGestureVirtualLocationSummary(void);
void WCGestureVirtualLocationSetPicking(BOOL picking);
BOOL WCGestureVirtualLocationIsPicking(void);
void WCGestureVirtualLocationSurfaceChanged(UIViewController *controller);
NSArray<NSDictionary<NSString *, id> *> *WCGestureVirtualLocationPresets(void);
void WCGestureVirtualLocationAddPreset(NSString *name, CLLocationCoordinate2D coordinate);
void WCGestureVirtualLocationRemovePresetAtIndex(NSUInteger index);
BOOL WCGestureVirtualLocationPresentPicker(UIViewController *presenter);
void WCGestureVirtualLocationPickerDisappeared(UIViewController *picker);
UIViewController *WCGestureCreateVirtualLocationSettingsController(void);
NS_ASSUME_NONNULL_END
