#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
static unsigned long long WCWalletConfiguredFen(void) {
    id stored=[NSUserDefaults.standardUserDefaults objectForKey:WCGestureWalletDisplayFenKey];
    unsigned long long value=[stored respondsToSelector:@selector(unsignedLongLongValue)] ? [stored unsignedLongLongValue] : 0;
    return value<=999999999999ULL ? value:0;
}
static char WCWalletOriginalKey,WCWalletAccountKey,WCWalletRefreshingKey,WCWalletAppliedKey;
static NSHashTable *WCWalletNumbers(void){static NSHashTable *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSHashTable weakObjectsHashTable];});return v;}
static UIView *WCWalletHeader(UIView *view){Class cls=NSClassFromString(@"WCPayWalletEntryHeaderView");for(UIView *v=view;v;v=v.superview)if(cls && [v isKindOfClass:cls])return v;return nil;}
unsigned long long WCGestureWalletDisplayNumber(UIView *view,unsigned long long original){
    UIView *header=WCWalletHeader(view);if(!header || WCTweakSafeValue(header,@"timeoutNumber")!=view)return original;
    [WCWalletNumbers() addObject:view];
    if(![objc_getAssociatedObject(view,&WCWalletRefreshingKey) boolValue]){objc_setAssociatedObject(view,&WCWalletOriginalKey,@(original),OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(view,&WCWalletAccountKey,WCCurrentUserWXID() ?: @"",OBJC_ASSOCIATION_COPY_NONATOMIC);}
    unsigned long long value=WCWalletConfiguredFen();
    unsigned long long desired=WCGestureEnabled(WCGestureWalletDisplayEnabledKey) && value>0 && [objc_getAssociatedObject(view,&WCWalletAccountKey) isEqualToString:WCCurrentUserWXID() ?: @""] ? value:original;
    objc_setAssociatedObject(view,&WCWalletAppliedKey,@(desired),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return desired;
}
void WCGestureWalletDisplayLayout(UIView *header){
    id target=WCTweakSafeValue(header,@"timeoutNumber");SEL update=NSSelectorFromString(@"updateNumber:");if(![target isKindOfClass:UIView.class] || ![target respondsToSelector:update])return;
    NSNumber *original=objc_getAssociatedObject(target,&WCWalletOriginalKey);
    if(!original){id scroll=WCTweakSafeValue(target,@"scrollNumber");id number=WCTweakSafeValue(scroll,@"currentNumber");if([number isKindOfClass:NSNumber.class]){original=number;objc_setAssociatedObject(target,&WCWalletOriginalKey,number,OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(target,&WCWalletAccountKey,WCCurrentUserWXID() ?: @"",OBJC_ASSOCIATION_COPY_NONATOMIC);}}
    if(!original || ![objc_getAssociatedObject(target,&WCWalletAccountKey) isEqualToString:WCCurrentUserWXID() ?: @""])return;
    unsigned long long value=WCWalletConfiguredFen();
    unsigned long long desired=WCGestureEnabled(WCGestureWalletDisplayEnabledKey) && value>0 ? value:original.unsignedLongLongValue;
    NSNumber *applied=objc_getAssociatedObject(target,&WCWalletAppliedKey);
    if ([objc_getAssociatedObject(target,&WCWalletRefreshingKey) boolValue] || (applied && applied.unsignedLongLongValue==desired))return;
    NSNumber *current=WCTweakSafeValue(WCTweakSafeValue(target,@"scrollNumber"),@"currentNumber");
    if ([current isKindOfClass:NSNumber.class] && current.unsignedLongLongValue==desired)return;
    [WCWalletNumbers() addObject:target];objc_setAssociatedObject(target,&WCWalletRefreshingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try{((void (*)(id,SEL,unsigned long long))objc_msgSend)(target,update,original.unsignedLongLongValue);}@finally{objc_setAssociatedObject(target,&WCWalletRefreshingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
}
void WCGestureWalletDisplaySettingsChanged(NSString *key){if(key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.local-display.wallet."])return;for(UIView *view in WCWalletNumbers().allObjects){UIView *header=WCWalletHeader(view);if(header)WCGestureWalletDisplayLayout(header);}}
NSString *WCGestureWalletDisplayText(void){unsigned long long value=WCWalletConfiguredFen();return [NSString stringWithFormat:@"%llu.%02llu",value/100,value%100];}
void WCGestureWalletDisplayEdit(void){
    [WCPopup showInputWithTitle:@"钱包余额本机显示" message:nil text:WCGestureWalletDisplayText() placeholder:@"0 恢复原生；最多两位小数" keyboard:UIKeyboardTypeDecimalPad completion:^(NSString *text){
        NSString *value=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!value.length)value=@"0";
        NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,10}([.][0-9]{1,2})?$" options:0 error:nil];
        if([regex numberOfMatchesInString:value options:0 range:NSMakeRange(0,value.length)]!=1){WCShowToast(@"请输入最多两位小数的金额");return;}
        NSDecimalNumber *fen=[[NSDecimalNumber decimalNumberWithString:value locale:@{@"NSLocaleDecimalSeparator":@"."}] decimalNumberByMultiplyingByPowerOf10:2];
        [NSUserDefaults.standardUserDefaults setObject:@(fen.unsignedLongLongValue) forKey:WCGestureWalletDisplayFenKey];WCGestureSettingsPostChange(WCGestureWalletDisplayFenKey);
    }];
}
