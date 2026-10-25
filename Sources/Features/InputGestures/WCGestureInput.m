#import <objc/message.h>
#import <objc/runtime.h>

#import "Sources/API/WCGestureInternal.h"

static char WCInputSwipeLeftRecognizerKey;
static char WCInputSwipeRightRecognizerKey;
static char WCInputDoubleTapRecognizerKey;
static char WCInputTripleTapRecognizerKey;

#pragma mark - Text access

UITextView *WCInnerTextView(id growTextView) {
    id textView = WCTweakSafeValue(growTextView, @"textView");
    if (![textView isKindOfClass:[UITextView class]]) textView = WCTweakSafeValue(growTextView, @"_textView");
    return [textView isKindOfClass:[UITextView class]] ? textView : nil;
}

// Finds the chat input's MMGrowTextView whose inner text view is first responder.
MMGrowTextView *WCFirstResponderGrowTextView(void) {
    Class growClass = NSClassFromString(@"MMGrowTextView");
    if (!growClass) return nil;
    UIWindow *window = WCActiveWindow();
    if (!window) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithArray:window.subviews];
    while (stack.count) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:growClass]) {
            UITextView *textView = WCInnerTextView(view);
            if (textView.isFirstResponder) return (MMGrowTextView *)view;
        }
        [stack addObjectsFromArray:view.subviews];
    }
    return nil;
}

NSString *WCInputText(MMGrowTextView *view) {
    NSString *text = WCTweakSafeValue(view, @"text");
    if (![text isKindOfClass:[NSString class]]) {
        UITextView *textView = WCInnerTextView(view);
        text = textView.text;
    }
    return text ?: @"";
}

void WCReplaceInputText(MMGrowTextView *view, NSString *text) {
    if (!view) return;
    NSString *value = text ?: @"";
    WCTweakSetValue(view, @"text", value);
    UITextView *textView = WCInnerTextView(view);
    if (textView) {
        textView.text = value;
        textView.selectedRange = NSMakeRange(value.length, 0);
        SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
        if ([view respondsToSelector:changeSelector]) {
            ((void (*)(id, SEL, id))objc_msgSend)(view, changeSelector, textView);
        }
    }
}

#pragma mark - Translation / AI

static void WCApplyTranslation(MMGrowTextView *view, NSString *translated, NSString *errorMessage) {
    if (![translated isKindOfClass:[NSString class]] || translated.length == 0) {
        WCShowToast(errorMessage.length > 0 ? errorMessage : @"翻译失败");
        return;
    }
    WCReplaceInputText(view, translated);
    WCShowToast(@"已翻译");
}

// One "互译" action: Chinese input is translated into the configured pair
// language, anything else into Chinese. Uses the configurable engine
// (Edge / MyMemory / AI).
static void WCTranslateInputText(MMGrowTextView *view) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:WCTranslateEnabledKey]) {
        WCShowToast(@"翻译未开启");
        return;
    }
    NSString *text = WCInputText(view);
    if (text.length == 0) { WCShowToast(@"输入框为空"); return; }
    NSString *targetCode = WCTranslateTargetCodeForText(text);
    WCGestureTranslateText(text, targetCode, ^(NSString *translated, NSString *errorMessage) {
        WCApplyTranslation(view, translated, errorMessage);
    });
}

static void WCAIPerformInputTask(MMGrowTextView *view, WCGestureAITask task) {
    if (!view) return;
    if (!WCGestureAIIsEnabled()) { WCShowToast(@"AI 未开启"); return; }
    if (!WCGestureAIIsConfigured()) { WCShowToast(@"请先在插件设置中配置 AI"); return; }
    NSString *text = WCInputText(view);
    if (text.length == 0) { WCShowToast(@"输入框为空"); return; }
    WCShowToast(task == WCGestureAITaskPolish ? @"AI 润色中…" : @"AI 回答中…");
    WCGestureAIPerform(task, text, ^(NSString *result, NSString *errorMessage) {
        if (result.length == 0) {
            WCShowToast(errorMessage.length > 0 ? errorMessage : @"AI 请求失败");
            return;
        }
        WCReplaceInputText(view, result);
        WCShowToast(task == WCGestureAITaskPolish ? @"已润色" : @"已生成回答");
    });
}

#pragma mark - Actions

// Performs a configured input-gesture action on the grow-text-view.
void WCPerformInputAction(MMGrowTextView *view, WCInputAction action) {
    if (action == WCInputActionNone) return;
    UITextView *textView = WCInnerTextView(view);
    if (action == WCInputActionClear) {
        WCTweakSetValue(view, @"text", @"");
        if (textView) {
            textView.text = @"";
            textView.selectedRange = NSMakeRange(0, 0);
            SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
            if ([view respondsToSelector:changeSelector]) {
                ((void (*)(id, SEL, id))objc_msgSend)(view, changeSelector, textView);
            }
        }
        return;
    }
    if (action == WCInputActionPaste) {
        if (textView) {
            [textView becomeFirstResponder];
            [textView paste:nil];
            return;
        }
        NSString *pasteText = UIPasteboard.generalPasteboard.string;
        if (pasteText.length == 0) return;
        NSString *currentText = WCTweakSafeValue(view, @"text");
        if (![currentText isKindOfClass:[NSString class]]) currentText = @"";
        WCTweakSetValue(view, @"text", [currentText stringByAppendingString:pasteText]);
        return;
    }
    if (action == WCInputActionCopy) {
        NSString *text = WCTweakSafeValue(view, @"text");
        if ([text length] > 0) UIPasteboard.generalPasteboard.string = text;
        return;
    }
    if (action == WCInputActionCut) {
        NSString *text = WCTweakSafeValue(view, @"text");
        if ([text length] > 0) {
            UIPasteboard.generalPasteboard.string = text;
            WCTweakSetValue(view, @"text", @"");
            if (textView) {
                textView.text = @"";
                textView.selectedRange = NSMakeRange(0, 0);
                SEL changeSelector = NSSelectorFromString(@"textViewDidChange:");
                if ([view respondsToSelector:changeSelector]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(view, changeSelector, textView);
                }
            }
        }
        return;
    }
    if (action == WCInputActionUppercase) {
        NSString *text = WCInputText(view);
        if (text.length) WCReplaceInputText(view, [text uppercaseString]);
        return;
    }
    if (action == WCInputActionLowercase) {
        NSString *text = WCInputText(view);
        if (text.length) WCReplaceInputText(view, [text lowercaseString]);
        return;
    }
    if (action == WCInputActionTrim) {
        NSString *text = WCInputText(view);
        NSString *trimmed = [[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                             componentsJoinedByString:@""];
        if (trimmed.length) WCReplaceInputText(view, trimmed);
        return;
    }
    // The legacy "译成中文" value still resolves to the mutual action.
    if (action == WCInputActionTranslate || action == WCInputActionTranslateLegacy) {
        WCTranslateInputText(view);
        return;
    }
    if (action == WCInputActionAIAnswer) { WCAIPerformInputTask(view, WCGestureAITaskAnswer); return; }
    if (action == WCInputActionAIPolish) { WCAIPerformInputTask(view, WCGestureAITaskPolish); return; }
}

#pragma mark - Gesture synchronization

void WCSynchronizeInputGestures(MMGrowTextView *view) {
    if (!view) return;
    BOOL enabled = WCGestureEnabled(WCInputGestureEnabledKey) && view.window;
    // Swipe recognizers
    UISwipeGestureRecognizer *left = objc_getAssociatedObject(view, &WCInputSwipeLeftRecognizerKey);
    UISwipeGestureRecognizer *right = objc_getAssociatedObject(view, &WCInputSwipeRightRecognizerKey);
    BOOL swipeLeftOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeLeftActionKey] != WCInputActionNone;
    BOOL swipeRightOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputSwipeRightActionKey] != WCInputActionNone;
    if (swipeLeftOn && !left) {
        left = [[UISwipeGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputSwipeLeft:)];
        left.direction = UISwipeGestureRecognizerDirectionLeft;
        left.cancelsTouchesInView = NO;
        [view addGestureRecognizer:left];
        objc_setAssociatedObject(view, &WCInputSwipeLeftRecognizerKey, left, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!swipeLeftOn && left) {
        [view removeGestureRecognizer:left];
        objc_setAssociatedObject(view, &WCInputSwipeLeftRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (swipeRightOn && !right) {
        right = [[UISwipeGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputSwipeRight:)];
        right.direction = UISwipeGestureRecognizerDirectionRight;
        right.cancelsTouchesInView = NO;
        [view addGestureRecognizer:right];
        objc_setAssociatedObject(view, &WCInputSwipeRightRecognizerKey, right, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!swipeRightOn && right) {
        [view removeGestureRecognizer:right];
        objc_setAssociatedObject(view, &WCInputSwipeRightRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Multi-tap recognizers
    UITapGestureRecognizer *doubleTap = objc_getAssociatedObject(view, &WCInputDoubleTapRecognizerKey);
    UITapGestureRecognizer *tripleTap = objc_getAssociatedObject(view, &WCInputTripleTapRecognizerKey);
    BOOL doubleOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputDoubleTapActionKey] != WCInputActionNone;
    BOOL tripleOn = enabled && (WCInputAction)[[NSUserDefaults standardUserDefaults]
        integerForKey:WCInputTripleTapActionKey] != WCInputActionNone;
    if (!doubleOn && doubleTap) {
        [view removeGestureRecognizer:doubleTap];
        objc_setAssociatedObject(view, &WCInputDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        doubleTap = nil;
    }
    if (!tripleOn && tripleTap) {
        [view removeGestureRecognizer:tripleTap];
        objc_setAssociatedObject(view, &WCInputTripleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tripleTap = nil;
        if (doubleTap) {
            [view removeGestureRecognizer:doubleTap];
            objc_setAssociatedObject(view, &WCInputDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            doubleTap = nil;
        }
    }
    if (!doubleTap && doubleOn) {
        doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputTapAction:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.numberOfTouchesRequired = 1;
        doubleTap.cancelsTouchesInView = YES;
        [view addGestureRecognizer:doubleTap];
        objc_setAssociatedObject(view, &WCInputDoubleTapRecognizerKey, doubleTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!tripleTap && tripleOn) {
        tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(wc_handleInputTapAction:)];
        tripleTap.numberOfTapsRequired = 3;
        tripleTap.numberOfTouchesRequired = 1;
        tripleTap.cancelsTouchesInView = YES;
        [view addGestureRecognizer:tripleTap];
        objc_setAssociatedObject(view, &WCInputTripleTapRecognizerKey, tripleTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (doubleTap && tripleTap) [doubleTap requireGestureRecognizerToFail:tripleTap];
}
