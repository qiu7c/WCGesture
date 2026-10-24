#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^WCGestureTranslateCompletion)(NSString * _Nullable translated,
                                             NSString * _Nullable errorMessage);

/// Translates text using free, key-less engines: Microsoft Edge
/// (translatetext) as primary, MyMemory as fallback. Completion runs on the
/// main queue.
void WCGestureTranslateText(NSString *text, BOOL toEnglish, WCGestureTranslateCompletion completion);

NS_ASSUME_NONNULL_END
