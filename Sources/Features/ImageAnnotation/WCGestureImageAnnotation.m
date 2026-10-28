#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import "Sources/API/WCGestureInternal.h"

// HB image-editor REPORT/PLACEMENT_CONTRACT: mode 1=arrow,2=oval,
// head=min(.55*distance,max(3*width,18)), wing=.55*head, padding=4*width.
// One Wx owns toolbar layout, bounded render scale and unique-widget selection.
@interface WCAnnotationPlacement : NSObject
@property(nonatomic,strong) UIImage *image;
@property(nonatomic) CGPoint center;
@property(nonatomic) CGAffineTransform transform;
@property(nonatomic,strong) NSNumber *viewScale;
@property(nonatomic,strong) NSNumber *widgetScale;
@end
@implementation WCAnnotationPlacement
@end
@class WCAnnotationState;
@interface WCAnnotationCanvas : UIView
@property(nonatomic,weak) WCAnnotationState *owner;
@end
@interface WCAnnotationState : NSObject
@property(nonatomic,weak) UIView *host;
@property(nonatomic,weak) UIView *editorCanvas;
@property(nonatomic,weak) UIScrollView *scroll;
@property(nonatomic,strong) WCAnnotationCanvas *overlay;
@property(nonatomic,strong) CAShapeLayer *draft;
@property(nonatomic,strong) UIView *toolbar;
@property(nonatomic,strong) UIButton *oval;
@property(nonatomic,strong) UIButton *arrow;
@property(nonatomic) NSInteger mode;
@property(nonatomic) CGPoint start;
@property(nonatomic) BOOL drawing;
@property(nonatomic) BOOL submitting;
@property(nonatomic) BOOL changedInteraction;
@property(nonatomic,copy) NSString *account;
- (void)choose:(UIButton *)sender;
- (void)draw:(UIPanGestureRecognizer *)gesture;
@end
static char WCAnnotationStateKey,WCAnnotationPlacementKey;
static NSHashTable *WCAnnotationHosts(void){static NSHashTable *v;static dispatch_once_t once;dispatch_once(&once,^{v=[NSHashTable weakObjectsHashTable];});return v;}
static CGFloat WCAnnotationWidth(void){double v=[NSUserDefaults.standardUserDefaults doubleForKey:WCGestureImageAnnotationWidthKey];return isfinite(v)?MIN(16,MAX(1,v)):4;}
static UIColor *WCAnnotationColor(BOOL oval){return WCGestureColorForDefaultsKey(oval?WCGestureImageAnnotationOvalColorKey:WCGestureImageAnnotationArrowColorKey,UIColor.systemRedColor);}
static UIBezierPath *WCAnnotationPath(BOOL oval,CGPoint start,CGPoint end,CGFloat width){
    if(oval){CGRect rect=CGRectMake(MIN(start.x,end.x),MIN(start.y,end.y),MAX(1,fabs(end.x-start.x)),MAX(1,fabs(end.y-start.y)));return [UIBezierPath bezierPathWithOvalInRect:rect];}
    UIBezierPath *p=[UIBezierPath bezierPath];[p moveToPoint:start];[p addLineToPoint:end];
    double dx=end.x-start.x,dy=end.y-start.y,d=hypot(dx,dy);if(d<.001)return p;
    double ux=dx/d,uy=dy/d,h=MIN(.55*d,MAX(3*width,18));
    CGPoint a=CGPointMake(end.x-ux*h-.55*uy*h,end.y-uy*h+.55*ux*h);
    CGPoint b=CGPointMake(end.x-ux*h+.55*uy*h,end.y-uy*h-.55*ux*h);
    [p moveToPoint:a];[p addLineToPoint:end];[p addLineToPoint:b];return p;
}
static NSArray<UIView *> *WCAnnotationWidgets(UIView *canvas){
    id wrappers=WCTweakSafeValue(canvas,@"_drawViewWidgetArray");NSMutableArray *views=[NSMutableArray array];
    if(![wrappers isKindOfClass:NSArray.class])return views;
    Class cls=NSClassFromString(@"EditImageWidgetTool");
    for(id wrapper in wrappers){id view=[wrapper isKindOfClass:UIView.class]?wrapper:WCTweakSafeValue(wrapper,@"_czUIView");
        if(cls && [view isKindOfClass:cls] && [(UIView *)view isDescendantOfView:canvas])[views addObject:view];}
    return views;
}
static UIImageView *WCAnnotationWidgetImage(UIView *widget){id image=WCTweakSafeValue(widget,@"_imageView");return [image isKindOfClass:UIImageView.class]?image:nil;}
void WCGestureImageAnnotationWidgetCapture(UIView *widget){
    WCAnnotationPlacement *s=objc_getAssociatedObject(widget,&WCAnnotationPlacementKey);if(!s)return;
    s.center=widget.center;s.transform=widget.transform;
    id v=WCTweakSafeValue(widget,@"_viewScale"),w=WCTweakSafeValue(widget,@"_widgetScale");
    if([v isKindOfClass:NSNumber.class])s.viewScale=v;if([w isKindOfClass:NSNumber.class])s.widgetScale=w;
}
void WCGestureImageAnnotationWidgetRestore(UIView *widget){
    WCAnnotationPlacement *s=objc_getAssociatedObject(widget,&WCAnnotationPlacementKey);if(!s)return;
    UIImageView *image=WCAnnotationWidgetImage(widget);if(image)image.image=s.image;
    widget.transform=s.transform;widget.center=s.center;
    if(s.viewScale)WCTweakSetValue(widget,@"_viewScale",s.viewScale);if(s.widgetScale)WCTweakSetValue(widget,@"_widgetScale",s.widgetScale);
}
static void WCAnnotationSubmit(WCAnnotationState *s,CGPoint end){
    if(!s.editorCanvas.window || s.submitting || ![s.account isEqualToString:WCCurrentUserWXID() ?: @""])return;
    SEL submit=NSSelectorFromString(@"didSelectEmoticonWithWrap:decodedImage:");if(![s.host respondsToSelector:submit]){WCShowToast(@"当前图片编辑器不支持标注");return;}
    CGFloat width=WCAnnotationWidth();BOOL oval=s.mode==2;
    UIBezierPath *global=WCAnnotationPath(oval,s.start,end,width);
    CGRect rect=CGRectInset(global.bounds,-4*width,-4*width);
    if(CGRectIsEmpty(rect)||!isfinite(rect.size.width)||!isfinite(rect.size.height)||rect.size.width>8192||rect.size.height>8192)return;
    CGPoint start=CGPointMake(s.start.x-rect.origin.x,s.start.y-rect.origin.y),finish=CGPointMake(end.x-rect.origin.x,end.y-rect.origin.y);
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.opaque=NO;
    // Pixel budget is a documented One Wx resource bound, not a recovered HB value.
    format.scale=MAX(.25,MIN(UIScreen.mainScreen.scale,2048/MAX(rect.size.width,rect.size.height)));
    UIImage *image=[[[UIGraphicsImageRenderer alloc] initWithSize:rect.size format:format] imageWithActions:^(UIGraphicsImageRendererContext *context){
        UIBezierPath *path=WCAnnotationPath(oval,start,finish,width);path.lineWidth=width;path.lineCapStyle=kCGLineCapRound;path.lineJoinStyle=kCGLineJoinRound;[WCAnnotationColor(oval) setStroke];[path stroke];
    }];
    NSArray *before=WCAnnotationWidgets(s.editorCanvas);s.submitting=YES;
    @try{((void (*)(id,SEL,id,id))objc_msgSend)(s.host,submit,nil,image);}
    @catch(__unused NSException *exception){WCShowToast(@"原生标注插入失败");}
    @finally{s.submitting=NO;}
    NSMutableArray *added=[NSMutableArray array];for(UIView *candidate in WCAnnotationWidgets(s.editorCanvas))if([before indexOfObjectIdenticalTo:candidate]==NSNotFound)[added addObject:candidate];
    if(added.count!=1){WCShowToast(@"原生标注位置不可识别，请在编辑器中检查");return;}
    UIView *widget=added.firstObject;UIImageView *nativeImage=WCAnnotationWidgetImage(widget);
    if(nativeImage && widget.superview){
        // Public UIView coordinate/transform adaptation. No guessed private scale.
        CGRect desired=[s.overlay convertRect:rect toView:widget.superview];
        CGRect actual=[nativeImage convertRect:nativeImage.bounds toView:widget.superview];
        if(actual.size.width>0 && actual.size.height>0 && desired.size.width>0 && desired.size.height>0){
            CGFloat sx=desired.size.width/actual.size.width,sy=desired.size.height/actual.size.height;
            if(isfinite(sx)&&isfinite(sy)&&sx>.001&&sy>.001&&sx<100&&sy<100){
                widget.transform=CGAffineTransformScale(widget.transform,sx,sy);
                CGRect placed=[nativeImage convertRect:nativeImage.bounds toView:widget.superview];
                widget.center=CGPointMake(widget.center.x+CGRectGetMidX(desired)-CGRectGetMidX(placed),widget.center.y+CGRectGetMidY(desired)-CGRectGetMidY(placed));
            }
        }
    }
    WCAnnotationPlacement *placement=[WCAnnotationPlacement new];placement.image=image;
    objc_setAssociatedObject(widget,&WCAnnotationPlacementKey,placement,OBJC_ASSOCIATION_RETAIN_NONATOMIC);WCGestureImageAnnotationWidgetCapture(widget);
}
@implementation WCAnnotationCanvas
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return self.owner.mode>0 && [super pointInside:point withEvent:event]; }
@end
@implementation WCAnnotationState
- (void)choose:(UIButton *)sender {
    if(!WCGestureEnabled(WCGestureImageAnnotationEnabledKey))return;
    NSInteger wanted=sender==self.oval?2:1;
    if(self.mode==wanted){WCGestureImageAnnotationStop(self.host);return;}
    SEL stop=NSSelectorFromString(@"stop");for(id target in @[self.scroll ?: (id)NSNull.null,self.host ?: (id)NSNull.null])if([target respondsToSelector:stop])((void (*)(id,SEL))objc_msgSend)(target,stop);
    SEL use=NSSelectorFromString(@"useImageTool:");if([self.scroll respondsToSelector:use])((void (*)(id,SEL,int))objc_msgSend)(self.scroll,use,0);
    if(!self.editorCanvas.userInteractionEnabled){self.editorCanvas.userInteractionEnabled=YES;self.changedInteraction=YES;}
    self.mode=wanted;self.arrow.selected=wanted==1;self.oval.selected=wanted==2;
    [self.editorCanvas bringSubviewToFront:self.overlay];
}
- (void)draw:(UIPanGestureRecognizer *)gesture {
    if(!self.mode || !WCGestureEnabled(WCGestureImageAnnotationEnabledKey))return;
    CGPoint p=[gesture locationInView:self.overlay];
    if(gesture.state==UIGestureRecognizerStateBegan){self.start=p;self.drawing=YES;}
    if(gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateBegan){
        self.draft.path=WCAnnotationPath(self.mode==2,self.start,p,WCAnnotationWidth()).CGPath;
        self.draft.strokeColor=WCAnnotationColor(self.mode==2).CGColor;self.draft.lineWidth=WCAnnotationWidth();
    }else if(gesture.state==UIGestureRecognizerStateEnded){
        if(self.drawing && hypot(p.x-self.start.x,p.y-self.start.y)>2)WCAnnotationSubmit(self,p);
        self.drawing=NO;self.draft.path=nil;
    }else if(gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed){self.drawing=NO;self.draft.path=nil;}
}
@end
void WCGestureImageAnnotationStop(UIView *host){WCAnnotationState *s=objc_getAssociatedObject(host,&WCAnnotationStateKey);s.mode=0;s.drawing=NO;s.draft.path=nil;s.arrow.selected=NO;s.oval.selected=NO;if(s.changedInteraction){s.editorCanvas.userInteractionEnabled=NO;s.changedInteraction=NO;}}
void WCGestureImageAnnotationLayout(UIView *host){
    if(!host || !NSThread.isMainThread)return;[WCAnnotationHosts() addObject:host];
    WCAnnotationState *s=objc_getAssociatedObject(host,&WCAnnotationStateKey);
    if(!host.window || !WCGestureEnabled(WCGestureImageAnnotationEnabledKey)){
        WCGestureImageAnnotationStop(host);[s.toolbar removeFromSuperview];[s.overlay removeFromSuperview];objc_setAssociatedObject(host,&WCAnnotationStateKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);return;
    }
    // Only expose drawing controls where the native editor exposes its pen.
    // Crop-only/avatar screens and transient text-input panels retain native UI.
    id pen=WCTweakSafeValue(host,@"_penBtn");
    if((!s || !s.mode) && (![pen isKindOfClass:UIView.class] || [(UIView *)pen isHidden])){
        WCGestureImageAnnotationStop(host);s.toolbar.hidden=YES;return;
    }
    id scroll=WCTweakSafeValue(host,@"eIScrollView"),canvas=WCTweakSafeValue(scroll,@"oEditImageView");
    if(![scroll isKindOfClass:UIScrollView.class] || ![canvas isKindOfClass:UIView.class] || ![(UIView *)canvas isDescendantOfView:host] || ![host respondsToSelector:NSSelectorFromString(@"didSelectEmoticonWithWrap:decodedImage:")])return;
    if(s && s.editorCanvas!=canvas){WCGestureImageAnnotationStop(host);[s.overlay removeFromSuperview];[s.toolbar removeFromSuperview];s=nil;}
    if(!s){
        s=[WCAnnotationState new];s.host=host;s.scroll=scroll;s.editorCanvas=canvas;s.account=WCCurrentUserWXID() ?: @"";
        s.overlay=[WCAnnotationCanvas new];s.overlay.owner=s;s.overlay.backgroundColor=UIColor.clearColor;s.overlay.multipleTouchEnabled=YES;
        s.draft=[CAShapeLayer layer];s.draft.fillColor=UIColor.clearColor.CGColor;s.draft.lineCap=kCALineCapRound;s.draft.lineJoin=kCALineJoinRound;[s.overlay.layer addSublayer:s.draft];
        UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:s action:@selector(draw:)];pan.maximumNumberOfTouches=1;[s.overlay addGestureRecognizer:pan];
        s.toolbar=[UIView new];s.toolbar.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:.56];s.toolbar.layer.cornerRadius=18;
        for(NSUInteger i=0;i<2;i++){UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];button.frame=CGRectMake(4+44*i,2,40,32);
            [button setImage:[UIImage systemImageNamed:i?@"oval":@"arrow.up.right"] forState:UIControlStateNormal];button.tintColor=UIColor.whiteColor;
            [button setImage:[[UIImage systemImageNamed:i?@"oval":@"arrow.up.right"] imageWithTintColor:UIColor.systemBlueColor renderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateSelected];
            button.accessibilityLabel=i?@"圆圈":@"箭头";[button addTarget:s action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];[s.toolbar addSubview:button];if(i)s.oval=button;else s.arrow=button;}
        objc_setAssociatedObject(host,&WCAnnotationStateKey,s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[canvas addSubview:s.overlay];[host addSubview:s.toolbar];
    }
    if(![s.account isEqualToString:WCCurrentUserWXID() ?: @""]){WCGestureImageAnnotationStop(host);s.account=WCCurrentUserWXID() ?: @"";}
    s.toolbar.hidden=NO;s.overlay.frame=[(UIView *)canvas bounds];s.draft.frame=s.overlay.bounds;
    id bottom=WCTweakSafeValue(host,@"_bottomEditImageBar");CGFloat y=host.bounds.size.height-host.safeAreaInsets.bottom-96;
    if([bottom isKindOfClass:UIView.class] && [(UIView *)bottom isDescendantOfView:host])y=CGRectGetMinY([(UIView *)bottom convertRect:[(UIView *)bottom bounds] toView:host])-44;
    s.toolbar.frame=CGRectMake((host.bounds.size.width-96)/2,MAX(host.safeAreaInsets.top+8,y),96,36);[host bringSubviewToFront:s.toolbar];
    if(s.mode)[(UIView *)canvas bringSubviewToFront:s.overlay];
}
BOOL WCGestureImageAnnotationBlocksGesture(UIScrollView *scroll,UIGestureRecognizer *gesture){
    if(![gesture isKindOfClass:UIPanGestureRecognizer.class])return NO;
    for(UIView *v=scroll.superview;v;v=v.superview){WCAnnotationState *s=objc_getAssociatedObject(v,&WCAnnotationStateKey);if(s && s.scroll==scroll)return s.mode>0;}
    return NO;
}
void WCGestureImageAnnotationSettingsChanged(NSString *key){if(key && ![key isEqualToString:WCGestureEnabledKey] && ![key hasPrefix:@"com.qiu7c.onewx.image-annotation."])return;for(UIView *host in WCAnnotationHosts().allObjects)WCGestureImageAnnotationLayout(host);}
