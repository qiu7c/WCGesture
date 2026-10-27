#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
@interface WCLocalEditRecord : NSObject
@property (nonatomic,weak) id wrap;
@property (nonatomic,weak) UIView *cell;
@property (nonatomic,copy) NSString *identity;
@property (nonatomic,copy) NSString *original;
@property (nonatomic,copy) NSString *replacement;
@property (nonatomic) BOOL transfer;
@end
@implementation WCLocalEditRecord
@end
static NSHashTable *WCLocalTimeCells(void);
static NSMapTable *WCLocalEditRecords(void) {
    static NSMapTable *records; static dispatch_once_t once;
    dispatch_once(&once,^{ records=[NSMapTable weakToStrongObjectsMapTable]; });return records;
}
static BOOL WCLocalTransfer(UIView *cell) {
    Class cls=NSClassFromString(@"WCPayTransferMessageCellView"); return cls && [cell isKindOfClass:cls];
}
static BOOL WCLocalEditable(UIView *cell, BOOL transfer) {
    id wrap=WCGestureMessageWrapForCell(cell);
    return WCGestureLocalChatIdentity(cell).length && (transfer ? WCLocalTransfer(cell) && WCGestureEnabled(WCGestureTransferDisplayEditEnabledKey) :
        [WCTweakSafeValue(wrap,@"m_uiMessageType") integerValue]==1 && WCGestureEnabled(WCGestureTextEditEnabledKey));
}
static NSRange WCLocalTransferRange(NSString *content) {
    if (![content isKindOfClass:NSString.class]) return NSMakeRange(NSNotFound,0);
    NSRange start=[content rangeOfString:@"<feedesc><![CDATA["];
    if (start.location==NSNotFound) return NSMakeRange(NSNotFound,0);
    NSUInteger from=NSMaxRange(start); NSRange end=[content rangeOfString:@"]]></feedesc>" options:0 range:NSMakeRange(from,content.length-from)];
    return end.location==NSNotFound ? NSMakeRange(NSNotFound,0) : NSMakeRange(from,end.location-from);
}
BOOL WCGestureLocalEditAllowsAction(UIView *cell, SEL action) {
    if (action==NSSelectorFromString(@"wc_localEditText:")) return WCLocalEditable(cell,NO);
    if (action==NSSelectorFromString(@"wc_localEditTransfer:")) return WCLocalEditable(cell,YES);
    if (action==NSSelectorFromString(@"wc_localRestoreEdit:")) { id wrap=WCGestureMessageWrapForCell(cell); return wrap && [WCLocalEditRecords() objectForKey:wrap]!=nil; }
    return NO;
}
NSArray *WCGestureLocalEditMenuItems(UIView *cell, NSArray *items) {
    if (![items isKindOfClass:NSArray.class]) return items;
    NSMutableArray *result=[items mutableCopy];
    NSArray *rows=@[@[@"修改本机文字",@"square.and.pencil",@"wc_localEditText:"],@[@"修改显示金额",@"number",@"wc_localEditTransfer:"],@[@"恢复原始内容",@"arrow.uturn.backward",@"wc_localRestoreEdit:"]];
    for (NSArray *row in rows) {
        SEL action=NSSelectorFromString(row[2]); if (!WCGestureLocalEditAllowsAction(cell,action)) continue;
        id item=WCGestureLocalChatMenuItem(cell,row[0],row[1],action);if(item)[result addObject:item];
    }return result;
}
static void WCLocalRestore(WCLocalEditRecord *record) {
    id wrap=record.wrap; if (!wrap) return;
    if ([WCTweakSafeValue(wrap,@"m_nsContent") isEqualToString:record.replacement]) {
        WCTweakSetValue(wrap,@"m_nsContent",record.original);
        if ([record.identity isEqualToString:WCGestureLocalChatIdentity(record.cell)]) WCGestureLocalChatRefreshCell(record.cell);
    }
    [WCLocalEditRecords() removeObjectForKey:wrap];
}
void WCGestureLocalEditPerform(UIView *cell, BOOL transfer, BOOL restore) {
    id wrap=WCGestureMessageWrapForCell(cell); if (!cell.window || !wrap) return;
    WCLocalEditRecord *record=[WCLocalEditRecords() objectForKey:wrap];
    if (restore) { if(record)WCLocalRestore(record); return; }
    if (!WCLocalEditable(cell,transfer)) return;
    NSString *identity=WCGestureLocalChatIdentity(cell), *original=WCTweakSafeValue(wrap,@"m_nsContent");
    if (![original isKindOfClass:NSString.class]) return;
    NSRange range=transfer ? WCLocalTransferRange(original) : NSMakeRange(0,original.length);
    if (range.location==NSNotFound) { WCShowToast(@"这条转账卡片暂不支持修改显示");return; }
    NSString *value=[original substringWithRange:range];
    if (transfer) value=[value stringByTrimmingCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet]];
    __weak UIView *weakCell=cell;
    [WCPopup showInputWithTitle:transfer ? @"修改本机显示金额" : @"修改本机文字" message:nil text:value
        placeholder:transfer ? @"例如 88.88" : @"消息文字" keyboard:transfer ? UIKeyboardTypeDecimalPad : UIKeyboardTypeDefault completion:^(NSString *text) {
        UIView *target=weakCell;
        if (!target.window || ![identity isEqualToString:WCGestureLocalChatIdentity(target)] || !WCLocalEditable(target,transfer) ||
            ![WCTweakSafeValue(wrap,@"m_nsContent") isEqualToString:original]) { WCShowToast(@"消息已变化，未修改");return; }
        NSString *replacement=text ?: @"";
        if (transfer) {
            NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,10}([.][0-9]{1,2})?$" options:0 error:nil];
            if ([regex numberOfMatchesInString:replacement options:0 range:NSMakeRange(0,replacement.length)]!=1) { WCShowToast(@"请输入最多两位小数的金额");return; }
            NSDecimalNumber *fen=[[NSDecimalNumber decimalNumberWithString:replacement locale:@{@"NSLocaleDecimalSeparator":@"."}] decimalNumberByMultiplyingByPowerOf10:2];
            unsigned long long cents=fen.unsignedLongLongValue;
            replacement=[NSString stringWithFormat:@"¥%llu.%02llu",cents/100,cents%100];
            replacement=[original stringByReplacingCharactersInRange:range withString:replacement];
        }
        WCLocalEditRecord *saved=[WCLocalEditRecords() objectForKey:wrap];
        if (!saved) { saved=[WCLocalEditRecord new];saved.wrap=wrap;saved.original=original;saved.identity=identity;saved.transfer=transfer; }
        saved.cell=target;saved.replacement=replacement;
        WCTweakSetValue(wrap,@"m_nsContent",replacement); [WCLocalEditRecords() setObject:saved forKey:wrap];
        WCGestureLocalChatRefreshCell(target);
    }];
}
void WCGestureLocalEditSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.local-chat."]) return;
    for (UIView *cell in WCLocalTimeCells().allObjects) WCGestureLocalTimeLayout(cell);
    for (WCLocalEditRecord *record in WCLocalEditRecords().objectEnumerator.allObjects)
        if (![record.identity hasPrefix:[(WCCurrentUserWXID() ?: @"") stringByAppendingString:@"|"]] || !WCGestureEnabled(record.transfer ? WCGestureTransferDisplayEditEnabledKey : WCGestureTextEditEnabledKey)) WCLocalRestore(record);
}
void WCGestureLocalEditLeaving(UIViewController *controller) {
    for (UIView *cell in WCLocalTimeCells().allObjects) if (WCViewControllerForResponder(cell)==controller) WCGestureLocalTimeReset(cell);
    NSString *prefix=[NSString stringWithFormat:@"%@|%@|",WCCurrentUserWXID() ?: @"",WCGestureLocalChatSession(controller)];
    for (WCLocalEditRecord *record in WCLocalEditRecords().objectEnumerator.allObjects)
        if ([record.identity hasPrefix:prefix] || WCViewControllerForResponder(record.cell)==controller) WCLocalRestore(record);
}

@interface WCLocalTimeState : NSObject
@property (nonatomic,weak) UILabel *label;
@property (nonatomic,weak) id model;
@property (nonatomic,copy) NSString *account;
@property (nonatomic,copy) NSAttributedString *original;
@property (nonatomic,copy) NSString *replacement;
@property (nonatomic,strong) UILongPressGestureRecognizer *gesture;
@property (nonatomic) BOOL originalInteraction;
@end
@implementation WCLocalTimeState
@end
static char WCLocalTimeKey;
static NSHashTable *WCLocalTimeCells(void) { static NSHashTable *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSHashTable weakObjectsHashTable];});return v; }
void WCGestureLocalTimeReset(UIView *cell) {
    WCLocalTimeState *state=objc_getAssociatedObject(cell,&WCLocalTimeKey);if(!state)return;
    if (state.model==WCTweakSafeValue(cell,@"viewModel") && [state.account isEqualToString:WCCurrentUserWXID() ?: @""] &&
        [state.label.text isEqualToString:state.replacement]) state.label.attributedText=state.original;
    if (cell.userInteractionEnabled) cell.userInteractionEnabled=state.originalInteraction;
    [cell removeGestureRecognizer:state.gesture];objc_setAssociatedObject(cell,&WCLocalTimeKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void WCGestureLocalTimeLayout(UIView *cell) {
    [WCLocalTimeCells() addObject:cell];id label=WCTweakSafeValue(cell,@"m_timeLabel"),model=WCTweakSafeValue(cell,@"viewModel");
    WCLocalTimeState *state=objc_getAssociatedObject(cell,&WCLocalTimeKey);
    if (!cell.window || !WCGestureEnabled(WCGestureTimeEditEnabledKey) || ![label isKindOfClass:UILabel.class] || !model) { WCGestureLocalTimeReset(cell);return; }
    if (state && (state.model!=model || state.label!=label || ![state.account isEqualToString:WCCurrentUserWXID() ?: @""])) { WCGestureLocalTimeReset(cell);state=nil; }
    if (!state) {
        state=[WCLocalTimeState new];state.originalInteraction=cell.userInteractionEnabled;state.model=model;state.label=label;state.account=WCCurrentUserWXID() ?: @"";
        state.gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:cell action:NSSelectorFromString(@"wc_editLocalTime:")];
        state.gesture.minimumPressDuration=.55;[cell addGestureRecognizer:state.gesture];objc_setAssociatedObject(cell,&WCLocalTimeKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    cell.userInteractionEnabled=YES;
    if (state.replacement) {
        if (![state.label.text isEqualToString:state.replacement]) state.original=state.label.attributedText ?: [[NSAttributedString alloc] initWithString:state.label.text ?: @""];
        state.label.text=state.replacement;
    }
}
void WCGestureLocalTimeLongPress(UIView *cell, UILongPressGestureRecognizer *gesture) {
    if (gesture.state!=UIGestureRecognizerStateBegan || !WCGestureEnabled(WCGestureTimeEditEnabledKey))return;
    WCLocalTimeState *state=objc_getAssociatedObject(cell,&WCLocalTimeKey); if(!state)return;
    NSString *account=state.account;id model=state.model;__weak UIView *weakCell=cell;
    [WCPopup showInputWithTitle:@"修改本机时间显示" message:nil text:state.label.text placeholder:@"时间文字；留空恢复原始显示" keyboard:UIKeyboardTypeDefault completion:^(NSString *text) {
        UIView *target=weakCell;if(!target.window || model!=WCTweakSafeValue(target,@"viewModel") || ![account isEqualToString:WCCurrentUserWXID() ?: @""] || !WCGestureEnabled(WCGestureTimeEditEnabledKey))return;
        if(!text.length){WCGestureLocalTimeReset(target);WCGestureLocalTimeLayout(target);return;}
        if(!state.replacement)state.original=state.label.attributedText ?: [[NSAttributedString alloc] initWithString:state.label.text ?: @""];
        state.replacement=text;state.label.text=text;
    }];
}
