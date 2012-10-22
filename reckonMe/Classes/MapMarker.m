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

#import "MapMarker.h"

@implementation MapMarker

@synthesize projectedLocation;
@synthesize enableDragging;
@synthesize markerLabel;
@synthesize parentView;
@dynamic position;
 
#define defaultMarkerAnchorPoint CGPointMake(0.5, 0.5)

- (id) initWithMarkerImage:(UIImage*)image
{
	if (self = [super init]) {
     
        self.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        self.layer.anchorPoint = defaultMarkerAnchorPoint;
        self.layer.contents = (id)[image CGImage];
        self.layer.masksToBounds = NO;
        
        self.markerLabel = nil;
        gestureRecognizer = nil;
        enableDragging = NO;
    }
	
	return self;
}

- (void) dealloc 
{
    [markerLabel release];
    [gestureRecognizer release];
    
	[super dealloc];
}

//MARK: -
- (void) setMarkerLabel:(UILabel *)newMarkerLabel {
    
	if (markerLabel != nil) {
        
		[markerLabel removeFromSuperview];
		[markerLabel release];
		markerLabel = nil;
	}
	
	if (newMarkerLabel != nil) {
        
		markerLabel = [newMarkerLabel retain];
        
        //size it to fit its contents
        [markerLabel sizeToFit];

        //center it horizontally and one pixel beneath the image
        CGPoint labelOrigin = CGPointMake(self.bounds.size.width / 2 - markerLabel.bounds.size.width / 2,
                                       self.bounds.size.height + 1);
        
        CGRect frame = CGRectMake(labelOrigin.x,
                                  labelOrigin.y,
                                  markerLabel.bounds.size.width,
                                  markerLabel.bounds.size.height);
        
        markerLabel.frame = frame;
        
        //make it a rounded rect
        markerLabel.layer.cornerRadius = 4;
        markerLabel.layer.masksToBounds = YES;
        
		[self addSubview:markerLabel];
	}
}

- (void)setEnableDragging:(BOOL)enableDraggingNow {
    
    if (!gestureRecognizer) {
        
        gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                    action:@selector(handlePanGesture:)];
    }
    
    if (enableDraggingNow) {
        
        enableDragging = YES;
        
        [self addGestureRecognizer:gestureRecognizer];
        
    } else {
        
        enableDragging = NO;
        
        [self removeGestureRecognizer:gestureRecognizer];
    }
}


//MARK: - positioning
- (void)setPosition:(CGPoint)newPosition {
    
    self.frame = CGRectMake(newPosition.x - self.bounds.size.width / 2,
                            newPosition.y - self.bounds.size.height / 2,
                            self.bounds.size.width,
                            self.bounds.size.height);
}

- (CGPoint)position {
    
    return CGPointMake(self.frame.origin.x + self.bounds.size.width / 2,
                       self.frame.origin.y + self.bounds.size.height / 2);
}

- (void)setProjectedLocation:(ProjectedPoint)newProjectedLocation {
    
    projectedLocation = newProjectedLocation;
    
    if (parentView != nil) {
        
        //move the marker to its new position on the screen
        self.position = [self.parentView projectedViewPointForMapPoint:projectedLocation];
    }
}

-(void)handlePanGesture:(UIPanGestureRecognizer *)sender {
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        draggingReferenceFrame = self.frame;
    }
    
    CGPoint translate = [sender translationInView:self];
    
    CGRect newFrame = draggingReferenceFrame;
    newFrame.origin.x += translate.x;
    newFrame.origin.y += translate.y;
    self.frame = newFrame;
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (self.parentView) {
            
            //save the final position on the map
            projectedLocation = [self.parentView ProjectedPointForPointInView:self.position];
            [self.parentView mapMarkerStoppedPanning:self];
        }
    }
}

@end
