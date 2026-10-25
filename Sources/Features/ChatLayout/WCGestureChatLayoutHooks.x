#import <UIKit/UIKit.h>
#import "Sources/API/WCGestureInternal.h"

#pragma mark - Chat layout hooks

// Text size: WeChat asks CLocalInfo for the global font level on every layout
// pass, so overriding the getter makes native chat layout reflow at our size.
%hook CLocalInfo

- (unsigned int)m_uiGlobalFontLevel {
    return WCChatLayoutResolvedFontLevel(%orig);
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
    return WCMomentsLayoutAdjustedHeight(%orig);
}

%end

%hook WCTimeLineCommentCellView

+ (double)getCellHeightForDataItem:(id)item
                          RowIndex:(long long)rowIndex
                       pageContext:(id)context {
    return WCMomentsLayoutAdjustedHeight(%orig);
}

%end

%ctor {
    %init;
}
