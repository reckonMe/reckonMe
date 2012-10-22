/**
*	The BSD 2-Clause License (aka "FreeBSD License")
*
*	Copyright (c) 2012, Benjamin Thiel, Kamil Kloch
*	All rights reserved.
*
*	Redistribution and use in source and binary forms, with or without
*	modification, are permitted provided that the following conditions are met: 
*
*	1. Redistributions of source code must retain the above copyright notice, this
*	   list of conditions and the following disclaimer. 
*	2. Redistributions in binary form must reproduce the above copyright notice,
*	   this list of conditions and the following disclaimer in the documentation
*	   and/or other materials provided with the distribution. 
*
*	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
*	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
*	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
*	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
*	ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
*	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
*	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
*	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
*	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

#import "BTFancyButton.h"

@interface BTFancyButton ()

- (void)swapGradientStartAndEndPoint;
- (void)commonInit;

@end

@implementation BTFancyButton

+ (UIColor *)aestheticallyPleasingGreen {
    
    return [UIColor colorWithRed:0.2
                           green:0.5
                            blue:0.0
                           alpha:1];
}

//MARK: - initialization
- (id)init {
    
    if (self = [super init]) {
        
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    if (self = [super initWithCoder:aDecoder]) {
        
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:frame]) {
        
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    
    // Initialize the gradient layer
    gradientLayer = [[CAGradientLayer alloc] init];
    // Set its bounds to be the same of its parent
    [gradientLayer setBounds:[self bounds]];
    // Center the layer inside the parent layer
    [gradientLayer setPosition:CGPointMake([self bounds].size.width / 2,
                                           [self bounds].size.height / 2)];
    
    // Insert the layer at position zero to make sure the 
    // text of the button is not obscured
    [[self layer] insertSublayer:gradientLayer atIndex:0];
    
    //make the button a "rounded rect"
    [[self layer] setCornerRadius:10.0f];
    [[self layer] setMasksToBounds:YES];

    //give it a border
    [[self layer] setBorderWidth:1.0f];
    [[self layer] setBorderColor:[[UIColor grayColor] CGColor]];
    
    //call setBackgroundColor to setup the gradient's color
    [self setBackgroundColor:self.backgroundColor];
}

- (void)dealloc {
    
    [gradientLayer release];
    [super dealloc];
}

//MARK: - overriding methods
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    
    [super setBackgroundColor:backgroundColor];
    
    CGFloat bgRed, bgGreen, bgBlue, bgAlpha;
    bgRed = bgGreen = bgBlue = bgAlpha = 0;
    
    //try to get the component values of the background color
    if ([backgroundColor getRed:&bgRed
                          green:&bgGreen
                           blue:&bgBlue
                          alpha:&bgAlpha]) {
        
        //add the summand and check for bounds
        CGFloat highRed = MIN(bgRed + kBTFancyButtonGradientLightColorSummand, 1.0);
        CGFloat highGreen = MIN(bgGreen + kBTFancyButtonGradientLightColorSummand, 1.0);
        CGFloat highBlue = MIN(bgBlue + kBTFancyButtonGradientLightColorSummand, 1.0);
        
        //subtract the (1 - summand) and check for bounds
        CGFloat lowRed = MAX(bgRed - (1 - kBTFancyButtonGradientLightColorSummand), 0.0);
        CGFloat lowGreen = MAX(bgGreen - (1 - kBTFancyButtonGradientLightColorSummand), 0.0);
        CGFloat lowBlue = MAX(bgBlue - (1 - kBTFancyButtonGradientLightColorSummand), 0.0);
        
        UIColor *highColor = [UIColor colorWithRed:highRed
                                             green:highGreen
                                              blue:highBlue
                                             alpha:bgAlpha];
        
        UIColor *lowColor = [UIColor colorWithRed:lowRed
                                            green:lowGreen
                                             blue:lowBlue
                                            alpha:bgAlpha];
        
        //use these ligher and darker versions of the backgroundColor for the gradient
        [gradientLayer setColors:[NSArray arrayWithObjects:
                                  (id) [highColor CGColor], 
                                  (id) [backgroundColor CGColor],
                                  (id) [lowColor CGColor],
                                  nil]];
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [self swapGradientStartAndEndPoint];
    
    return [super beginTrackingWithTouch:touch
                               withEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [self swapGradientStartAndEndPoint];
    
    [super endTrackingWithTouch:touch
                      withEvent:event];
}

//MARK: - make the button look (un)pressed
- (void)swapGradientStartAndEndPoint {
    
    CGPoint start = gradientLayer.startPoint;
    CGPoint end = gradientLayer.endPoint;
    
    gradientLayer.startPoint = end;
    gradientLayer.endPoint = start;
}

@end
