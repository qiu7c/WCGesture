#import "Sources/API/WCGestureInternal.h"

@interface WCContactPickerCell : UITableViewCell
@property (nonatomic, copy) NSString *username;
@property (nonatomic, strong) UIView *avatar;
@end
@implementation WCContactPickerCell
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat scale=WCGestureSettingsScaleFactor(), size=40*scale;
    self.avatar.frame=CGRectMake(16*scale,(self.contentView.bounds.size.height-size)/2,size,size);
    CGFloat x=CGRectGetMaxX(self.avatar.frame)+12*scale;
    self.textLabel.frame=CGRectMake(x,0,MAX(0,self.contentView.bounds.size.width-x-16*scale),self.contentView.bounds.size.height);
}
@end
UITableViewCell *WCGestureContactPickerCell(UITableView *table, NSString *username, NSString *title) {
    WCContactPickerCell *cell=[table dequeueReusableCellWithIdentifier:@"onewx.contact"];
    if (!cell) cell=[[WCContactPickerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"onewx.contact"];
    if (![cell.username isEqual:username]) {
        [cell.avatar removeFromSuperview];cell.username=username;
        cell.avatar=WCGestureContactAvatarView(username);cell.avatar.userInteractionEnabled=NO;
        cell.avatar.layer.cornerRadius=8*WCGestureSettingsScaleFactor();cell.avatar.clipsToBounds=YES;
        [cell.contentView addSubview:cell.avatar];
    }
    cell.textLabel.text=title;cell.textLabel.font=[UIFont systemFontOfSize:15*WCGestureSettingsScaleFactor()];
    cell.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;cell.tintColor=UIColor.systemBlueColor;
    [cell setNeedsLayout];return cell;
}
