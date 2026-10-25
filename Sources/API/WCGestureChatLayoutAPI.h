#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BOOL WCGestureLayoutScaleEnabled(void);
double WCGestureLayoutScaleFactor(void);
/// Paired around theme lookups so nested proxy/manager calls scale only once.
void WCGestureLayoutBeginThemeLookup(void);
id _Nullable WCGestureLayoutEndThemeLookup(id _Nullable value, id _Nullable property, id _Nullable ruleSet);
/// Record the requested WebView zoom before applying the interface override.
double WCGestureLayoutWebViewZoom(id webView, double requestedFactor);
void WCGestureLayoutApplyWebView(id webView);
void WCGestureLayoutSettingsChanged(NSString * _Nullable key);

/// Font level to report to WeChat, or the original one when the feature is off.
unsigned int WCChatLayoutResolvedFontLevel(unsigned int originalLevel);

/// Moments cell height after the optional compensation percentage.
double WCMomentsLayoutAdjustedHeight(double originalHeight);

NS_ASSUME_NONNULL_END
