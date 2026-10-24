#import "WCPopup.h"
#import <objc/runtime.h>

#pragma mark - Option

@implementation WCPopupOption
+ (instancetype)optionWithTitle:(NSString *)title value:(id)value {
    WCPopupOption *o = [WCPopupOption new];
    o.title = title;
    o.value = value;
    return o;
}
@end

#pragma mark - Window helpers

static UIWindow *WCPopupWindow = nil;

static UIWindow *WCPopupActiveWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) return w;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (!w.hidden && w.alpha > 0.0) return w;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static UIWindow *WCPopupMakeWindow(void) {
    UIWindow *active = WCPopupActiveWindow();
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = active.windowScene;
        if (scene) win = [[UIWindow alloc] initWithWindowScene:scene];
    }
    if (!win) win = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    win.frame = UIScreen.mainScreen.bounds;
    win.windowLevel = UIWindowLevelAlert + 1;
    win.backgroundColor = UIColor.clearColor;
    return win;
}

#pragma mark - Popup controller

typedef NS_ENUM(NSInteger, WCPopupMode) {
    WCPopupModeOptions,
    WCPopupModeInput,
    WCPopupModeText,
    WCPopupModeMessage,
};

@interface WCPopupController : UIViewController
@property (nonatomic, assign) WCPopupMode mode;
@property (nonatomic, copy) NSString *popupTitle;
@property (nonatomic, copy) NSString *popupMessage;
@property (nonatomic, copy) NSArray<WCPopupOption *> *options;
@property (nonatomic, strong) id selectedValue;
@property (nonatomic, copy) NSString *inputText;
@property (nonatomic, assign) BOOL secureInput;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, assign) UIKeyboardType keyboard;
@property (nonatomic, copy) NSString *codeText;
@property (nonatomic, copy) void (^onSelect)(id value);
@property (nonatomic, copy) void (^onInput)(NSString *text);
@property (nonatomic, strong) UIView *dimming;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UITextView *codeView;

- (void)buildContent;
- (UIView *)makeTitleArea;
- (UILabel *)makeLabel:(NSString *)text font:(UIFont *)font color:(UIColor *)color align:(NSTextAlignment)align;
- (UIButton *)makeActionButton:(NSString *)title color:(UIColor *)color primary:(BOOL)primary;
- (UIView *)makeButtonRowPrimary:(nullable NSString *)primaryTitle
                    primaryBlock:(nullable void (^)(void))primaryBlock
                     cancelTitle:(nullable NSString *)cancelTitle;
- (void)addMessageBelow:(NSString *)message inStack:(UIStackView *)stack;
- (void)buildOptions;
- (void)buildInput;
- (void)buildText;
- (void)buildMessage;
- (void)backdropTapped;
- (void)dismissWithResult:(nullable id)result;
- (void)tearDown;
@end

@implementation WCPopupController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    UIView *dimming = [[UIView alloc] init];
    dimming.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    dimming.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:dimming];
    self.dimming = dimming;
    [dimming.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [dimming.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [dimming.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [dimming.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [dimming addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped)]];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 20.0;
    card.layer.masksToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:card];
    self.card = card;

    [card.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    NSLayoutConstraint *edgeWidth = [card.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-56.0];
    edgeWidth.priority = 999.0;
    edgeWidth.active = YES;
    [card.widthAnchor constraintLessThanOrEqualToConstant:340.0].active = YES;
    [card.heightAnchor constraintLessThanOrEqualToAnchor:self.view.heightAnchor multiplier:0.78].active = YES;

    [self buildContent];
}

- (void)buildContent {
    switch (self.mode) {
        case WCPopupModeOptions: [self buildOptions]; break;
        case WCPopupModeInput:   [self buildInput];   break;
        case WCPopupModeText:    [self buildText];    break;
        case WCPopupModeMessage: [self buildMessage]; break;
    }
}

#pragma mark Building blocks

- (UIView *)makeTitleArea {
    UIView *area = [[UIView alloc] init];
    area.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *label = [self makeLabel:self.popupTitle font:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
                               color:UIColor.labelColor align:NSTextAlignmentCenter];
    [area addSubview:label];
    [label.leadingAnchor constraintEqualToAnchor:area.leadingAnchor constant:20].active = YES;
    [label.trailingAnchor constraintEqualToAnchor:area.trailingAnchor constant:-20].active = YES;
    [label.centerYAnchor constraintEqualToAnchor:area.centerYAnchor].active = YES;
    [area.heightAnchor constraintEqualToConstant:60].active = YES;
    return area;
}

- (UILabel *)makeLabel:(NSString *)text font:(UIFont *)font color:(UIColor *)color align:(NSTextAlignment)align {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.textAlignment = align;
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UIButton *)makeActionButton:(NSString *)title color:(UIColor *)color primary:(BOOL)primary {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:(primary ? 16.5 : 16.0) weight:(primary ? UIFontWeightSemibold : UIFontWeightRegular)];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

// A full-width bottom bar with one or two action buttons.
- (UIView *)makeButtonRowPrimary:(nullable NSString *)primaryTitle
                     primaryBlock:(nullable void (^)(void))primaryBlock
                      cancelTitle:(nullable NSString *)cancelTitle {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row.heightAnchor constraintEqualToConstant:54].active = YES;

    UIButton *cancel = [self makeActionButton:(cancelTitle ?: @"取消") color:UIColor.secondaryLabelColor primary:NO];
    __weak typeof(self) weakSelf = self;
    [cancel addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf dismissWithResult:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:cancel];
    [cancel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor].active = YES;

    if (primaryTitle) {
        UIButton *primary = [self makeActionButton:primaryTitle color:UIColor.systemBlueColor primary:YES];
        [primary addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
            if (primaryBlock) primaryBlock();
        }] forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:primary];
        [primary.centerYAnchor constraintEqualToAnchor:row.centerYAnchor].active = YES;

        [cancel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor].active = YES;
        [cancel.widthAnchor constraintEqualToAnchor:row.widthAnchor multiplier:0.5].active = YES;
        [primary.leadingAnchor constraintEqualToAnchor:row.centerXAnchor].active = YES;
        [primary.trailingAnchor constraintEqualToAnchor:row.trailingAnchor].active = YES;
    } else {
        [cancel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor].active = YES;
        [cancel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor].active = YES;
    }
    return row;
}

- (void)addMessageBelow:(NSString *)message inStack:(UIStackView *)stack {
    if (message.length == 0) return;
    UIView *wrap = [[UIView alloc] init];
    wrap.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *label = [self makeLabel:message font:[UIFont systemFontOfSize:13] color:UIColor.secondaryLabelColor align:NSTextAlignmentCenter];
    [wrap addSubview:label];
    [label.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:20].active = YES;
    [label.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-20].active = YES;
    [label.topAnchor constraintEqualToAnchor:wrap.topAnchor].active = YES;
    [label.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-4].active = YES;
    [stack addArrangedSubview:wrap];
}

#pragma mark Options mode

- (void)buildOptions {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:stack];
    [stack.topAnchor constraintEqualToAnchor:self.card.topAnchor].active = YES;
    [stack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor].active = YES;
    [stack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor].active = YES;
    [stack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor].active = YES;

    [stack addArrangedSubview:[self makeTitleArea]];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = YES;
    [stack addArrangedSubview:scroll];

    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 0;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:rows];
    [rows.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor].active = YES;
    [rows.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor].active = YES;
    [rows.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor].active = YES;
    [rows.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor].active = YES;
    [rows.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor].active = YES;

    NSLayoutConstraint *scrollEq = [scroll.heightAnchor constraintEqualToAnchor:rows.heightAnchor];
    scrollEq.priority = 998.0;
    scrollEq.active = YES;

    [self.options enumerateObjectsUsingBlock:^(WCPopupOption *option, NSUInteger index, __unused BOOL *stop) {
        (void)index;
        BOOL selected = [option.value isEqual:self.selectedValue];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 20);
        [row setTitle:option.title forState:UIControlStateNormal];
        [row setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:16];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [row.heightAnchor constraintEqualToConstant:52].active = YES;
        if (selected) {
            UIImage *check = [UIImage systemImageNamed:@"checkmark"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]];
            UIImageView *iv = [[UIImageView alloc] initWithImage:check];
            iv.tintColor = UIColor.systemBlueColor;
            iv.translatesAutoresizingMaskIntoConstraints = NO;
            [row addSubview:iv];
            [iv.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-20].active = YES;
            [iv.centerYAnchor constraintEqualToAnchor:row.centerYAnchor].active = YES;
        }
        NSUInteger capturedIndex = index;
        __weak typeof(self) weakSelf = self;
        [row addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            WCPopupOption *picked = strongSelf.options[capturedIndex];
            [strongSelf dismissWithResult:picked.value];
        }] forControlEvents:UIControlEventTouchUpInside];
        [rows addArrangedSubview:row];
    }];

    [stack addArrangedSubview:[self makeButtonRowPrimary:nil primaryBlock:nil cancelTitle:@"取消"]];
}

#pragma mark Input mode

- (void)buildInput {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:stack];
    [stack.topAnchor constraintEqualToAnchor:self.card.topAnchor].active = YES;
    [stack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor].active = YES;
    [stack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor].active = YES;
    [stack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor].active = YES;

    [stack addArrangedSubview:[self makeTitleArea]];
    [self addMessageBelow:self.popupMessage inStack:stack];

    UIView *fieldWrap = [[UIView alloc] init];
    fieldWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:fieldWrap];

    UITextField *field = [[UITextField alloc] init];
    field.text = self.inputText;
    field.placeholder = self.placeholder;
    field.keyboardType = self.keyboard;
    field.secureTextEntry = self.secureInput;
    field.font = [UIFont systemFontOfSize:16];
    field.textColor = UIColor.labelColor;
    field.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    field.layer.cornerRadius = 10.0;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    field.rightViewMode = UITextFieldViewModeAlways;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [fieldWrap addSubview:field];
    self.inputField = field;

    [field.topAnchor constraintEqualToAnchor:fieldWrap.topAnchor].active = YES;
    [field.bottomAnchor constraintEqualToAnchor:fieldWrap.bottomAnchor constant:-4].active = YES;
    [field.leadingAnchor constraintEqualToAnchor:fieldWrap.leadingAnchor constant:20].active = YES;
    [field.trailingAnchor constraintEqualToAnchor:fieldWrap.trailingAnchor constant:-20].active = YES;
    [field.heightAnchor constraintEqualToConstant:44].active = YES;

    __weak typeof(self) weakSelf = self;
    [stack addArrangedSubview:[self makeButtonRowPrimary:@"确定" primaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *text = [strongSelf.inputField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [strongSelf dismissWithResult:(text.length > 0 ? text : nil)];
    } cancelTitle:@"取消"]];
}

#pragma mark Text mode

- (void)buildText {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:stack];
    [stack.topAnchor constraintEqualToAnchor:self.card.topAnchor].active = YES;
    [stack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor].active = YES;
    [stack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor].active = YES;
    [stack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor].active = YES;

    [stack addArrangedSubview:[self makeTitleArea]];
    [self addMessageBelow:self.popupMessage inStack:stack];

    UIView *codeWrap = [[UIView alloc] init];
    codeWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:codeWrap];

    UITextView *code = [[UITextView alloc] init];
    code.text = self.codeText;
    code.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    code.textColor = UIColor.labelColor;
    code.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    code.layer.cornerRadius = 10.0;
    code.editable = NO;
    code.selectable = YES;
    code.textContainerInset = UIEdgeInsetsMake(10, 8, 10, 8);
    code.translatesAutoresizingMaskIntoConstraints = NO;
    [codeWrap addSubview:code];
    self.codeView = code;

    [code.topAnchor constraintEqualToAnchor:codeWrap.topAnchor].active = YES;
    [code.bottomAnchor constraintEqualToAnchor:codeWrap.bottomAnchor constant:-4].active = YES;
    [code.leadingAnchor constraintEqualToAnchor:codeWrap.leadingAnchor constant:20].active = YES;
    [code.trailingAnchor constraintEqualToAnchor:codeWrap.trailingAnchor constant:-20].active = YES;
    [code.heightAnchor constraintEqualToConstant:140].active = YES;

    __weak typeof(self) weakSelf = self;
    [stack addArrangedSubview:[self makeButtonRowPrimary:@"复制" primaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        UIPasteboard.generalPasteboard.string = strongSelf.codeText;
        [strongSelf dismissWithResult:nil];
    } cancelTitle:@"关闭"]];
}

#pragma mark Message mode

- (void)buildMessage {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:stack];
    [stack.topAnchor constraintEqualToAnchor:self.card.topAnchor].active = YES;
    [stack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor].active = YES;
    [stack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor].active = YES;
    [stack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor].active = YES;

    [stack addArrangedSubview:[self makeTitleArea]];
    [self addMessageBelow:self.popupMessage inStack:stack];
    [stack addArrangedSubview:[self makeButtonRowPrimary:nil primaryBlock:nil cancelTitle:@"好"]];
}

#pragma mark Selection / dismissal

- (void)backdropTapped {
    [self dismissWithResult:nil];
}

- (void)dismissWithResult:(id)result {
    BOOL isInput = (self.mode == WCPopupModeInput);
    void (^onSelect)(id) = self.onSelect;
    void (^onInput)(NSString *) = self.onInput;
    NSString *inputValue = [result isKindOfClass:[NSString class]] ? result : nil;

    [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.card.transform = CGAffineTransformMakeScale(0.94, 0.94);
        self.card.alpha = 0.0;
        self.dimming.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        [self tearDown];
        if (isInput) {
            if (onInput && inputValue) onInput(inputValue);
        } else if (onSelect && result) {
            onSelect(result);
        }
    }];
}

- (void)tearDown {
    UIWindow *win = self.view.window;
    win.hidden = YES;
    win.rootViewController = nil;
    WCPopupWindow = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.card.transform = CGAffineTransformMakeScale(0.92, 0.92);
    self.card.alpha = 0.0;
    self.dimming.alpha = 0.0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [UIView animateWithDuration:0.22 delay:0.0 usingSpringWithDamping:0.86 initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.card.transform = CGAffineTransformIdentity;
        self.card.alpha = 1.0;
        self.dimming.alpha = 1.0;
    } completion:nil];
}

@end

#pragma mark - Public API

@interface WCPopup ()
+ (WCPopupController *)presentController:(WCPopupController *)controller;
@end

@implementation WCPopup

+ (WCPopupController *)presentController:(WCPopupController *)controller {
    // Dismiss any existing popup first.
    if (WCPopupWindow) {
        WCPopupWindow.hidden = YES;
        WCPopupWindow.rootViewController = nil;
        WCPopupWindow = nil;
    }
    UIWindow *win = WCPopupMakeWindow();
    WCPopupWindow = win;
    win.rootViewController = controller;
    win.hidden = NO;
    [win makeKeyAndVisible];
    return controller;
}

+ (void)showOptionsWithTitle:(NSString *)title
                     message:(nullable NSString *)message
                     options:(NSArray<WCPopupOption *> *)options
                    selected:(nullable id)selected
                  completion:(void (^)(id selectedValue))completion {
    WCPopupController *c = [WCPopupController new];
    c.mode = WCPopupModeOptions;
    c.popupTitle = title;
    c.popupMessage = message;
    c.options = options ?: @[];
    c.selectedValue = selected;
    c.onSelect = completion;
    [self presentController:c];
}

+ (void)showInputWithTitle:(NSString *)title
                   message:(nullable NSString *)message
                      text:(nullable NSString *)text
               placeholder:(nullable NSString *)placeholder
                  keyboard:(UIKeyboardType)keyboard
                completion:(void (^)(NSString *text))completion {
    WCPopupController *c = [WCPopupController new];
    c.mode = WCPopupModeInput;
    c.popupTitle = title;
    c.popupMessage = message;
    c.inputText = text;
    c.placeholder = placeholder;
    c.keyboard = keyboard;
    c.onInput = completion;
    [self presentController:c];
}

+ (void)showSecureInputWithTitle:(NSString *)title
                         message:(nullable NSString *)message
                            text:(nullable NSString *)text
                     placeholder:(nullable NSString *)placeholder
                        keyboard:(UIKeyboardType)keyboard
                      completion:(void (^)(NSString *text))completion {
    WCPopupController *c = [WCPopupController new];
    c.mode = WCPopupModeInput;
    c.popupTitle = title;
    c.popupMessage = message;
    c.inputText = text;
    c.placeholder = placeholder;
    c.keyboard = keyboard;
    c.secureInput = YES;
    c.onInput = completion;
    [self presentController:c];
}

+ (void)showTextWithTitle:(NSString *)title
                  message:(nullable NSString *)message
                     text:(NSString *)text {
    WCPopupController *c = [WCPopupController new];
    c.mode = WCPopupModeText;
    c.popupTitle = title;
    c.popupMessage = message;
    c.codeText = text;
    [self presentController:c];
}

+ (void)showMessage:(NSString *)title message:(nullable NSString *)message {
    WCPopupController *c = [WCPopupController new];
    c.mode = WCPopupModeMessage;
    c.popupTitle = title;
    c.popupMessage = message;
    [self presentController:c];
}

@end
