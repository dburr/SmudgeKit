//
//  SmudgyWindow.m
//  SmudgeKit
//
//  Created by Hans Petter Eikemo on 29.09.14.
//  Copyright (c) 2014 Ideon. All rights reserved.
//

#import <objc/runtime.h>

#import "SmudgyWindow.h"

#pragma mark - UIWindow category

static const void *EnableSmudgeKitKey = &EnableSmudgeKitKey;
static const void *SmudgeColorKey = &SmudgeColorKey;

@implementation UIWindow (SmudgeKitProperties)
- (void)setEnableSmudgeKit:(BOOL)enableSmudgeKit
{
    objc_setAssociatedObject(self, EnableSmudgeKitKey, [NSNumber numberWithBool:enableSmudgeKit], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setSmudgeColor:(UIColor *)smudgeColor
{
    objc_setAssociatedObject(self, SmudgeColorKey, smudgeColor, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIColor *)smudgeColor
{
    return objc_getAssociatedObject(self, SmudgeColorKey);
}

- (BOOL)isSmudgeKitEnabled
{
    NSNumber *value = objc_getAssociatedObject(self, EnableSmudgeKitKey);
    return [value boolValue];
}

@end

#pragma mark - Private SmudgeLayer implementation -

@interface SmudgeLayer : CAShapeLayer

@property (nonatomic, strong) UIColor *smudgeColor;

///Called when the related event changes. Override to update internal state. Position is set automatically by the superlayer.
- (void)appear;

///Called after smudge creation when a touch begins. Override to customize appear animation.
- (void)disappear;

///Called after the related touch event ends or is cancelled. Override to customize disappear animation, the user must call removeFromSuperview on the instance.
- (void)updateWithTouch:(UITouch *)touch;

@end

@interface SmudgeLayer ()

@property CGPoint velocity;
@property CGPoint previousPosition;

@end

@implementation SmudgeLayer

- (instancetype)init
{
    if (self = [super init]) {
        self.smudgeColor = [UIColor colorWithWhite:0.9 alpha:0.9];
        
        self.velocity = CGPointZero;
        self.contentsScale = [UIScreen mainScreen].scale;

#pragma mark - FINDME
        
        CGFloat radius = 20.0;
        self.path = CGPathCreateWithEllipseInRect(CGRectMake(-radius, -radius, radius*2, radius*2), NULL);
        self.fillColor = self.smudgeColor.CGColor;
        self.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.35].CGColor;
        self.lineWidth = 1;

        self.shadowPath = self.path;
        self.shadowColor = [UIColor blackColor].CGColor;
        self.shadowOpacity = 0.15;
        self.shadowRadius = 3.0;
        self.shadowOffset = CGSizeMake(0.0, 1.0);
    }
    return self;
}

- (void)setSmudgeColor:(UIColor *)smudgeColor
{
    _smudgeColor = smudgeColor;
    self.fillColor = _smudgeColor.CGColor;
}

- (void)updateWithTouch:(UITouch *)touch
{
    if (touch.phase != UITouchPhaseBegan) {
        self.velocity = CGPointMake( (self.velocity.x + self.position.x - self.previousPosition.x) * 0.5 , (self.velocity.y + self.position.y - self.previousPosition.y) * 0.5 );
    }
    self.previousPosition = self.position;
}

- (void)appear
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.opacity = 0.0;
    self.transform = CATransform3DMakeScale(1.5, 1.5, 1);

    [CATransaction commit];

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.1];

    self.opacity = 1.0;
    self.transform = CATransform3DIdentity;

    [CATransaction commit];

}

- (void)disappear
{
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.2];

    __weak typeof(self) weakSelf = self;
    [CATransaction setCompletionBlock:^{
        [weakSelf removeFromSuperlayer];
    }];

    self.opacity = 0.0;
    self.transform = CATransform3DMakeScale(1.5, 1.5, 1);
    self.position = CGPointMake( self.position.x + self.velocity.x * 4.0 , self.position.y + self.velocity.y * 4.0 );

    [CATransaction commit];

}


@end


#pragma mark - Private SmudgeContainer implementation -

@interface SmudgeContainerLayer : CALayer

- (void)updateWithEvent:(UIEvent *)event;
- (void)clearAllTouches;

@end

@interface SmudgeContainerLayer ()

@property (nonatomic, strong) UIColor *smudgeColor;
@property (readonly,nonatomic) NSMutableDictionary *touchSmudgeTable;

@end

@implementation SmudgeContainerLayer

- (instancetype)init
{
    if (self = [super init]) {
        _touchSmudgeTable = @{}.mutableCopy;
        _smudgeColor = [UIColor colorWithWhite:0.9 alpha:0.9];
    }
    return self;
}

- (void)updateWithEvent:(UIEvent *)event
{
    for (UITouch *touch in event.allTouches) {
        NSValue* touchKey = [NSValue valueWithNonretainedObject:touch];
        SmudgeLayer* smudgeLayer = self.touchSmudgeTable[touchKey];
        smudgeLayer.smudgeColor = self.smudgeColor;

        [CATransaction begin];
        [CATransaction setDisableActions:YES];

        if (!smudgeLayer) {
            smudgeLayer = [SmudgeLayer layer];
            smudgeLayer.smudgeColor = self.smudgeColor;
            self.touchSmudgeTable[touchKey] = smudgeLayer;
            [self addSublayer:smudgeLayer];
        }

        smudgeLayer.position = [touch locationInView:nil];
        [smudgeLayer updateWithTouch:touch];

        [CATransaction commit];

        switch (touch.phase) {
            case UITouchPhaseBegan:
                [smudgeLayer appear];
                break;
            case UITouchPhaseCancelled:
            case UITouchPhaseEnded:
                [smudgeLayer disappear];
                [self.touchSmudgeTable removeObjectForKey:touchKey];
                break;
            default:
                break;
        }

    }
}

- (void)clearAllTouches
{
    for (NSValue *touchKey in self.touchSmudgeTable)  {
        SmudgeLayer *smudgeLayer = self.touchSmudgeTable[touchKey];
        [smudgeLayer disappear];
        [self.touchSmudgeTable removeObjectForKey:touchKey];
    }
}

@end


#pragma mark - SmudgyWindow -

@interface SmudgyWindow ()

@property (readonly,nonatomic) SmudgeContainerLayer *smudgeContainer;

@end

@implementation SmudgyWindow

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)  {
        self.enableSmudgeKit = YES;
    }
    return self;
}

- (void)sendEvent:(UIEvent *)event
{
    [super sendEvent:event];
    if (self.enableSmudgeKit)  {
        [self renderTouchesForEvent:event];
    } else {
        [self.smudgeContainer clearAllTouches];
    }
}

- (void)renderTouchesForEvent:(UIEvent *)event
{
    if (!self.smudgeContainer) {
        _smudgeContainer = [SmudgeContainerLayer layer];
        _smudgeContainer.smudgeColor = self.smudgeColor;
        [self.layer addSublayer:self.smudgeContainer];
    } else if ([self.layer.sublayers lastObject] != self.smudgeContainer) {
	    [self.smudgeContainer removeFromSuperlayer];
	    [self.layer addSublayer:self.smudgeContainer];
    }
    [self.smudgeContainer updateWithEvent:event];
}

@end