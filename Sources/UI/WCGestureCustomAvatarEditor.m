#import <objc/runtime.h>
#import "Sources/API/WCGestureInternal.h"

static char WCCustomAvatarEditorKey;
@interface WCCustomAvatarEditor : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) void (^completion)(BOOL);
- (void)pick;
- (BOOL)validAccount;
@end
@implementation WCCustomAvatarEditor
- (BOOL)validAccount {
    return WCRefreshCachedCurrentUser() && [self.account isEqualToString:WCCurrentUserWXID()];
}
- (void)pick {
    if (![self validAccount]) { WCShowToast(@"账号已变化，请重新打开");return; }
    UIViewController *presenter=self.presenter;
    if (!presenter.view.window || presenter.presentedViewController) return;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) { WCShowToast(@"相册不可用");return; }
    UIImagePickerController *picker=[UIImagePickerController new];
    picker.sourceType=UIImagePickerControllerSourceTypePhotoLibrary;picker.allowsEditing=YES;picker.delegate=self;
    objc_setAssociatedObject(picker,&WCCustomAvatarEditorKey,self,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter presentViewController:picker animated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{ self.completion(NO); }];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image=info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (![self validAccount]) { WCShowToast(@"账号已变化，请重新打开");self.completion(NO);return; }
        if (![image isKindOfClass:UIImage.class]) { self.completion(NO);return; }
        WCGestureCustomAvatarSave(self.username,image,^(BOOL success){
            if (!success) WCShowToast(@"保存头像失败");
            self.completion(success);
        });
    }];
}
@end
void WCGesturePresentCustomAvatarEditor(UIViewController *presenter, NSString *username, void (^completion)(BOOL)) {
    if (!WCRefreshCachedCurrentUser() || !presenter.view.window || presenter.presentedViewController) return;
    if (WCGestureContactPickerKind(WCPrivateContact(username),username)==NSNotFound) return;
    WCCustomAvatarEditor *editor=[WCCustomAvatarEditor new];
    editor.presenter=presenter;editor.account=WCCurrentUserWXID();editor.username=username;editor.completion=completion;
    if (![WCGestureCustomAvatarSavedUsers() containsObject:username]) { [editor pick];return; }
    [WCPopup showOptionsWithTitle:@"替换头像" message:nil options:@[
        [WCPopupOption optionWithTitle:@"修改" value:@"change"],
        [WCPopupOption optionWithTitle:@"恢复" value:@"restore"]] selected:nil completion:^(id choice){
        if (![editor validAccount]) { WCShowToast(@"账号已变化，请重新打开");return; }
        if ([choice isEqual:@"change"]) [editor pick];
        else if ([choice isEqual:@"restore"]) WCGestureCustomAvatarRemove(username,^(BOOL success){
            if (!success) WCShowToast(@"恢复头像失败");
            completion(success);
        });
    }];
}
