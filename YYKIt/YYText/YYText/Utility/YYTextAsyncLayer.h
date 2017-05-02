//
//  YYTextAsyncLayer.h
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/4/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class YYTextAsyncLayerDisplayTask;

NS_ASSUME_NONNULL_BEGIN

/**
 YYTextAsyncLayerDisplayTask是在YYTextAsyncLayer去background queue 渲染是调用的对象，它有三个回调，一个willDisplay在渲染之前、一个didDisplay在渲染之后和渲染时被调用的display。
 
 YYTextAsyncLayer是CAlayer的子类，当这个layer更新contents时就会调用delegate方法去调用 async display task 去background queue 渲染。这个delegate方法是YYTextAsyncLayerDelegate的方法。
 
 YYTextAsyncLayer在刷新时调用_displayAsync:方法，然后调用遵守YYTextAsyncLayerDisplayTask的对象实现的newAsyncDisplayTask方法，获取到需要绘制的前后和绘制时的task，根据是够需要异步来判断直接在主线程执行绘制代码还是异步执行绘制代码。
 
 在异步绘制过程中用到了一个异步队列，获取方法是YYTextAsyncLayerGetDisplayQueue，在这个方法中有一个关于QOS的概念，NSQualityOfService（QOS）ios8之后提供的新功能，这个枚举值是要告诉操作系统我们在进行什么样的工作，让系统能通过合理的资源控制来最高效的执行任务代码，主要涉及CPU调度、IO优先级、任务运行在哪个线程以及运行的顺序等等。
 
 */

/**
 `YYTextAsyncLayer`类是`CALayer`的子类，用来异步渲染内容；
 
 当层需要更新它的内容时，它会询问代理, 用异步显示任务`YYAsyncLayerDisplayTask`， 在后台队列中渲染内容。
 */
/**
 The YYTextAsyncLayer class is a subclass of CALayer used for render contents asynchronously.
 
 @discussion When the layer need update it's contents, it will ask the delegate 
 for a async display task to render the contents in a background queue.
 */
@interface YYTextAsyncLayer : CALayer

/// 渲染代码，是否在后台执行。默认YES；
/// Whether the render code is executed in background. Default is YES.
@property BOOL displaysAsynchronously;
@end

/**
 YYTextAsyncLayer 的代理协议。YYTextAsyncLayer的代理，一般都是UIView或其子类，必修实现这个协议方法；
 */
/**
 The YYTextAsyncLayer's delegate protocol. The delegate of the YYTextAsyncLayer (typically a UIView)
 must implements the method in this protocol.
 */
@protocol YYTextAsyncLayerDelegate <NSObject>
@required

/// 当层的内容需要更新时，调用此方法返回新的显示任务`YYAsyncLayerDisplayTask`。
/// This method is called to return a new display task when the layer's contents need update.
- (YYTextAsyncLayerDisplayTask *)newAsyncDisplayTask;
@end

/**
 YYTextAsyncLayer用于在后台队列中，渲染内容的显示任务。

 */
/**
 A display task used by YYTextAsyncLayer to render the contents in background queue.
 */
@interface YYTextAsyncLayerDisplayTask : NSObject

/**
 在异步绘图开始前，将会调用这个回调block；它将在主线程上被调用。
 */
/**
 This block will be called before the asynchronous drawing begins.
 It will be called on the main thread.
 
 @param layer  The layer.
 */
@property (nullable, nonatomic, copy) void (^willDisplay)(CALayer *layer);  // 在渲染之前

/**
 该回调block用来绘制图层的内容。
 
 @discussion 这个block可能在休闲城或后台线程运行，所以它必须是线程安全的；
 
 @param context      图层创建的新的位图内容
 @param size         内容的尺寸size (一般和layer的bound size 相同).
 @param isCancelled  如果这个block返回YES，该方法应该取消绘图过程，并立即返回。
 */
/**
 This block is called to draw the layer's contents.
 
 @discussion This block may be called on main thread or background thread,
 so is should be thread-safe.
 
 @param context      A new bitmap content created by layer.
 @param size         The content size (typically same as layer's bound size).
 @param isCancelled  If this block returns `YES`, the method should cancel the
 drawing process and return as quickly as possible.
 */
@property (nullable, nonatomic, copy) void (^display)(CGContextRef context, CGSize size, BOOL(^isCancelled)(void)); // 渲染时

/**
 当异步绘制任务结束，将会调用这个回调block。它将在主线程上被调用。
 
 @param layer  图层layer
 @param finished  如果绘图进程被取消了, 返回`NO`, 否则`YES`;
 */
/**
 This block will be called after the asynchronous drawing finished.
 It will be called on the main thread.
 
 @param layer  The layer.
 @param finished  If the draw process is cancelled, it's `NO`, otherwise it's `YES`;
 */
@property (nullable, nonatomic, copy) void (^didDisplay)(CALayer *layer, BOOL finished);    // 在渲染之后

@end

NS_ASSUME_NONNULL_END
