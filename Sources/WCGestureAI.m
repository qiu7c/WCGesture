#import "WCGestureAI.h"
#import "WCGestureConfig.h"

static NSString *WCAITrimmed(NSString *text) {
    if (![text isKindOfClass:[NSString class]]) return @"";
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSDictionary<NSString *, NSString *> *WCAIProviderTemplate(NSInteger provider) {
    switch (provider) {
        case WCGestureAIProviderDeepSeek:
            return @{ @"base": @"https://api.deepseek.com/v1",
                      @"model": @"deepseek-chat" };
        case WCGestureAIProviderQwen:
            return @{ @"base": @"https://dashscope.aliyuncs.com/compatible-mode/v1",
                      @"model": @"qwen-plus" };
        case WCGestureAIProviderBailian:
            return @{ @"base": @"https://dashscope.aliyuncs.com/compatible-mode/v1",
                      @"model": @"qwen-max" };
        case WCGestureAIProviderSiliconFlow:
            return @{ @"base": @"https://api.siliconflow.cn/v1",
                      @"model": @"deepseek-ai/DeepSeek-V3" };
        default:
            return @{ @"base": @"", @"model": @"" };
    }
}

NSString *WCGestureAIProviderName(NSInteger provider) {
    switch (provider) {
        case WCGestureAIProviderDeepSeek: return @"DeepSeek";
        case WCGestureAIProviderQwen: return @"千问";
        case WCGestureAIProviderBailian: return @"百炼";
        case WCGestureAIProviderSiliconFlow: return @"硅基流动";
        default: return @"自定义";
    }
}

NSString *WCGestureAIProviderDefaultBaseURL(NSInteger provider) {
    return WCAIProviderTemplate(provider)[@"base"] ?: @"";
}

NSString *WCGestureAIProviderDefaultModel(NSInteger provider) {
    return WCAIProviderTemplate(provider)[@"model"] ?: @"";
}

NSString *WCGestureAIResolvedBaseURL(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *base = WCAITrimmed([defaults stringForKey:WCGestureAIBaseURLKey]);
    if (base.length > 0) return base;
    return WCGestureAIProviderDefaultBaseURL([defaults integerForKey:WCGestureAIProviderKey]);
}

NSString *WCGestureAIResolvedModel(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *model = WCAITrimmed([defaults stringForKey:WCGestureAIModelKey]);
    if (model.length > 0) return model;
    return WCGestureAIProviderDefaultModel([defaults integerForKey:WCGestureAIProviderKey]);
}

static NSString *WCAIAPIKey(void) {
    return WCAITrimmed([[NSUserDefaults standardUserDefaults] stringForKey:WCGestureAIAPIKeyKey]);
}

BOOL WCGestureAIIsConfigured(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger provider = [defaults integerForKey:WCGestureAIProviderKey];
    if (WCGestureAIResolvedBaseURL().length == 0) return NO;
    // Self-hosted / custom endpoints often accept requests without a key.
    return WCAIAPIKey().length > 0 || provider == WCGestureAIProviderCustom;
}

static NSString *WCAIExtractContent(id object) {
    if (![object isKindOfClass:[NSDictionary class]]) return nil;
    id choices = ((NSDictionary *)object)[@"choices"];
    if (![choices isKindOfClass:[NSArray class]] || [choices count] == 0) return nil;
    id first = [(NSArray *)choices firstObject];
    if (![first isKindOfClass:[NSDictionary class]]) return nil;
    id message = ((NSDictionary *)first)[@"message"];
    if ([message isKindOfClass:[NSDictionary class]]) {
        id content = ((NSDictionary *)message)[@"content"];
        if ([content isKindOfClass:[NSString class]]) return content;
        // Some providers return content as an array of parts.
        if ([content isKindOfClass:[NSArray class]]) {
            NSMutableString *joined = [NSMutableString string];
            for (id part in (NSArray *)content) {
                if (![part isKindOfClass:[NSDictionary class]]) continue;
                id text = ((NSDictionary *)part)[@"text"];
                if ([text isKindOfClass:[NSString class]]) [joined appendString:text];
            }
            if (joined.length > 0) return joined;
        }
    }
    id text = ((NSDictionary *)first)[@"text"];
    return [text isKindOfClass:[NSString class]] ? text : nil;
}

static NSString *WCAIExtractError(id object) {
    if (![object isKindOfClass:[NSDictionary class]]) return nil;
    id error = ((NSDictionary *)object)[@"error"];
    if ([error isKindOfClass:[NSDictionary class]]) {
        id message = ((NSDictionary *)error)[@"message"];
        if ([message isKindOfClass:[NSString class]]) return message;
    }
    if ([error isKindOfClass:[NSString class]]) return error;
    id message = ((NSDictionary *)object)[@"message"];
    return [message isKindOfClass:[NSString class]] ? message : nil;
}

static NSString *WCAIPresetSelectionKeyForTask(WCGestureAITask task) {
    switch (task) {
        case WCGestureAITaskReply: return WCGestureAIReplyPresetKey;
        case WCGestureAITaskAnswer: return WCGestureAIAnswerPresetKey;
        case WCGestureAITaskPolish: return WCGestureAIPolishPresetKey;
    }
    return nil;
}

// Extra instruction of the preset (方案 1/2/3) selected for this task.
static NSString *WCAIPresetPromptForTask(WCGestureAITask task) {
    NSString *selectionKey = WCAIPresetSelectionKeyForTask(task);
    if (selectionKey.length == 0) return @"";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger index = [defaults integerForKey:selectionKey];
    if (index < 0 || index > 2) index = 0;
    NSArray<NSString *> *keys = @[
        WCGestureAIPresetPrompt1Key,
        WCGestureAIPresetPrompt2Key,
        WCGestureAIPresetPrompt3Key,
    ];
    return WCAITrimmed([defaults stringForKey:keys[(NSUInteger)index]]);
}

static NSString *WCAIBaseSystemPrompt(WCGestureAITask task) {
    switch (task) {
        case WCGestureAITaskReply:
            return @"你在帮用户回复微信聊天。根据对方发来的消息，写一条自然、简短的中文回复。"
                   @"只输出回复正文，不要引号、不要解释，也不要复述原文。";
        case WCGestureAITaskAnswer:
            return @"回答用户提出的问题。用简体中文，简洁直接；需要分步骤时用编号。只输出答案本身。";
        case WCGestureAITaskPolish:
            return @"润色用户提供的文字：保持原意和语气，让表达更通顺自然。只输出润色后的文字，不要解释。";
    }
    return @"";
}

static NSString *WCAISystemPrompt(WCGestureAITask task) {
    NSMutableString *prompt = [WCAIBaseSystemPrompt(task) mutableCopy];
    NSString *preset = WCAIPresetPromptForTask(task);
    if (preset.length > 0) [prompt appendFormat:@"补充要求：%@。", preset];
    return prompt;
}

static void WCAIPerformWithSystemPrompt(NSString *systemPrompt, NSString *input,
                                        double temperature, NSInteger maxTokens,
                                        WCGestureAICompletion completion) {
    void (^deliver)(NSString *, NSString *) = ^(NSString *text, NSString *errorMessage) {
        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(text, errorMessage); });
    };

    NSString *content = WCAITrimmed(input);
    if (content.length == 0) { deliver(nil, @"内容为空"); return; }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger provider = [defaults integerForKey:WCGestureAIProviderKey];
    NSString *base = WCGestureAIResolvedBaseURL();
    if (base.length == 0) { deliver(nil, @"请先在插件设置中配置 AI 接口"); return; }
    NSString *apiKey = WCAIAPIKey();
    if (apiKey.length == 0 && provider != WCGestureAIProviderCustom) {
        deliver(nil, @"请先在插件设置中填写 AI API Key");
        return;
    }
    NSString *model = WCGestureAIResolvedModel();
    if (model.length == 0) { deliver(nil, @"请先在插件设置中填写模型名称"); return; }

    NSString *endpoint = WCAITrimmed(base);
    if (![endpoint hasSuffix:@"/chat/completions"]) {
        while ([endpoint hasSuffix:@"/"]) endpoint = [endpoint substringToIndex:endpoint.length - 1];
        endpoint = [endpoint stringByAppendingString:@"/chat/completions"];
    }
    NSURL *url = [NSURL URLWithString:endpoint];
    if (!url) { deliver(nil, @"接口地址无效"); return; }

    NSDictionary *body = @{
        @"model": model,
        @"messages": @[
            @{ @"role": @"system", @"content": systemPrompt },
            @{ @"role": @"user", @"content": content },
        ],
        @"temperature": @(temperature),
        @"max_tokens": @(maxTokens),
        @"stream": @NO,
    };

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (apiKey.length > 0) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey]
       forHTTPHeaderField:@"Authorization"];
    }
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            deliver(nil, [NSString stringWithFormat:@"网络错误：%@", error.localizedDescription]);
            return;
        }
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)response).statusCode : 0;
        id object = data.length
            ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSString *text = WCAIExtractContent(object);
        text = WCAITrimmed(text);
        if (text.length > 0) { deliver(text, nil); return; }
        NSString *apiError = WCAIExtractError(object);
        if (status >= 400) {
            deliver(nil, apiError.length > 0
                ? [NSString stringWithFormat:@"请求失败 (%ld)：%@", (long)status, apiError]
                : [NSString stringWithFormat:@"请求失败 (%ld)", (long)status]);
        } else if (apiError.length > 0) {
            deliver(nil, apiError);
        } else {
            deliver(nil, @"返回内容为空");
        }
    }] resume];
}

void WCGestureAIPerform(WCGestureAITask task, NSString *input,
                        WCGestureAICompletion completion) {
    double temperature = 0.3;
    NSInteger maxTokens = 1200;
    if (task == WCGestureAITaskReply) {
        temperature = 0.8;
        maxTokens = 600;
    } else if (task == WCGestureAITaskAnswer) {
        temperature = 0.5;
    }
    WCAIPerformWithSystemPrompt(WCAISystemPrompt(task), input,
                                temperature, maxTokens, completion);
}

void WCGestureAITranslate(NSString *text, NSString *targetLanguage,
                          WCGestureAICompletion completion) {
    NSString *language = WCAITrimmed(targetLanguage);
    if (language.length == 0) language = @"简体中文";
    NSString *systemPrompt = [NSString stringWithFormat:
        @"把用户提供的文字翻译成%@。保持原意和语气，只输出译文；不要解释、不要引号，也不要附带原文。",
        language];
    WCAIPerformWithSystemPrompt(systemPrompt, text, 0.2, 1200, completion);
}
