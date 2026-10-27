#import "Sources/API/WCGestureInternal.h"
%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)value {
    unsigned long long display=WCGestureWalletDisplayNumber((UIView *)self,value);
    %orig(display);
}
%end
%hook WCPayWalletEntryHeaderView
- (void)layoutSubviews {
    %orig;
    WCGestureWalletDisplayLayout((UIView *)self);
}
%end
%ctor {
    %init;
}
