#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <ImageIO/ImageIO.h>
#import <AVKit/AVKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
@interface WCChatMediaRecord : NSObject
@property (nonatomic,strong) UIImage *image;
@property (nonatomic,strong) NSURL *videoURL;
@property (nonatomic,copy) NSString *session;
@end
@implementation WCChatMediaRecord
@end
static NSMutableDictionary *WCChatMediaRecords(void){static NSMutableDictionary *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSMutableDictionary dictionary];});return v;}
static NSHashTable *WCChatMediaCells(void){static NSHashTable *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSHashTable weakObjectsHashTable];});return v;}
static char WCChatMediaOverlayKey,WCChatMediaPickerKey;
static NSUInteger WCChatMediaGeneration;
static NSMutableDictionary *WCChatMediaRequests(void) { static NSMutableDictionary *v; static dispatch_once_t once; dispatch_once(&once,^{v=[NSMutableDictionary dictionary];}); return v; }
static BOOL WCChatMediaVideo(UIView *cell){Class cls=NSClassFromString(@"VideoMessageCellView");return cls && [cell isKindOfClass:cls];}
static BOOL WCChatMediaEligible(UIView *cell){
    NSInteger type=[WCTweakSafeValue(WCGestureMessageWrapForCell(cell),@"m_uiMessageType") integerValue];
    return WCGestureEnabled(WCGestureChatMediaReplacementEnabledKey) && (type==3 || type==43 || type==62) && WCGestureLocalChatIdentity(cell).length;
}
BOOL WCGestureChatMediaAllowsAction(UIView *cell,SEL action){
    if(!WCChatMediaEligible(cell))return NO;
    if(action==NSSelectorFromString(@"wc_replaceLocalMedia:"))return YES;
    return action==NSSelectorFromString(@"wc_restoreLocalMedia:") && WCChatMediaRecords()[WCGestureLocalChatIdentity(cell)]!=nil;
}
NSArray *WCGestureChatMediaMenuItems(UIView *cell,NSArray *items){
    if(![items isKindOfClass:NSArray.class] || !WCChatMediaEligible(cell))return items;
    NSMutableArray *result=[items mutableCopy];
    for(NSArray *row in @[@[@"替换本机媒体",@"photo",@"wc_replaceLocalMedia:"],@[@"恢复原始媒体",@"arrow.uturn.backward",@"wc_restoreLocalMedia:"]]){
        SEL action=NSSelectorFromString(row[2]);if(!WCGestureChatMediaAllowsAction(cell,action))continue;
        id item=WCGestureLocalChatMenuItem(cell,row[0],row[1],action);if(item)[result addObject:item];
    }return result;
}
void WCGestureChatMediaResetCell(UIView *cell){UIView *view=objc_getAssociatedObject(cell,&WCChatMediaOverlayKey);[view removeFromSuperview];objc_setAssociatedObject(cell,&WCChatMediaOverlayKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
void WCGestureChatMediaLayout(UIView *cell){
    [WCChatMediaCells() addObject:cell];WCChatMediaRecord *record=WCChatMediaEligible(cell)?WCChatMediaRecords()[WCGestureLocalChatIdentity(cell)]:nil;
    if(!cell.window || !record){WCGestureChatMediaResetCell(cell);return;}
    id native=WCTweakSafeValue(cell,WCChatMediaVideo(cell)?@"m_thumbImageView":@"m_imageView");
    if(![native isKindOfClass:UIImageView.class] || ![(UIView *)native isDescendantOfView:cell])return;
    UIImageView *image=native;UIImageView *overlay=objc_getAssociatedObject(cell,&WCChatMediaOverlayKey);
    if(!overlay){overlay=[UIImageView new];overlay.userInteractionEnabled=NO;overlay.clipsToBounds=YES;objc_setAssociatedObject(cell,&WCChatMediaOverlayKey,overlay,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    if(overlay.superview!=image.superview)[image.superview insertSubview:overlay aboveSubview:image];
    overlay.frame=image.frame;overlay.contentMode=image.contentMode;overlay.layer.cornerRadius=image.layer.cornerRadius;overlay.layer.cornerCurve=image.layer.cornerCurve;overlay.image=record.image ?: [UIImage systemImageNamed:@"play.rectangle.fill"];
}
static void WCChatMediaDiscard(WCChatMediaRecord *record){if(record.videoURL)[NSFileManager.defaultManager removeItemAtURL:record.videoURL error:nil];}
@interface WCChatMediaPicker : NSObject <PHPickerViewControllerDelegate>
@property(nonatomic,weak) UIView *cell;
@property(nonatomic,copy) NSString *identity;
@property(nonatomic,copy) NSString *account;
@property(nonatomic) BOOL video;
@property(nonatomic,strong) NSNumber *request;
@property(nonatomic) NSUInteger generation;
@end
@implementation WCChatMediaPicker
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results{
    [picker dismissViewControllerAnimated:YES completion:nil];if(!results.count)return;
    NSItemProvider *provider=results.firstObject.itemProvider;NSString *type=self.video?UTTypeMovie.identifier:UTTypeImage.identifier;
    if(![provider hasItemConformingToTypeIdentifier:type]){WCShowToast(@"请选择对应的图片或视频");return;}
    [provider loadFileRepresentationForTypeIdentifier:type completionHandler:^(NSURL *url,NSError *error){
        if(!url || error){dispatch_async(dispatch_get_main_queue(),^{WCShowToast(@"无法读取所选媒体");});return;}
        WCChatMediaRecord *record=[WCChatMediaRecord new];record.session=self.identity;
        if(self.video){
            NSURL *folder=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"OneWxChatMedia"] isDirectory:YES];
            [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
            NSURL *destination=[folder URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:url.pathExtension.length?url.pathExtension:@"mov"]];
            if(![NSFileManager.defaultManager copyItemAtURL:url toURL:destination error:nil]){dispatch_async(dispatch_get_main_queue(),^{WCShowToast(@"无法复制所选视频");});return;}
            record.videoURL=destination;
            AVAssetImageGenerator *generator=[[AVAssetImageGenerator alloc] initWithAsset:[AVURLAsset URLAssetWithURL:destination options:nil]];
            generator.appliesPreferredTrackTransform=YES;generator.maximumSize=CGSizeMake(1024,1024);
            SEL copy=NSSelectorFromString(@"copyCGImageAtTime:actualTime:error:");
            CGImageRef image=NULL;
            if([generator respondsToSelector:copy]) image=((CGImageRef (*)(id,SEL,CMTime,CMTime *,NSError **))objc_msgSend)(generator,copy,kCMTimeZero,NULL,NULL);
            if(image){record.image=[UIImage imageWithCGImage:image];CGImageRelease(image);}
        }else{
            CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);
            if(source){CGImageRef image=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)@{(id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(id)kCGImageSourceCreateThumbnailWithTransform:@YES,(id)kCGImageSourceThumbnailMaxPixelSize:@2048});
                if(image){record.image=[UIImage imageWithCGImage:image];CGImageRelease(image);}CFRelease(source);}
        }
        dispatch_async(dispatch_get_main_queue(),^{
            UIView *cell=self.cell;
            if(self.generation!=WCChatMediaGeneration || ![WCChatMediaRequests()[self.identity] isEqual:self.request] || !cell.window || ![self.account isEqualToString:WCCurrentUserWXID() ?: @""] || ![self.identity isEqualToString:WCGestureLocalChatIdentity(cell)] || !WCChatMediaEligible(cell)) {WCChatMediaDiscard(record);return;}
            if(!record.image && !record.videoURL){WCShowToast(@"无法解码所选媒体");return;}
            WCChatMediaDiscard(WCChatMediaRecords()[self.identity]);WCChatMediaRecords()[self.identity]=record;
            WCGestureChatMediaLayout(cell);[cell setNeedsLayout];
        });
    }];
}
@end
void WCGestureChatMediaPick(UIView *cell,BOOL restore){
    if(!cell.window || !WCChatMediaEligible(cell))return;NSString *identity=WCGestureLocalChatIdentity(cell);
    [WCChatMediaRequests() removeObjectForKey:identity];
    if(restore){WCChatMediaDiscard(WCChatMediaRecords()[identity]);[WCChatMediaRecords() removeObjectForKey:identity];WCGestureChatMediaResetCell(cell);return;}
    UIViewController *presenter=WCViewControllerForResponder(cell);if(!presenter || presenter.presentedViewController)return;
    WCChatMediaPicker *bridge=[WCChatMediaPicker new];bridge.cell=cell;bridge.identity=identity;bridge.account=WCCurrentUserWXID() ?: @"";bridge.video=WCChatMediaVideo(cell);
    bridge.request=@(++WCChatMediaGeneration);bridge.generation=WCChatMediaGeneration;WCChatMediaRequests()[identity]=bridge.request;
    PHPickerConfiguration *config=[[PHPickerConfiguration alloc] init];config.selectionLimit=1;config.filter=bridge.video?PHPickerFilter.videosFilter:PHPickerFilter.imagesFilter;
    PHPickerViewController *picker=[[PHPickerViewController alloc] initWithConfiguration:config];picker.delegate=bridge;
    objc_setAssociatedObject(picker,&WCChatMediaPickerKey,bridge,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[presenter presentViewController:picker animated:YES completion:nil];
}
BOOL WCGestureChatMediaPresent(UIView *cell){
    WCChatMediaRecord *record=WCChatMediaEligible(cell)?WCChatMediaRecords()[WCGestureLocalChatIdentity(cell)]:nil;if(!record || !cell.window)return NO;
    UIViewController *host=WCViewControllerForResponder(cell);if(!host || host.presentedViewController)return NO;
    if(record.videoURL){AVPlayerViewController *player=[AVPlayerViewController new];player.player=[AVPlayer playerWithURL:record.videoURL];[host presentViewController:player animated:YES completion:^{[player.player play];}];}
    else{UIViewController *preview=[UIViewController new];preview.view.backgroundColor=UIColor.systemBackgroundColor;
        UIImageView *image=[[UIImageView alloc] initWithImage:record.image];image.contentMode=UIViewContentModeScaleAspectFit;image.frame=preview.view.bounds;image.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[preview.view addSubview:image];
        preview.modalPresentationStyle=UIModalPresentationPageSheet;[host presentViewController:preview animated:YES completion:nil];}
    return YES;
}
void WCGestureChatMediaLeaving(UIViewController *controller){
    WCChatMediaGeneration++;
    [WCChatMediaRequests() removeAllObjects];
    NSMutableSet *keys=[NSMutableSet set];for(UIView *cell in WCChatMediaCells().allObjects)if(WCViewControllerForResponder(cell)==controller){NSString *key=WCGestureLocalChatIdentity(cell);if(key.length)[keys addObject:key];WCGestureChatMediaResetCell(cell);}
    NSString *prefix=[NSString stringWithFormat:@"%@|%@|",WCCurrentUserWXID() ?: @"",WCGestureLocalChatSession(controller)];
    for(NSString *key in WCChatMediaRecords().allKeys)if([key hasPrefix:prefix] || [keys containsObject:key]){WCChatMediaDiscard(WCChatMediaRecords()[key]);[WCChatMediaRecords() removeObjectForKey:key];}
}
void WCGestureChatMediaSettingsChanged(NSString *key){
    if(key && ![key isEqualToString:WCGestureChatMediaReplacementEnabledKey] && ![key isEqualToString:WCGestureEnabledKey])return;
    WCChatMediaGeneration++; [WCChatMediaRequests() removeAllObjects];
    if(!WCGestureEnabled(WCGestureChatMediaReplacementEnabledKey)){for(WCChatMediaRecord *r in WCChatMediaRecords().allValues)WCChatMediaDiscard(r);[WCChatMediaRecords() removeAllObjects];}
    for(UIView *cell in WCChatMediaCells().allObjects)WCGestureChatMediaLayout(cell);
}
