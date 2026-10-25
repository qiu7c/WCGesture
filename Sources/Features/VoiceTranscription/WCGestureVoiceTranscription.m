#import <objc/message.h>
#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"
static char WCVoiceTranscriptionDoneKey, WCVoiceTranscriptionInProgressKey, WCVoiceTranscriptionAttemptedKey, WCVoiceTranscriptionScheduledKey;
static NSHashTable<UIView *> *WCVoiceCells(void) {
    static NSHashTable *cells; static dispatch_once_t once;
    dispatch_once(&once, ^{ cells = [NSHashTable weakObjectsHashTable]; }); return cells;
}
static BOOL WCVoiceMessageIsGroup(id message) {
    NSString *from = WCTweakValueForSelectorNames(message, @[@"m_nsFromUsr", @"fromUser"]);
    NSString *to = WCTweakValueForSelectorNames(message, @[@"m_nsToUsr", @"toUser"]);
    return [from hasSuffix:@"@chatroom"] || [to hasSuffix:@"@chatroom"];
}

static BOOL WCVoiceTranscriptionHasResult(id cell, id message) {
    SEL resultSelector = NSSelectorFromString(@"hasLocalTranslateResult");
    if ([message respondsToSelector:resultSelector] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(message, resultSelector)) return YES;
    for (NSString *key in @[@"m_textTranslateView", @"m_textTranslateLabel", @"m_translateResultLabel"]) {
        UIView *view = WCTweakSafeValue(cell, key);
        if ([view isKindOfClass:[UIView class]] && !view.hidden && view.alpha > 0.01) return YES;
    }
    return NO;
}

static BOOL WCVoiceTranscriptionIsActive(id cell) {
    if ([WCTweakSafeValue(cell, @"m_isTranslating") boolValue]) return YES;
    for (NSString *key in @[@"m_translatingView", @"m_textTranslateLoadingView"]) {
        UIView *view = WCTweakSafeValue(cell, key);
        if ([view isKindOfClass:[UIView class]] && !view.hidden && view.alpha > 0.01) return YES;
    }
    return NO;
}

static BOOL WCShouldAutoTranscribeVoiceCell(id cell, id message) {
    if (!WCGestureEnabled(WCGestureVoiceTranscriptionEnabledKey) || !message) return NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL group = WCVoiceMessageIsGroup(message);
    if (group && [defaults boolForKey:WCGestureVoiceTranscriptionIgnoreGroupKey]) return NO;
    if (!group && [defaults boolForKey:WCGestureVoiceTranscriptionIgnorePrivateKey]) return NO;
    id viewModel = WCTweakValueForSelectorNames(cell, @[@"viewModel", @"m_viewModel"]);
    id sender = WCTweakSafeValue(viewModel, @"isSender") ?: WCTweakSafeValue(message, @"isSender");
    BOOL isSender = sender ? [sender boolValue] :
        [WCTweakSafeValue(message, @"m_nsFromUsr") isEqualToString:WCCurrentUserWXID()];
    if (isSender && [defaults boolForKey:WCGestureVoiceTranscriptionIgnoreSelfKey]) return NO;
    if ([objc_getAssociatedObject(message, &WCVoiceTranscriptionDoneKey) boolValue] ||
        [objc_getAssociatedObject(message, &WCVoiceTranscriptionInProgressKey) boolValue] ||
        [objc_getAssociatedObject(message, &WCVoiceTranscriptionAttemptedKey) boolValue]) return NO;
    if (WCVoiceTranscriptionHasResult(cell, message)) {
        objc_setAssociatedObject(message, &WCVoiceTranscriptionDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return NO;
    }
    return !WCVoiceTranscriptionIsActive(cell);
}

static void WCScheduleVoiceTranscription(VoiceMessageCellView *cell, id message) {
    if (!cell.window || !WCShouldAutoTranscribeVoiceCell(cell, message)) return;
    if ([objc_getAssociatedObject(cell, &WCVoiceTranscriptionScheduledKey) boolValue]) return;
    objc_setAssociatedObject(cell, &WCVoiceTranscriptionScheduledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak VoiceMessageCellView *weakCell = cell;
    __weak id weakMessage = message;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VoiceMessageCellView *strongCell = weakCell;
        id strongMessage = weakMessage;
        if (!strongCell) return;
        objc_setAssociatedObject(strongCell, &WCVoiceTranscriptionScheduledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id currentMessage = WCGestureMessageWrapForCell(strongCell);
        if (!strongCell.window || currentMessage != strongMessage || !WCShouldAutoTranscribeVoiceCell(strongCell, strongMessage)) return;
        SEL selector = NSSelectorFromString(@"onVoiceTrans:");
        if (![strongCell respondsToSelector:selector]) return;
        id button = WCTweakSafeValue(strongCell, @"m_quickTransTipButton") ?: strongCell;
        objc_setAssociatedObject(strongMessage, &WCVoiceTranscriptionAttemptedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(strongMessage, &WCVoiceTranscriptionInProgressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        @try {
            ((void (*)(id, SEL, id))objc_msgSend)(strongCell, selector, button);
        } @catch (__unused NSException *exception) {
            objc_setAssociatedObject(strongMessage, &WCVoiceTranscriptionInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        __weak VoiceMessageCellView *checkingCell = strongCell;
        __weak id checkingMessage = strongMessage;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            VoiceMessageCellView *cellToCheck = checkingCell;
            id messageToCheck = checkingMessage;
            if (!messageToCheck) return;
            if (cellToCheck && WCGestureMessageWrapForCell(cellToCheck) == messageToCheck && WCVoiceTranscriptionHasResult(cellToCheck, messageToCheck)) {
                objc_setAssociatedObject(messageToCheck, &WCVoiceTranscriptionDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            objc_setAssociatedObject(messageToCheck, &WCVoiceTranscriptionInProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        });
    });
}


void WCGestureVoiceTranscriptionSchedule(UIView *cell) {
    [WCVoiceCells() addObject:cell];
    id message = WCGestureMessageWrapForCell(cell);
    if ([WCTweakSafeValue(message, @"m_uiMessageType") integerValue] == 34)
        WCScheduleVoiceTranscription((VoiceMessageCellView *)cell, message);
}
void WCGestureVoiceTranscriptionSettingsChanged(NSString *key) {
    if (key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.chat.voice-transcription."]) return;
    for (UIView *cell in WCVoiceCells().allObjects) if (cell.window) WCGestureVoiceTranscriptionSchedule(cell);
}
