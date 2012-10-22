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

#import <UIKit/UIKit.h>
#import "TiledMapView.h"
#import "MapViewProtocol.h"

@class MapMarker;

@interface MapScrollView : UIScrollView <UIScrollViewDelegate, MapView> {
	
    // The view that is currently front most
	TiledMapView *mapView;
    // The old view that we draw on top of when the zooming stops
	TiledMapView *oldMapView;
    // a low res rendering as background view
    UIImageView *backgroundImageView;
    CGRect backgroundRect;
    
    NSMutableSet *markers;
    
    //determines whether the map source is a PDF or bitmap
    BOOL isBitmap;
    BOOL isPDF;

    //the map source if isBitmap
    UIImage *mapImage;
    
    //the map source if isPDF
    CGPDFDocumentRef pdf;
	CGPDFPageRef page;
    
    //the map source's rect
    CGRect mapRect;
    
    //the path to draw on top of the map
    UIBezierPath *path;
    BOOL isPathOrigin;

	// current zoom scale
	CGFloat mapViewScale;
    CGFloat minimumScale;
    
    //the scale of the map itself
    CGFloat mapScaleInPixelsPerMeter;
}

- (id)initWithFrame:(CGRect)frame mapFilePath:(NSString *)path mapScale:(CGFloat)scaleInPixelsPerMeter;

//methods for MapMarker instances to postition themselves
-(ProjectedPoint)ProjectedPointForPointInView:(CGPoint)viewPoint;
-(CGPoint)projectedViewPointForMapPoint:(ProjectedPoint)mapPoint;
-(void)mapMarkerStoppedPanning:(MapMarker *)marker;

@end
