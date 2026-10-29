#import "Sources/API/WCGestureInternal.h"

%hook NewMainFrameViewController
- (void)tableView:(UITableView *)table willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {
    %orig(table,cell,path);
    WCGestureHomeGroupsStyleCell((UIViewController *)self,cell,path);
    WCGestureHomePageCornerLayoutCell(cell);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    WCGestureHomeGroupsAttach((UIViewController *)self);
    WCGestureHomePageCornerAttach((UIViewController *)self);
}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    CGFloat original=%orig(table,section);
    return WCGestureHomePageCornerHeaderHeight(table,section,original);
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    UIView *original=%orig(table,section);
    return WCGestureHomePageCornerHeaderView(table,section,original);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    WCGestureHomeGroupsDidAppear((UIViewController *)self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    WCGestureHomeGroupsAttach((UIViewController *)self);
    WCGestureHomePageCornerAttach((UIViewController *)self);
}
%end

%hook MainFrameLogicController
- (BOOL)isTopSessionFolding {
    if (WCGestureHomeGroupsEnabled()) return NO;
    return %orig;
}
- (BOOL)canFoldTopSession {
    if (WCGestureHomeGroupsEnabled()) return NO;
    return %orig;
}
- (void)setReadyToLoadData {
    WCGestureHomeGroupsInvalidate(self);
    %orig;
    WCGestureHomeGroupsInvalidate(self);
}
- (id)getSessionBaseInfoAtIndexPath:(NSIndexPath *)path {
    NSIndexPath *native=WCGestureHomeGroupsNativePath(self,path);
    WCGestureHomeGroupsBeginNative();
    id result=%orig(native);
    WCGestureHomeGroupsEndNative();
    return result;
}
- (long long)getSessionCountForSection:(long long)section {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig(section);
    return (long long)WCGestureHomeGroupsSection(self, section).count;
}
- (unsigned int)getSessionCount {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig;
    return (unsigned int)(WCGestureHomeGroupsSection(self,1).count + WCGestureHomeGroupsSection(self,2).count);
}
- (unsigned int)getVisibleSessionCount {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig;
    return (unsigned int)(WCGestureHomeGroupsSection(self,1).count + WCGestureHomeGroupsSection(self,2).count);
}
- (id)getSessionInfoAtIndexPath:(NSIndexPath *)path {
    NSIndexPath *native = WCGestureHomeGroupsNativePath(self, path);
    WCGestureHomeGroupsBeginNative();
    id result = %orig(native);
    WCGestureHomeGroupsEndNative();
    return result;
}
- (id)getCellDataAtIndexPath:(NSIndexPath *)path {
    NSIndexPath *native = WCGestureHomeGroupsNativePath(self, path);
    WCGestureHomeGroupsBeginNative();
    id result = %orig(native);
    WCGestureHomeGroupsEndNative();
    return result;
}
- (id)indexPathOfSessionUserName:(NSString *)user {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig(user);
    return WCGestureHomeGroupsFind(self,user);
}
- (long long)indexOfSessionUserName:(NSString *)user inSection:(long long)section {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig(user,section);
    NSIndexPath *path = WCGestureHomeGroupsFind(self,user);
    return path && path.section == section ? path.row : NSNotFound;
}
- (long long)indexInAllVisibleSessions:(NSString *)user {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig(user);
    NSIndexPath *path = WCGestureHomeGroupsFind(self,user);
    if (!path) return NSNotFound;
    NSUInteger count = path.row;
    for (NSInteger section=1;section<path.section;section++) count += WCGestureHomeGroupsSection(self,section).count;
    return count;
}
- (void)onMainSessionReload {
    WCGestureHomeGroupsInvalidate(self);
    %orig;
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onSessionRebuildEnd {
    WCGestureHomeGroupsInvalidate(self);
    %orig;
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onNeedRebuild {
    WCGestureHomeGroupsInvalidate(self);
    %orig;
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onSessionChanged:(id)session {
    WCGestureHomeGroupsInvalidate(self);
    %orig(session);
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onNewMsgArriving:(id)message NotifyFlag:(long long)flag {
    WCGestureHomeGroupsInvalidate(self);
    %orig(message,flag);
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onDeleteSession:(unsigned int)index withUser:(id)user {
    WCGestureHomeGroupsInvalidate(self);
    %orig(index,user);
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onHideSessionWithUserName:(id)user {
    WCGestureHomeGroupsInvalidate(self);
    %orig(user);
    WCGestureHomeGroupsInvalidate(self);
}
- (void)OnChangeGroup:(id)group {
    WCGestureHomeGroupsInvalidate(self);
    %orig(group);
    WCGestureHomeGroupsInvalidate(self);
}
- (void)OnChangeNotifyStatus:(id)user withStatus:(BOOL)status {
    WCGestureHomeGroupsInvalidate(self);
    %orig(user,status);
    WCGestureHomeGroupsInvalidate(self);
}
%end

%hook CMessageMgr
- (void)onNewSyncAddMessage:(id)wrap {
    %orig(wrap);
    WCGestureHomeGroupsMessageAdded(nil,wrap,NO);
}
- (void)AddLocalMsg:(id)user MsgWrap:(id)wrap {
    %orig(user,wrap);
    WCGestureHomeGroupsMessageAdded(user,wrap,YES);
}
- (void)AddLocalMsg:(id)user MsgWrap:(id)wrap fixTime:(BOOL)fixTime NewMsgArriveNotify:(BOOL)notify {
    %orig(user,wrap,fixTime,notify);
    WCGestureHomeGroupsMessageAdded(user,wrap,YES);
}
- (void)AsyncOnAddMsg:(id)user MsgWrap:(id)wrap {
    %orig(user,wrap);
    WCGestureHomeGroupsMessageAdded(user,wrap,NO);
}
%end

%hook MainSessionMgr
- (BOOL)isFoldTopSession {
    if (WCGestureHomeGroupsEnabled()) return NO;
    return %orig;
}
- (void)updateMainSessionList {
    WCGestureHomeGroupsInvalidate(self);
    %orig;
    WCGestureHomeGroupsInvalidate(self);
}
- (void)updateMainSessionListNotify:(BOOL)notify {
    WCGestureHomeGroupsInvalidate(self);
    %orig(notify);
    WCGestureHomeGroupsInvalidate(self);
}
- (void)rebuildMainSessions {
    WCGestureHomeGroupsInvalidate(self);
    %orig;
    WCGestureHomeGroupsInvalidate(self);
}
%end

%ctor {
    %init;
}
