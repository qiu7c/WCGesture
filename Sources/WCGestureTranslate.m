#import "WCGestureTranslate.h"
#import "WCGestureConfig.h"

// Parse the Edge "translatetext" response: array of items, each either
// {translations:[{text}]} or {text}.
static NSString *WCExtractEdgeTranslation(id object) {
    if (![object isKindOfClass:[NSArray class]] || [object count] == 0) return nil;
    id first = [(NSArray *)object firstObject];
    if ([first isKindOfClass:[NSArray class]] && [first count] > 0) first = [(NSArray *)first firstObject];
    if (![first isKindOfClass:[NSDictionary class]]) return nil;
    id translations = ((NSDictionary *)first)[@"translations"];
    if ([translations isKindOfClass:[NSArray class]] && [translations count] > 0) {
        id item = [(NSArray *)translations firstObject];
        if ([item isKindOfClass:[NSDictionary class]]) {
            id text = ((NSDictionary *)item)[@"text"];
            if ([text isKindOfClass:[NSString class]]) return text;
        }
    }
    id text = ((NSDictionary *)first)[@"text"];
    return [text isKindOfClass:[NSString class]] ? text : nil;
}

static NSString *WCExtractCustomTranslation(id object) {
    if (![object isKindOfClass:[NSDictionary class]]) return nil;
    id choices = ((NSDictionary *)object)[@"choices"];
    if (![choices isKindOfClass:[NSArray class]] || [choices count] == 0) return nil;
    id first = [(NSArray *)choices firstObject];
    if (![first isKindOfClass:[NSDictionary class]]) return nil;
    id message = ((NSDictionary *)first)[@"message"];
    if (![message isKindOfClass:[NSDictionary class]]) return nil;
    id content = ((NSDictionary *)message)[@"content"];
    if ([content isKindOfClass:[NSString class]]) return content;
    // Some providers return content as an array of parts.
    if ([content isKindOfClass:[NSArray class]]) {
        NSMutableString *joined = [NSMutableString string];
        for (id part in (NSArray *)content) {
            if ([part isKindOfClass:[NSDictionary class]]) {
                id text = ((NSDictionary *)part)[@"text"];
                if ([text isKindOfClass:[NSString class]]) [joined appendString:text];
            }
        }
        return joined.length > 0 ? joined : nil;
    }
    return nil;
}

static NSString *WCEdgeLanguage(BOOL toEnglish, BOOL source) {
    if (toEnglish) return source ? @"zh-Hans" : @"en";
    return source ? @"en" : @"zh-Hans";
}

static void WCTranslateEdge(NSString *text, BOOL toEnglish, void (^handler)(NSString *)) {
    NSString *urlString = [NSString stringWithFormat:
        @"https://edge.microsoft.com/translate/translatetext?from=%@&to=%@&isEnterpriseClient=false",
        WCEdgeLanguage(toEnglish, YES), WCEdgeLanguage(toEnglish, NO)];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 12.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
     forHTTPHeaderField:@"User-Agent"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@[text] options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError *error) {
        NSString *translated = WCExtractEdgeTranslation(data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil);
        if (handler) handler(translated);
    }] resume];
}

static void WCTranslateMyMemory(NSString *text, BOOL toEnglish, void (^handler)(NSString *)) {
    NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: @"";
    NSString *pair = toEnglish ? @"zh-CN|en" : @"en|zh-CN";
    NSString *urlString = [NSString stringWithFormat:@"https://api.mymemory.translated.net/get?q=%@&langpair=%@", encoded, pair];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:12.0];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError *error) {
        NSString *translated = nil;
        if (data.length) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([object isKindOfClass:[NSDictionary class]]) {
                id responseData = ((NSDictionary *)object)[@"responseData"];
                if ([responseData isKindOfClass:[NSDictionary class]]) {
                    id value = ((NSDictionary *)responseData)[@"translatedText"];
                    if ([value isKindOfClass:[NSString class]]) translated = value;
                }
            }
        }
        if (handler) handler(translated);
    }] resume];
}

static void WCTranslateCustom(NSString *text, BOOL toEnglish, void (^handler)(NSString *)) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *urlString = [defaults stringForKey:WCTranslateCustomURLKey];
    NSString *apiKey = [defaults stringForKey:WCTranslateCustomKeyKey];
    NSString *model = [defaults stringForKey:WCTranslateCustomModelKey];
    if (urlString.length == 0) { if (handler) handler(nil); return; }
    if (model.length == 0) model = @"gpt-4o-mini";
    NSString *prompt = toEnglish
        ? @"Translate the user's text to English. Output only the translation, without quotes or explanation."
        : @"Translate the user's text to Chinese. Output only the translation, without quotes or explanation.";
    NSDictionary *body = @{
        @"model": model,
        @"messages": @[
            @{ @"role": @"system", @"content": prompt },
            @{ @"role": @"user", @"content": text },
        ],
        @"temperature": @0,
    };
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (apiKey.length > 0) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    }
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError *error) {
        NSString *translated = WCExtractCustomTranslation(data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil);
        if (handler) handler(translated);
    }] resume];
}

void WCGestureTranslateText(NSString *text, BOOL toEnglish, WCGestureTranslateCompletion completion) {
    void (^deliver)(NSString *, NSString *) = ^(NSString *translated, NSString *errorMessage) {
        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(translated, errorMessage); });
    };
    if (text.length == 0) { deliver(nil, @"输入为空"); return; }

    NSInteger engine = [[NSUserDefaults standardUserDefaults] integerForKey:WCTranslateEngineKey];
    if (engine == WCTranslateEngineCustom) {
        WCTranslateCustom(text, toEnglish, ^(NSString *custom) {
            if (custom.length) { deliver(custom, nil); return; }
            // Fall back to the free engines when the custom endpoint fails.
            WCTranslateEdge(text, toEnglish, ^(NSString *edge) {
                if (edge.length) { deliver(edge, nil); return; }
                WCTranslateMyMemory(text, toEnglish, ^(NSString *mm) {
                    if (mm.length) deliver(mm, nil);
                    else deliver(nil, @"翻译失败（自定义接口与备用接口均不可用）");
                });
            });
        });
        return;
    }
    if (engine == WCTranslateEngineMyMemory) {
        WCTranslateMyMemory(text, toEnglish, ^(NSString *mm) {
            if (mm.length) { deliver(mm, nil); return; }
            WCTranslateEdge(text, toEnglish, ^(NSString *edge) {
                if (edge.length) deliver(edge, nil);
                else deliver(nil, @"翻译失败");
            });
        });
        return;
    }
    // Default: Edge primary, MyMemory fallback.
    WCTranslateEdge(text, toEnglish, ^(NSString *edge) {
        if (edge.length) { deliver(edge, nil); return; }
        WCTranslateMyMemory(text, toEnglish, ^(NSString *mm) {
            if (mm.length) deliver(mm, nil);
            else deliver(nil, @"翻译失败");
        });
    });
}
