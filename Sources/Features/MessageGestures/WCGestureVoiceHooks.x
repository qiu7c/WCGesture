#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Voice repeat upload hooks

// These four hooks make voice repeat actually deliver. Without them, the
// 12-second forward window set by WCSendVoiceMessage is never consulted and
// WeChat uploads the resent voice in ordinary-recording mode, which it rejects.
@interface UploadVoiceWrap : NSObject
@end
@interface UploadVoiceRequest : NSObject
@end
@interface MMNewUploadVoiceMgr : NSObject
@end
@interface UploadVoiceCDNMgr : NSObject
@end

%hook UploadVoiceWrap
- (void)setM_uiVoiceForwardFlag:(unsigned int)forwardFlag {
    %orig(WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag);
}
%end

%hook UploadVoiceRequest
- (void)setForwardFlag:(unsigned int)forwardFlag {
    %orig(WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag);
}
%end

%hook MMNewUploadVoiceMgr
- (void)AddNewPart:(id)part
           LocalID:(unsigned int)localID
          n64SvrID:(long long)serverID
            Offset:(unsigned int)offset
               Len:(unsigned int)length
         VoiceTime:(unsigned int)voiceTime
        CreateTime:(unsigned int)createTime
           EndFlag:(unsigned int)endFlag
        CancelFlag:(unsigned int)cancelFlag
       VoiceFormat:(unsigned int)voiceFormat
       ForwardFlag:(unsigned int)forwardFlag
         msgSource:(id)msgSource
          chatName:(id)chatName {
    %orig(part, localID, serverID, offset, length, voiceTime, createTime,
          endFlag, cancelFlag, voiceFormat,
          WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag,
          msgSource, chatName);
}
%end

%hook UploadVoiceCDNMgr
- (void)AddNewPart:(id)part
           LocalID:(unsigned int)localID
          n64SvrID:(long long)serverID
            Offset:(unsigned int)offset
               Len:(unsigned int)length
         VoiceTime:(unsigned int)voiceTime
        CreateTime:(unsigned int)createTime
           EndFlag:(unsigned int)endFlag
        CancelFlag:(unsigned int)cancelFlag
       VoiceFormat:(unsigned int)voiceFormat
       ForwardFlag:(unsigned int)forwardFlag
         msgSource:(id)msgSource
          chatName:(id)chatName {
    %orig(part, localID, serverID, offset, length, voiceTime, createTime,
          endFlag, cancelFlag, voiceFormat,
          WCVoiceRepeatUploadIsActive() ? 1 : forwardFlag,
          msgSource, chatName);
}
%end

%ctor {
    %init;
}
