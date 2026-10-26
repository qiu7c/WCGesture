#import <objc/message.h>
#import "Sources/API/WCGestureInternal.h"

static id WCProfilePrivacyValue(id object, NSString *key) {
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}
static void WCProfilePrivacyClear(void) {
    Class profileClass = NSClassFromString(@"SettingMyProfileViewController");
    SEL fetch = NSSelectorFromString(@"fetchData"), save = NSSelectorFromString(@"Save");
    if (!profileClass || ![profileClass instancesRespondToSelector:save]) {
        [WCPopup showMessage:@"无法清空资料" message:@"当前微信版本缺少个人资料保存入口"]; return;
    }
    @try {
        UIViewController *controller = [[profileClass alloc] init];
        if (!controller) { WCShowToast(@"无法创建微信个人资料页面"); return; }
        [controller loadViewIfNeeded];
        if ([controller respondsToSelector:fetch]) ((void (*)(id,SEL))objc_msgSend)(controller,fetch);
        id info = WCProfilePrivacyValue(WCProfilePrivacyValue(controller,@"m_infoLogic"),@"m_usrInfo");
        if (!info) info = WCProfilePrivacyValue(controller,@"m_usrInfo");
        if (!info) { WCShowToast(@"无法读取当前微信资料，请稍后重试"); return; }
        NSArray<NSString *> *keys = @[@"m_uiSex",@"m_nsCountry",@"m_nsProvince",@"m_nsCity"];
        NSMutableArray *original = [NSMutableArray array];
        for (NSString *key in keys) [original addObject:[info valueForKey:key] ?: NSNull.null];
        @try {
            [info setValue:@0 forKey:keys[0]];
            for (NSUInteger i=1;i<keys.count;i++) [info setValue:@"" forKey:keys[i]];
        } @catch (NSException *exception) {
            for (NSUInteger i=0;i<keys.count;i++) {
                @try { [info setValue:original[i] == NSNull.null ? nil : original[i] forKey:keys[i]]; }
                @catch (__unused NSException *restoreException) {}
            }
            WCLog(@"清空资料：原生字段写入失败 %@",exception.name);
            WCShowToast(@"当前微信资料字段不兼容，未调用保存"); return;
        }
        ((void (*)(id,SEL))objc_msgSend)(controller,save);
        [WCPopup showMessage:@"已调用微信保存" message:@"地区已设为空，性别已尝试设为未设置。微信可能不支持清除性别；请稍后用其他设备确认实际结果。"];
    } @catch (NSException *exception) {
        WCLog(@"清空资料：原生保存流程异常 %@",exception.name);
        [WCPopup showMessage:@"保存未确认" message:@"微信个人资料保存流程发生异常，请检查实际资料。"];
    }
}
void WCGesturePresentClearProfileInformation(void) {
    [WCPopup showOptionsWithTitle:@"清空地区与性别信息"
        message:@"将地区设为空，并尝试清除性别。微信可能不支持清除性别。"
        options:@[[WCPopupOption optionWithTitle:@"确认清空" value:@YES]] selected:nil completion:^(id value) {
            if ([value boolValue]) WCProfilePrivacyClear();
        }];
}
