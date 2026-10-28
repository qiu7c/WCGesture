#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

// Xiaowei FINANCE_PORT_SPEC.md: explicit wallet controls + text-context merchant.
@interface WCWalletNumberState : NSObject
@property(nonatomic) unsigned long long original;
@property(nonatomic) unsigned long long applied;
@property(nonatomic) NSUInteger depth;
@property(nonatomic) BOOL hasOriginal;
@property(nonatomic) BOOL refreshing;
@property(nonatomic) NSInteger kind;
@property(nonatomic,copy) NSString *account;
@property(nonatomic,weak) id owner;
@end
@implementation WCWalletNumberState
@end
static char WCWalletNumberKey;
static NSHashTable *WCWalletNumbers(void){static NSHashTable *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSHashTable weakObjectsHashTable];});return v;}
static BOOL WCWalletClass(id value,NSString *name){Class cls=NSClassFromString(name);return cls && [value isKindOfClass:cls];}
static NSString *WCWalletKey(NSInteger kind){return kind==2?WCGestureWalletLQTFenKey:(kind==3?WCGestureWalletMerchantFenKey:WCGestureWalletDisplayFenKey);}
static unsigned long long WCWalletFen(NSInteger kind){id v=[NSUserDefaults.standardUserDefaults objectForKey:WCWalletKey(kind)];unsigned long long n=[v respondsToSelector:@selector(unsignedLongLongValue)]?[v unsignedLongLongValue]:0;return n<=999999999999ULL?n:0;}
static WCWalletNumberState *WCWalletState(UIView *view){WCWalletNumberState *s=objc_getAssociatedObject(view,&WCWalletNumberKey);if(!s){s=[WCWalletNumberState new];objc_setAssociatedObject(view,&WCWalletNumberKey,s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return s;}
static UIViewController *WCWalletOwner(UIView *view){return WCViewControllerForResponder(view);}
static BOOL WCWalletMerchantText(UIView *view){
    NSMutableArray *stack=[NSMutableArray arrayWithObject:@[view,@0]];NSUInteger labels=0;BOOL merchant=NO,balance=NO;
    while(stack.count && labels<30){NSArray *entry=stack.lastObject;[stack removeLastObject];UIView *v=entry[0];NSUInteger depth=[entry[1] unsignedIntegerValue];
        if([v isKindOfClass:UILabel.class]){labels++;NSString *text=[(UILabel *)v text] ?: @"";BOOL account=[text containsString:@"经营账户"]||[text containsString:@"商户账户"];merchant|=account||[text containsString:@"经营余额"]||[text containsString:@"商户余额"];balance|=account||[text containsString:@"余额"];}
        if(depth<8)for(UIView *child in v.subviews)[stack addObject:@[child,@(depth+1)]];
    }return merchant && balance;
}
static NSInteger WCWalletKind(UIView *view){
    for(UIView *v=view.superview;v;v=v.superview)if(WCWalletClass(v,@"WCPayWalletEntryHeaderView") && WCTweakSafeValue(v,@"timeoutNumber")==view)return 1;
    UIViewController *owner=WCWalletOwner(view);
    if(WCWalletClass(owner,@"WCPayWalletViewController")){
        if(WCTweakSafeValue(owner,@"balanceNumber")==view)return 1;if(WCTweakSafeValue(owner,@"lqtNumber")==view)return 2;
    }
    if(WCWalletClass(owner,@"WCPayLQTDetailViewController") && WCTweakSafeValue(owner,@"timeoutNumber")==view)return 2;
    if(WCWalletClass(owner,@"WCPayBalanceDetailViewController") && WCTweakSafeValue(owner,@"timeoutNumber")==view){
        NSString *title=[NSString stringWithFormat:@"%@ %@",owner.title ?: @"",WCTweakSafeValue(WCTweakSafeValue(owner,@"balanceTitleLabel"),@"text") ?: @""];
        if([title containsString:@"零钱通"])return 2;if([title containsString:@"零钱"])return 1;
    }
    // Sample type3 uses nearby labels. One Wx narrows this to a wallet-screen
    // context and a local merchant-account/balance label group, never arbitrary chat labels.
    NSString *title=owner.title ?: @"";
    if(WCWalletClass(owner,@"WCPayWalletViewController") || (WCWalletClass(owner,@"WCPayBaseViewController") && ([title containsString:@"经营"]||[title containsString:@"商户"]))){
        UIView *area=view.superview;for(NSUInteger i=0;i<2 && area && area!=owner.view;i++,area=area.superview)if(WCWalletMerchantText(area))return 3;
    }
    return 0;
}
unsigned long long WCGestureWalletDisplayNumber(UIView *view,unsigned long long value){
    WCWalletNumberState *s=WCWalletState(view);NSInteger kind=WCWalletKind(view);
    if(!s.depth && !s.refreshing){s.original=value;s.hasOriginal=YES;s.account=WCCurrentUserWXID() ?: @"";s.kind=kind;s.owner=WCWalletOwner(view);}
    s.depth++;
    if(kind)[WCWalletNumbers() addObject:view];
    unsigned long long replacement=kind?WCWalletFen(kind):0;
    if(kind && WCGestureEnabled(WCGestureWalletDisplayEnabledKey) && replacement && [s.account isEqualToString:WCCurrentUserWXID() ?: @""])value=replacement;
    s.applied=value;return value;
}
void WCGestureWalletDisplayNumberEnded(UIView *view){WCWalletNumberState *s=objc_getAssociatedObject(view,&WCWalletNumberKey);if(s.depth)s.depth--;}
static void WCWalletRefreshNumber(UIView *view){
    NSInteger kind=WCWalletKind(view);WCWalletNumberState *s=objc_getAssociatedObject(view,&WCWalletNumberKey);
    if(!kind && (!s.hasOriginal || s.owner!=WCWalletOwner(view) || s.applied==s.original))return;
    if(!s)s=WCWalletState(view);
    if(!s.hasOriginal){id n=WCTweakSafeValue(WCTweakSafeValue(view,@"scrollNumber"),@"currentNumber");if(![n isKindOfClass:NSNumber.class])return;
        s.original=s.applied=[n unsignedLongLongValue];s.hasOriginal=YES;s.account=WCCurrentUserWXID() ?: @"";}
    if(s.depth || s.refreshing || ![s.account isEqualToString:WCCurrentUserWXID() ?: @""])return;
    s.kind=kind;unsigned long long configured=kind?WCWalletFen(kind):0,desired=WCGestureEnabled(WCGestureWalletDisplayEnabledKey) && configured?configured:s.original;
    [WCWalletNumbers() addObject:view];if(s.applied==desired)return;
    SEL update=NSSelectorFromString(@"updateNumber:");if(![view respondsToSelector:update])return;
    s.refreshing=YES;@try{((void (*)(id,SEL,unsigned long long))objc_msgSend)(view,update,s.original);}@finally{s.refreshing=NO;}
}
void WCGestureWalletDisplayLayout(UIView *header){id view=WCTweakSafeValue(header,@"timeoutNumber");if([view isKindOfClass:UIView.class])WCWalletRefreshNumber(view);}
void WCGestureWalletDisplayControllerChanged(UIViewController *owner){
    NSArray *fields=WCWalletClass(owner,@"WCPayWalletViewController")?@[@"balanceNumber",@"lqtNumber"]:@[@"timeoutNumber"];
    for(NSString *field in fields){id view=WCTweakSafeValue(owner,field);if([view isKindOfClass:UIView.class])WCWalletRefreshNumber(view);}
}
void WCGestureWalletDisplaySettingsChanged(NSString *key){if(key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.local-display.wallet."])return;for(UIView *v in WCWalletNumbers().allObjects)WCWalletRefreshNumber(v);}
NSString *WCGestureWalletDisplayTextForKind(NSInteger kind){unsigned long long value=WCWalletFen(kind);return [NSString stringWithFormat:@"%llu.%02llu",value/100,value%100];}
NSString *WCGestureWalletDisplayText(void){return WCGestureWalletDisplayTextForKind(1);}
void WCGestureWalletDisplayEditKind(NSInteger kind){
    if(kind<1 || kind>3)return;NSString *title=kind==2?@"零钱通显示金额":(kind==3?@"经营账户显示金额":@"钱包显示金额");
    [WCPopup showInputWithTitle:title message:nil text:WCGestureWalletDisplayTextForKind(kind) placeholder:@"0 恢复原生；最多两位小数" keyboard:UIKeyboardTypeDecimalPad completion:^(NSString *text){
        NSString *value=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!value.length)value=@"0";
        NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,10}([.][0-9]{1,2})?$" options:0 error:nil];
        if([regex numberOfMatchesInString:value options:0 range:NSMakeRange(0,value.length)]!=1){WCShowToast(@"请输入最多两位小数的金额");return;}
        NSDecimalNumber *fen=[[NSDecimalNumber decimalNumberWithString:value locale:@{@"NSLocaleDecimalSeparator":@"."}] decimalNumberByMultiplyingByPowerOf10:2];
        [NSUserDefaults.standardUserDefaults setObject:@(fen.unsignedLongLongValue) forKey:WCWalletKey(kind)];WCGestureSettingsPostChange(WCWalletKey(kind));
    }];
}
void WCGestureWalletDisplayEdit(void){WCGestureWalletDisplayEditKind(1);}
