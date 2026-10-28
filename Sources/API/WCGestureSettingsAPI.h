#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WCGestureCategory) {
    WCGestureCategoryChat,
    WCGestureCategoryGestures,
    WCGestureCategoryMoments,
    WCGestureCategoryInterface,
    WCGestureCategoryDisabled,
    WCGestureCategoryPlugin,
    WCGestureCategoryEnhancements,
    WCGestureCategoryCount,
};

typedef NS_ENUM(NSInteger, WCGesturePreviewKind) {
    WCGesturePreviewMessageTime,
    WCGesturePreviewAntiRevoke,
    WCGesturePreviewInputRounding,
    WCGesturePreviewChatTopBar,
    WCGesturePreviewAvatarRounding,
};

UIView *WCGestureCreateChatPreview(WCGesturePreviewKind kind);
void WCGestureSetPreviewEditing(UIView *preview, BOOL editing);
void WCGestureSetChatPreviewKind(UIView *preview, WCGesturePreviewKind kind);
void WCGestureSetPreviewNavigation(UIView *preview, void (^back)(void), void (^controls)(void));
void WCGestureSetPreviewInputLines(UIView *preview, NSUInteger lines);
void WCGestureSetPreviewControlsExpanded(UIView *preview, BOOL expanded);
UIViewController *WCGestureCreatePositionEditor(WCGesturePreviewKind kind);
/// Reusable editor. Numeric descriptors use title/key/minimum/maximum/reset;
/// option descriptors use the same option dictionaries as ChatOptions.
UIViewController *WCGestureCreateAdjustmentEditor(NSString *title, UIView *preview, NSArray<NSDictionary *> *parameters);
UIViewController *WCGestureCreateRevokeRecordsController(void);
UIViewController *WCGestureCreateLongPressMenuController(void);
NSArray<NSDictionary *> *WCGestureChatOptions(BOOL antiRevoke, BOOL includeHidden);
NSString *WCGestureChatOptionDetail(NSDictionary *option);
void WCGestureEditChatOption(UIViewController *presenter, NSDictionary *option);

/// Searchable home with seven feature categories.
/// Used by all entry locations; plugin managers instantiate it by class name.
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

UIViewController *WCGestureCreateCornerSettingsController(void);
UIViewController *WCGestureCreateAutoStatusSettingsController(void);
UITableViewCell *WCGestureContactPickerCell(UITableView *table, NSString *username, NSString *title);
UIViewController *WCGestureCreateChangelogController(void);
NS_ASSUME_NONNULL_END
