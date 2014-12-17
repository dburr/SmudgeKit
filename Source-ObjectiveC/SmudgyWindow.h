//
//  SmudgyWindow.h
//  SmudgeKit
//
//  Created by Hans Petter Eikemo on 29.09.14.
//  Copyright (c) 2014 Ideon. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIWindow (SmudgeKitProperties)
@property (nonatomic, getter=isSmudgeKitEnabled) BOOL enableSmudgeKit;
@property (nonatomic, strong) UIColor *smudgeColor;
@end

/**
 * The SmudgyWindow class is a drop in replacement for UIWindow which
 * draws a visual representation of all touch events onto the screen.
 */
@interface SmudgyWindow : UIWindow

@end