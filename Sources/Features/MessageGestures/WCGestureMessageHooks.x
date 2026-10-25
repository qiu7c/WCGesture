#import <UIKit/UIKit.h>

#import "Sources/API/WCGestureInternal.h"

#pragma mark - Message bubble + chat controller hooks

%hook CommonMessageCellView

- (void)setViewModel:(id)viewModel {
    %orig;
    WCSynchronizeReplyGesture(self);
}

- (void)didMoveToWindow {
    %orig;
    WCSynchronizeReplyGesture(self);
}

%new
- (void)wc_handleReplyPan:(UIPanGestureRecognizer *)recognizer {
    WCReplyPanHandle(self, recognizer);
}

%new
- (void)wc_handleMessageTapAction:(UITapGestureRecognizer *)recognizer {
    WCMessageTapHandle(self, recognizer);
}

%end

%hook BaseMsgContentViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WCSetVisibleChatController(self);
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (WCVisibleChatControllerGet() == self) WCSetVisibleChatController(nil);
}

%end

%ctor {
    %init;
}
