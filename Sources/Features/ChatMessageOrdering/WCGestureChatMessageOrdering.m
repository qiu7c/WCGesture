#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
extern void MSHookMessageEx(Class,SEL,IMP,IMP *);
@interface WCChatSortState : NSObject
@property(nonatomic,strong) NSMutableArray *nodes;
@property(nonatomic,weak) UITableView *table;
@property(nonatomic,strong) UIButton *finish;
@property(nonatomic,copy) NSString *account;
@property(nonatomic) BOOL allowsSelection;
@end
@implementation WCChatSortState
@end
static char WCChatSortKey;
static NSHashTable *WCChatSortControllers(void){static NSHashTable *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSHashTable weakObjectsHashTable];});return v;}
static UITableView *WCChatSortTable(id controller){id table=WCTweakValueForSelectorNames(controller,@[@"m_tableView",@"tableView"]);if(![table isKindOfClass:UITableView.class])table=WCTweakSafeValue(controller,@"m_tableView");return [table isKindOfClass:UITableView.class]?table:nil;}
static NSInteger WCChatSortIndex(id owner,NSIndexPath *path){
    WCChatSortState *state=objc_getAssociatedObject(owner,&WCChatSortKey);
    if(!path || path.section<0 || path.row<0 || !state || ![state.account isEqualToString:WCCurrentUserWXID() ?: @""] || !WCGestureEnabled(WCGestureChatSortEnabledKey) ||
        WCTweakSafeValue(owner,@"m_arrMessageNodeData")!=state.nodes)return NSNotFound;
    UITableView *table=state.table;NSUInteger count=state.nodes.count;
    if(table.numberOfSections==(NSInteger)count && path.row==0 && path.section<(NSInteger)count)return path.section;
    if(table.numberOfSections==1 && [table numberOfRowsInSection:0]==(NSInteger)count && path.section==0 && path.row<(NSInteger)count)return path.row;
    return NSNotFound;
}
static BOOL WCChatSortHasWrap(id node){
    for(NSString *key in @[@"messageWrap",@"m_msgWrap",@"m_messageWrap"]){id wrap=WCTweakSafeValue(node,key);if([WCTweakSafeValue(wrap,@"m_uiMessageType") integerValue]>0)return YES;}
    return [WCTweakSafeValue(node,@"m_uiMessageType") integerValue]>0;
}
static BOOL (*WCChatSortOrigCanMove)(id,SEL,id,id);
static void (*WCChatSortOrigMove)(id,SEL,id,id,id);
static id (*WCChatSortOrigTarget)(id,SEL,id,id,id);
static NSInteger (*WCChatSortOrigStyle)(id,SEL,id,id);
static BOOL WCChatSortCanMove(id self,SEL cmd,id table,NSIndexPath *path){
    WCChatSortState *state=objc_getAssociatedObject(self,&WCChatSortKey);
    if(!state)return WCChatSortOrigCanMove?WCChatSortOrigCanMove(self,cmd,table,path):NO;
    NSInteger index=WCChatSortIndex(self,path);return index!=NSNotFound && index>=0 && index<(NSInteger)state.nodes.count && WCChatSortHasWrap(state.nodes[index]);
}
static id WCChatSortTarget(id self,SEL cmd,id table,NSIndexPath *from,NSIndexPath *to){
    if(!objc_getAssociatedObject(self,&WCChatSortKey))return WCChatSortOrigTarget?WCChatSortOrigTarget(self,cmd,table,from,to):to;
    return WCChatSortCanMove(self,cmd,table,to)?to:from;
}
static NSInteger WCChatSortStyle(id self,SEL cmd,id table,id path){
    return objc_getAssociatedObject(self,&WCChatSortKey)?UITableViewCellEditingStyleNone:(WCChatSortOrigStyle?WCChatSortOrigStyle(self,cmd,table,path):UITableViewCellEditingStyleDelete);
}
static void WCChatSortMove(id self,SEL cmd,id table,NSIndexPath *from,NSIndexPath *to){
    WCChatSortState *state=objc_getAssociatedObject(self,&WCChatSortKey);
    if(!state){if(WCChatSortOrigMove)WCChatSortOrigMove(self,cmd,table,from,to);return;}
    NSInteger first=WCChatSortIndex(self,from),last=WCChatSortIndex(self,to);
    if(first==NSNotFound || last==NSNotFound || first<0 || last<0 || first>=(NSInteger)state.nodes.count || last>=(NSInteger)state.nodes.count)return;
    if(!WCChatSortHasWrap(state.nodes[first]) || !WCChatSortHasWrap(state.nodes[last]))return;
    id node=state.nodes[first];[state.nodes removeObjectAtIndex:first];[state.nodes insertObject:node atIndex:last];
    __weak UITableView *weakTable=table;dispatch_async(dispatch_get_main_queue(),^{[weakTable reloadData];});
}
void WCGestureChatSortInstall(void){
    static dispatch_once_t once;dispatch_once(&once,^{
        Class cls=NSClassFromString(@"BaseMsgContentViewController");if(!cls)return;
        NSArray *names=@[@"tableView:canMoveRowAtIndexPath:",@"tableView:moveRowAtIndexPath:toIndexPath:",@"tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:",@"tableView:editingStyleForRowAtIndexPath:"];
        IMP replacements[]={(IMP)WCChatSortCanMove,(IMP)WCChatSortMove,(IMP)WCChatSortTarget,(IMP)WCChatSortStyle};
        IMP *originals[]={(IMP *)&WCChatSortOrigCanMove,(IMP *)&WCChatSortOrigMove,(IMP *)&WCChatSortOrigTarget,(IMP *)&WCChatSortOrigStyle};
        const char *types[]={"B@:@@","v@:@@@","@@:@@@","q@:@@"};
        for(NSUInteger i=0;i<names.count;i++){SEL selector=NSSelectorFromString(names[i]);if(class_getInstanceMethod(cls,selector))MSHookMessageEx(cls,selector,replacements[i],originals[i]);else class_addMethod(cls,selector,replacements[i],types[i]);}
    });
}
BOOL WCGestureChatSortAllowsAction(UIView *cell,SEL action){return action==NSSelectorFromString(@"wc_toggleChatSort:") && WCGestureEnabled(WCGestureChatSortEnabledKey) && cell.window && WCGestureLocalChatIdentity(cell).length;}
NSArray *WCGestureChatSortMenuItems(UIView *cell,NSArray *items){
    SEL action=NSSelectorFromString(@"wc_toggleChatSort:");if(![items isKindOfClass:NSArray.class] || !WCGestureChatSortAllowsAction(cell,action))return items;
    BOOL sorting=objc_getAssociatedObject(WCViewControllerForResponder(cell),&WCChatSortKey)!=nil;
    id item=WCGestureLocalChatMenuItem(cell,sorting?@"结束排序":@"排序",@"arrow.up.arrow.down",action);return item?[items arrayByAddingObject:item]:items;
}
void WCGestureChatSortEnd(UIViewController *controller){
    WCChatSortState *state=objc_getAssociatedObject(controller,&WCChatSortKey);if(!state)return;
    objc_setAssociatedObject(controller,&WCChatSortKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [state.finish removeFromSuperview];state.table.allowsSelectionDuringEditing=state.allowsSelection;[state.table setEditing:NO animated:YES];
}
void WCGestureChatSortToggle(UIView *cell){
    UIViewController *controller=WCViewControllerForResponder(cell);if(!WCGestureChatSortAllowsAction(cell,NSSelectorFromString(@"wc_toggleChatSort:")))return;
    if(objc_getAssociatedObject(controller,&WCChatSortKey)){WCGestureChatSortEnd(controller);return;}
    UITableView *table=WCChatSortTable(controller);id nodes=WCTweakSafeValue(controller,@"m_arrMessageNodeData");
    if(table.editing){WCShowToast(@"请先退出微信多选模式");return;}
    if(!table || ![nodes isKindOfClass:NSArray.class] || [nodes count]<2){WCShowToast(@"当前聊天列表暂不支持排序");return;}
    if(![nodes isKindOfClass:NSMutableArray.class]){nodes=[nodes mutableCopy];WCTweakSetValue(controller,@"m_arrMessageNodeData",nodes);}
    if(WCTweakSafeValue(controller,@"m_arrMessageNodeData")!=nodes || !((NSUInteger)table.numberOfSections==[nodes count] || (table.numberOfSections==1 && (NSUInteger)[table numberOfRowsInSection:0]==[nodes count]))){WCShowToast(@"当前版本的聊天节点结构不匹配");return;}
    WCChatSortState *state=[WCChatSortState new];state.nodes=nodes;state.table=table;state.account=WCCurrentUserWXID() ?: @"";state.allowsSelection=table.allowsSelectionDuringEditing;
    objc_setAssociatedObject(controller,&WCChatSortKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[WCChatSortControllers() addObject:controller];
    UIButton *done=[UIButton buttonWithType:UIButtonTypeSystem];[done setTitle:@"完成排序" forState:UIControlStateNormal];done.backgroundColor=UIColor.secondarySystemBackgroundColor;done.layer.cornerRadius=14;
    done.frame=CGRectMake(MAX(12,controller.view.bounds.size.width-112),controller.view.safeAreaInsets.top+52,100,32);done.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin;
    __weak UIViewController *weakController=controller;[done addAction:[UIAction actionWithHandler:^(__unused UIAction *action){WCGestureChatSortEnd(weakController);}] forControlEvents:UIControlEventTouchUpInside];
    state.finish=done;[controller.view addSubview:done];table.allowsSelectionDuringEditing=YES;[table setEditing:YES animated:YES];
}
void WCGestureChatSortSettingsChanged(NSString *key){if(key && ![key isEqualToString:WCGestureChatSortEnabledKey] && ![key isEqualToString:WCGestureEnabledKey])return;for(UIViewController *c in WCChatSortControllers().allObjects)if(!WCGestureEnabled(WCGestureChatSortEnabledKey) || ![((WCChatSortState *)objc_getAssociatedObject(c,&WCChatSortKey)).account isEqualToString:WCCurrentUserWXID() ?: @""])WCGestureChatSortEnd(c);}
