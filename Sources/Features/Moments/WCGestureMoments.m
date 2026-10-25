#import <objc/runtime.h>

#import "Sources/API/WCGestureInternal.h"

static char WCMomentsDoubleTapRecognizerKey;

static BOOL WCMomentsIsNativeDetailContext(id responderObject) {
    Class detailClass = NSClassFromString(@"WCCommentDetailViewControllerFB");
    if (!detailClass) return NO;
    UIViewController *controller = WCViewControllerForResponder(responderObject);
    for (UIViewController *current = controller; current; current = current.parentViewController) {
        if ([current isKindOfClass:detailClass]) return YES;
    }
    return controller && [controller.navigationController.topViewController isKindOfClass:detailClass];
}

static void WCShowMomentsHeart(WCTimeLineCellView *cell, UITapGestureRecognizer *recognizer) {
    UIWindow *window = cell.window;
    if (!window || !recognizer) return;
    CGPoint point = [recognizer locationInView:window];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:34.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *heart = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill" withConfiguration:config]];
    heart.tintColor = [UIColor colorWithRed:0.96 green:0.25 blue:0.34 alpha:1.0];
    heart.contentMode = UIViewContentModeScaleAspectFit;
    heart.bounds = CGRectMake(0.0, 0.0, 44.0, 44.0);
    heart.center = point;
    heart.alpha = 0.0;
    heart.transform = CGAffineTransformMakeScale(0.52, 0.52);
    heart.userInteractionEnabled = NO;
    [window addSubview:heart];
    [UIView animateKeyframesWithDuration:0.52 delay:0.0
        options:UIViewKeyframeAnimationOptionCalculationModeCubic | UIViewAnimationOptionAllowUserInteraction
        animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.30 animations:^{
            heart.alpha = 1.0;
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -5.0), CGAffineTransformMakeScale(1.12, 1.12));
        }];
        [UIView addKeyframeWithRelativeStartTime:0.30 relativeDuration:0.32 animations:^{
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -12.0), CGAffineTransformIdentity);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.62 relativeDuration:0.38 animations:^{
            heart.alpha = 0.0;
            heart.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -24.0), CGAffineTransformMakeScale(0.88, 0.88));
        }];
    } completion:^(__unused BOOL finished) {
        [heart removeFromSuperview];
    }];
}

void WCSynchronizeMomentsDoubleTap(WCTimeLineCellView *cell) {
    if (!cell) return;
    UITapGestureRecognizer *recognizer = objc_getAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey);
    BOOL enabled = WCGestureEnabled(WCMomentsDoubleTapLikeKey) &&
                   !WCMomentsIsNativeDetailContext(cell);
    if (enabled && !recognizer) {
        recognizer = [[UITapGestureRecognizer alloc] initWithTarget:cell action:@selector(wc_handleMomentsDoubleTap)];
        recognizer.numberOfTapsRequired = 2;
        recognizer.cancelsTouchesInView = NO;
        [cell addGestureRecognizer:recognizer];
        objc_setAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!enabled && recognizer) {
        [cell removeGestureRecognizer:recognizer];
        objc_setAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

void WCMomentsHandleDoubleTap(WCTimeLineCellView *cell) {
    if (!WCGestureEnabled(WCMomentsDoubleTapLikeKey) ||
        WCMomentsIsNativeDetailContext(cell)) return;
    UITapGestureRecognizer *recognizer = objc_getAssociatedObject(cell, &WCMomentsDoubleTapRecognizerKey);
    [cell onAccessibilityLike];
    WCShowMomentsHeart(cell, recognizer);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WCMomentsLikeHapticKey]) {
        WCPlayConfiguredHaptic();
    }
}
