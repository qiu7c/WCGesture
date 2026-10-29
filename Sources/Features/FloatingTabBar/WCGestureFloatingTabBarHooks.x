#import "Sources/API/WCGestureInternal.h"

%hook MMTabBar
- (void)layoutSubviews {
    BOOL apply = WCGestureFloatingTabBarBeginLayout((UITabBar *)self);
    if (apply) {
        [UIView performWithoutAnimation:^{
            %orig;
            WCGestureFloatingTabBarEndLayout((UITabBar *)self);
        }];
    } else {
        %orig;
    }
}
- (void)setHidden:(BOOL)hidden {
    if (!hidden && [(UITabBar *)self isHidden]) WCGestureFloatingTabBarPrepareForDisplay((UITabBar *)self);
    %orig(hidden);
}
- (void)willMoveToWindow:(UIWindow *)window {
    %orig(window);
    if (window) WCGestureFloatingTabBarPrepareForDisplay((UITabBar *)self);
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *original = %orig(point, event);
    return WCGestureFloatingTabBarHitTest((UITabBar *)self, point, original);
}
- (void)setBackgroundColor:(UIColor *)color {
    UIColor *adjusted = WCGestureFloatingTabBarAppearance((UITabBar *)self, @selector(setBackgroundColor:), color);
    %orig(adjusted);
}
- (void)setBarTintColor:(UIColor *)color {
    UIColor *adjusted = WCGestureFloatingTabBarAppearance((UITabBar *)self, @selector(setBarTintColor:), color);
    %orig(adjusted);
}
- (void)setBackgroundImage:(UIImage *)image {
    UIImage *adjusted = WCGestureFloatingTabBarAppearance((UITabBar *)self, @selector(setBackgroundImage:), image);
    %orig(adjusted);
}
- (void)setShadowImage:(UIImage *)image {
    UIImage *adjusted = WCGestureFloatingTabBarAppearance((UITabBar *)self, @selector(setShadowImage:), image);
    %orig(adjusted);
}
- (void)setStandardAppearance:(UITabBarAppearance *)appearance {
    UITabBarAppearance *adjusted = WCGestureFloatingTabBarAppearance((UITabBar *)self, @selector(setStandardAppearance:), appearance);
    %orig(adjusted);
}
- (void)selectIndex:(long long)index {
    %orig(index);
    [(UIView *)self setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    %orig(previous);
    [(UIView *)self setNeedsLayout];
}
%end

%hook UITabBarButton
- (void)layoutSubviews {
    %orig;
    WCGestureFloatingTabBarButtonLayout((UIView *)self);
}
%end

%hook MMTabBarItemView
- (void)layoutSubviews {
    %orig;
    WCGestureFloatingTabBarItemLayout((UIView *)self);
}
- (void)layoutIcon {
    %orig;
    WCGestureFloatingTabBarItemLayout((UIView *)self);
}
- (void)relayoutIconAndBadge {
    %orig;
    WCGestureFloatingTabBarItemLayout((UIView *)self);
}
- (void)setSelected:(BOOL)selected {
    WCGestureFloatingTabBarItemWillSelect((UIView *)self);
    %orig(selected);
    WCGestureFloatingTabBarItemDidSelect((UIView *)self, selected);
}
- (void)reloadIconImage {
    WCGestureFloatingTabBarItemWillSelect((UIView *)self);
    %orig;
    WCGestureFloatingTabBarItemLayout((UIView *)self);
}
%end

%hook MMBadgeView
- (void)setFrame:(CGRect)frame {
    CGRect adjusted = WCGestureFloatingTabBarBadgeFrame((UIView *)self, frame);
    %orig(adjusted);
}
- (void)setString:(id)string {
    %orig(string);
    [(UIView *)self setNeedsLayout];
}
%end

%ctor {
    %init;
    WCGestureFloatingTabBarInstall();
}
