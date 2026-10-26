#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolves a contact object by WeChat username. Tries the cache/database
/// selectors known across WeChat versions; returns the first valid result.
/// Call on the main thread. nil when unavailable.
FOUNDATION_EXPORT id _Nullable WCPrivateContact(NSString *userName);

/// Reads the stable username (wxid or @chatroom) from a contact-like object.
/// Tries `m_nsUsrName` before older field names. nil when no field is present.
FOUNDATION_EXPORT NSString * _Nullable WCPrivateContactUserName(id _Nullable contact);

/// Opens a native conversation on the main thread; NO when navigation is unavailable.
FOUNDATION_EXPORT BOOL WCGesturePushPrivateChat(NSString *userName);

NS_ASSUME_NONNULL_END
