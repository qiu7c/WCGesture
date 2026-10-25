#import "Sources/API/WCGestureInternal.h"

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    return WCGestureVoiceForwardMenuItems(self, items);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == NSSelectorFromString(@"wc_repeatMenuMessage:")) return WCGestureMessageCanRepeat(self);
    if (WCGestureVoiceForwardAllowsAction(action)) return YES;
    return %orig;
}
%end

%hook ForwardMessageLogicController

- (void)ForwardMsg:(id)message ToContact:(id)contact {
    NSArray *remaining = WCGestureVoiceForwardMessages(message ? @[message] : @[],
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && message) return;
    %orig(message, contact);
}

- (void)ForwardMsgList:(NSArray *)messages ToContact:(id)contact {
    NSArray *remaining = WCGestureVoiceForwardMessages(messages,
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contact);
}

- (void)ForwardMsgList:(NSArray *)messages ToContact:(id)contact batchRevokeScene:(unsigned long long)scene {
    NSArray *remaining = WCGestureVoiceForwardMessages(messages,
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contact, scene);
}

- (void)ForwardMsgList:(NSArray *)messages ToContact:(id)contact WithRevokeBatchId:(id)batchID {
    NSArray *remaining = WCGestureVoiceForwardMessages(messages,
                                                             contact ? @[contact] : @[],
                                                             NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contact, batchID);
}

- (void)forwardMsgList:(NSArray *)messages toContacts:(NSArray *)contacts {
    NSArray *remaining = WCGestureVoiceForwardMessages(messages, contacts, NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contacts);
}

- (void)forwardNoConfirmForMsgList:(NSArray *)messages toContacts:(NSArray *)contacts {
    NSArray *remaining = WCGestureVoiceForwardMessages(messages, contacts, NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contacts);
}

- (void)forwardNoConfirmForMsgList:(NSArray *)messages
                        toContacts:(NSArray *)contacts
                withBatchSendScene:(unsigned long long)scene {
    NSArray *remaining = WCGestureVoiceForwardMessages(messages, contacts, NULL);
    if (remaining.count == 0 && messages.count > 0) return;
    %orig(remaining, contacts, scene);
}

- (void)forwardMsgList:(NSArray *)messages
         msgOriginList:(NSArray *)origins
            toContacts:(NSArray *)contacts
            ignoreTips:(BOOL)ignoreTips {
    NSIndexSet *handled = nil;
    NSArray *remaining = WCGestureVoiceForwardMessages(messages, contacts, &handled);
    if (remaining.count == 0 && messages.count > 0) return;
    NSArray *remainingOrigins = WCGestureVoiceForwardFilteredOrigins(origins, handled);
    %orig(remaining, remainingOrigins, contacts, ignoreTips);
}

- (void)forwardMsgList:(NSArray *)messages
         msgOriginList:(NSArray *)origins
            toContacts:(NSArray *)contacts
            ignoreTips:(BOOL)ignoreTips
       showConfirmView:(BOOL)showConfirmView {
    NSIndexSet *handled = nil;
    NSArray *remaining = WCGestureVoiceForwardMessages(messages, contacts, &handled);
    if (remaining.count == 0 && messages.count > 0) return;
    NSArray *remainingOrigins = WCGestureVoiceForwardFilteredOrigins(origins, handled);
    %orig(remaining,
          remainingOrigins,
          contacts,
          ignoreTips,
          showConfirmView);
}

- (void)forwardMsgList:(NSArray *)messages
         msgOriginList:(NSArray *)origins
            toContacts:(NSArray *)contacts
            ignoreTips:(BOOL)ignoreTips
       showConfirmView:(BOOL)showConfirmView
      batchRevokeScene:(unsigned long long)scene {
    NSIndexSet *handled = nil;
    NSArray *remaining = WCGestureVoiceForwardMessages(messages, contacts, &handled);
    if (remaining.count == 0 && messages.count > 0) return;
    NSArray *remainingOrigins = WCGestureVoiceForwardFilteredOrigins(origins, handled);
    %orig(remaining,
          remainingOrigins,
          contacts,
          ignoreTips,
          showConfirmView,
          scene);
}

%end

%ctor {
    %init;
}
