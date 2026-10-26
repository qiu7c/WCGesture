#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
UIView *WCGestureCreateChatGlassView(void);
UIView *WCGestureChatGlassContent(UIView *glass);
void WCGestureConfigureChatGlass(UIView *glass);
void WCGestureConfigureChatPinnedGlass(UIView *glass);
CGFloat WCGestureChatTopBarScale(void);
CGFloat WCGestureChatTopBarShellFactor(void);
CGFloat WCGestureChatTopBarActionsWidth(BOOL search);
void WCGestureChatPinnedGlassApply(UIView *tips, BOOL enabled);
void WCGestureChatPinnedLayout(UIView *tips);
void WCGestureChatPinnedRefresh(void);

/// The native bar and the existing full-page chat preview use this same renderer.
@interface WCGestureChatTopCapsuleView : UIView
@property (nonatomic, copy, nullable) void (^backAction)(void);
@property (nonatomic, copy, nullable) void (^moreAction)(void);
@property (nonatomic, copy, nullable) void (^searchAction)(void);
- (instancetype)initWithProfile:(BOOL)profile;
- (void)setAvatarView:(UIView *)avatar;
- (CGSize)configureWithName:(NSString *)name typing:(BOOL)typing search:(BOOL)search
                 moreImage:(UIImage * _Nullable)image menu:(UIMenu * _Nullable)menu maximumWidth:(CGFloat)width;
@end

void WCGestureChatTopBarUpdate(UIViewController *controller);
void WCGestureChatTopBarPrepareAppearance(UIViewController *controller);
void WCGestureChatTopBarWillDisappear(UIViewController *controller);
void WCGestureChatTopBarNavigationLayout(UINavigationBar *bar);
void WCGestureChatTopBarRestore(UIViewController *controller);
void WCGestureChatTopBarTitleChanged(UIViewController *controller, id _Nullable titleView);
void WCGestureChatTopBarSettingsChanged(NSString * _Nullable key);
NS_ASSUME_NONNULL_END
