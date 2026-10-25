#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/// YES only for a verified other-user revoke whose original message exists.
BOOL WCGestureAntiRevokeHandle(id manager, id _Nullable incomingMessage);
void WCGestureAntiRevokeSetPersistenceEnabled(BOOL enabled);
NSArray<NSDictionary *> *WCGestureAntiRevokeRecords(void);
NSString *WCGestureAntiRevokeDefaultTemplate(BOOL reply);
NSString *WCGestureAntiRevokeMessageTypeName(NSUInteger type);
NSString * _Nullable WCGestureAntiRevokeSidePromptForMessage(id _Nullable message);
BOOL WCGestureAntiRevokeIsLocalPromptMessage(id _Nullable message);
void WCGestureAntiRevokeLayout(UIView *cell);
void WCGestureAntiRevokeHide(UIView *cell);
void WCGestureAntiRevokeSettingsChanged(NSString * _Nullable key);
void WCGestureAntiRevokeStyleLabel(UILabel *label);
CGRect WCGestureAntiRevokeSideFrame(CGRect bounds, CGRect bubble, BOOL sender, CGSize size);
void WCGestureAntiRevokeSystemCellLayout(UIView *cell);
NS_ASSUME_NONNULL_END
