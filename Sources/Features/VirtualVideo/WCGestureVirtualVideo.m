#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreImage/CoreImage.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import <string.h>
#import "Sources/API/WCGestureInternal.h"

// Xiaowei HOOK_CAPTURE_SPEC.md proves capture-delegate substitution + readers.
// Explicit One Wx policies: preferredTransform only (no guessed fixed90), user
// rotation, shared capture-PTS clock, modulo loop/seek, owned result per callback.
@interface WCVirtualVideoState : NSObject {
@public CMSampleBufferRef currentVideo,nextVideo;
}
@property(nonatomic,strong) NSLock *lock;
@property(nonatomic,strong) AVURLAsset *asset;
@property(nonatomic,strong) AVAssetTrack *videoTrack;
@property(nonatomic,strong) AVAssetTrack *audioTrack;
@property(nonatomic,strong) AVAssetReader *videoReader;
@property(nonatomic,strong) AVAssetReader *audioReader;
@property(nonatomic,strong) AVAssetReaderTrackOutput *videoOutput;
@property(nonatomic,strong) AVAssetReaderTrackOutput *audioOutput;
@property(nonatomic,strong) NSMutableData *audioBytes;
@property(nonatomic,copy) NSString *account;
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSString *file;
@property(nonatomic) CMTime captureOrigin;
@property(nonatomic) double duration;
@property(nonatomic) double lastVideoTime;
@property(nonatomic) double audioPosition;
@property(nonatomic) CGAffineTransform preferredTransform;
@property(nonatomic) AudioStreamBasicDescription audioFormat;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) NSUInteger importGeneration;
@property(nonatomic) NSUInteger loadingGeneration;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL failedFile;
@end
@implementation WCVirtualVideoState
- (instancetype)init { if((self=[super init])){_lock=[NSLock new];_captureOrigin=kCMTimeInvalid;_lastVideoTime=-1;_audioPosition=-1;}return self; }
- (void)dealloc {if(currentVideo)CFRelease(currentVideo);if(nextVideo)CFRelease(nextVideo);[_videoReader cancelReading];[_audioReader cancelReading];}
@end
static WCVirtualVideoState *WCVirtualVideo(void){static WCVirtualVideoState *s;static dispatch_once_t once;dispatch_once(&once,^{s=[WCVirtualVideoState new];});return s;}
static void WCVirtualResetReaders(WCVirtualVideoState *s){
    [s.videoReader cancelReading];[s.audioReader cancelReading];s.videoReader=nil;s.audioReader=nil;s.videoOutput=nil;s.audioOutput=nil;s.audioBytes=nil;
    if(s->currentVideo){CFRelease(s->currentVideo);s->currentVideo=NULL;}if(s->nextVideo){CFRelease(s->nextVideo);s->nextVideo=NULL;}
    s.captureOrigin=kCMTimeInvalid;s.lastVideoTime=-1;s.audioPosition=-1;AudioStreamBasicDescription empty={0};s.audioFormat=empty;
}
static NSDictionary *WCVirtualRecord(NSString *account){id all=[NSUserDefaults.standardUserDefaults objectForKey:WCGestureVirtualVideoSourcesKey];id row=[all isKindOfClass:NSDictionary.class]?all[account ?: @""]:nil;return [row isKindOfClass:NSDictionary.class]?row:nil;}
static NSString *WCVirtualDirectory(void){return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/OneWxVirtualVideo"];}
static NSString *WCVirtualPath(NSDictionary *record){id file=record[@"file"];if(![file isKindOfClass:NSString.class] || ![file length] || ![file isEqual:[file lastPathComponent]] || [file containsString:@".."])return nil;return [WCVirtualDirectory() stringByAppendingPathComponent:file];}
NSString *WCGestureVirtualVideoSourceName(void){id name=WCVirtualRecord(WCCurrentUserWXID())[@"name"];return [name isKindOfClass:NSString.class]?name:@"未选择";}
static NSArray *WCVirtualTracks(AVAsset *asset,NSString *type){
    // Public AVAsset API is dynamically called to keep iOS14 support without
    // referencing deprecated SDK18 declarations; never execute sample code.
    SEL sel=NSSelectorFromString(@"tracksWithMediaType:");if(![asset respondsToSelector:sel])return @[];
    id tracks=((id (*)(id,SEL,id))objc_msgSend)(asset,sel,type);return [tracks isKindOfClass:NSArray.class]?tracks:@[];
}
static CMTime WCVirtualDuration(AVAsset *asset){SEL sel=NSSelectorFromString(@"duration");return [asset respondsToSelector:sel]?((CMTime (*)(id,SEL))objc_msgSend)(asset,sel):kCMTimeInvalid;}
static BOOL WCVirtualProbeVideo(AVURLAsset *asset,AVAssetTrack *track){
    if(!track)return NO;AVAssetReader *reader=[[AVAssetReader alloc] initWithAsset:asset error:nil];if(!reader)return NO;
    AVAssetReaderTrackOutput *output=[[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
    if(![reader canAddOutput:output])return NO;[reader addOutput:output];if(![reader startReading])return NO;
    CMSampleBufferRef sample=[output copyNextSampleBuffer];BOOL valid=sample && CMSampleBufferGetImageBuffer(sample)!=NULL;
    if(sample)CFRelease(sample);[reader cancelReading];return valid;
}
static CGAffineTransform WCVirtualTransform(AVAssetTrack *track){SEL sel=NSSelectorFromString(@"preferredTransform");return [track respondsToSelector:sel]?((CGAffineTransform (*)(id,SEL))objc_msgSend)(track,sel):CGAffineTransformIdentity;}
static void WCVirtualLoadCurrent(void){
    WCVirtualVideoState *s=WCVirtualVideo();NSString *account=WCCurrentUserWXID() ?: @"",*file=WCVirtualPath(WCVirtualRecord(account));
    [s.lock lock];BOOL changed=![s.account isEqual:account] || !((!s.file && !file) || [s.file isEqual:file]);
    if(changed){s.generation++;WCVirtualResetReaders(s);s.asset=nil;s.videoTrack=nil;s.audioTrack=nil;s.duration=0;s.account=account;s.file=file;s.failedFile=NO;}
    NSUInteger generation=s.generation;BOOL needs=file.length && !s.asset && !s.failedFile && (!s.loading || s.loadingGeneration!=generation);
    if(needs){s.loading=YES;s.loadingGeneration=generation;}[s.lock unlock];
    if(!needs)return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:file] options:nil];
        AVAssetTrack *video=WCVirtualTracks(asset,AVMediaTypeVideo).firstObject,*audio=WCVirtualTracks(asset,AVMediaTypeAudio).firstObject;
        double duration=CMTimeGetSeconds(WCVirtualDuration(asset));CGAffineTransform transform=WCVirtualTransform(video);
        BOOL valid=video && isfinite(duration) && duration>=.1 && isfinite(transform.a) && isfinite(transform.b) && isfinite(transform.c) && isfinite(transform.d) && isfinite(transform.tx) && isfinite(transform.ty);
        [s.lock lock];if(s.loadingGeneration==generation)s.loading=NO;
        if(generation==s.generation && [s.account isEqual:account] && [s.file isEqual:file]){s.failedFile=!valid;if(valid){s.asset=asset;s.videoTrack=video;s.audioTrack=audio;s.duration=duration;s.preferredTransform=transform;}}[s.lock unlock];
    });
}
void WCGestureVirtualVideoStop(void){WCVirtualVideoState *s=WCVirtualVideo();[s.lock lock];s.generation++;s.token=nil;WCVirtualResetReaders(s);[s.lock unlock];}
void WCGestureVirtualVideoContextChanged(void){
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{WCGestureVirtualVideoContextChanged();});return;}
    NSString *token=WCGestureVideoCallContextToken();WCVirtualVideoState *s=WCVirtualVideo();
    [s.lock lock];if(![s.token isEqual:token]){s.generation++;WCVirtualResetReaders(s);s.token=token;}[s.lock unlock];WCVirtualLoadCurrent();
}
void WCGestureVirtualVideoSettingsChanged(NSString *key){
    if(key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.virtual-video."])return;
    WCGestureVirtualVideoStop();WCGestureVirtualVideoContextChanged();
}
static AVAssetReaderTrackOutput *WCVirtualReader(WCVirtualVideoState *s,AVAssetTrack *track,NSDictionary *settings,double time,BOOL audio){
    if(!track || !s.asset)return nil;NSError *error=nil;AVAssetReader *reader=[[AVAssetReader alloc] initWithAsset:s.asset error:&error];if(!reader)return nil;
    AVAssetReaderTrackOutput *output=[[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];output.alwaysCopiesSampleData=NO;
    if(![reader canAddOutput:output])return nil;[reader addOutput:output];
    reader.timeRange=CMTimeRangeMake(CMTimeMakeWithSeconds(MAX(0,time),60000),CMTimeMakeWithSeconds(MAX(.001,s.duration-time),60000));
    if(![reader startReading])return nil;
    if(audio){[s.audioReader cancelReading];s.audioReader=reader;s.audioOutput=output;s.audioBytes=[NSMutableData data];s.audioPosition=time;}
    else{[s.videoReader cancelReading];s.videoReader=reader;s.videoOutput=output;s.lastVideoTime=time;
        if(s->currentVideo){CFRelease(s->currentVideo);s->currentVideo=NULL;}if(s->nextVideo){CFRelease(s->nextVideo);s->nextVideo=NULL;}}
    return output;
}
static CMSampleBufferRef WCVirtualNewVideo(WCVirtualVideoState *s,CMSampleBufferRef incoming,double time,BOOL captureMirror){
    if(!s.videoOutput || time<s.lastVideoTime || time-s.lastVideoTime>.3 || s.videoReader.status==AVAssetReaderStatusFailed){
        if(!WCVirtualReader(s,s.videoTrack,@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)},time,NO))return NULL;
    }
    s.lastVideoTime=time;CMTime target=CMTimeMakeWithSeconds(time,60000);
    for(NSUInteger count=0;count<180;count++){
        if(!s->nextVideo)s->nextVideo=[s.videoOutput copyNextSampleBuffer];
        if(!s->nextVideo)break;
        if(s->currentVideo && CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(s->nextVideo),target)>0)break;
        if(s->currentVideo)CFRelease(s->currentVideo);s->currentVideo=s->nextVideo;s->nextVideo=NULL;
        if(CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(s->currentVideo),target)>=0)break;
    }
    if(!s->currentVideo)return NULL;
    double frameTime=CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(s->currentVideo));if(!isfinite(frameTime)||fabs(frameTime-time)>.25)return NULL;
    CVPixelBufferRef input=CMSampleBufferGetImageBuffer(incoming),file=CMSampleBufferGetImageBuffer(s->currentVideo);if(!input||!file)return NULL;
    size_t width=CVPixelBufferGetWidth(input),height=CVPixelBufferGetHeight(input);if(!width||!height||width>4096||height>4096)return NULL;
    OSType format=CVPixelBufferGetPixelFormatType(input);if(format!=kCVPixelFormatType_32BGRA && format!=kCVPixelFormatType_420YpCbCr8BiPlanarFullRange && format!=kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)return NULL;
    CIImage *image=[[CIImage imageWithCVPixelBuffer:file] imageByApplyingTransform:s.preferredTransform];
    NSInteger degrees=[NSUserDefaults.standardUserDefaults integerForKey:WCGestureVirtualVideoRotationKey];if(degrees==90||degrees==180||degrees==270)image=[image imageByApplyingTransform:CGAffineTransformMakeRotation(degrees*M_PI/180.0)];
    CGRect extent=image.extent;if(CGRectIsEmpty(extent)||!isfinite(extent.size.width)||!isfinite(extent.size.height))return NULL;
    image=[image imageByApplyingTransform:CGAffineTransformMakeTranslation(-extent.origin.x,-extent.origin.y)];
    if([NSUserDefaults.standardUserDefaults boolForKey:WCGestureVirtualVideoMirrorKey] != captureMirror)image=[image imageByApplyingTransform:CGAffineTransformMake(-1,0,0,1,extent.size.width,0)];
    CGFloat scale=MAX(width/extent.size.width,height/extent.size.height);image=[image imageByApplyingTransform:CGAffineTransformMakeScale(scale,scale)];
    image=[image imageByApplyingTransform:CGAffineTransformMakeTranslation((width-extent.size.width*scale)/2,(height-extent.size.height*scale)/2)];
    CVPixelBufferRef output=NULL;NSDictionary *attrs=@{(id)kCVPixelBufferIOSurfacePropertiesKey:@{},(id)kCVPixelBufferMetalCompatibilityKey:@YES};
    if(CVPixelBufferCreate(kCFAllocatorDefault,width,height,format,(__bridge CFDictionaryRef)attrs,&output)!=kCVReturnSuccess)return NULL;
    CVBufferPropagateAttachments(input,output);CMSampleBufferRef result=NULL;CMVideoFormatDescriptionRef description=NULL;
    if(WCGestureVideoCallRenderToPixels(image,output) && CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,output,&description)==noErr){
        CMSampleTimingInfo timing={CMSampleBufferGetDuration(incoming),CMSampleBufferGetPresentationTimeStamp(incoming),CMSampleBufferGetDecodeTimeStamp(incoming)};
        if(CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,output,description,&timing,&result)==noErr)CMPropagateAttachments(incoming,result);
    }
    if(description)CFRelease(description);CVPixelBufferRelease(output);return result;
}
static CMSampleBufferRef WCVirtualNewAudio(WCVirtualVideoState *s,CMSampleBufferRef incoming,double time){
    if(!s.audioTrack || ![NSUserDefaults.standardUserDefaults boolForKey:WCGestureVirtualVideoAudioKey])return NULL;
    CMAudioFormatDescriptionRef desc=(CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(incoming);
    const AudioStreamBasicDescription *ptr=desc?CMAudioFormatDescriptionGetStreamBasicDescription(desc):NULL;if(!ptr)return NULL;
    AudioStreamBasicDescription format=*ptr;BOOL floats=(format.mFormatFlags&kAudioFormatFlagIsFloat)!=0;
    if(format.mFormatID!=kAudioFormatLinearPCM || (format.mFormatFlags&(kAudioFormatFlagIsNonInterleaved|kAudioFormatFlagIsBigEndian)) || format.mSampleRate<8000 || format.mSampleRate>192000 || format.mChannelsPerFrame<1 || format.mChannelsPerFrame>2 || (!floats && !(format.mFormatFlags&kAudioFormatFlagIsSignedInteger)) || (floats?format.mBitsPerChannel!=32:format.mBitsPerChannel!=16))return NULL;
    CMItemCount count=CMSampleBufferGetNumSamples(incoming);if(count<=0 || count>19200 || format.mBytesPerFrame!=format.mChannelsPerFrame*format.mBitsPerChannel/8)return NULL;
    size_t bytes=(size_t)count*format.mBytesPerFrame;
    AudioStreamBasicDescription old=s.audioFormat;
    BOOL sameFormat=old.mFormatID==format.mFormatID && old.mSampleRate==format.mSampleRate && old.mChannelsPerFrame==format.mChannelsPerFrame && old.mFormatFlags==format.mFormatFlags && old.mBitsPerChannel==format.mBitsPerChannel && old.mBytesPerFrame==format.mBytesPerFrame && old.mFramesPerPacket==format.mFramesPerPacket && old.mBytesPerPacket==format.mBytesPerPacket;
    BOOL rebuild=!s.audioOutput || !sameFormat || time<s.audioPosition-.05 || fabs(time-s.audioPosition)>.1 || s.audioReader.status==AVAssetReaderStatusFailed;
    NSDictionary *settings=@{AVFormatIDKey:@(kAudioFormatLinearPCM),AVSampleRateKey:@(format.mSampleRate),AVNumberOfChannelsKey:@(format.mChannelsPerFrame),
        AVLinearPCMBitDepthKey:@(format.mBitsPerChannel),AVLinearPCMIsFloatKey:@(floats),AVLinearPCMIsBigEndianKey:@NO,AVLinearPCMIsNonInterleaved:@NO};
    if(rebuild){if(!WCVirtualReader(s,s.audioTrack,settings,time,YES))return NULL;s.audioFormat=format;}
    for(NSUInteger i=0;s.audioBytes.length<bytes && i<64;i++){
        CMSampleBufferRef sample=[s.audioOutput copyNextSampleBuffer];
        if(!sample){NSData *remainder=[s.audioBytes copy];if(!WCVirtualReader(s,s.audioTrack,settings,0,YES))break;[s.audioBytes appendData:remainder];sample=[s.audioOutput copyNextSampleBuffer];if(!sample)break;}
        CMBlockBufferRef data=CMSampleBufferGetDataBuffer(sample);size_t length=data?CMBlockBufferGetDataLength(data):0;
        if(length && length<8*1024*1024){NSMutableData *chunk=[NSMutableData dataWithLength:length];if(CMBlockBufferCopyDataBytes(data,0,length,chunk.mutableBytes)==noErr)[s.audioBytes appendData:chunk];}
        CFRelease(sample);
    }
    if(s.audioBytes.length<bytes)return NULL;NSMutableData *mixed=[[s.audioBytes subdataWithRange:NSMakeRange(0,bytes)] mutableCopy];[s.audioBytes replaceBytesInRange:NSMakeRange(0,bytes) withBytes:NULL length:0];
    s.audioPosition=fmod(time+count/format.mSampleRate,s.duration);
    if([NSUserDefaults.standardUserDefaults boolForKey:WCGestureVirtualVideoMixMicKey]){
        CMBlockBufferRef mic=CMSampleBufferGetDataBuffer(incoming);if(mic && CMBlockBufferGetDataLength(mic)>=bytes){NSMutableData *original=[NSMutableData dataWithLength:bytes];
            if(CMBlockBufferCopyDataBytes(mic,0,bytes,original.mutableBytes)==noErr){NSUInteger samples=bytes/(format.mBitsPerChannel/8);
                if(floats){float *dst=mixed.mutableBytes;const float *src=original.bytes;for(NSUInteger i=0;i<samples;i++){double v=.75*dst[i]+.75*src[i];dst[i]=isfinite(v)?MAX(-1,MIN(1,v)):0;}}
                else{int16_t *dst=mixed.mutableBytes;const int16_t *src=original.bytes;for(NSUInteger i=0;i<samples;i++){int v=(int)(.75*dst[i]+.75*src[i]);dst[i]=(int16_t)MAX(-32768,MIN(32767,v));}}
            }
        }
    }
    CMBlockBufferRef block=NULL;CMSampleBufferRef result=NULL;
    if(CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,NULL,bytes,kCFAllocatorDefault,NULL,0,bytes,kCMBlockBufferAssureMemoryNowFlag,&block)!=noErr)return NULL;
    if(CMBlockBufferReplaceDataBytes(mixed.bytes,block,0,bytes)==noErr){
        CMSampleTimingInfo timing={CMTimeMake(1,(int32_t)format.mSampleRate),CMSampleBufferGetPresentationTimeStamp(incoming),kCMTimeInvalid};size_t sampleSize=format.mBytesPerFrame;
        if(CMSampleBufferCreateReady(kCFAllocatorDefault,block,desc,count,1,&timing,1,&sampleSize,&result)==noErr)CMPropagateAttachments(incoming,result);
    }
    CFRelease(block);return result;
}
CMSampleBufferRef WCGestureVirtualVideoCreateSample(id output,CMSampleBufferRef incoming,id connection){
    if(!incoming || !CMSampleBufferIsValid(incoming) || !CMSampleBufferDataIsReady(incoming) || !WCGestureEnabled(WCGestureVirtualVideoEnabledKey))return NULL;
    WCVirtualVideoState *s=WCVirtualVideo();if(![s.lock tryLock])return NULL;CMSampleBufferRef result=NULL;
    @try{
        if(!s.token.length || !s.asset || !s.videoTrack || ![s.account isEqualToString:WCCurrentUserWXID() ?: @""] || s.duration<.1)return NULL;
        CMFormatDescriptionRef description=CMSampleBufferGetFormatDescription(incoming);if(!description)return NULL;
        CMMediaType type=CMFormatDescriptionGetMediaType(description);
        if(type!=kCMMediaType_Video && type!=kCMMediaType_Audio)return NULL;
        if(type==kCMMediaType_Audio && (![NSUserDefaults.standardUserDefaults boolForKey:WCGestureVirtualVideoAudioKey] || !CMTIME_IS_NUMERIC(s.captureOrigin)))return NULL;
        CMTime pts=CMSampleBufferGetPresentationTimeStamp(incoming);if(!CMTIME_IS_NUMERIC(pts))return NULL;
        if(!CMTIME_IS_NUMERIC(s.captureOrigin))s.captureOrigin=pts;
        double elapsed=CMTimeGetSeconds(CMTimeSubtract(pts,s.captureOrigin));if(!isfinite(elapsed))return NULL;
        // Unrelated/earlier audio clock must never reset an active video reader.
        if(elapsed<0){if(type==kCMMediaType_Audio)return NULL;WCVirtualResetReaders(s);s.captureOrigin=pts;elapsed=0;}
        double time=fmod(elapsed,s.duration);
        if(type==kCMMediaType_Video){
            SEL mirror=NSSelectorFromString(@"isVideoMirrored");BOOL captureMirror=[connection respondsToSelector:mirror] && ((BOOL (*)(id,SEL))objc_msgSend)(connection,mirror);
            result=WCVirtualNewVideo(s,incoming,time,captureMirror);
        }else if(type==kCMMediaType_Audio)result=WCVirtualNewAudio(s,incoming,time);
    }@catch(__unused NSException *exception){if(result){CFRelease(result);result=NULL;}WCVirtualResetReaders(s);}
    @finally{[s.lock unlock];}
    return result;
}
extern void MSHookMessageEx(Class,SEL,IMP,IMP *);
@interface WCVirtualAudioHook : NSObject {
@public IMP original;
}
@end
@implementation WCVirtualAudioHook
@end
void WCGestureVirtualVideoInstallAudioDelegate(id delegate){
    if(!delegate)return;Class video=NSClassFromString(@"AVVideoDevice");if(video && [delegate isKindOfClass:video])return;
    SEL selector=NSSelectorFromString(@"captureOutput:didOutputSampleBuffer:fromConnection:");Method method=class_getInstanceMethod([delegate class],selector);if(!method)return;
    NSMethodSignature *signature=[delegate methodSignatureForSelector:selector];if(signature.numberOfArguments!=5 || signature.methodReturnType[0]!='v' || [signature getArgumentTypeAtIndex:2][0]!='@' || [signature getArgumentTypeAtIndex:3][0]!='^' || [signature getArgumentTypeAtIndex:4][0]!='@')return;
    static NSMutableDictionary *installed;static NSLock *guard;static dispatch_once_t once;dispatch_once(&once,^{installed=[NSMutableDictionary dictionary];guard=[NSLock new];});
    [guard lock];NSString *name=NSStringFromClass([delegate class]);if(installed[name]){[guard unlock];return;}
    WCVirtualAudioHook *hook=[WCVirtualAudioHook new];
    IMP replacement=imp_implementationWithBlock(^(id receiver,id output,CMSampleBufferRef sample,id connection){
        NSMutableDictionary *thread=NSThread.currentThread.threadDictionary;NSString *key=@"com.qiu7c.onewx.virtual-video.capture-depth";NSUInteger depth=[thread[key] unsignedIntegerValue];thread[key]=@(depth+1);
        CMSampleBufferRef processed=NULL;
        @try{
            if(!depth && [output isKindOfClass:AVCaptureAudioDataOutput.class])processed=WCGestureVirtualVideoCreateSample(output,sample,connection);
            if(hook->original)((void (*)(id,SEL,id,CMSampleBufferRef,id))hook->original)(receiver,selector,output,processed ?: sample,connection);
        }@finally{if(processed)CFRelease(processed);if(depth)thread[key]=@(depth);else[thread removeObjectForKey:key];}
    });
    installed[name]=hook;MSHookMessageEx([delegate class],selector,replacement,&hook->original);[guard unlock];
}
void WCGestureVirtualVideoImport(NSURL *url,void (^completion)(BOOL)){
    WCVirtualVideoState *s=WCVirtualVideo();NSString *account=WCCurrentUserWXID();if(!account.length || !url.isFileURL){completion(NO);return;}
    [s.lock lock];NSUInteger request=++s.importGeneration;[s.lock unlock];BOOL access=[url startAccessingSecurityScopedResource];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *extension=url.pathExtension.lowercaseString;if(![@[@"mov",@"mp4",@"m4v"] containsObject:extension])extension=@"mov";
        NSString *file=[NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension],*path=[WCVirtualDirectory() stringByAppendingPathComponent:file];
        [NSFileManager.defaultManager createDirectoryAtPath:WCVirtualDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
        BOOL okay=[NSFileManager.defaultManager copyItemAtURL:url toURL:[NSURL fileURLWithPath:path] error:nil];if(access)[url stopAccessingSecurityScopedResource];
        if(okay){AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];double duration=CMTimeGetSeconds(WCVirtualDuration(asset));AVAssetTrack *track=WCVirtualTracks(asset,AVMediaTypeVideo).firstObject;okay=track && isfinite(duration) && duration>=.1 && WCVirtualProbeVideo(asset,track);}
        dispatch_async(dispatch_get_main_queue(),^{
            [s.lock lock];BOOL current=request==s.importGeneration && [account isEqualToString:WCCurrentUserWXID() ?: @""];[s.lock unlock];
            if(okay && current){NSString *old=WCVirtualPath(WCVirtualRecord(account));id stored=[NSUserDefaults.standardUserDefaults objectForKey:WCGestureVirtualVideoSourcesKey];NSMutableDictionary *all=[stored isKindOfClass:NSDictionary.class]?[stored mutableCopy]:[NSMutableDictionary dictionary];
                all[account]=@{@"file":file,@"name":url.lastPathComponent ?: @"视频"};[NSUserDefaults.standardUserDefaults setObject:all forKey:WCGestureVirtualVideoSourcesKey];
                WCGestureVirtualVideoStop();WCGestureVirtualVideoContextChanged();if(old && ![old isEqual:path])[NSFileManager.defaultManager removeItemAtPath:old error:nil];
            }else [NSFileManager.defaultManager removeItemAtPath:path error:nil];
            completion(okay && current);
        });
    });
}
void WCGestureVirtualVideoClear(void){
    WCVirtualVideoState *s=WCVirtualVideo();NSString *account=WCCurrentUserWXID();if(!account.length)return;
    [s.lock lock];s.importGeneration++;[s.lock unlock];NSString *path=WCVirtualPath(WCVirtualRecord(account));
    id stored=[NSUserDefaults.standardUserDefaults objectForKey:WCGestureVirtualVideoSourcesKey];NSMutableDictionary *all=[stored isKindOfClass:NSDictionary.class]?[stored mutableCopy]:[NSMutableDictionary dictionary];[all removeObjectForKey:account];
    [NSUserDefaults.standardUserDefaults setObject:all forKey:WCGestureVirtualVideoSourcesKey];WCGestureVirtualVideoStop();WCVirtualLoadCurrent();if(path)[NSFileManager.defaultManager removeItemAtPath:path error:nil];
}
void WCGestureVirtualVideoStart(void){
    static dispatch_once_t once;dispatch_once(&once,^{dispatch_async(dispatch_get_main_queue(),^{
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){WCGestureVirtualVideoStop();}];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){dispatch_async(dispatch_get_main_queue(),^{WCGestureVirtualVideoContextChanged();});}];
        WCVirtualLoadCurrent();
    });});
}
