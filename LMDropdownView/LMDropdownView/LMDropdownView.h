//
//  LMDropdownView.h
//  LMDropdownView
//
//  Created by LMinh on 16/11/2014.
//  Copyright (c) 2014 LMinh. All rights reserved.
//

#import <UIKit/UIKit.h>

/*!
 Dropdown view state.
 */
typedef NS_ENUM(NSUInteger, LMDropdownViewState) {
    LMDropdownViewStateWillOpen,
    LMDropdownViewStateDidOpen,
    LMDropdownViewStateWillClose,
    LMDropdownViewStateDidClose,
};

typedef NS_ENUM(NSUInteger, LMDropdownViewDirection) {
    LMDropdownViewDirectionTop,
    LMDropdownViewDirectionBottom,
};

@protocol LMDropdownViewDelegate;

/*!
 *  A simple dropdown view inspired by Tappy.
 *  LMDropdownView是一个简单的下拉视图，灵感来自于Tappy。
 */
@interface LMDropdownView : NSObject

/*!
 *  The closed scale of container view.
 *  Set it to 1 to disable container scale animation.
 *  设为1，关闭容器view缩放动画
 */
@property (nonatomic, assign) CGFloat closedScale;

/**
 A boolean indicates whether container view should be blurred. Default is YES
 容器view是否使用模糊效果，默认yes；
 */
@property (nonatomic, assign) BOOL shouldBlurContainerView;

/*!
 *  The blur radius of container view.
 *  容器view的模糊半径
 */
@property (nonatomic, assign) CGFloat blurRadius;

/*!
 *  The alpha of black mask button.
 *  背景遮罩透明度
 */
@property (nonatomic, assign) CGFloat blackMaskAlpha;

/*!
 *  The animation duration.
 *  动画持续时间
 */
@property (nonatomic, assign) CGFloat animationDuration;

/*!
 *  The animation bounce height of content view.
 *  内容view的拉伸高度；使用关键帧动画实现Spring弹簧动画效果
 */
@property (nonatomic, assign) CGFloat animationBounceHeight;

/*!
 *  The animation direction.
 *  动画方向，顶部向下，底部向上；
 */
@property (nonatomic, assign) LMDropdownViewDirection direction;

/*!
 *  The background color of content view.
 *  内容view 背景色
 */
@property (nonatomic, strong) UIColor *contentBackgroundColor;

/*!
 *  The current dropdown view state.
 *  当前dropdown view 的状态；
 */
@property (nonatomic, assign, readonly) LMDropdownViewState currentState;

/*!
 *  A boolean indicates whether dropdown is open.
 *  标志dropdown是否打开；
 */
@property (nonatomic, assign, readonly) BOOL isOpen;

/*!
 *  The dropdown view delegate.
 *  代理
 */
@property (nonatomic, weak) id<LMDropdownViewDelegate> delegate;

/**
 *  The callback when dropdown view did show in the container view.
 *  dropdown在容器view中已经显示后的回调
 */
@property (nonatomic, copy) dispatch_block_t didShowHandler;

/**
 *  The callback when dropdown view did hide in the container view.
 *  隐藏的回调
 */
@property (nonatomic, copy) dispatch_block_t didHideHandler;

/*!
 *  Convenience constructor for LMDropdownView.
 *  类方法，方便的构造方法
 */
+ (instancetype)dropdownView;

/*!
 *  Show dropdown view.
 *  显示方法，指定容器view，内容view；
 *
 *  @param containerView The containerView to contain.
 *  @param contentView   The contentView to show.
 *  @param origin        The origin point in the container coordinator system.
 */
- (void)showInView:(UIView *)containerView withContentView:(UIView *)contentView atOrigin:(CGPoint)origin;

/*!
 *  Show dropdown view from navigation controller.
 *  从导航控制器navigation下显示；
 *
 *  @param navigationController The navigation controller to show from.
 *  @param contentView          The contentView to show.
 */
- (void)showFromNavigationController:(UINavigationController *)navigationController withContentView:(UIView *)contentView;

/*!
 *  Hide dropdown view.
 *  隐藏；
 */
- (void)hide;

/*!
 *  Force hide dropdown view.
 *  强制隐藏，没有hide里的动画了；
 */
- (void)forceHide;

@end

/*!
 *  Dropdown view delegate.
 */
@protocol LMDropdownViewDelegate <NSObject>

@optional
- (void)dropdownViewWillShow:(LMDropdownView *)dropdownView;
- (void)dropdownViewDidShow:(LMDropdownView *)dropdownView;
- (void)dropdownViewWillHide:(LMDropdownView *)dropdownView;
- (void)dropdownViewDidHide:(LMDropdownView *)dropdownView;

@end
