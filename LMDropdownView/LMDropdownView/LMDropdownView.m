//
//  LMDropdownView.m
//  LMDropdownView
//
//  Created by LMinh on 16/11/2014.
//  Copyright (c) 2014 LMinh. All rights reserved.
//

#import "LMDropdownView.h"
#import "UIImage+LMExtension.h"

#define frx(a)                      (a.frame.origin.x)
#define fry(a)                      (a.frame.origin.y)
#define midx(a)                     (CGRectGetMidX(a.frame))
#define midy(a)                     (CGRectGetMidY(a.frame))
#define W(a)                        (a.frame.size.width)
#define H(a)                        (a.frame.size.height)

#define kDefaultClosedScale                 0.85
#define kDefaultBlurRadius                  5
#define kDefaultBlackMaskAlpha              0.5
#define kDefaultAnimationDuration           0.5
#define kDefaultAnimationBounceHeight       20
#define kDefaultAnimationBounceScale        0.05

@interface LMDropdownView ()
{
    UIInterfaceOrientation lastOrientation;
    CGPoint originContentCenter;
    CGPoint desContentCenter;
}
@property (nonatomic, strong) UIView *mainView;     // 主view，scrollView
@property (nonatomic, strong) UIView *contentWrapperView;           // 内容包裹view
@property (nonatomic, strong) UIImageView *containerWrapperView;    // 容器包裹view
@property (nonatomic, strong) UIButton *backgroundButton;

@end

@implementation LMDropdownView

#pragma mark - INIT

+ (instancetype)dropdownView
{
    return [[LMDropdownView alloc] init];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _closedScale = kDefaultClosedScale;
        _shouldBlurContainerView = YES;
        _blurRadius = kDefaultBlurRadius;
        _blackMaskAlpha = kDefaultBlackMaskAlpha;
        _animationDuration = kDefaultAnimationDuration;
        _animationBounceHeight = kDefaultAnimationBounceHeight;
        _direction = LMDropdownViewDirectionTop;
        _currentState = LMDropdownViewStateDidClose;
        
        lastOrientation = [UIApplication sharedApplication].statusBarOrientation;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - PROPERTIES

- (void)setClosedScale:(CGFloat)closedScale
{
    _closedScale = MIN(MAX(closedScale, 0.1), 1);  // 0.1 < x < 1
}

- (void)setBlackMaskAlpha:(CGFloat)blackMaskAlpha
{
    _blackMaskAlpha = MIN(MAX(blackMaskAlpha, 0), 0.9);
}


#pragma mark - PUBLIC METHOD

- (BOOL)isOpen
{
    return (_currentState == LMDropdownViewStateDidOpen);
}

- (void)showInView:(UIView *)containerView withContentView:(UIView *)contentView atOrigin:(CGPoint)origin
{
    if (_currentState != LMDropdownViewStateDidClose) {     // 已经close后，才能open，显示；
        return;
    }
    
    // Start showing
    // 将要显示代理；
    _currentState = LMDropdownViewStateWillOpen;
    if (self.delegate && [self.delegate respondsToSelector:@selector(dropdownViewWillShow:)]) {
        [self.delegate dropdownViewWillShow:self];
    }
    
    // Setup menu in view
    // 设置内容view，在容器view中
    [self setupContentView:contentView inView:containerView atOrigin:origin];   // 内容view， 容器view；显示指定位置；
    
    // Animate menu view controller
    // 添加 内容view动画
    [self addContentAnimationForState:_currentState];
    
    // Animate content view controller
    // 添加 容器view动画
    if (self.closedScale < 1) {
        [self addContainerAnimationForState:_currentState];
    }
    
    // Finish showing
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.animationDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        _currentState = LMDropdownViewStateDidOpen;
        
        // 已经显示代理
        if (self.delegate && [self.delegate respondsToSelector:@selector(dropdownViewDidShow:)]) {
            [self.delegate dropdownViewDidShow:self];
        }
        
        // 显示完成回调
        if (self.didShowHandler) {
            self.didShowHandler();
        }
    });
}

- (void)showInView:(UIView *)containerView withContentView:(UIView *)contentView atView:(UIView *)atView
{
    CGPoint origin = CGPointMake(CGRectGetMinX(atView.frame), CGRectGetMaxY(atView.frame)); // 左下角
    [self showInView:containerView withContentView:contentView atOrigin:origin];
}

- (void)showFromNavigationController:(UINavigationController *)navigationController withContentView:(UIView *)contentView
{
    [self showInView:navigationController.visibleViewController.view withContentView:contentView atOrigin:CGPointZero];
}

/**
 *  逻辑和show方法类似
 *
 */
- (void)hide
{
    if (_currentState != LMDropdownViewStateDidOpen) {      // 已经open，显示后，才能hide；
        return;
    }
    
    // Start hiding
    _currentState = LMDropdownViewStateWillClose;
    if (self.delegate && [self.delegate respondsToSelector:@selector(dropdownViewWillHide:)]) {
        [self.delegate dropdownViewWillHide:self];
    }
    
    // Animate menu view controller
    [self addContentAnimationForState:_currentState];
    
    // Animate content view controller
    if (self.closedScale < 1) {
        [self addContainerAnimationForState:_currentState];
    }
    
    // Finish hiding
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.animationDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        _currentState = LMDropdownViewStateDidClose;
        if (self.delegate && [self.delegate respondsToSelector:@selector(dropdownViewDidHide:)]) {
            [self.delegate dropdownViewDidHide:self];
        }
        if (self.didHideHandler) {
            self.didHideHandler();
        }
        
        [UIView animateWithDuration:0.2 animations:^{
            self.mainView.alpha = 0;
        } completion:^(BOOL finished) {
            self.mainView.alpha = 1;
            [self forceHide];
        }];
    });
}

- (void)forceHide
{
    _currentState = LMDropdownViewStateDidClose;
    
    // layer 设值，就有动画； lastObject最后一个，就是最终隐藏位置；
    [self.contentWrapperView.layer setValue:[[self contentPositionValuesForState:_currentState] lastObject] forKeyPath:@"position"];
    
    [[self.contentWrapperView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.contentWrapperView removeFromSuperview];
    [self.backgroundButton removeFromSuperview];
    
    
    [self.containerWrapperView.layer setValue:[[self containerTransformValuesForState:_currentState] lastObject] forKeyPath:@"transform"];
    [self.containerWrapperView removeFromSuperview];
    [self.mainView removeFromSuperview];
}


#pragma mark - PRIVATE

- (void)setupContentView:(UIView *)contentView inView:(UIView *)containerView atOrigin:(CGPoint)origin
{
    /*!
     *  Prepare container captured image
     *  支持retina 截屏
     */
    CGSize containerSize = [containerView bounds].size;
    CGFloat scale = (3 - 2 * self.closedScale);     // closedScale 为1就不缩放scale
    
    CGSize capturedSize = CGSizeMake(containerSize.width * scale, containerSize.height * scale);
    UIImage *capturedImage = [UIImage imageFromView:containerView withSize:capturedSize];
    UIImage *containerImage = capturedImage;
    
    if (self.shouldBlurContainerView) {
        // 根据模糊半径，对图片模糊处理
        containerImage = [capturedImage blurredImageWithRadius:self.blurRadius iterations:5 tintColor:[UIColor clearColor]];
    }
    
    /**
     *  加到containerView中，作为子view；mainView是scrollView；
     *
     */
    
    /*!
     *  Main View
     */
    if (!self.mainView) {
        self.mainView = [[UIScrollView alloc] init];
        self.mainView.backgroundColor = [UIColor blackColor];
    }
    self.mainView.frame = containerView.bounds;
    [containerView addSubview:self.mainView];
    
    /*!
     *  Container Wrapper View
     */
    if (!self.containerWrapperView) {
        self.containerWrapperView = [[UIImageView alloc] init];
        self.containerWrapperView.backgroundColor = [UIColor blackColor];
        self.containerWrapperView.contentMode = UIViewContentModeCenter;
    }
    self.containerWrapperView.image = containerImage;
    self.containerWrapperView.bounds = CGRectMake(0, 0, capturedSize.width, capturedSize.height);
    self.containerWrapperView.center = self.mainView.center;
    [self.mainView addSubview:self.containerWrapperView];
    
    /*!
     *  Background Button
     */
    if (!self.backgroundButton) {
        self.backgroundButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.backgroundButton addTarget:self action:@selector(backgroundButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    UIColor *maskColor = [[UIColor blackColor] colorWithAlphaComponent:self.blackMaskAlpha];
    self.backgroundButton.backgroundColor = maskColor;
    self.backgroundButton.frame = self.mainView.bounds;
    [self.mainView addSubview:self.backgroundButton];
    
    /*!
     *  Content Wrapper View
     */
    if (!self.contentWrapperView) {
        self.contentWrapperView = [[UIView alloc] init];
    }
    self.contentWrapperView.backgroundColor = self.contentBackgroundColor;
    
    // content包裹view高度
    CGFloat contentWrapperViewHeight = CGRectGetHeight(contentView.frame) + self.animationBounceHeight;
    switch (self.direction) {
        case LMDropdownViewDirectionTop:
            contentView.frame = CGRectMake(0, self.animationBounceHeight, W(contentView), H(contentView));
            
            // 开始设置view，没出现位置开始，方便动画
            self.contentWrapperView.frame = CGRectMake(origin.x,
                                                       origin.y - contentWrapperViewHeight,
                                                       W(contentView),
                                                       contentWrapperViewHeight);
            break;
        case LMDropdownViewDirectionBottom:
            // 往下点，
            contentView.frame = CGRectMake(0, 0, W(contentView), H(contentView));
            self.contentWrapperView.frame = CGRectMake(origin.x,
                                                       origin.y + contentWrapperViewHeight,
                                                       W(contentView),
                                                       contentWrapperViewHeight);
            break;
        default:
            break;
    }
    [self.contentWrapperView addSubview:contentView];
    [self.mainView addSubview:self.contentWrapperView];
    
    /*!
     *  Set up origin, destination content center
     *  设置 origin，destination 内容中心
     */
    // 内容包裹view，动画开始位置中心
    originContentCenter = CGPointMake(midx(self.contentWrapperView), midy(self.contentWrapperView));
    
    // 内容包裹view，动画终点位置中心
    if (self.direction == LMDropdownViewDirectionTop) {
        desContentCenter = CGPointMake(midx(self.contentWrapperView), origin.y + contentWrapperViewHeight/2 - self.animationBounceHeight);
    }
    else {
        desContentCenter = CGPointMake(midx(self.contentWrapperView), origin.y + contentWrapperViewHeight/2);
    }
}

- (void)orientationChanged:(NSNotification *)notification
{
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    BOOL canForceHide = UIInterfaceOrientationIsPortrait(currentOrientation) && UIInterfaceOrientationIsLandscape(lastOrientation);
    canForceHide |= UIInterfaceOrientationIsPortrait(lastOrientation) && UIInterfaceOrientationIsLandscape(currentOrientation);
    
    if (canForceHide) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(dropdownViewWillHide:)]) {
            [self.delegate dropdownViewWillHide:self];
        }
        
        [self forceHide];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(dropdownViewDidHide:)]) {
            [self.delegate dropdownViewDidHide:self];
        }
        if (self.didHideHandler) {
            self.didHideHandler();
        }
    }
    
    lastOrientation = currentOrientation;
}

- (void)backgroundButtonTapped:(id)sender
{
    [self hide];
}


#pragma mark - KEYFRAME ANIMATION

- (void)addContentAnimationForState:(LMDropdownViewState)state
{
    CAKeyframeAnimation *contentBounceAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    contentBounceAnim.duration = self.animationDuration;
    contentBounceAnim.removedOnCompletion = NO;
    contentBounceAnim.fillMode = kCAFillModeForwards;
    contentBounceAnim.values = [self contentPositionValuesForState:state];
    contentBounceAnim.timingFunctions = [self contentTimingFunctionsForState:state];
    contentBounceAnim.keyTimes = [self contentKeyTimesForState:state];
    
    [self.contentWrapperView.layer addAnimation:contentBounceAnim forKey:nil];
    [self.contentWrapperView.layer setValue:[contentBounceAnim.values lastObject] forKeyPath:@"position"];
}

- (void)addContainerAnimationForState:(LMDropdownViewState)state
{
    CAKeyframeAnimation *containerScaleAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    containerScaleAnim.duration = self.animationDuration;
    containerScaleAnim.removedOnCompletion = NO;
    containerScaleAnim.fillMode = kCAFillModeForwards;
    containerScaleAnim.values = [self containerTransformValuesForState:state];
    containerScaleAnim.timingFunctions = [self containerTimingFunctionsForState:state];
    containerScaleAnim.keyTimes = [self containerKeyTimesForState:state];
    
    [self.containerWrapperView.layer addAnimation:containerScaleAnim forKey:nil];
    [self.containerWrapperView.layer setValue:[containerScaleAnim.values lastObject] forKeyPath:@"transform"];
}


#pragma mark - PROPERTIES FOR KEYFRAME ANIMATION

/** content 内容view, 不同状态的，各种位置保存下 */
- (NSArray *)contentPositionValuesForState:(LMDropdownViewState)state
{
    CGPoint currentContentCenter = self.contentWrapperView.layer.position; // position 为中心点
    
    NSMutableArray *values = [NSMutableArray new];
    [values addObject:[NSValue valueWithCGPoint:currentContentCenter]];
    
    if (state == LMDropdownViewStateWillOpen || state == LMDropdownViewStateDidOpen)    // show
    {
        if (self.direction == LMDropdownViewDirectionTop) {
            // 向下拉伸点，类似弹簧
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(currentContentCenter.x, desContentCenter.y + self.animationBounceHeight)]];
        }
        else {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(currentContentCenter.x, desContentCenter.y - self.animationBounceHeight)]];
        }
        [values addObject:[NSValue valueWithCGPoint:CGPointMake(currentContentCenter.x, desContentCenter.y)]];
    }
    else    // hide
    {
        if (self.direction == LMDropdownViewDirectionTop) {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(currentContentCenter.x, currentContentCenter.y + self.animationBounceHeight)]]; // 关闭时，往下伸一下，作出弹簧效果；
        }
        else {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(currentContentCenter.x, currentContentCenter.y - self.animationBounceHeight)]];
        }
        // 最终隐藏点；
        [values addObject:[NSValue valueWithCGPoint:CGPointMake(currentContentCenter.x, originContentCenter.y)]];
    }
    
    return values;
}

- (NSArray *)contentKeyTimesForState:(LMDropdownViewState)state
{
    NSMutableArray *keyTimes = [NSMutableArray new];
    [keyTimes addObject:[NSNumber numberWithFloat:0]];
    [keyTimes addObject:[NSNumber numberWithFloat:0.5]];
    [keyTimes addObject:[NSNumber numberWithFloat:1]];
    return keyTimes;
}

- (NSArray *)contentTimingFunctionsForState:(LMDropdownViewState)state
{
    NSMutableArray *timingFunctions = [NSMutableArray new];
    [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    return timingFunctions;
}

- (NSArray *)containerTransformValuesForState:(LMDropdownViewState)state
{
    CATransform3D transform = self.containerWrapperView.layer.transform;
    
    NSMutableArray *values = [NSMutableArray new];
    [values addObject:[NSValue valueWithCATransform3D:transform]];
    
    if (state == LMDropdownViewStateWillOpen || state == LMDropdownViewStateDidOpen)
    {
        CGFloat scale = self.closedScale - kDefaultAnimationBounceScale;
        [values addObject:[NSValue valueWithCATransform3D:CATransform3DScale(transform, scale, scale, scale)]];
        [values addObject:[NSValue valueWithCATransform3D:CATransform3DScale(transform, self.closedScale, self.closedScale, self.closedScale)]];
    }
    else
    {
        CGFloat scale = 1 - kDefaultAnimationBounceScale;
        [values addObject:[NSValue valueWithCATransform3D:CATransform3DScale(transform, scale, scale, scale)]];
        [values addObject:[NSValue valueWithCATransform3D:CATransform3DIdentity]];
    }
    
    return values;      // CATransform3DScale 3d缩放动画吗
}

- (NSArray *)containerKeyTimesForState:(LMDropdownViewState)state
{
    NSMutableArray *keyTimes = [NSMutableArray new];
    [keyTimes addObject:[NSNumber numberWithFloat:0]];
    [keyTimes addObject:[NSNumber numberWithFloat:0.5]];
    [keyTimes addObject:[NSNumber numberWithFloat:1]];
    return keyTimes;
}

- (NSArray *)containerTimingFunctionsForState:(LMDropdownViewState)state
{
    NSMutableArray *timingFunctions = [NSMutableArray new];
    [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    return timingFunctions;
}

@end
