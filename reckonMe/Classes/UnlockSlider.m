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

/*
 Copyright (c) 2011-2012 Ryan (NULL) and Alex Nichol
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UnlockSlider.h"

const NSTimeInterval kSlideBackAnimationDuration = 0.15;
const CGFloat kTextMaxAlpha = 0.6;

NSString* const kBaseImageName = @"bottom.png";
NSString* const kSlideButtonImage = @"default_slider.png";

const CGFloat kButtonOffsetX = 2;
const CGFloat kButtonOffsetY = 4;

const CGFloat kButtonStartX = 24;
const CGFloat kButtonStartY = 25;

const CGFloat kSliderHeight = 95;
const CGFloat kSliderWidth = 320;

const CGFloat kTextStartX = 113;
const CGFloat kTextStartY = 35;
const CGFloat kTextStartWidth = 378;
const CGFloat kTextStartHeight = 44;

const CGFloat kMaxSlideX = 204;

@interface UnlockSlider ()

-(void)userPannedSlider:(UIPanGestureRecognizer *)sender;

@end

@implementation UnlockSlider {
    
    @private
    UILabel *textView;
	UIImageView *backgroundImage;
	UIImageView *sliderImage;
}

@dynamic text;
@synthesize delegate;

- (void)commonInit {

    UIImage *background = [UIImage imageNamed:kBaseImageName];
    backgroundImage = [[UIImageView alloc] initWithFrame:CGRectMake(0,
                                                                    0,
                                                                    kSliderWidth,
                                                                    kSliderHeight)];
    backgroundImage.image = background;
    [self addSubview:backgroundImage];
    
    textView = [[UILabel alloc] initWithFrame:CGRectMake(kTextStartX,
                                                         kTextStartY,
                                                         kTextStartWidth / 2,
                                                         kTextStartHeight / 2)];
    textView.font = [UIFont systemFontOfSize:22.5];
    textView.textColor = [UIColor whiteColor];
    textView.backgroundColor = [UIColor clearColor];
    textView.text = @"slide to unlock";
    textView.alpha = kTextMaxAlpha;
    [self addSubview:textView];
    
    UIImage *slider = [UIImage imageNamed:kSlideButtonImage];
    sliderImage = [[UIImageView alloc] initWithFrame:CGRectMake(kButtonStartX - (kButtonOffsetX / 2),
                                                                kButtonStartY - (kButtonOffsetY / 2),
                                                                slider.size.width / 2,
                                                                slider.size.height / 2)];
    sliderImage.image = slider;
    [self addSubview:sliderImage];
    
    UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(userPannedSlider:)];
    gesture.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:gesture];
    [gesture release];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        [self commonInit];
    }
    return self;
}

- (void)setText:(NSString *)text {
    
    textView.text = text;
}

- (NSString *)text {
    
    return textView.text;
}

- (void)dealloc {
    
    self.text = nil;
    [backgroundImage release];
    [textView release];
    [sliderImage release];
    
    [super dealloc];
}

- (void)userPannedSlider:(UIPanGestureRecognizer *)sender {
    
    CGPoint translation = [sender translationInView:self];
    CGFloat translationX = MAX(0, MIN(translation.x, kMaxSlideX));
    
    switch (sender.state) {
            
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
        {
            sliderImage.transform = CGAffineTransformMakeTranslation(translationX, 0);
            textView.alpha = kTextMaxAlpha * MAX((kMaxSlideX - translationX * 2) / kMaxSlideX, 0);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
            
            if (translationX == kMaxSlideX) {
                
                [self.delegate userUnlockedSlider:self];
            }
            //no break
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        default:
        {
            [UIView animateWithDuration:kSlideBackAnimationDuration
                             animations:^(void)
             {
                 sliderImage.transform = CGAffineTransformIdentity;
                 textView.alpha = kTextMaxAlpha;
             }];
        }
            break;
    }
}

@end
