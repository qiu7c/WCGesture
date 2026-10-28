#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
@interface WCLocalEditRecord : NSObject
@property (nonatomic,weak) id wrap;
@property (nonatomic,weak) UIView *cell;
@property (nonatomic,copy) NSString *identity;
@property (nonatomic,copy) NSString *original;
@property (nonatomic,copy) NSString *replacement;
@property (nonatomic) BOOL transfer;
@property (nonatomic) BOOL card;
@property (nonatomic,strong) NSMutableDictionary<NSString *, NSString *> *originalFields;
@property (nonatomic,strong) NSMutableDictionary<NSString *, NSString *> *replacementFields;
@end
@implementation WCLocalEditRecord
@end
static NSHashTable *WCLocalTimeCells(void);
// Native refreshes can replace both the wrap and the visible cell. Keep the
// original content under the message identity, rather than a weak wrap key.
static NSMutableDictionary<NSString *, WCLocalEditRecord *> *WCLocalEditRecords(void) {
    static NSMutableDictionary *records; static dispatch_once_t once;
    dispatch_once(&once,^{ records=[NSMutableDictionary dictionary]; });return records;
}
static BOOL WCLocalTransfer(UIView *cell) {
    Class cls=NSClassFromString(@"WCPayTransferMessageCellView"); return cls && [cell isKindOfClass:cls];
}
// AppRecord field path is verified in Xiaowei DEEP_EDIT.md (0x9def0/0x9e060).
static id WCLocalCardItem(id wrap) {
    return WCTweakSafeValue(WCTweakSafeValue(wrap,@"m_extendInfoWithMsgType"),@"m_oRecordItem");
}
static BOOL WCLocalCardCell(UIView *cell) {
    Class cls=NSClassFromString(@"AppRecordMessageCellView");
    return cls && [cell isKindOfClass:cls];
}
static void WCLocalCardPerform(UIView *cell);
static BOOL WCLocalEditable(UIView *cell, BOOL transfer) {
    id wrap=WCGestureMessageWrapForCell(cell);
    if (!transfer && WCLocalCardCell(cell)) return WCGestureLocalChatIdentity(cell).length && WCLocalCardItem(wrap) && WCGestureEnabled(WCGestureRecordCardEditEnabledKey);
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
    if (action==NSSelectorFromString(@"wc_localRestoreEdit:")) {
        WCLocalEditRecord *record=WCLocalEditRecords()[WCGestureLocalChatIdentity(cell)];
        return record && WCLocalEditable(cell,record.transfer);
    }
    return NO;
}
NSArray *WCGestureLocalEditMenuItems(UIView *cell, NSArray *items) {
    if (![items isKindOfClass:NSArray.class]) return items;
    NSMutableArray *result=[items mutableCopy];
    NSArray *rows=@[@[@"修改",@"square.and.pencil",@"wc_localEditText:"],@[@"修改",@"number",@"wc_localEditTransfer:"],@[@"恢复",@"arrow.uturn.backward",@"wc_localRestoreEdit:"]];
    for (NSArray *row in rows) {
        SEL action=NSSelectorFromString(row[2]); if (!WCGestureLocalEditAllowsAction(cell,action)) continue;
        id item=WCGestureLocalChatMenuItem(cell,row[0],row[1],action);if(item)[result addObject:item];
    }return result;
}
static void WCLocalRestore(WCLocalEditRecord *record, UIView *preferredCell) {
    if (!record) return;
    UIView *cell=preferredCell ?: record.cell;
    BOOL sameCell=[record.identity isEqualToString:WCGestureLocalChatIdentity(cell)];
    id current=sameCell ? WCGestureMessageWrapForCell(cell) : nil;
    id previous=record.wrap;
    if (record.card) {
        NSMutableArray *items=[NSMutableArray array];
        id oldItem=WCLocalCardItem(previous),currentItem=WCLocalCardItem(current);
        if (oldItem) [items addObject:oldItem];
        if (currentItem && currentItem!=oldItem) [items addObject:currentItem];
        for (id item in items) for (NSString *field in record.replacementFields) {
            if ([WCTweakSafeValue(item,field) isEqual:record.replacementFields[field]]) WCTweakSetValue(item,field,record.originalFields[field]);
        }
        if (sameCell) WCGestureLocalChatRefreshCell(cell);
        if (WCLocalEditRecords()[record.identity]==record) [WCLocalEditRecords() removeObjectForKey:record.identity];
        return;
    }
    // Restore only content still owned by this edit. A replacement native wrap
    // needs its own assignment even when the previously captured wrap is gone.
    if ([WCTweakSafeValue(previous,@"m_nsContent") isEqualToString:record.replacement])
        WCTweakSetValue(previous,@"m_nsContent",record.original);
    NSString *content=WCTweakSafeValue(current,@"m_nsContent");
    if ([content isEqualToString:record.replacement]) {
        WCTweakSetValue(current,@"m_nsContent",record.original);
        content=WCTweakSafeValue(current,@"m_nsContent");
    }
    if (sameCell && [content isEqualToString:record.original]) {
        // Refresh the cell pressed now, not the old weak cell saved by Modify.
        WCGestureLocalChatRefreshCell(cell);
    }
    if (WCLocalEditRecords()[record.identity]==record) [WCLocalEditRecords() removeObjectForKey:record.identity];
}
void WCGestureLocalEditRestore(UIView *cell) {
    if (!cell.window) return;
    WCLocalEditRecord *record=WCLocalEditRecords()[WCGestureLocalChatIdentity(cell)];
    if (!record || !WCLocalEditable(cell,record.transfer)) return;
    WCLocalRestore(record,cell);
}
void WCGestureLocalEditPerform(UIView *cell, BOOL transfer) {
    id wrap=WCGestureMessageWrapForCell(cell); if (!cell.window || !wrap) return;
    if (!WCLocalEditable(cell,transfer)) return;
    if (!transfer && WCLocalCardCell(cell)) { WCLocalCardPerform(cell); return; }
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
        id current=WCGestureMessageWrapForCell(target);
        if (!target.window || ![identity isEqualToString:WCGestureLocalChatIdentity(target)] || !WCLocalEditable(target,transfer) ||
            ![WCTweakSafeValue(current,@"m_nsContent") isEqualToString:original]) { WCShowToast(@"消息已变化，未修改");return; }
        NSString *replacement=text ?: @"";
        if (transfer) {
            NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,10}([.][0-9]{1,2})?$" options:0 error:nil];
            if ([regex numberOfMatchesInString:replacement options:0 range:NSMakeRange(0,replacement.length)]!=1) { WCShowToast(@"请输入最多两位小数的金额");return; }
            NSDecimalNumber *fen=[[NSDecimalNumber decimalNumberWithString:replacement locale:@{@"NSLocaleDecimalSeparator":@"."}] decimalNumberByMultiplyingByPowerOf10:2];
            unsigned long long cents=fen.unsignedLongLongValue;
            replacement=[NSString stringWithFormat:@"¥%llu.%02llu",cents/100,cents%100];
            replacement=[original stringByReplacingCharactersInRange:range withString:replacement];
        }
        WCLocalEditRecord *saved=WCLocalEditRecords()[identity];
        if (saved && ![original isEqualToString:saved.replacement]) saved=nil;
        if (!saved) { saved=[WCLocalEditRecord new];saved.original=original;saved.identity=identity;saved.transfer=transfer; }
        saved.wrap=current;saved.cell=target;saved.replacement=replacement;
        WCTweakSetValue(current,@"m_nsContent",replacement); WCLocalEditRecords()[identity]=saved;
        WCGestureLocalChatRefreshCell(target);
    }];
}
static void WCLocalCardPerform(UIView *cell) {
    NSString *identity=WCGestureLocalChatIdentity(cell);
    __weak UIView *weakCell=cell;
    [WCPopup showOptionsWithTitle:@"修改记录卡片" message:nil options:@[
        [WCPopupOption optionWithTitle:@"标题" value:@"title"],
        [WCPopupOption optionWithTitle:@"描述" value:@"desc"]] selected:nil completion:^(id selected) {
        NSString *field=selected;
        if (![@[@"title",@"desc"] containsObject:field]) return;
        UIView *target=weakCell;
        if (!target.window || ![identity isEqualToString:WCGestureLocalChatIdentity(target)] || !WCLocalEditable(target,NO)) return;
        NSString *original=WCTweakSafeValue(WCLocalCardItem(WCGestureMessageWrapForCell(target)),field);
        if (![original isKindOfClass:NSString.class]) { WCShowToast(@"当前卡片字段不可用"); return; }
        [WCPopup showInputWithTitle:[field isEqualToString:@"title"] ? @"修改标题" : @"修改描述"
            message:nil text:original placeholder:@"内容" keyboard:UIKeyboardTypeDefault completion:^(NSString *text) {
            UIView *currentCell=weakCell;id wrap=WCGestureMessageWrapForCell(currentCell);id item=WCLocalCardItem(wrap);
            if (!currentCell.window || ![identity isEqualToString:WCGestureLocalChatIdentity(currentCell)] || !WCLocalEditable(currentCell,NO) || ![WCTweakSafeValue(item,field) isEqual:original]) { WCShowToast(@"消息已变化，未修改"); return; }
            WCLocalEditRecord *record=WCLocalEditRecords()[identity];
            if (!record || !record.card) {
                record=[WCLocalEditRecord new];record.card=YES;record.identity=identity;
                record.originalFields=[NSMutableDictionary dictionary];record.replacementFields=[NSMutableDictionary dictionary];
            }
            if (!record.originalFields[field] || ![record.replacementFields[field] isEqual:original]) record.originalFields[field]=[original copy];
            WCTweakSetValue(item,field,text ?: @"");
            if (![WCTweakSafeValue(item,field) isEqual:text ?: @""]) { WCShowToast(@"卡片修改失败"); return; }
            record.replacementFields[field]=[text copy] ?: @"";record.wrap=wrap;record.cell=currentCell;
            WCLocalEditRecords()[identity]=record;WCGestureLocalChatRefreshCell(currentCell);
        }];
    }];
}
void WCGestureLocalEditSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.local-chat."]) return;
    for (UIView *cell in WCLocalTimeCells().allObjects) WCGestureLocalTimeLayout(cell);
    for (WCLocalEditRecord *record in WCLocalEditRecords().allValues)
        if (![record.identity hasPrefix:[(WCCurrentUserWXID() ?: @"") stringByAppendingString:@"|"]] || !WCGestureEnabled(record.card ? WCGestureRecordCardEditEnabledKey : (record.transfer ? WCGestureTransferDisplayEditEnabledKey : WCGestureTextEditEnabledKey))) WCLocalRestore(record,nil);
}
void WCGestureLocalEditLeaving(UIViewController *controller) {
    for (UIView *cell in WCLocalTimeCells().allObjects) if (WCViewControllerForResponder(cell)==controller) WCGestureLocalTimeReset(cell);
    NSString *prefix=[NSString stringWithFormat:@"%@|%@|",WCCurrentUserWXID() ?: @"",WCGestureLocalChatSession(controller)];
    for (WCLocalEditRecord *record in WCLocalEditRecords().allValues)
        if ([record.identity hasPrefix:prefix] || WCViewControllerForResponder(record.cell)==controller) WCLocalRestore(record,nil);
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
