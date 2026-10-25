#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCGestureCategory) {
    WCGestureCategoryChat,
    WCGestureCategoryGestures,
    WCGestureCategoryMoments,
    WCGestureCategoryInterface,
    WCGestureCategoryDisabled,
    WCGestureCategoryPlugin,
};

typedef NS_ENUM(NSInteger, WCGesturePreviewKind) {
    WCGesturePreviewMessageTime,
    WCGesturePreviewAntiRevoke,
    WCGesturePreviewLayout,
};

UIView *WCGestureCreateChatPreview(WCGesturePreviewKind kind);
void WCGestureSetPreviewEditing(UIView *preview, BOOL editing);
UIViewController *WCGestureCreatePositionEditor(WCGesturePreviewKind kind);
/// Reusable editor. Numeric descriptors use title/key/minimum/maximum/reset;
/// option descriptors use the same option dictionaries as ChatOptions.
UIViewController *WCGestureCreateAdjustmentEditor(NSString *title, UIView *preview, NSArray<NSDictionary *> *parameters);
UIViewController *WCGestureCreateRevokeRecordsController(void);
NSArray<NSDictionary *> *WCGestureChatOptions(BOOL antiRevoke, BOOL includeHidden);
NSString *WCGestureChatOptionDetail(NSDictionary *option);
void WCGestureEditChatOption(UIViewController *presenter, NSDictionary *option);

/// Searchable home with six feature categories.
/// Registered with WeChat's WCPluginsMgr; instantiated by class name.
@interface WCGestureSettingsController : UITableViewController
@end

/// Detail page for a category of gestures.
@interface WCGestureDetailController : UITableViewController
- (instancetype)initWithCategory:(NSInteger)category;
+ (NSArray<NSDictionary *> *)searchEntries;
- (void)focusSearchResult:(NSDictionary *)result;
@end

/// Presents the WCGesture settings sheet (ActionSheet style) from the given
/// view controller. Used by the Me-page fallback entry.
void WCGesturePresentSettings(UIViewController *presenter);

/// Registers WCGestureSettingsController with WeChat's plugin manager
/// (WCPluginsMgr) using the real registerControllerWithTitle:version:controller:
/// API. Falls back silently when the API is unavailable.
void WCGestureRegisterEntry(void);

NS_ASSUME_NONNULL_END
