#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "Sources/API/WCGestureInternal.h"

#pragma mark - Chat layout hooks

// Theme manager overloads and the proxy may call one another. Only the
// outermost lookup applies the percentage; finally also balances exceptions.
%hook MMThemeManager

- (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet {
    id value = nil;
    WCGestureLayoutBeginThemeLookup();
    @try {
        value = %orig;
    }
    @finally { value = WCGestureLayoutEndThemeLookup(value, property, ruleSet); }
    return value;
}

- (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet isAdapt:(BOOL)isAdapt {
    id value = nil;
    WCGestureLayoutBeginThemeLookup();
    @try {
        value = %orig;
    }
    @finally { value = WCGestureLayoutEndThemeLookup(value, property, ruleSet); }
    return value;
}

%end

%hook WAThemeProxy

+ (id)getValueOfProperty:(id)property inRuleSet:(id)ruleSet {
    id value = nil;
    WCGestureLayoutBeginThemeLookup();
    @try {
        value = %orig;
    }
    @finally { value = WCGestureLayoutEndThemeLookup(value, property, ruleSet); }
    return value;
}

%end

%hook WKWebView

- (id)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    id webView = %orig;
    WCGestureLayoutApplyWebView(webView);
    return webView;
}

- (void)didMoveToWindow {
    %orig;
    WCGestureLayoutApplyWebView(self);
}

- (void)_setTextZoomFactor:(CGFloat)factor {
    CGFloat resolved = WCGestureLayoutWebViewZoom(self, factor);
    %orig(resolved);
}

%end

// Text size: WeChat asks CLocalInfo for the global font level on every layout
// pass, so overriding the getter makes native chat layout reflow at our size.
%hook CLocalInfo

- (unsigned int)m_uiWebviewFontLevel {
    unsigned int original = %orig;
    return WCGestureLayoutScaleEnabled() ? 1 : original;
}

- (unsigned int)m_uiGlobalFontLevel {
    unsigned int original = %orig;
    return WCChatLayoutResolvedFontLevel(original);
}

%end

// Moments: the cell heights are computed by class methods. Scaling the result
// keeps longer text readable instead of clipping it.
%hook WCListBaseCellView

+ (double)getLayoutHeightWithGroup:(id)group
                        groupItem:(id)item
                            width:(double)width
                 isFirstOneInsection:(BOOL)first
                 isLastOneInSection:(BOOL)last {
    double height = %orig;
    return WCMomentsLayoutAdjustedHeight(height);
}

%end

%hook WCTimeLineCommentCellView

+ (double)getCellHeightForDataItem:(id)item
                          RowIndex:(long long)rowIndex
                       pageContext:(id)context {
    double height = %orig;
    return WCMomentsLayoutAdjustedHeight(height);
}

%end

%ctor {
    %init;
}
