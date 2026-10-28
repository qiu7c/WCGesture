#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

// WeChatX PORT_SPEC.md: username identity, 640px JPEG/.92, getter + view hooks.
// One Wx adaptations: per-account files, bounded caches and correct oriented crop.
@interface WCCustomAvatarViewState : NSObject
@property(nonatomic,copy) NSString *identity;
@property(nonatomic,strong) UIImage *applied;
@property(nonatomic,strong) UIImage *nativeImage;
@property(nonatomic) BOOL restoring;
@end
@implementation WCCustomAvatarViewState
@end
static char WCCustomAvatarViewKey;
static NSLock *WCCustomAvatarLock;
static NSCache *WCCustomAvatarSources,*WCCustomAvatarRendered,*WCCustomAvatarUserLists,*WCCustomAvatarUserSets;
static NSMutableDictionary *WCCustomAvatarVersions;
static NSMutableSet *WCCustomAvatarPending,*WCCustomAvatarUnavailable;
static NSHashTable *WCCustomAvatarViews;
static dispatch_queue_t WCCustomAvatarQueue;
static NSUInteger WCCustomAvatarEpoch;
static void WCCustomAvatarInit(void) {
    static dispatch_once_t once;dispatch_once(&once,^{
        WCCustomAvatarLock=[NSLock new];WCCustomAvatarSources=[NSCache new];WCCustomAvatarRendered=[NSCache new];
        WCCustomAvatarUserLists=[NSCache new];WCCustomAvatarUserSets=[NSCache new];WCCustomAvatarUserLists.countLimit=8;WCCustomAvatarUserSets.countLimit=8;
        WCCustomAvatarSources.totalCostLimit=16*1024*1024;WCCustomAvatarRendered.totalCostLimit=32*1024*1024;
        WCCustomAvatarVersions=[NSMutableDictionary dictionary];WCCustomAvatarPending=[NSMutableSet set];WCCustomAvatarUnavailable=[NSMutableSet set];
        WCCustomAvatarViews=[NSHashTable weakObjectsHashTable];WCCustomAvatarQueue=dispatch_queue_create("com.qiu7c.onewx.custom-avatar",DISPATCH_QUEUE_SERIAL);
    });
}
static NSString *WCCustomAvatarSafeName(NSString *name) {
    NSMutableString *safe=[NSMutableString string];NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-@"];
    for (NSUInteger i=0;i<name.length;i++){unichar c=[name characterAtIndex:i];if([allowed characterIsMember:c])[safe appendFormat:@"%C",c];else[safe appendFormat:@"_%04x",c];}
    return safe;
}
static NSString *WCCustomAvatarPath(NSString *account,NSString *name) {
    if(!account.length || !name.length || account.length>512 || name.length>512)return nil;
    NSString *root=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/OneWxCustomAvatars"];
    NSString *folder=[root stringByAppendingPathComponent:[WCCustomAvatarSafeName(account) stringByAppendingString:@".account"]];
    return [folder stringByAppendingPathComponent:[WCCustomAvatarSafeName(name) stringByAppendingPathExtension:@"jpg"]];
}
static NSString *WCCustomAvatarIdentity(NSString *account,NSString *name) { return [NSString stringWithFormat:@"%@|%@",account,name]; }
static NSArray *WCCustomAvatarUsersLocked(NSString *account) {
    if(!account.length)return @[];WCCustomAvatarInit();NSArray *cached=[WCCustomAvatarUserLists objectForKey:account];if(cached)return cached;
    id all=[NSUserDefaults.standardUserDefaults objectForKey:WCGestureCustomAvatarUsersKey];id users=[all isKindOfClass:NSDictionary.class]?all[account]:nil;
    NSArray *list=[users isKindOfClass:NSArray.class]?[users filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id value,__unused NSDictionary *b){return [value isKindOfClass:NSString.class] && [value length]>0;}]]:@[];
    [WCCustomAvatarUserLists setObject:list forKey:account];return list;
}
static NSArray *WCCustomAvatarUsers(NSString *account){
    if(!account.length)return @[];WCCustomAvatarInit();[WCCustomAvatarLock lock];NSArray *result=WCCustomAvatarUsersLocked(account);[WCCustomAvatarLock unlock];return result;
}
static BOOL WCCustomAvatarHasUser(NSString *account,NSString *user){
    if(!account.length || !user.length)return NO;WCCustomAvatarInit();[WCCustomAvatarLock lock];NSSet *users=[WCCustomAvatarUserSets objectForKey:account];
    if(!users){users=[NSSet setWithArray:WCCustomAvatarUsersLocked(account)];[WCCustomAvatarUserSets setObject:users forKey:account];}BOOL result=[users containsObject:user];[WCCustomAvatarLock unlock];return result;
}
NSArray<NSString *> *WCGestureCustomAvatarSavedUsers(void) { return WCCustomAvatarUsers(WCCurrentUserWXID() ?: @""); }
static void WCCustomAvatarIndex(NSString *account,NSString *user,BOOL add) {
    id stored=[NSUserDefaults.standardUserDefaults objectForKey:WCGestureCustomAvatarUsersKey];
    NSMutableDictionary *all=[stored isKindOfClass:NSDictionary.class]?[stored mutableCopy]:[NSMutableDictionary dictionary];
    NSMutableArray *users=[WCCustomAvatarUsers(account) mutableCopy];[users removeObject:user];if(add)[users addObject:user];
    all[account]=users;[NSUserDefaults.standardUserDefaults setObject:all forKey:WCGestureCustomAvatarUsersKey];
    [WCCustomAvatarLock lock];[WCCustomAvatarUserLists setObject:[users copy] forKey:account];[WCCustomAvatarUserSets setObject:[NSSet setWithArray:users] forKey:account];[WCCustomAvatarLock unlock];
}
static void WCCustomAvatarRefresh(NSString *user) {
    for(UIView *view in WCCustomAvatarViews.allObjects)if(!user || [WCTweakSafeValue(view,@"nsUsrName") isEqual:user])WCGestureCustomAvatarApply(view);
}
static UIImage *WCCustomAvatarRender(UIImage *source,CGSize size,CGFloat radius,CGFloat scale) {
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=scale;format.opaque=NO;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx){
        CGRect rect=(CGRect){CGPointZero,size};if(radius>=0)[[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:MIN(radius,MIN(size.width,size.height)/2)] addClip];
        [source drawInRect:rect];
    }];
}
UIImage *WCGestureCustomAvatarImage(NSString *username,CGSize size,CGFloat radius) {
    if(![username isKindOfClass:NSString.class] || !username.length || !WCGestureEnabled(WCGestureCustomAvatarEnabledKey))return nil;
    NSString *account=WCCurrentUserWXID();if(!account.length || !WCCustomAvatarHasUser(account,username))return nil;
    WCCustomAvatarInit();if(!isfinite(size.width)||!isfinite(size.height)||size.width<=0||size.height<=0)size=CGSizeMake(120,120);
    if(size.width>2048 || size.height>2048)return nil;
    if(!isfinite(radius))radius=0;CGFloat scale=UIScreen.mainScreen.scale;if(!isfinite(scale)||scale<=0)scale=1;
    scale=MIN(scale,2048/MAX(size.width,size.height));
    size=CGSizeMake(MAX(1,round(size.width*scale))/scale,MAX(1,round(size.height*scale))/scale);
    NSString *identity=WCCustomAvatarIdentity(account,username);
    [WCCustomAvatarLock lock];NSUInteger epoch=WCCustomAvatarEpoch,version=[WCCustomAvatarVersions[identity] unsignedIntegerValue];
    NSString *key=[NSString stringWithFormat:@"%@|%lu|%lu|%.3f|%.3f|%.3f|%.3f",identity,(unsigned long)epoch,(unsigned long)version,size.width,size.height,radius,scale];
    if([WCCustomAvatarUnavailable containsObject:identity]){[WCCustomAvatarLock unlock];return nil;}
    UIImage *ready=[WCCustomAvatarRendered objectForKey:key];
    if(ready || [WCCustomAvatarPending containsObject:key]){[WCCustomAvatarLock unlock];return ready;}
    [WCCustomAvatarPending addObject:key];UIImage *cached=[WCCustomAvatarSources objectForKey:identity];[WCCustomAvatarLock unlock];
    NSString *path=WCCustomAvatarPath(account,username);
    dispatch_async(WCCustomAvatarQueue,^{@autoreleasepool{
        UIImage *source=cached ?: [UIImage imageWithContentsOfFile:path];UIImage *rendered=source?WCCustomAvatarRender(source,size,radius,scale):nil;
        dispatch_async(dispatch_get_main_queue(),^{
            [WCCustomAvatarLock lock];[WCCustomAvatarPending removeObject:key];
            BOOL valid=epoch==WCCustomAvatarEpoch && version==[WCCustomAvatarVersions[identity] unsignedIntegerValue] && [account isEqualToString:WCCurrentUserWXID() ?: @""];
            if(valid && !source)[WCCustomAvatarUnavailable addObject:identity];
            if(valid && source)[WCCustomAvatarSources setObject:source forKey:identity cost:640*640*4];
            if(valid && rendered)[WCCustomAvatarRendered setObject:rendered forKey:key cost:(NSUInteger)(size.width*scale*size.height*scale*4)];
            [WCCustomAvatarLock unlock];if(valid && rendered)WCCustomAvatarRefresh(username);
        });
    }});
    return nil;
}
void WCGestureCustomAvatarWillChangeUser(UIView *headView) {
    if(!headView)return;
    WCCustomAvatarViewState *state=objc_getAssociatedObject(headView,&WCCustomAvatarViewKey);
    id target=WCTweakSafeValue(headView,@"headImageView");
    if([target isKindOfClass:UIImageView.class] && [(UIImageView *)target image]==state.applied && state.nativeImage)[target setImage:state.nativeImage];
    objc_setAssociatedObject(headView,&WCCustomAvatarViewKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
void WCGestureCustomAvatarApply(UIView *headView) {
    if(!headView)return;
    if(!NSThread.isMainThread){__weak UIView *weak=headView;dispatch_async(dispatch_get_main_queue(),^{if(weak)WCGestureCustomAvatarApply(weak);});return;}
    WCCustomAvatarInit();[WCCustomAvatarViews addObject:headView];
    id target=WCTweakSafeValue(headView,@"headImageView");if(![target isKindOfClass:UIImageView.class])return;
    UIImageView *imageView=target;NSString *user=WCTweakSafeValue(headView,@"nsUsrName");if(![user isKindOfClass:NSString.class])return;
    WCCustomAvatarViewState *state=objc_getAssociatedObject(headView,&WCCustomAvatarViewKey);if(state.restoring)return;
    NSString *identity=WCCustomAvatarIdentity(WCCurrentUserWXID() ?: @"",user);
    if(state && ![state.identity isEqualToString:identity]){WCGestureCustomAvatarWillChangeUser(headView);state=nil;}
    BOOL active=WCGestureEnabled(WCGestureCustomAvatarEnabledKey) && WCCustomAvatarHasUser(WCCurrentUserWXID(),user);
    if(!active){
        if(state){state.restoring=YES;if(imageView.image==state.applied && state.nativeImage)imageView.image=state.nativeImage;
            SEL update=NSSelectorFromString(@"doUpdateHeadImg:");if([headView respondsToSelector:update])((void (*)(id,SEL,BOOL))objc_msgSend)(headView,update,YES);
            objc_setAssociatedObject(headView,&WCCustomAvatarViewKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        return;
    }
    if(!state){state=[WCCustomAvatarViewState new];state.identity=identity;objc_setAssociatedObject(headView,&WCCustomAvatarViewKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    if(imageView.image && imageView.image!=state.applied)state.nativeImage=imageView.image;
    if(CGRectIsEmpty(imageView.bounds))return;
    CGFloat radius=-1;
    BOOL layerOwnsRounding=WCGestureEnabled(WCGestureGlobalAvatarRoundingEnabledKey) && !WCGestureHeadViewIsExcludedFromGlobalAvatarRounding(headView);
    if(!layerOwnsRounding && [WCTweakSafeValue(headView,@"bRoundedCorner") boolValue]){
        unsigned int corner=[WCTweakSafeValue(headView,@"conerSize") unsignedIntValue];radius=corner?corner:.18*MIN(imageView.bounds.size.width,imageView.bounds.size.height);if(radius<=0)radius=8;
    }
    UIImage *replacement=WCGestureCustomAvatarImage(user,imageView.bounds.size,radius);
    if(replacement){state.applied=replacement;if(imageView.image!=replacement)imageView.image=replacement;}
}
static void WCCustomAvatarMutate(NSString *username,UIImage *image,void (^completion)(BOOL)) {
    WCCustomAvatarInit();NSString *account=WCCurrentUserWXID(),*path=WCCustomAvatarPath(account,username);
    if(!path){completion(NO);return;}NSString *identity=WCCustomAvatarIdentity(account,username);
    [WCCustomAvatarLock lock];NSUInteger version=[WCCustomAvatarVersions[identity] unsignedIntegerValue]+1;WCCustomAvatarVersions[identity]=@(version);
    [WCCustomAvatarUnavailable removeObject:identity];
    [WCCustomAvatarSources removeObjectForKey:identity];[WCCustomAvatarRendered removeAllObjects];[WCCustomAvatarLock unlock];
    dispatch_async(WCCustomAvatarQueue,^{@autoreleasepool{
        BOOL success=NO;UIImage *prepared=nil;
        if(image){
            CGSize source=image.size;CGFloat side=MIN(source.width,source.height);
            if(isfinite(side) && side>0){UIGraphicsImageRendererFormat *f=[UIGraphicsImageRendererFormat defaultFormat];f.scale=1;f.opaque=YES;
                prepared=[[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(640,640) format:f] imageWithActions:^(__unused UIGraphicsImageRendererContext *context){
                    CGFloat ratio=640/side;[image drawInRect:CGRectMake((640-source.width*ratio)/2,(640-source.height*ratio)/2,source.width*ratio,source.height*ratio)];
                }];}
        }
        [WCCustomAvatarLock lock];BOOL current=version==[WCCustomAvatarVersions[identity] unsignedIntegerValue];[WCCustomAvatarLock unlock];
        if(current){
            if(!image)success=![NSFileManager.defaultManager fileExistsAtPath:path] || [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            else if(prepared){[NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
                success=[UIImageJPEGRepresentation(prepared,.92) writeToFile:path options:NSDataWritingAtomic error:nil];}
        }
        dispatch_async(dispatch_get_main_queue(),^{
            [WCCustomAvatarLock lock];BOOL valid=version==[WCCustomAvatarVersions[identity] unsignedIntegerValue] && [account isEqualToString:WCCurrentUserWXID() ?: @""];
            if(valid && success && prepared)[WCCustomAvatarSources setObject:prepared forKey:identity cost:640*640*4];[WCCustomAvatarLock unlock];
            if(valid && success){WCCustomAvatarIndex(account,username,image!=nil);WCCustomAvatarRefresh(username);}
            completion(valid && success);
        });
    }});
}
void WCGestureCustomAvatarSave(NSString *username,UIImage *image,void (^completion)(BOOL)) { WCCustomAvatarMutate(username,image,completion); }
void WCGestureCustomAvatarRemove(NSString *username,void (^completion)(BOOL)) { WCCustomAvatarMutate(username,nil,completion); }
void WCGestureCustomAvatarSettingsChanged(NSString *key) {
    if(key && ![key isEqualToString:WCGestureEnabledKey] && ![key isEqualToString:WCGestureCustomAvatarEnabledKey])return;
    WCCustomAvatarInit();[WCCustomAvatarLock lock];WCCustomAvatarEpoch++;[WCCustomAvatarUserLists removeAllObjects];[WCCustomAvatarUserSets removeAllObjects];[WCCustomAvatarSources removeAllObjects];[WCCustomAvatarRendered removeAllObjects];[WCCustomAvatarPending removeAllObjects];[WCCustomAvatarUnavailable removeAllObjects];[WCCustomAvatarLock unlock];WCCustomAvatarRefresh(nil);
}
