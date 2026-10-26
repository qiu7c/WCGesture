#import "Sources/API/WCGestureInternal.h"

%hook BaseMsgContentLogicController
- (void)SendImageMessageByMMAsset:(id)asset {
    NSString *target = [WCTweakSafeValue(self, @"getCurrentChatName") copy];
    if (WCGestureSendConfirmationHold(target, @"图片：1 张", ^BOOL{
        return [WCTweakSafeValue(self, @"getCurrentChatName") isEqual:target];
    }, ^{
        %orig(asset);
    })) return;
    %orig(asset);
}
%end

%hook WeixinContentLogicController
- (void)AddMsg:(id)message MsgWrap:(id)wrap {
    NSInteger type = [WCTweakSafeValue(wrap, @"m_uiMessageType") integerValue];
    NSString *target = WCTweakSafeValue(wrap, @"m_nsToUsr");
    if (type == 3 && WCGestureSendConfirmationHoldMessage(target, wrap, ^{
        %orig(message, wrap);
    })) return;
    %orig(message, wrap);
}
%end

%hook CMessageMgr
- (void)AddMsg:(NSString *)target MsgWrap:(id)wrap {
    NSInteger type = [WCTweakSafeValue(wrap, @"m_uiMessageType") integerValue];
    if ((type == 1 || WCGestureSendConfirmationIsAppEmoticon(wrap)) &&
        WCGestureSendConfirmationHoldMessage(target, wrap, ^{
        %orig(target, wrap);
    })) return;
    %orig(target, wrap);
}
- (void)AddEmoticonMsg:(NSString *)target MsgWrap:(id)wrap {
    if (WCGestureSendConfirmationHoldMessage(target, wrap, ^{
        %orig(target, wrap);
    })) return;
    %orig(target, wrap);
}
- (id)AddVideoMsg:(id)message ToUsr:(NSString *)target VideoInfo:(id)info {
    if (WCGestureSendConfirmationHold(target, @"视频：1 个", nil, ^{
        id result = %orig(message, target, info);
        (void)result;
    })) return nil;
    id result = %orig(message, target, info);
    return result;
}
- (id)AddVideoMsg:(id)message ToUsr:(NSString *)target VideoInfo:(id)info MsgType:(unsigned int)type {
    if (WCGestureSendConfirmationHold(target, @"视频：1 个", nil, ^{
        id result = %orig(message, target, info, type);
        (void)result;
    })) return nil;
    id result = %orig(message, target, info, type);
    return result;
}
%end

%ctor {
    %init;
}
