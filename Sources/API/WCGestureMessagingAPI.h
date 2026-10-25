#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
BOOL WCGesturePrivateSendTextMessage(NSString *username, NSString *text);
BOOL WCGesturePrivateSendImageMessage(NSString *username, NSString *path);
BOOL WCGesturePrivateSendVideoMessage(NSString *username, NSString *path);
NS_ASSUME_NONNULL_END
