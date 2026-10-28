#import <objc/runtime.h>
#import <math.h>
#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"

@protocol WCHomeSwipeContact <NSObject>
- (BOOL)isSilent;
- (BOOL)isChatStatusNotifyOpen;
- (void)setChatStatusNotifyOpen:(BOOL)value;
- (void)setChatRoomNotify:(BOOL)value;
- (void)setUpdateNotifyMuted:(BOOL)value;
- (void)setChatBoxStatus:(BOOL)value;
- (void)onTopSession:(BOOL)value;
@end
static IMP WCHomeSwipeOriginal;

static UIViewController *WCHomeSwipeInfo(id contact, BOOL group) {
    Class cls=NSClassFromString(group?@"ChatRoomInfoViewController":@"AddContactToChatRoomViewController");
    UIViewController *info=[[cls alloc] init];
    WCTweakSetValue(info,group?@"m_chatRoomContact":@"m_contact",contact);
    // Sample 0x1d7be4/0x1d7f24/0x1d82fc uses temporary native controllers,
    // not navigation. Loading view initializes their native setting logic.
    (void)info.view;return info;
}
static void WCHomeSwipeFinish(UIViewController *info, UITableView *table, id logic) {
    [info viewWillDisappear:YES];[info viewDidDisappear:YES];
    WCGestureHomeGroupsInvalidate(logic);if(!WCGestureHomeGroupsEnabled())[table reloadData];
}
static UISwipeActionsConfiguration *WCHomeSwipeBuild(UIViewController *controller, UITableView *table, NSIndexPath *path) {
    if (!WCGestureEnabled(WCGestureHomeSwipeEnabledKey)) return nil;
    UITableViewCell *cell=[table cellForRowAtIndexPath:path];
    if (![cell isKindOfClass:NSClassFromString(@"NewMainFrameCell")]) return nil;
    id data=WCTweakSafeValue(cell,@"m_cellData");
    NSString *user=WCGestureHomeGroupsUserName(data);
    if (!user.length) return nil;
    id contact=WCPrivateContact(user);if(!contact)return nil;
    BOOL group=[user hasSuffix:@"@chatroom"];
    id session=WCTweakSafeValue(data,@"m_sessionInfo");
    BOOL top=[WCTweakSafeValue(session,@"m_bIsTop") boolValue];
    BOOL silent=[contact respondsToSelector:@selector(isSilent)]?[(id<WCHomeSwipeContact>)contact isSilent]:NO;
    BOOL notify=[contact respondsToSelector:@selector(isChatStatusNotifyOpen)]?[(id<WCHomeSwipeContact>)contact isChatStatusNotifyOpen]:!silent;
    id logic=WCTweakSafeValue(controller,@"m_mainFrameLogicController");
    NSMutableArray *actions=[NSMutableArray array];
    UIContextualAction *remark=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"备注" handler:^(__unused UIContextualAction *action,__unused UIView *view,void(^done)(BOOL)){
        Class cls=NSClassFromString(group?@"ChatRoomRemarkEditViewController":@"NewRemarkViewController");
        UIViewController *editor=[[cls alloc] init];WCTweakSetValue(editor,group?@"chatRoomContact":@"m_contact",contact);
        if (editor) { editor.hidesBottomBarWhenPushed=YES;[controller.navigationController pushViewController:editor animated:YES]; }done(editor!=nil);
    }];remark.backgroundColor=UIColor.systemBlueColor;[actions addObject:remark];
    // Builder 0x1d60f0..: Moments excludes group, gh_, filehelper and weixin.
    if (!group && ![user hasPrefix:@"gh_"] && ![user isEqual:@"filehelper"] && ![user isEqual:@"weixin"]) {
        UIContextualAction *moments=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"朋友圈" handler:^(__unused UIContextualAction *action,__unused UIView *view,void(^done)(BOOL)){
            Class cls=NSClassFromString(@"WCListViewController");UIViewController *page=[[cls alloc] init];WCTweakSetValue(page,@"m_contact",contact);
            if(page){page.hidesBottomBarWhenPushed=YES;[controller.navigationController pushViewController:page animated:YES];}done(page!=nil);
        }];moments.backgroundColor=UIColor.systemPurpleColor;[actions addObject:moments];
    }
    if (group) {
        UIContextualAction *fold=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"折叠群聊" handler:^(__unused UIContextualAction *action,__unused UIView *view,void(^done)(BOOL)){
            UIViewController *info=WCHomeSwipeInfo(contact,YES);BOOL supported=[info respondsToSelector:@selector(setChatBoxStatus:)];
            if(supported)[(id<WCHomeSwipeContact>)info setChatBoxStatus:YES];WCHomeSwipeFinish(info,table,logic);done(supported);
        }];fold.backgroundColor=UIColor.systemTealColor;[actions addObject:fold];
    }
    UIContextualAction *mute=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:silent?@"取消勿扰":@"勿扰" handler:^(__unused UIContextualAction *action,__unused UIView *view,void(^done)(BOOL)){
        if([contact respondsToSelector:@selector(setChatStatusNotifyOpen:)])[(id<WCHomeSwipeContact>)contact setChatStatusNotifyOpen:notify];
        if([contact respondsToSelector:@selector(setChatRoomNotify:)])[(id<WCHomeSwipeContact>)contact setChatRoomNotify:notify];
        UIViewController *info=WCHomeSwipeInfo(contact,group);BOOL supported=[info respondsToSelector:@selector(setUpdateNotifyMuted:)];
        if(supported)[(id<WCHomeSwipeContact>)info setUpdateNotifyMuted:!notify];WCHomeSwipeFinish(info,table,logic);done(supported);
    }];mute.backgroundColor=UIColor.systemOrangeColor;[actions addObject:mute];
    UIContextualAction *pin=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:top?@"取消置顶":@"置顶" handler:^(__unused UIContextualAction *action,__unused UIView *view,void(^done)(BOOL)){
        UIViewController *info=WCHomeSwipeInfo(contact,group);BOOL supported=[info respondsToSelector:@selector(onTopSession:)];
        if(supported)[(id<WCHomeSwipeContact>)info onTopSession:!top];WCHomeSwipeFinish(info,table,logic);done(supported);
    }];pin.backgroundColor=UIColor.systemIndigoColor;[actions addObject:pin];
    UISwipeActionsConfiguration *configuration=[UISwipeActionsConfiguration configurationWithActions:actions];configuration.performsFirstActionWithFullSwipe=NO;return configuration;
}
static id WCHomeSwipeLeading(id object,SEL selector,UITableView *table,NSIndexPath *path) {
    id config=WCHomeSwipeBuild(object,table,path);
    return config ?: (WCHomeSwipeOriginal?((id(*)(id,SEL,id,id))WCHomeSwipeOriginal)(object,selector,table,path):nil);
}
void WCGestureHomeSwipeInstall(void) {
    static dispatch_once_t once;dispatch_once(&once,^{
        Class cls=NSClassFromString(@"NewMainFrameViewController");SEL selector=NSSelectorFromString(@"tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:");
        Method method=class_getInstanceMethod(cls,selector);
        if (method) {
            WCHomeSwipeOriginal=method_getImplementation(method);
            if (!class_addMethod(cls,selector,(IMP)WCHomeSwipeLeading,method_getTypeEncoding(method))) method_setImplementation(class_getInstanceMethod(cls,selector),(IMP)WCHomeSwipeLeading);
        } else class_addMethod(cls,selector,(IMP)WCHomeSwipeLeading,"@@:@@");
    });
}
BOOL WCGestureHomeSwipeAllowsCellGesture(UIGestureRecognizer *gesture,UIView *cell) {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class]) return YES;
    CGPoint velocity=[(UIPanGestureRecognizer *)gesture velocityInView:cell];
    if (WCGestureHomeGroupsEnabled() && [NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsGestureKey]) {
        UITableView *table=nil;for(UIView *view=cell.superview;view;view=view.superview) if([view isKindOfClass:UITableView.class]) {table=(UITableView *)view;break;}
        CGFloat ratio=[NSUserDefaults.standardUserDefaults doubleForKey:WCGestureHomeGroupsGestureRatioKey]*0.5;
        CGFloat x=[gesture locationInView:table].x,width=table.bounds.size.width;
        if (table && (x<width*ratio || x>width*(1-ratio))) return NO;
    }
    return !WCGestureEnabled(WCGestureHomeSwipeEnabledKey) || !(velocity.x>0 && velocity.x>fabs(velocity.y));
}
