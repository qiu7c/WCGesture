#import "Sources/API/WCGestureInternal.h"
%hook MMHeadImageView
- (id)initWithUsrName:(id)name headImgUrl:(id)url bAutoUpdate:(BOOL)update bRoundCorner:(BOOL)round {
    id result = %orig(name,url,update,round);
    WCGestureCustomAvatarApply((UIView *)result);
    return result;
}
- (void)updateUsrName:(id)name withHeadImgUrl:(id)url {
    WCGestureCustomAvatarWillChangeUser((UIView *)self);
    %orig(name,url);
    WCGestureCustomAvatarApply((UIView *)self);
}
- (void)setHeadImageByName:(id)name {
    %orig(name);
    WCGestureCustomAvatarApply((UIView *)self);
}
- (void)updateHeadImage:(id)image {
    %orig(image);
    WCGestureCustomAvatarApply((UIView *)self);
}
%end
%hook MMHeadImageMgr
- (id)getHeadImage:(id)name withCategory:(unsigned char)category {
    UIImage *image=WCGestureCustomAvatarImage(name,CGSizeMake(120,120),12);
    if(image)return image;
    return %orig(name,category);
}
- (id)getHeadImageWithUseScene:(id)name withScene:(unsigned char)scene withCategory:(unsigned char)category {
    UIImage *image=WCGestureCustomAvatarImage(name,CGSizeMake(120,120),12);
    if(image)return image;
    return %orig(name,scene,category);
}
- (id)getHeadImageWithUseScene:(id)name withScene:(unsigned char)scene withCategory:(unsigned char)category retHeadImgIsExistedLocal:(BOOL *)exists {
    UIImage *image=WCGestureCustomAvatarImage(name,CGSizeMake(120,120),12);
    if(image){if(exists)*exists=YES;return image;}
    return %orig(name,scene,category,exists);
}
- (id)getRoundImage:(id)name size:(CGSize)size withCategory:(unsigned char)category {
    CGFloat radius=.18*MIN(size.width,size.height);if(radius<=0)radius=8;
    UIImage *image=WCGestureCustomAvatarImage(name,size,radius);
    if(image)return image;
    return %orig(name,size,category);
}
- (id)getRoundImage:(id)name size:(CGSize)size cornerSize:(unsigned int)corner withCategory:(unsigned char)category {
    CGFloat radius=corner?corner:.18*MIN(size.width,size.height);if(radius<=0)radius=8;
    UIImage *image=WCGestureCustomAvatarImage(name,size,radius);
    if(image)return image;
    return %orig(name,size,corner,category);
}
%end
%ctor {
    %init;
}
