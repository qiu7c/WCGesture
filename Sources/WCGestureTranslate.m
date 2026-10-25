#import "WCGestureTranslate.h"
#import "WCGestureConfig.h"
#import "WCGestureAI.h"

// Languages offered as the other side of the translation pair. "zh-Hans" is
// intentionally absent: it is always the Chinese side of the pair.
static NSArray<NSDictionary *> *WCTranslateLanguageTable(void) {
    return @[
        @{ @"code": @"en", @"title": @"英语", @"edge": @"en", @"memory": @"en", @"ai": @"英语" },
        @{ @"code": @"ja", @"title": @"日语", @"edge": @"ja", @"memory": @"ja", @"ai": @"日语" },
        @{ @"code": @"ko", @"title": @"韩语", @"edge": @"ko", @"memory": @"ko", @"ai": @"韩语" },
        @{ @"code": @"fr", @"title": @"法语", @"edge": @"fr", @"memory": @"fr", @"ai": @"法语" },
        @{ @"code": @"de", @"title": @"德语", @"edge": @"de", @"memory": @"de", @"ai": @"德语" },
        @{ @"code": @"ru", @"title": @"俄语", @"edge": @"ru", @"memory": @"ru", @"ai": @"俄语" },
        @{ @"code": @"es", @"title": @"西班牙语", @"edge": @"es", @"memory": @"es", @"ai": @"西班牙语" },
        @{ @"code": @"pt", @"title": @"葡萄牙语", @"edge": @"pt", @"memory": @"pt", @"ai": @"葡萄牙语" },
        @{ @"code": @"zh-Hant", @"title": @"繁体中文", @"edge": @"zh-Hant", @"memory": @"zh-TW", @"ai": @"繁体中文" },
    ];
}

static NSDictionary *WCTranslateLanguageEntry(NSString *code) {
    if (code.length == 0) return nil;
    for (NSDictionary *entry in WCTranslateLanguageTable()) {
        if ([entry[@"code"] isEqualToString:code]) return entry;
    }
    return nil;
}

NSArray<NSDictionary *> *WCTranslateLanguageOptions(void) {
    return WCTranslateLanguageTable();
}

NSString *WCTranslatePairTargetCode(void) {
    NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:WCTranslatePairTargetKey];
    return WCTranslateLanguageEntry(code) ? code : @"en";
}

NSString *WCTranslateLanguageName(NSString *code) {
    if ([code isEqualToString:@"zh-Hans"]) return @"中文";
    NSDictionary *entry = WCTranslateLanguageEntry(code);
    return entry ? entry[@"title"] : @"英语";
}

static BOOL WCTranslateHasHan(NSString *text) {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if ((c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) ||
            (c >= 0xF900 && c <= 0xFAFF)) return YES;
    }
    return NO;
}

static BOOL WCTranslateHasScript(NSString *text, unichar lower, unichar upper) {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= lower && c <= upper) return YES;
    }
    return NO;
}

// Shared Han characters cover both Chinese scripts, so a handful of very
// common traditional forms is enough to tell which side of 简/繁 was typed.
static BOOL WCTranslateLooksTraditional(NSString *text) {
    static NSString *markers = @"這說時會來為對國學麼樣兒頭長開關門東車馬語話讀寫聽請謝還進過發現實問題們個著裡與從沒讓給當點後";
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if ([markers rangeOfString:[NSString stringWithCharacters:&c length:1]].location != NSNotFound) return YES;
    }
    return NO;
}

NSString *WCTranslateTargetCodeForText(NSString *text) {
    NSString *pair = WCTranslatePairTargetCode();
    // Kana/Hangul can contain Han characters too, but such text is Japanese or
    // Korean, not Chinese, so it should be translated into Chinese.
    BOOL chinese = WCTranslateHasHan(text)
        && !WCTranslateHasScript(text, 0x3040, 0x30FF)  // hiragana + katakana
        && !WCTranslateHasScript(text, 0xAC00, 0xD7AF); // hangul syllables
    if (!chinese) return @"zh-Hans";
    if ([pair isEqualToString:@"zh-Hant"] && WCTranslateLooksTraditional(text)) return @"zh-Hans";
    return pair;
}

static NSString *WCTranslateEntryValue(NSString *code, NSString *field, NSString *fallback) {
    NSDictionary *entry = WCTranslateLanguageEntry(code);
    NSString *value = entry[field];
    return value.length > 0 ? value : fallback;
}

// 中文 → pair: source is Chinese; pair → 中文: source is the pair language.
static NSString *WCTranslateEdgeSource(NSString *targetCode) {
    if ([targetCode isEqualToString:@"zh-Hans"]) {
        return WCTranslateEntryValue(WCTranslatePairTargetCode(), @"edge", @"en");
    }
    return @"zh-Hans";
}

static NSString *WCTranslateEdgeTarget(NSString *targetCode) {
    if ([targetCode isEqualToString:@"zh-Hans"]) return @"zh-Hans";
    return WCTranslateEntryValue(targetCode, @"edge", @"en");
}

static NSString *WCTranslateMemorySource(NSString *targetCode) {
    if ([targetCode isEqualToString:@"zh-Hans"]) {
        return WCTranslateEntryValue(WCTranslatePairTargetCode(), @"memory", @"en");
    }
    return @"zh-CN";
}

static NSString *WCTranslateMemoryTarget(NSString *targetCode) {
    if ([targetCode isEqualToString:@"zh-Hans"]) return @"zh-CN";
    return WCTranslateEntryValue(targetCode, @"memory", @"en");
}

static NSString *WCTranslateAILanguageName(NSString *targetCode) {
    if ([targetCode isEqualToString:@"zh-Hans"]) return @"简体中文";
    return WCTranslateEntryValue(targetCode, @"ai", @"英语");
}

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

static void WCTranslateEdge(NSString *text, NSString *targetCode, void (^handler)(NSString *)) {
    NSString *urlString = [NSString stringWithFormat:
        @"https://edge.microsoft.com/translate/translatetext?from=%@&to=%@&isEnterpriseClient=false",
        WCTranslateEdgeSource(targetCode), WCTranslateEdgeTarget(targetCode)];
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

static void WCTranslateMyMemory(NSString *text, NSString *targetCode, void (^handler)(NSString *)) {
    // URLQueryAllowedCharacterSet keeps "&", "+" and "=", which would break the
    // query string for text that contains them.
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&+=?#"];
    NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
    NSString *pair = [NSString stringWithFormat:@"%@|%@",
        WCTranslateMemorySource(targetCode), WCTranslateMemoryTarget(targetCode)];
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

// The former custom endpoint is gone: the AI engine reuses the configured AI
// provider with a preset translation prompt.
static void WCTranslateAI(NSString *text, NSString *targetCode, void (^handler)(NSString *)) {
    WCGestureAITranslate(text, WCTranslateAILanguageName(targetCode),
                         ^(NSString *translated, __unused NSString *errorMessage) {
        if (handler) handler(translated);
    });
}

void WCGestureTranslateText(NSString *text, NSString *targetCode,
                            WCGestureTranslateCompletion completion) {
    void (^deliver)(NSString *, NSString *) = ^(NSString *translated, NSString *errorMessage) {
        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(translated, errorMessage); });
    };
    if (text.length == 0) { deliver(nil, @"输入为空"); return; }
    if (targetCode.length == 0) targetCode = WCTranslatePairTargetCode();

    NSInteger engine = [[NSUserDefaults standardUserDefaults] integerForKey:WCTranslateEngineKey];
    if (engine == WCTranslateEngineAI) {
        WCTranslateAI(text, targetCode, ^(NSString *ai) {
            if (ai.length) { deliver(ai, nil); return; }
            // AI unconfigured or failed: keep translating with a free engine.
            WCTranslateEdge(text, targetCode, ^(NSString *edge) {
                if (edge.length) { deliver(edge, nil); return; }
                WCTranslateMyMemory(text, targetCode, ^(NSString *mm) {
                    if (mm.length) deliver(mm, nil);
                    else deliver(nil, @"翻译失败（AI 与备用接口均不可用）");
                });
            });
        });
        return;
    }
    if (engine == WCTranslateEngineMyMemory) {
        WCTranslateMyMemory(text, targetCode, ^(NSString *mm) {
            if (mm.length) { deliver(mm, nil); return; }
            WCTranslateEdge(text, targetCode, ^(NSString *edge) {
                if (edge.length) deliver(edge, nil);
                else deliver(nil, @"翻译失败");
            });
        });
        return;
    }
    // Default: Edge primary, MyMemory fallback.
    WCTranslateEdge(text, targetCode, ^(NSString *edge) {
        if (edge.length) { deliver(edge, nil); return; }
        WCTranslateMyMemory(text, targetCode, ^(NSString *mm) {
            if (mm.length) deliver(mm, nil);
            else deliver(nil, @"翻译失败");
        });
    });
}
