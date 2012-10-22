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

#import "TiledMapView.h"
#import <QuartzCore/QuartzCore.h>
#import "MapViewProtocol.h"

@implementation TiledMapView


// Create a new TiledPDFView with the desired frame and scale.
- (id)initWithFrame:(CGRect)frame andScale:(CGFloat)scale{
   
    if ((self = [super initWithFrame:frame])) {
		
		CATiledLayer *tiledLayer = (CATiledLayer *)[self layer];
		// levelsOfDetail and levelsOfDetailBias determine how
		// the layer is rendered at different zoom levels.  This
		// only matters while the view is zooming, since once the 
		// the view is done zooming a new TiledMapView is created
		// at the correct size and scale.
        tiledLayer.levelsOfDetail = 4;
		tiledLayer.levelsOfDetailBias = 4;
		tiledLayer.tileSize = CGSizeMake(1024, 1024);
        
        /*
         * Flipping the geometry turns the coordinate system upside down,
         * conforming to the expectation of Quartz/CoreGraphics that the
         * origin lies in the lower left corner instead of upper left (UIKit).
         *
         * NOTE: The following line is commented out because it induced
         * visual glitches (maybe changing the frame for a short time, which
         * confuses layoutSubview in the UIScrollView).
         */
        //tiledLayer.geometryFlipped = YES;
        
        hasPDF = NO;
        hasImage = NO;
        hasPath = NO;
        
        path = nil;
        image = nil;
        pdfPage = NULL;
        
		myScale = scale;
    }
    return self;
}

// Set the layer's class to be CATiledLayer.
+ (Class)layerClass {
	return [CATiledLayer class];
}

// Set the CGPDFPageRef for the view.
- (void)setPage:(CGPDFPageRef)newPage
{
    CGPDFPageRelease(self->pdfPage);
    self->pdfPage = CGPDFPageRetain(newPage);
    
    hasPDF = YES;
}

- (void)setPath:(UIBezierPath *)newPath {
    
    [path release];
    path = [newPath retain];
    
    hasPath = YES;
}

- (void)setImage:(UIImage *)newImage {
    
    [image release];
    image = [newImage retain];
    
    hasImage = YES;
}


-(void)drawRect:(CGRect)r
{
    // UIView uses the existence of -drawRect: to determine if it should allow its CALayer
    // to be invalidated, which would then lead to the layer creating a backing store and
    // -drawLayer:inContext: being called.
    // By implementing an empty -drawRect: method, we allow UIKit to continue to implement
    // this logic, while doing our real drawing work inside of -drawLayer:inContext:
}


// Draw into the layer at the correct scale.
-(void)drawLayer:(CALayer*)layer inContext:(CGContextRef)context
{
    //push the current context to the stack,
    //as we make modifications to it
    CGContextSaveGState(context);
    
	// First, fill the background with white.
	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(context, self.bounds);
    
    // Turn the provided context upside down, to match the native origin of Quartz which is lower left.
    // I would love to use tiledLayer.geometryFlipped = YES, but it leads to visual glitches.
    CGContextTranslateCTM(context, 0.0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // Scale the context so that everything is rendered 
    // at the correct size for the zoom level.
    CGContextScaleCTM(context, myScale, myScale);	
    
    if (hasPDF) {
        
        CGContextDrawPDFPage(context, pdfPage);
    }
    
    if (hasImage) {
        
        CGRect imageRect = CGRectMake(0.0f, 
                                      0.0f, 
                                      CGImageGetWidth(image.CGImage), 
                                      CGImageGetHeight(image.CGImage));
        
        CGContextDrawImage(context, imageRect, image.CGImage);
    }
    
    if (hasPath) {
        
        //set the drawing properties
        CGContextSetRGBStrokeColor(context, kPathStrokeRGBColor);
        CGContextSetLineCap(context, kPathLineCap);
        CGContextSetLineJoin(context, kPathLineJoin);
        CGContextSetLineWidth(context, kPathLineWidth);
        
        //draw the path
        CGContextAddPath(context, path.CGPath);
        CGContextStrokePath(context);
    }
    
    //pop the old context from the stack
    CGContextRestoreGState(context);
}

// Clean up.
- (void)dealloc {
	
    if (hasPDF) CGPDFPageRelease(pdfPage);
	if (hasImage) [image release];
    if (hasPath) [path release];
    
    [super dealloc];
}


@end
