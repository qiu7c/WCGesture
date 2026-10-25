#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Font level to report to WeChat, or the original one when the feature is off.
unsigned int WCChatLayoutResolvedFontLevel(unsigned int originalLevel);

/// Moments cell height after the optional compensation percentage.
double WCMomentsLayoutAdjustedHeight(double originalHeight);

NS_ASSUME_NONNULL_END
