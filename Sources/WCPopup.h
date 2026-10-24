#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WCPopupOption : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) id value;
+ (instancetype)optionWithTitle:(NSString *)title value:(id)value;
@end

/// A fully self-drawn popup (dimmed backdrop + rounded white card), replacing
/// UIAlertController. All methods present on a dedicated alert-level window.
@interface WCPopup : NSObject

/// Single-select option list. `selected` is compared using isEqual.
+ (void)showOptionsWithTitle:(NSString *)title
                     message:(nullable NSString *)message
                     options:(NSArray<WCPopupOption *> *)options
                    selected:(nullable id)selected
                  completion:(void (^)(id selectedValue))completion;

/// Text input. `completion` receives the trimmed text; cancel does not call it.
+ (void)showInputWithTitle:(NSString *)title
                   message:(nullable NSString *)message
                      text:(nullable NSString *)text
               placeholder:(nullable NSString *)placeholder
                  keyboard:(UIKeyboardType)keyboard
                completion:(void (^)(NSString *text))completion;

/// Read-only selectable text with copy + close buttons.
+ (void)showTextWithTitle:(NSString *)title
                  message:(nullable NSString *)message
                     text:(NSString *)text;

/// Simple message with a single "好" button.
+ (void)showMessage:(NSString *)title
            message:(nullable NSString *)message;

@end

NS_ASSUME_NONNULL_END
