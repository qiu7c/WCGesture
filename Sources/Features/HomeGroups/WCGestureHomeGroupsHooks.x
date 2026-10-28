#import "Sources/API/WCGestureInternal.h"

%hook NewMainFrameViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    WCGestureHomeGroupsAttach((UIViewController *)self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    WCGestureHomeGroupsAttach((UIViewController *)self);
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
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
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
    return (unsigned int)(WCGestureHomeGroupsSection(self,0).count + WCGestureHomeGroupsSection(self,1).count);
}
- (unsigned int)getVisibleSessionCount {
    if (WCGestureHomeGroupsNative() || !WCGestureHomeGroupsEnabled()) return %orig;
    return (unsigned int)(WCGestureHomeGroupsSection(self,0).count + WCGestureHomeGroupsSection(self,1).count);
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
    for (NSInteger section=0;section<path.section;section++) count += WCGestureHomeGroupsSection(self,section).count;
    return count;
}
- (void)onMainSessionReload {
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onSessionRebuildEnd {
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onNeedRebuild {
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onSessionChanged:(id)session {
    WCGestureHomeGroupsBeginNative();
    %orig(session);
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onNewMsgArriving:(id)message NotifyFlag:(long long)flag {
    WCGestureHomeGroupsBeginNative();
    %orig(message,flag);
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onDeleteSession:(unsigned int)index withUser:(id)user {
    WCGestureHomeGroupsBeginNative();
    %orig(index,user);
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)onHideSessionWithUserName:(id)user {
    WCGestureHomeGroupsBeginNative();
    %orig(user);
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)OnChangeGroup:(id)group {
    WCGestureHomeGroupsBeginNative();
    %orig(group);
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)OnChangeNotifyStatus:(id)user withStatus:(BOOL)status {
    WCGestureHomeGroupsBeginNative();
    %orig(user,status);
    WCGestureHomeGroupsEndNative();
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
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)updateMainSessionListNotify:(BOOL)notify {
    WCGestureHomeGroupsBeginNative();
    %orig(notify);
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
- (void)rebuildMainSessions {
    WCGestureHomeGroupsBeginNative();
    %orig;
    WCGestureHomeGroupsEndNative();
    WCGestureHomeGroupsInvalidate(self);
}
%end

%ctor {
    %init;
}
