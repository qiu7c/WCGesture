#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

// Evidence: HomeCategories 0x3ab630..0x3bfd34. Rendering below uses UIKit
// rather than copying the sample's WebMM banner replacement.
@protocol WCHomeGroupsNative <NSObject>
- (long long)getSessionCountForSection:(long long)section;
- (id)getSessionInfoAtIndexPath:(NSIndexPath *)path;
- (BOOL)isChatroom;
- (BOOL)isOpenIMChatroom;
- (BOOL)isBrandContact;
- (BOOL)isOfficialContact;
- (BOOL)isEnterpriseBrand;
- (BOOL)isSingleChatSession;
- (BOOL)isWeixinSingleConatct;
- (BOOL)isSingleContactNotNecessarilyMM;
@end

static __thread NSUInteger WCGroupNativeDepth;
static NSUInteger WCGroupVersion = 1;
static NSArray<NSDictionary *> *WCGroupList;
static NSSet<NSString *> *WCGroupCustomMembers;
static __weak UIViewController *WCGroupMainController;
static BOOL WCGroupReloadPending;
static char WCGroupSectionsKey, WCGroupVersionKey, WCGroupAccountKey, WCGroupBannerKey;

BOOL WCGestureHomeGroupsEnabled(void) { return WCGestureEnabled(WCGestureHomeGroupsEnabledKey); }
BOOL WCGestureHomeGroupsNative(void) { return WCGroupNativeDepth != 0; }
void WCGestureHomeGroupsBeginNative(void) { WCGroupNativeDepth++; }
void WCGestureHomeGroupsEndNative(void) { WCGroupNativeDepth--; }

NSArray<NSDictionary *> *WCGestureHomeGroupsList(void) {
    if (WCGroupList) return WCGroupList;
    // Configuration import is the boundary; internal group dictionaries have
    // one normalized schema after this pass.
    id stored = [NSUserDefaults.standardUserDefaults objectForKey:WCGestureHomeGroupsListKey];
    NSMutableArray *groups = [NSMutableArray array];
    NSMutableSet *ids = [NSMutableSet set];
    NSMutableSet *members = [NSMutableSet set];
    NSSet *types = [NSSet setWithArray:@[@"all",@"friend",@"group",@"other",@"instant",@"custom"]];
    for (id item in [stored isKindOfClass:NSArray.class] ? stored : @[]) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSString *identifier = item[@"id"], *type = item[@"type"], *title = item[@"title"];
        if (![identifier isKindOfClass:NSString.class] || !identifier.length || [ids containsObject:identifier]
            || ![types containsObject:type] || ![title isKindOfClass:NSString.class] || !title.length) continue;
        NSMutableArray *names = [NSMutableArray array];
        for (id name in [item[@"members"] isKindOfClass:NSArray.class] ? item[@"members"] : @[])
            if ([name isKindOfClass:NSString.class] && [name length] && ![names containsObject:name]) [names addObject:name];
        [groups addObject:@{@"id":identifier,@"type":type,@"title":title,@"members":names}];
        [ids addObject:identifier];
        if ([type isEqual:@"custom"]) [members addObjectsFromArray:names];
    }
    if (!groups.count) [groups addObject:@{@"id":@"builtin.all",@"type":@"all",@"title":@"全部",@"members":@[]}];
    WCGroupList = [groups copy]; WCGroupCustomMembers = [members copy];
    return WCGroupList;
}
NSString *WCGestureHomeGroupsSelected(void) {
    NSString *selected = [NSUserDefaults.standardUserDefaults stringForKey:WCGestureHomeGroupsSelectedKey];
    for (NSDictionary *group in WCGestureHomeGroupsList()) if ([group[@"id"] isEqual:selected]) return selected;
    return WCGestureHomeGroupsList().firstObject[@"id"];
}
void WCGestureHomeGroupsSave(NSArray<NSDictionary *> *groups) {
    [NSUserDefaults.standardUserDefaults setObject:groups forKey:WCGestureHomeGroupsListKey];
    WCGestureHomeGroupsSettingsChanged(WCGestureHomeGroupsListKey);
    WCGestureSettingsPostChange(WCGestureHomeGroupsListKey);
}
void WCGestureHomeGroupsSelect(NSString *groupID) {
    [NSUserDefaults.standardUserDefaults setObject:groupID forKey:WCGestureHomeGroupsSelectedKey];
    WCGestureHomeGroupsSettingsChanged(WCGestureHomeGroupsSelectedKey);
}
static NSString *WCGroupName(id object, NSUInteger depth) {
    if (depth>3) return nil; // Original helper 0x3bb47c.
    if ([object isKindOfClass:NSString.class]) return [object length]?object:nil;
    for (NSString *key in @[@"m_nsUserName",@"m_nsUsrName",@"m_nsRealUsrName",@"userName",@"usrName",@"m_sessionInfo",@"sessionInfo",@"m_contact",@"contact",@"m_cellData",@"cellData"]) {
        SEL selector=NSSelectorFromString(key);
        if (![object respondsToSelector:selector]) continue;
        id value=((id(*)(id,SEL))objc_msgSend)(object,selector);
        if (value==object) continue;
        NSString *name=WCGroupName(value,depth+1);if(name.length)return name;
    }return nil;
}
NSString *WCGestureHomeGroupsUserName(id session) { return WCGroupName(session,0) ?: @""; }
static NSString *WCGroupSelf(void) {
    Class context=NSClassFromString(@"MMContext");SEL selector=NSSelectorFromString(@"currentUserName");
    NSString *name=[context respondsToSelector:selector]?((id(*)(id,SEL))objc_msgSend)(context,selector):nil;
    return name.length?name:(WCCurrentUserWXID() ?: @"");
}
static NSString *WCGroupAccount(void) {
    Class context=NSClassFromString(@"MMContext");SEL selector=NSSelectorFromString(@"currentUin");
    unsigned uin=[context respondsToSelector:selector]?((unsigned(*)(id,SEL))objc_msgSend)(context,selector):0;
    if (uin) return [NSString stringWithFormat:@"uin:%u",uin];
    NSString *user=WCGroupSelf();return user.length?[@"user:" stringByAppendingString:user]:@"";
}
static NSMutableSet *WCGroupPending(void) {
    NSString *account = WCGroupAccount();
    id all = [NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureHomeGroupsPendingKey];
    id names = all[account];
    return [NSMutableSet setWithArray:[names isKindOfClass:NSArray.class] ? names : @[]];
}
NSArray<NSString *> *WCGestureHomeGroupsPendingNames(void) { return [WCGroupPending().allObjects sortedArrayUsingSelector:@selector(compare:)]; }
static void WCGroupSavePending(NSSet *names, NSString *account) {
    if (!account.length) return;
    NSMutableDictionary *all=[[NSUserDefaults.standardUserDefaults dictionaryForKey:WCGestureHomeGroupsPendingKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (names.count) all[account]=[names.allObjects sortedArrayUsingSelector:@selector(compare:)];else [all removeObjectForKey:account];
    [NSUserDefaults.standardUserDefaults setObject:all forKey:WCGestureHomeGroupsPendingKey];
    WCGestureHomeGroupsSettingsChanged(WCGestureHomeGroupsPendingKey);
}
void WCGestureHomeGroupsSetPendingNames(NSArray<NSString *> *names) { WCGroupSavePending([NSSet setWithArray:names],WCGroupAccount()); }
static BOOL WCGroupFlag(id object, SEL selector) {
    return [object respondsToSelector:selector] && ((BOOL(*)(id,SEL))objc_msgSend)(object,selector);
}
static BOOL WCGroupMatches(id session, NSDictionary *group, NSSet *pending) {
    NSString *type=group[@"type"], *name=WCGestureHomeGroupsUserName(session);
    if ([type isEqual:@"all"]) return YES;
    BOOL instant=[type isEqual:@"instant"], inPending=[pending containsObject:name];
    BOOL hasInstant=NO;
    for (NSDictionary *item in WCGestureHomeGroupsList()) if ([item[@"type"] isEqual:@"instant"]) { hasInstant=YES;break; }
    if (instant || (hasInstant && inPending)) return instant && inPending;
    if ([type isEqual:@"custom"]) return [group[@"members"] containsObject:name];
    id contact=WCTweakSafeValue(session,@"m_contact") ?: WCPrivateContact(name);
    NSString *lower=name.lowercaseString;
    BOOL isGroup=[lower hasSuffix:@"@chatroom"] || [lower hasSuffix:@"@im.chatroom"]
        || WCGroupFlag(contact,@selector(isChatroom)) || WCGroupFlag(contact,@selector(isOpenIMChatroom));
    static NSSet *excluded;static dispatch_once_t once;
    dispatch_once(&once,^{ excluded=[NSSet setWithArray:@[@"filehelper",@"fmessage",@"medianote",@"newsapp",@"weixin",@"qqmail",@"tmessage",@"qmessage",@"floatbottle",@"lbsapp",@"shakeapp",@"masssendapp",@"feedsapp",@"voip",@"weixinreminder",@"notification_messages",@"notifymessage",@"brandsessionholder",@"brandservicesessionholder",@"officialaccounts",@"findersayhisessionholder",@"findersayhi",@"weixin_games",@"appbrandcustomerservicemsg"]]; });
    BOOL isFriend=NO;
    if (!isGroup && name.length && ![excluded containsObject:lower] && ![lower hasPrefix:@"gh_"] && ![lower hasSuffix:@"@app"]
        && !WCGroupFlag(contact,@selector(isBrandContact)) && !WCGroupFlag(contact,@selector(isOfficialContact))
        && !WCGroupFlag(contact,@selector(isEnterpriseBrand))) {
        if ([contact respondsToSelector:@selector(isSingleChatSession)]) isFriend=WCGroupFlag(contact,@selector(isSingleChatSession));
        else isFriend=WCGroupFlag(contact,@selector(isWeixinSingleConatct))
            || WCGroupFlag(contact,@selector(isSingleContactNotNecessarilyMM)) || [lower hasSuffix:@"@openim"];
    }
    if ([type isEqual:@"friend"]) return isFriend && ![WCGroupCustomMembers containsObject:name];
    if ([type isEqual:@"group"]) return isGroup && ![WCGroupCustomMembers containsObject:name];
    return [type isEqual:@"other"] && !isFriend && !isGroup;
}

static NSSet<NSString *> *WCGroupNativeTopNames(void) {
    if(![NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsPinnedPersistentKey])return [NSSet set];
    id manager=WCServiceForClass(NSClassFromString(@"MainSessionMgr"));id sessions=WCTweakSafeValue(manager,@"allTopSessions");
    NSMutableSet *names=[NSMutableSet set];
    for(id session in [sessions isKindOfClass:NSArray.class]?sessions:@[]) { NSString *name=WCGestureHomeGroupsUserName(session);if(name.length)[names addObject:name]; }
    return names;
}
NSArray *WCGestureHomeGroupsSection(id logic, NSInteger section) {
    NSString *account=WCCurrentUserWXID() ?: @"";
    NSMutableDictionary *sections=objc_getAssociatedObject(logic,&WCGroupSectionsKey);
    if ([objc_getAssociatedObject(logic,&WCGroupVersionKey) unsignedIntegerValue]!=WCGroupVersion
        || ![objc_getAssociatedObject(logic,&WCGroupAccountKey) isEqual:account]) sections=nil;
    if (!sections) {
        sections=[NSMutableDictionary dictionary];
        objc_setAssociatedObject(logic,&WCGroupSectionsKey,sections,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(logic,&WCGroupVersionKey,@(WCGroupVersion),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(logic,&WCGroupAccountKey,account,OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    if (sections[@(section)]) return sections[@(section)];
    NSDictionary *selected=nil;
    for (NSDictionary *group in WCGestureHomeGroupsList()) if ([group[@"id"] isEqual:WCGestureHomeGroupsSelected()]) { selected=group;break; }
    NSSet *pending=WCGroupPending();NSMutableArray *entries=[NSMutableArray array];
    WCGestureHomeGroupsBeginNative();
    NSSet *topNames=WCGroupNativeTopNames();
    long long count=[(id<WCHomeGroupsNative>)logic getSessionCountForSection:section];
    for (NSInteger row=0;row<count;row++) {
        NSIndexPath *path=[NSIndexPath indexPathForRow:row inSection:section];
        id session=[(id<WCHomeGroupsNative>)logic getSessionInfoAtIndexPath:path];
        session=WCTweakSafeValue(session,@"m_sessionInfo") ?: session;
        BOOL pinned=[NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsPinnedPersistentKey] && ([WCTweakSafeValue(session,@"m_bIsTop") boolValue] || [topNames containsObject:WCGestureHomeGroupsUserName(session)]);
        if (session && (pinned || WCGroupMatches(session,selected,pending))) [entries addObject:@{@"session":session,@"path":path}];
    }
    WCGestureHomeGroupsEndNative();
    sections[@(section)]=[entries copy];return sections[@(section)];
}
NSIndexPath *WCGestureHomeGroupsNativePath(id logic, NSIndexPath *path) {
    if (WCGroupNativeDepth || !WCGestureHomeGroupsEnabled() || !path) return path;
    NSArray *rows=WCGestureHomeGroupsSection(logic,path.section);
    return path.row < (NSInteger)rows.count ? rows[path.row][@"path"] : path;
}
NSIndexPath *WCGestureHomeGroupsFind(id logic, NSString *user) {
    for (NSInteger section=0;section<2;section++) {
        NSArray *rows=WCGestureHomeGroupsSection(logic,section);
        for (NSUInteger row=0;row<rows.count;row++) if ([WCGestureHomeGroupsUserName(rows[row][@"session"]) isEqual:user])
            return [NSIndexPath indexPathForRow:row inSection:section];
    }
    return nil;
}

@interface WCHomeGroupBanner : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UITableView *table;
@property (nonatomic, strong) UIView *originalHeader;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) UISwipeGestureRecognizer *left;
@property (nonatomic, strong) UISwipeGestureRecognizer *right;
@property (nonatomic) NSUInteger version;
@property (nonatomic) CGFloat lastWidth;
@property (nonatomic) CGFloat originalHeight;
@property (nonatomic) UIViewAutoresizing originalMask;
@property (nonatomic, strong) NSMutableArray<UIView *> *badges;
@property (nonatomic) BOOL nativeBadgeMode;
@property (nonatomic, strong) NSMapTable<UIView *, id> *nativeBackgrounds;
@property (nonatomic, strong) UIColor *chromeColor;
- (void)update;
- (void)updateBackground;
- (void)restoreBackgrounds;
- (void)styleCell:(UITableViewCell *)cell path:(NSIndexPath *)path;
@end

@implementation WCHomeGroupBanner
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        _nativeBackgrounds=[NSMapTable weakToStrongObjectsMapTable];
        _indicator=[UIView new]; _indicator.userInteractionEnabled=NO;[self addSubview:_indicator];
        _stack=[UIStackView new];_stack.axis=UILayoutConstraintAxisHorizontal;_stack.distribution=UIStackViewDistributionFillEqually;
        [self addSubview:_stack];
    }return self;
}
- (void)setChromeBackground:(UIView *)view {
    if (!view) return;
    if (![self.nativeBackgrounds objectForKey:view])
        [self.nativeBackgrounds setObject:view.backgroundColor ?: NSNull.null forKey:view];
    if (![view.backgroundColor isEqual:self.chromeColor]) view.backgroundColor=self.chromeColor;
}
- (void)restoreBackgrounds {
    for (UIView *view in self.nativeBackgrounds.keyEnumerator) {
        id color=[self.nativeBackgrounds objectForKey:view];
        if ([view.backgroundColor isEqual:self.chromeColor]) view.backgroundColor=color==NSNull.null?nil:color;
    }
    [self.nativeBackgrounds removeAllObjects];
}
- (void)styleCell:(UITableViewCell *)cell path:(NSIndexPath *)path {
    id logic=WCTweakSafeValue(self.controller,@"m_mainFrameLogicController");
    NSArray *entries=WCGestureHomeGroupsSection(logic,path.section);
    id session=path.row<(NSInteger)entries.count?entries[path.row][@"session"]:nil;
    BOOL pinned=[WCTweakSafeValue(session,@"m_bIsTop") boolValue];
    id header=WCTweakSafeValue(self.controller,@"m_headerLogic");
    UIView *device=WCTweakSafeValue(header,@"m_webMMBtn");
    BOOL deviceRow=device && [device isDescendantOfView:cell];
    for (UIView *view in @[cell,cell.contentView]) {
        if (pinned || deviceRow) [self setChromeBackground:view];
        else {
            id color=[self.nativeBackgrounds objectForKey:view];
            if (color) {
                if ([view.backgroundColor isEqual:self.chromeColor]) view.backgroundColor=color==NSNull.null?nil:color;
                [self.nativeBackgrounds removeObjectForKey:view];
            }
        }
    }
}
- (void)updateBackground {
    id header=WCTweakSafeValue(self.controller,@"m_headerLogic");
    UIView *device=WCTweakSafeValue(header,@"m_webMMBtn");
    UIColor *color=nil;
    for (UIView *view=device;view && view!=self.table;view=view.superview) {
        id native=[self.nativeBackgrounds objectForKey:view];
        UIColor *candidate=native?(native==NSNull.null?nil:native):view.backgroundColor;
        if (candidate && CGColorGetAlpha([candidate resolvedColorWithTraitCollection:self.traitCollection].CGColor)>0.99) { color=candidate;break; }
    }
    if (!color) color=self.table.backgroundColor ?: UIColor.systemGroupedBackgroundColor;
    self.chromeColor=color;self.backgroundColor=color;
    [self setChromeBackground:self.originalHeader];
    [self setChromeBackground:device];
    UIView *fold=WCTweakSafeValue(self.controller,@"topSessionFoldView");
    [self setChromeBackground:fold];
    [self setChromeBackground:WCTweakSafeValue(fold,@"bannerBtn")];
    for (UITableViewCell *cell in self.table.visibleCells) {
        NSIndexPath *path=[self.table indexPathForCell:cell];
        if (path) [self styleCell:cell path:path];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) [self updateBackground];
}
- (void)chosen:(UIButton *)button {
    WCGestureHomeGroupsSelect(WCGestureHomeGroupsList()[button.tag][@"id"]);
    if ([NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsButtonHapticKey]) [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}
- (void)manage:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state!=UIGestureRecognizerStateBegan) return;
    NSInteger index=gesture.view.tag;
    BOOL instant=index<(NSInteger)WCGestureHomeGroupsList().count && [WCGestureHomeGroupsList()[index][@"type"] isEqual:@"instant"];
    [self.controller.navigationController pushViewController:instant?WCGestureCreateHomeGroupsPendingController():WCGestureCreateHomeGroupsSettingsController() animated:YES];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    if (!WCGestureHomeGroupsEnabled() || ![NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsGestureKey]) return NO;
    if ([touch.view isDescendantOfView:self]) return NO;
    for(UIView *view=touch.view;view && view!=self.table;view=view.superview) if([view isKindOfClass:UIControl.class])return NO;
    CGFloat x=[touch locationInView:self.table].x, width=self.table.bounds.size.width;
    CGFloat ratio=[NSUserDefaults.standardUserDefaults doubleForKey:WCGestureHomeGroupsGestureRatioKey]*0.5;
    return x<width*ratio || x>width*(1-ratio);
}
- (void)swipe:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state!=UIGestureRecognizerStateRecognized) return;
    NSArray *groups=WCGestureHomeGroupsList();NSInteger index=0;
    for (NSUInteger i=0;i<groups.count;i++) if ([groups[i][@"id"] isEqual:WCGestureHomeGroupsSelected()]) index=i;
    NSInteger delta=gesture.direction==UISwipeGestureRecognizerDirectionLeft?1:-1;
    if ([NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsReverseKey]) delta=-delta;
    index+=delta;
    if (index<0 || index>=(NSInteger)groups.count) {
        if (![NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsContinuousKey]) return;
        index=(index+(NSInteger)groups.count)%(NSInteger)groups.count;
    }
    WCGestureHomeGroupsSelect(groups[index][@"id"]);
    if ([NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsHapticKey]) [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
}
- (void)update {
    CGFloat width=self.table.bounds.size.width, nativeHeight=self.originalHeader.bounds.size.height;
    if (self.version==WCGroupVersion && self.lastWidth==width && self.originalHeight==nativeHeight) return;
    self.version=WCGroupVersion;self.lastWidth=width;self.originalHeight=nativeHeight;
    CGFloat scale=WCGestureLayoutScaleFactor(), height=44*scale;
    self.frame=CGRectMake(0,0,width,nativeHeight+height);
    self.originalHeader.frame=CGRectMake(0,0,width,nativeHeight);
    self.stack.frame=CGRectMake(12*scale,nativeHeight,width-24*scale,height);
    NSArray *groups=WCGestureHomeGroupsList();NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    CGFloat font=MAX(10,MIN(24,[d doubleForKey:WCGestureHomeGroupsFontSizeKey]))*scale;
    CGFloat weight=[d doubleForKey:WCGestureHomeGroupsFontWeightKey];
    UIFontWeight fw=weight<=300?UIFontWeightLight:(weight>=500?UIFontWeightMedium:UIFontWeightRegular);
    NSUInteger selected=0;
    while(self.stack.arrangedSubviews.count>groups.count) { UIView *button=self.stack.arrangedSubviews.lastObject;[self.stack removeArrangedSubview:button];[button removeFromSuperview]; }
    while(self.stack.arrangedSubviews.count<groups.count) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self action:@selector(chosen:) forControlEvents:UIControlEventTouchUpInside];
        [button addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(manage:)]];
        [self.stack addArrangedSubview:button];
    }
    for (NSUInteger i=0;i<groups.count;i++) {
        UIButton *button=(UIButton *)self.stack.arrangedSubviews[i];button.tag=i;
        [button setTitle:groups[i][@"title"] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];button.titleLabel.font=[UIFont systemFontOfSize:font weight:fw];
        if ([groups[i][@"id"] isEqual:WCGestureHomeGroupsSelected()]) selected=i;
    }
    [self.stack layoutIfNeeded];
    CGFloat cellWidth=self.stack.bounds.size.width/groups.count;
    CGFloat percent=MAX(0,MIN(100,[d doubleForKey:WCGestureHomeGroupsSliderSizeKey]))/100.0;
    CGRect target=CGRectMake(self.stack.frame.origin.x+selected*cellWidth+(1-percent)*cellWidth/2,
        self.stack.frame.origin.y+(1-percent)*height/2,cellWidth*percent,height*percent);
    self.indicator.hidden=![d boolForKey:WCGestureHomeGroupsSliderKey] || percent==0;
    self.indicator.backgroundColor=WCGestureColorForDefaultsKey(WCGestureHomeGroupsSliderColorKey,UIColor.tertiarySystemFillColor);
    self.indicator.layer.cornerRadius=MIN(CGRectGetHeight(target)/2,MAX(0,[d doubleForKey:WCGestureHomeGroupsSliderRadiusKey]*scale));
    if ([d boolForKey:WCGestureHomeGroupsSliderAnimationKey]) [UIView animateWithDuration:0.25 animations:^{ self.indicator.frame=target; }];
    else self.indicator.frame=target;
    UIView *line=[self viewWithTag:9092];
    if (!line) { line=[UIView new];line.tag=9092;line.userInteractionEnabled=NO;[self addSubview:line]; }
    line.hidden=![d boolForKey:WCGestureHomeGroupsUnderlineKey];
    CGFloat length=MAX(1,MIN(200,[d doubleForKey:WCGestureHomeGroupsUnderlineLengthKey]))*scale;
    CGFloat thickness=MAX(0.5,MIN(20,[d doubleForKey:WCGestureHomeGroupsUnderlineThicknessKey]))*scale;
    line.frame=CGRectMake(self.stack.frame.origin.x+(selected+0.5)*cellWidth-length/2,
        CGRectGetMaxY(self.stack.frame)-[d doubleForKey:WCGestureHomeGroupsUnderlineOffsetKey]*scale,length,thickness);
    line.backgroundColor=WCGestureColorForDefaultsKey(WCGestureHomeGroupsUnderlineColorKey,UIColor.systemBlueColor);
    // One Wx aggregates the verified 8079 MMSessionInfo unread-count/dot
    // fields over the same predicates; native badge API verified in MMBadgeView.h.
    id logic=WCTweakSafeValue(self.controller,@"m_mainFrameLogicController");
    NSMutableArray *sessions=[NSMutableArray array];NSMutableSet *seenNames=[NSMutableSet set];
    WCGestureHomeGroupsBeginNative();
    for(NSInteger section=0;section<2;section++) {
        NSInteger count=[(id<WCHomeGroupsNative>)logic getSessionCountForSection:section];
        for(NSInteger row=0;row<count;row++) { id item=[(id<WCHomeGroupsNative>)logic getSessionInfoAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];item=WCTweakSafeValue(item,@"m_sessionInfo") ?: item;NSString *name=WCGestureHomeGroupsUserName(item);if(name.length && ![seenNames containsObject:name]){[seenNames addObject:name];[sessions addObject:item];} }
    }
    WCGestureHomeGroupsEndNative();
    Class badgeClass=NSClassFromString(@"MMBadgeView");SEL factory=NSSelectorFromString(@"redDotWithNumber:");
    BOOL native=[d boolForKey:WCGestureHomeGroupsNativeBadgeKey] && [badgeClass respondsToSelector:factory]
        && [badgeClass instancesRespondToSelector:NSSelectorFromString(@"setValue:")]
        && [badgeClass instancesRespondToSelector:NSSelectorFromString(@"setBgColor:")]
        && [badgeClass instancesRespondToSelector:NSSelectorFromString(@"setTextColor:")]
        && [badgeClass instancesRespondToSelector:NSSelectorFromString(@"setAsSmallDotForChatSession")];
    if (self.nativeBadgeMode!=native) { for(UIView *badge in self.badges)[badge removeFromSuperview];self.badges=nil; }
    self.nativeBadgeMode=native;if(!self.badges)self.badges=[NSMutableArray array];
    while(self.badges.count>groups.count){[self.badges.lastObject removeFromSuperview];[self.badges removeLastObject];}
    NSSet *pending=WCGroupPending();
    for(NSUInteger index=0;index<groups.count;index++) {
        NSUInteger unread=0;BOOL dot=NO;
        for(id session in sessions) if(WCGroupMatches(session,groups[index],pending)) {
            NSUInteger value=[WCTweakSafeValue(session,@"m_uUnReadCount") unsignedIntegerValue];
            if(!value)continue; // Original 0x3b12b8 skips zero-unread sessions.
            if([WCTweakSafeValue(session,@"m_bShowUnReadAsRedDot") boolValue]) dot=YES;else unread+=value;
        }
        UIView *badge=index<self.badges.count?self.badges[index]:nil;
        if(!badge){badge=native?((id(*)(id,SEL,unsigned long long))objc_msgSend)(badgeClass,factory,1):[UILabel new];badge.userInteractionEnabled=NO;[self addSubview:badge];[self.badges addObject:badge];}
        if(native) {
            if(unread){SEL clear=NSSelectorFromString(@"removeSmallDot");if([badge respondsToSelector:clear])((void(*)(id,SEL))objc_msgSend)(badge,clear);((void(*)(id,SEL,unsigned long long))objc_msgSend)(badge,NSSelectorFromString(@"setValue:"),unread);}
            else ((void(*)(id,SEL))objc_msgSend)(badge,NSSelectorFromString(@"setAsSmallDotForChatSession"));
            ((void(*)(id,SEL,id))objc_msgSend)(badge,NSSelectorFromString(@"setBgColor:"),WCGestureColorForDefaultsKey(WCGestureHomeGroupsBadgeColorKey,UIColor.systemRedColor));
            ((void(*)(id,SEL,id))objc_msgSend)(badge,NSSelectorFromString(@"setTextColor:"),WCGestureColorForDefaultsKey(WCGestureHomeGroupsBadgeTextColorKey,UIColor.whiteColor));
        } else {
            UILabel *label=(UILabel *)badge;label.font=[UIFont systemFontOfSize:10*scale];label.textAlignment=NSTextAlignmentCenter;
            label.text=unread?(unread>99?@"99+":[NSString stringWithFormat:@"%lu",(unsigned long)unread]):@"";
            label.textColor=WCGestureColorForDefaultsKey(WCGestureHomeGroupsBadgeTextColorKey,UIColor.whiteColor);
            label.backgroundColor=WCGestureColorForDefaultsKey(WCGestureHomeGroupsBadgeColorKey,UIColor.systemRedColor);
            CGFloat w=unread?MAX(16*scale,[label.text sizeWithAttributes:@{NSFontAttributeName:label.font}].width+8*scale):6*scale;
            CGFloat h=(unread?16:6)*scale;label.bounds=CGRectMake(0,0,w,h);label.layer.cornerRadius=h/2;label.layer.masksToBounds=YES;
        }
        if (native) [badge sizeToFit];
        badge.hidden=[d boolForKey:WCGestureHomeGroupsHideBadgesKey] || (!unread && (!dot || [d boolForKey:WCGestureHomeGroupsHideRedDotsKey]));
        UIButton *button=(UIButton *)self.stack.arrangedSubviews[index];
        CGFloat titleWidth=[groups[index][@"title"] sizeWithAttributes:@{NSFontAttributeName:button.titleLabel.font}].width;
        badge.center=CGPointMake(self.stack.frame.origin.x+(index+0.5)*cellWidth+titleWidth/2+badge.bounds.size.width/2+[d doubleForKey:WCGestureHomeGroupsBadgeXKey]*scale,
            self.stack.frame.origin.y+height/2-font/2+[d doubleForKey:WCGestureHomeGroupsBadgeYKey]*scale);
    }
    self.left.enabled=self.right.enabled=[d boolForKey:WCGestureHomeGroupsGestureKey];
}
@end

void WCGestureHomeGroupsAttach(UIViewController *controller) {
    WCGroupMainController=controller;
    UITableView *table=WCTweakSafeValue(controller,@"m_tableView");
    if (![table isKindOfClass:UITableView.class]) return;
    WCHomeGroupBanner *banner=objc_getAssociatedObject(controller,&WCGroupBannerKey);
    if (!WCGestureHomeGroupsEnabled()) {
        if (table.tableHeaderView==banner) { banner.originalHeader.autoresizingMask=banner.originalMask;table.tableHeaderView=banner.originalHeader; }
        [banner restoreBackgrounds];
        banner.left.enabled=banner.right.enabled=NO;return;
    }
    if (!banner) {
        banner=[[WCHomeGroupBanner alloc] initWithFrame:CGRectZero];banner.controller=controller;banner.table=table;
        banner.left=[[UISwipeGestureRecognizer alloc] initWithTarget:banner action:@selector(swipe:)];banner.left.direction=UISwipeGestureRecognizerDirectionLeft;banner.left.delegate=banner;
        banner.right=[[UISwipeGestureRecognizer alloc] initWithTarget:banner action:@selector(swipe:)];banner.right.direction=UISwipeGestureRecognizerDirectionRight;banner.right.delegate=banner;
        [table addGestureRecognizer:banner.left];[table addGestureRecognizer:banner.right];
        [table.panGestureRecognizer requireGestureRecognizerToFail:banner.left];[table.panGestureRecognizer requireGestureRecognizerToFail:banner.right];
        objc_setAssociatedObject(controller,&WCGroupBannerKey,banner,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (table.tableHeaderView!=banner) {
        UIView *nativeHeader=table.tableHeaderView;
        // Detach through UITableView first; otherwise its setter would remove
        // the old header after it had already become a child of our wrapper.
        table.tableHeaderView=nil;
        banner.originalHeader.autoresizingMask=banner.originalMask;
        [banner.originalHeader removeFromSuperview];banner.originalHeader=nativeHeader;
        if (nativeHeader) { banner.originalMask=nativeHeader.autoresizingMask;nativeHeader.autoresizingMask=UIViewAutoresizingFlexibleWidth;[banner addSubview:nativeHeader]; }
        banner.version=0;
    }
    [banner updateBackground];
    CGFloat oldHeight=banner.bounds.size.height;[banner update];
    if (table.tableHeaderView!=banner || oldHeight!=banner.bounds.size.height) table.tableHeaderView=banner;
}
void WCGestureHomeGroupsStyleCell(UIViewController *controller, UITableViewCell *cell, NSIndexPath *path) {
    WCHomeGroupBanner *banner=objc_getAssociatedObject(controller,&WCGroupBannerKey);
    if (WCGestureHomeGroupsEnabled()) [banner styleCell:cell path:path];
}
static void WCGroupScheduleReload(void) {
    if (WCGroupReloadPending) return;WCGroupReloadPending=YES;
    dispatch_async(dispatch_get_main_queue(),^{
        WCGroupReloadPending=NO;UIViewController *controller=WCGroupMainController;
        if (!controller) return;
        SEL update=NSSelectorFromString(@"updateTopSessionFoldView");
        if([controller respondsToSelector:update])((void(*)(id,SEL))objc_msgSend)(controller,update);
        WCGestureHomeGroupsAttach(controller);
        [UIView performWithoutAnimation:^{ [(UITableView *)WCTweakSafeValue(controller,@"m_tableView") reloadData]; }];
    });
}
void WCGestureHomeGroupsInvalidate(id logic) {
    objc_setAssociatedObject(logic,&WCGroupSectionsKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    WCGroupVersion++;
    if(WCGestureHomeGroupsEnabled())WCGroupScheduleReload();
}
void WCGestureHomeGroupsSettingsChanged(NSString *key) {
    if (key && ![key hasPrefix:@"com.qiu7c.onewx.home.groups."] && ![key isEqual:WCGesturePageScalePercentKey] && ![key isEqual:WCGesturePageScaleEnabledKey] && ![key isEqual:WCGestureEnabledKey]) return;
    WCGroupList=nil;WCGroupCustomMembers=nil;WCGroupVersion++;WCGroupScheduleReload();
}

static __weak UIViewController *WCGroupChatController;
static NSString *WCGroupCurrentChatName(id controller) {
    for (NSString *key in @[@"getCurrentChatName",@"GetContact",@"GetCContact"]) {
        SEL selector=NSSelectorFromString(key);
        if ([controller respondsToSelector:selector]) {
            NSString *name=WCGroupName(((id(*)(id,SEL))objc_msgSend)(controller,selector),0);if(name.length)return name;
        }
    }return @"";
}
void WCGestureHomeGroupsChatEntered(id controller) {
    WCGroupChatController=controller;
    if (!WCGestureHomeGroupsEnabled() || ![NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsBurnAfterReadingKey]) return;
    NSString *name=WCGroupCurrentChatName(controller);NSMutableSet *pending=WCGroupPending();
    if ([pending containsObject:name]) { [pending removeObject:name];WCGroupSavePending(pending,WCGroupAccount()); }
}
void WCGestureHomeGroupsMessageAdded(id target, id wrap, BOOL localMessage) {
    if (!WCGestureHomeGroupsEnabled() || ![wrap isKindOfClass:NSClassFromString(@"CMessageWrap")]) return;
    // UIKit/account/pending state is owned by the main queue. Message data is
    // retained until this callback is applied; no background UIKit traversal.
    dispatch_async(dispatch_get_main_queue(),^{
        BOOL hasInstant=NO;for(NSDictionary *group in WCGestureHomeGroupsList()) if([group[@"type"] isEqual:@"instant"]){hasInstant=YES;break;}
        if(!hasInstant)return;
        BOOL burn=[NSUserDefaults.standardUserDefaults boolForKey:WCGestureHomeGroupsBurnAfterReadingKey];
        if (burn && localMessage) return;
        NSString *me=WCGroupSelf(),*from=WCTweakSafeValue(wrap,@"m_nsFromUsr"),*to=WCTweakSafeValue(wrap,@"m_nsToUsr");
        if (burn && me.length && [from isEqual:me]) return;
        NSString *name=WCTweakSafeValue(wrap,@"GetChatName");
        if (!name.length || [name isEqual:me]) {
            if ([target isKindOfClass:NSString.class] && [target length] && ![target isEqual:me]) name=target;
            else if ([from isEqual:me]) name=to;
            else if ([to isEqual:me]) name=from;
            else name=from.length?from:to;
        }
        NSString *account=WCGroupAccount();if(!name.length || !account.length || [name isEqual:me])return;
        long long server=[WCTweakSafeValue(wrap,@"m_n64MesSvrID") longLongValue];unsigned local=[WCTweakSafeValue(wrap,@"m_uiMesLocalID") unsignedIntValue];
        NSString *key=server?[NSString stringWithFormat:@"s:%@:%lld",name,server]:(local?[NSString stringWithFormat:@"l:%@:%u",name,local]:[NSString stringWithFormat:@"p:%@:%u:%p",name,[WCTweakSafeValue(wrap,@"m_uiCreateTime") unsignedIntValue],(__bridge void *)wrap]);
        static NSMutableOrderedSet *seen;if(!seen)seen=[NSMutableOrderedSet orderedSet];
        if([seen containsObject:key])return;[seen addObject:key];if(seen.count>512)[seen removeObjectAtIndex:0];
        NSMutableSet *pending=WCGroupPending();UIViewController *chat=WCGroupChatController;
        BOOL active=chat.isViewLoaded && chat.view.window && UIApplication.sharedApplication.applicationState==UIApplicationStateActive && [WCGroupCurrentChatName(chat) isEqual:name];
        if (burn && active) [pending removeObject:name];else [pending addObject:name];
        WCGroupSavePending(pending,account);
    });
}
