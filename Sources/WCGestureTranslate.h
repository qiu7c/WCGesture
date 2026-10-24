#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCGestureTranslateCompletion)(NSString * _Nullable translated,
                                             NSString * _Nullable errorMessage);

/// Languages that can be the other side of the translation pair
/// (中文 ↔ 目标语言). Each item is { @"code": NSString, @"title": NSString }.
NSArray<NSDictionary *> *WCTranslateLanguageOptions(void);

/// Display name of a language code ("en" → 英语). "zh-Hans" → 中文.
NSString *WCTranslateLanguageName(NSString *code);

/// The configured target code of the pair; never "zh-Hans".
NSString *WCTranslatePairTargetCode(void);

/// Translates text into `targetCode`. "zh-Hans" means Simplified Chinese,
/// otherwise the configured language pair's other side is used as source.
/// Completion runs on the main queue.
void WCGestureTranslateText(NSString *text, NSString *targetCode,
                            WCGestureTranslateCompletion completion);

NS_ASSUME_NONNULL_END
