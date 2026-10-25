#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCGestureAITask) {
    WCGestureAITaskReply = 0,  // 根据对方消息写一条回复
    WCGestureAITaskAnswer = 1, // 回答输入框里的问题
    WCGestureAITaskPolish = 2, // 润色输入框里的文字
};

typedef void (^WCGestureAICompletion)(NSString * _Nullable text,
                                      NSString * _Nullable errorMessage);

/// Human-readable provider template name (DeepSeek / 千问 / 百炼 / 硅基流动 / 自定义).
NSString *WCGestureAIProviderName(NSInteger provider);

/// Endpoint/model a provider template fills in. Empty for the custom provider.
NSString *WCGestureAIProviderDefaultBaseURL(NSInteger provider);
NSString *WCGestureAIProviderDefaultModel(NSInteger provider);

/// What the request will actually use: the user's override, else the template.
NSString *WCGestureAIResolvedBaseURL(void);
NSString *WCGestureAIResolvedModel(void);

/// YES when the user turned the AI assistant on in settings.
BOOL WCGestureAIIsEnabled(void);

/// YES when an endpoint plus a key (custom providers may omit the key) are set.
BOOL WCGestureAIIsConfigured(void);

/// Editable prompt presets, each { @"name": NSString, @"prompt": NSString }.
/// Always returns at least one entry. Before the user edits the list, the
/// built-in three presets are derived from the legacy keys.
NSArray<NSDictionary<NSString *, NSString *> *> *WCGestureAIPresets(void);

/// Stores the preset list (sanitized, never empty) and keeps the per-task
/// selections within range.
void WCGestureAISetPresets(NSArray<NSDictionary *> *presets);

/// Title of the preset at `index`, clamped to the available list.
NSString *WCGestureAIPresetName(NSInteger index);

/// The built-in system prompt for a task. Shown in settings for reference and
/// used whenever the selected preset's prompt is empty.
NSString *WCGestureAIDefaultPrompt(WCGestureAITask task);

/// Sends one OpenAI-compatible chat completion. `input` is the text the task
/// works on (the message to reply to, the question, or the text to polish).
/// A non-empty prompt on the selected preset replaces the built-in prompt.
/// The completion always runs on the main queue.
void WCGestureAIPerform(WCGestureAITask task, NSString *input,
                        WCGestureAICompletion _Nullable completion);

/// Translates `text` into `targetLanguage` (a display name such as "英语")
/// with the built-in translation prompt. Used by the AI translation engine.
void WCGestureAITranslate(NSString *text, NSString *targetLanguage,
                          WCGestureAICompletion _Nullable completion);

NS_ASSUME_NONNULL_END
