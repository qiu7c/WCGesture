#import "Sources/API/WCGestureInternal.h"
%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)value {
    unsigned long long display=WCGestureWalletDisplayNumber((UIView *)self,value);
    @try {
        %orig(display);
    } @finally { WCGestureWalletDisplayNumberEnded((UIView *)self); }
}
- (void)defaultNumber:(unsigned long long)value {
    unsigned long long display=WCGestureWalletDisplayNumber((UIView *)self,value);
    @try {
        %orig(display);
    } @finally { WCGestureWalletDisplayNumberEnded((UIView *)self); }
}
- (void)updateNumberInternal:(unsigned long long)value {
    unsigned long long display=WCGestureWalletDisplayNumber((UIView *)self,value);
    @try {
        %orig(display);
    } @finally { WCGestureWalletDisplayNumberEnded((UIView *)self); }
}
%end
%hook WCPayWalletEntryHeaderView
- (void)layoutSubviews {
    %orig;
    WCGestureWalletDisplayLayout((UIView *)self);
}
%end
%hook WCPayWalletViewController
- (void)updateBalanceNumber {
    %orig;
    WCGestureWalletDisplayControllerChanged((UIViewController *)self);
}
- (void)updateLqtNumber {
    %orig;
    WCGestureWalletDisplayControllerChanged((UIViewController *)self);
}
%end
%hook WCPayLQTDetailViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureWalletDisplayControllerChanged((UIViewController *)self);
}
%end
%hook WCPayBalanceDetailViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureWalletDisplayControllerChanged((UIViewController *)self);
}
%end
%ctor {
    %init;
}
