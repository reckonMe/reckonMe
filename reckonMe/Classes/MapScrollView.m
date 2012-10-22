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

#import "MapScrollView.h"
#import "TiledMapView.h"
#import "MapMarker.h"
#import <QuartzCore/QuartzCore.h>

@interface MapScrollView ()

@property(nonatomic, retain) MapMarker *currentPositionMarker;
@property(nonatomic, retain) MapMarker *correctedPositionMarker;
//@property(nonatomic, retain) UILabel *chooseInitialPositionMarkerLabel;
//@property(nonatomic, retain) UILabel *correctPositionMarkerLabel;

-(void)showNewTiledView;
-(void)renderNewBackgroundView;

-(ProjectedPoint)projectMapImagePointOnMap:(CGPoint)mapImagePoint;
-(CGPoint)projectMapPointOnMapImage:(ProjectedPoint)pointOnMap;

-(CGPoint)projectViewPointOnMapImage:(CGPoint)pointInView;
-(CGPoint)projectMapImagePointOnView:(CGPoint)pointOnMapImage;

-(void)showMarker:(MapMarker *)mapMarker;
-(void)showAllMarkers;
-(void)hideAllMarkers;

-(void)addMarker:(MapMarker *)mapMarker;
-(void)removeMarker:(MapMarker *)mapMarker;
-(void)removeAllMarkers;

-(void)createMarkers;

-(ProjectedPoint)maximumValueOfMapRect;

@end

@implementation MapScrollView

@synthesize correctedPositionMarker;
@synthesize currentPositionMarker;
@synthesize mapViewDelegate;

- (id)initWithFrame:(CGRect)frame mapFilePath:(NSString *)filePath mapScale:(CGFloat)scaleInPixelsPerMeter {
    
    if ((self = [super initWithFrame:frame])) {
        
        markers = [[NSMutableSet alloc] init];
        
        // Set up the UIScrollView
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.bouncesZoom = YES;
        self.decelerationRate = UIScrollViewDecelerationRateFast;
        self.delegate = self;
		[self setBackgroundColor:[UIColor grayColor]];
		self.maximumZoomScale = 5.0;
		self.minimumZoomScale = 0.25;
        
        backgroundImageView = nil;
        
        isPDF = NO;
        isBitmap = NO;
        
        mapScaleInPixelsPerMeter = scaleInPixelsPerMeter;
        
        path = [[UIBezierPath bezierPath] retain];
        isPathOrigin = YES;
        
        if (filePath) {
            
            //PDF?
            if ([[filePath pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
                
                // Open the PDF document
                NSURL *pdfURL = [[NSURL alloc] initFileURLWithPath:filePath];
                pdf = CGPDFDocumentCreateWithURL((CFURLRef)pdfURL);
                [pdfURL release];
                
                if (pdf != NULL) {
                    
                    isPDF = YES;
                    
                    // Get the PDF Page that we will be drawing
                    page = CGPDFDocumentGetPage(pdf, 1);
                    CGPDFPageRetain(page);
                    
                    // determine the size of the PDF page
                    mapRect = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
                }
                
            //bitmap?
            } else {
                
                mapImage = [[UIImage alloc] initWithContentsOfFile:filePath];
                
                if (mapImage != nil) {
                    
                    isBitmap = YES;
                    
                    mapRect = CGRectMake(0,
                                         0,
                                         mapImage.size.width,
                                         mapImage.size.height);
                }
            }
            
            //successfully aquired image?
            if (isBitmap || isPDF) {
                
                //scale the map to fit the view
                CGFloat horizontalScale = self.bounds.size.width / mapRect.size.width;
                CGFloat verticalScale = self.bounds.size.height / mapRect.size.height;

                //set the minimum scale as maximum of both values,
                //which fills the view and avoids blank space not belonging to the map
                //(which, in turn, causes some projections to break and makes markers "hop")
                minimumScale = MAX(horizontalScale, verticalScale);
                mapViewScale = minimumScale;
                
                CGRect rectThatFits = CGRectMake(0,
                                                 0,
                                                 mapRect.size.width * mapViewScale,
                                                 mapRect.size.height * mapViewScale);
                backgroundRect = rectThatFits;
                
                //render a low-res background image
                [self renderNewBackgroundView];
                
                //begin high-res rendering
                [self showNewTiledView];
                
                [self createMarkers];
            }
        }
    }
    return self;
}


- (void)createMarkers {
    
    ProjectedPoint mapCenter = {self.maximumValueOfMapRect.easting / 2,
        self.maximumValueOfMapRect.northing / 2};
    
    //create the draggable position marker
    self.correctedPositionMarker = [[[MapMarker alloc] initWithMarkerImage:[UIImage imageNamed:@"crosshairsLarge.png"]] autorelease];
    self.correctedPositionMarker.enableDragging = YES;
    self.correctedPositionMarker.projectedLocation = mapCenter;
    
    //create its labels
    /*
    self.correctPositionMarkerLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    self.correctPositionMarkerLabel.text = @"Drag me to your current position\nand press \"Correct Estimate\".";
    self.correctPositionMarkerLabel.numberOfLines = 2;
    self.correctPositionMarkerLabel.font = [UIFont systemFontOfSize:15];
    self.correctPositionMarkerLabel.backgroundColor = [UIColor colorWithRed:0
                                                                      green:0
                                                                       blue:0
                                                                      alpha:0.5];
    self.correctPositionMarkerLabel.textColor = [UIColor whiteColor];
    self.correctPositionMarkerLabel.textAlignment = UITextAlignmentCenter;
    
    self.chooseInitialPositionMarkerLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    self.chooseInitialPositionMarkerLabel.text = @"Drag me to your current\nposition and press \"Start\".";
    self.chooseInitialPositionMarkerLabel.numberOfLines = 2;
    self.chooseInitialPositionMarkerLabel.font = [UIFont systemFontOfSize:15];
    self.chooseInitialPositionMarkerLabel.backgroundColor = [UIColor colorWithRed:0
                                                                            green:0
                                                                             blue:0
                                                                            alpha:0.4];
    self.chooseInitialPositionMarkerLabel.textColor = [UIColor colorWithRed:0
                                                                      green:1
                                                                       blue:0
                                                                      alpha:1];
    self.chooseInitialPositionMarkerLabel.textAlignment = UITextAlignmentCenter;
     */
    
    self.currentPositionMarker = [[[MapMarker alloc] initWithMarkerImage:[UIImage imageNamed:@"x.png"]] autorelease];
    self.currentPositionMarker.projectedLocation = mapCenter;
    [self addMarker:self.currentPositionMarker];
}

- (void)dealloc
{
    [path release];
    
    if (isPDF || isBitmap) {
        
        [backgroundImageView release];
        [mapView release];
    }
    
    if (isPDF) {
        
        CGPDFPageRelease(page);
        CGPDFDocumentRelease(pdf);
    }
    
    if (isBitmap) {
        
        [mapImage release];
    }
    
    self.correctedPositionMarker = nil;
    self.currentPositionMarker = nil;
    //self.correctPositionMarkerLabel = nil;
    ///self.chooseInitialPositionMarkerLabel = nil;
    
    [markers release];
    
    [super dealloc];
}

// We use layoutSubviews to center the PDF page in the view
- (void)layoutSubviews 
{
    [super layoutSubviews];
    
    // center the image as it becomes smaller than the size of the screen
	if (mapViewScale <= minimumScale) {
        
        CGSize boundsSize = self.bounds.size;
        CGRect frameToCenter = mapView.frame;
        
        // center horizontally
        if (frameToCenter.size.width < boundsSize.width)
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2;
        else
            frameToCenter.origin.x = 0;
        
        // center vertically
        if (frameToCenter.size.height < boundsSize.height)
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2;
        else
            frameToCenter.origin.y = 0;
        
        mapView.frame = frameToCenter;
    }
    
    //always resize the backgroundView to match the mapView
    backgroundImageView.frame = mapView.frame;
    oldMapView.frame = mapView.frame;
    self.contentSize = mapView.frame.size;
    
	// to handle the interaction between CATiledLayer and high resolution screens, we need to manually set the
	// tiling view's contentScaleFactor to 1.0. (If we omitted this, it would be 2.0 on high resolution screens,
	// which would cause the CATiledLayer to ask us for tiles of the wrong scales.)
	mapView.contentScaleFactor = 1.0;
}

//creates and shows a new TiledMapView (typically after zooming)
- (void)showNewTiledView {
    
	CGRect scaledMapRect = CGRectMake(mapRect.origin.x,
                                       mapRect.origin.y,
                                       mapRect.size.width * mapViewScale,
                                       mapRect.size.height * mapViewScale);
    
    //create the view based on the map size and scale it to the desired size.
    mapView = [[TiledMapView alloc] initWithFrame:scaledMapRect
                                         andScale:mapViewScale];
    
    if (isPDF) {
        
        [mapView setPage:page];
    }
    
    if (isBitmap) {
        
        [mapView setImage:mapImage];
    }
    
    [mapView setPath:path];
    
    //show it
    [self addSubview:mapView];
}

//renders a low res representation of the map and the path and puts it in the background
- (void)renderNewBackgroundView {    
    
    /* 
     * Since we might not be on the main thread, we must not use the convenience methods
     * UIGraphicsBeginImageContext(...) and UIGraphicsGetCurrentContext().
     * Instead, we use low-level CoreGraphics functions to create our off-screen context.
     */
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB(); 
    CGContextRef context = CGBitmapContextCreate(NULL,                          //void *data
                                                 backgroundRect.size.width,
                                                 backgroundRect.size.height,
                                                 8,                             //bits per component
                                                 4 * (size_t) backgroundRect.size.width, //bytes per row
                                                 colorSpaceRef,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host                                                 );
    CGColorSpaceRelease(colorSpaceRef);
    
    // First fill the background with white.
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(context, backgroundRect);
    
    if (isBitmap) {
        
        //no scaling of the coordinate system is necessary for drawing the bitmap,
        //as the backgroundRect is the mapRect already scaled down by minimumScale
        CGContextDrawImage(context, backgroundRect, mapImage.CGImage);
    }
    
    // Scale the context so that the path and PDF is rendered 
    // at the correct size for the zoom level.
    CGContextScaleCTM(context, minimumScale, minimumScale);	
    
    if (isPDF) {

        CGContextDrawPDFPage(context, page);
    }
    
    //set the path drawing properties
    CGContextSetRGBStrokeColor(context, kPathStrokeRGBColor);
    CGContextSetLineCap(context, kPathLineCap);
    CGContextSetLineJoin(context, kPathLineJoin);
    CGContextSetLineWidth(context, kPathLineWidth);
    
    //draw the path
    CGContextAddPath(context, path.CGPath);
    CGContextStrokePath(context);
    
    //fetch the image
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *backgroundImage = [[UIImage alloc] initWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(context);
    
    //remove/add background image on the main thread (which UIKit may only be called from)
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        //remove the old background
        [backgroundImageView removeFromSuperview];
        [backgroundImageView release];
        backgroundImageView = nil;
        
        backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
        [backgroundImage release];
        backgroundImageView.frame = backgroundRect;
        backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
        
        [self addSubview:backgroundImageView];
        [self sendSubviewToBack:backgroundImageView];
    });
}


//MARK: - projections

//in and out: lower left origin (LLO)
-(ProjectedPoint)projectMapImagePointOnMap:(CGPoint)mapImagePoint {
    
    ProjectedPoint result = {0, 0};
    
    if (mapScaleInPixelsPerMeter != 0) {
        
        result.easting = mapImagePoint.x / mapScaleInPixelsPerMeter;
        result.northing = mapImagePoint.y / mapScaleInPixelsPerMeter;
    }
    
    return result;
}

//in and out: lower left origin (LLO)
-(CGPoint)projectMapPointOnMapImage:(ProjectedPoint)pointOnMap {
    
    CGPoint result = CGPointMake(0, 0);
    
    result.x = pointOnMap.easting * mapScaleInPixelsPerMeter;
    result.y = pointOnMap.northing * mapScaleInPixelsPerMeter;
    
    return result;
}

//in: LLO, out: upper left origin (ULO) following UIKit
-(CGPoint)projectMapImagePointOnView:(CGPoint)pointOnMapImage {
    
    CGPoint result = CGPointMake(0, 0);

    result.x = pointOnMapImage.x * mapViewScale;
    //flip the y coordinate to make it ULO
    result.y = (mapRect.size.height - pointOnMapImage.y) * mapViewScale;
    
    return result;
}

//in: ULO, out: LLO
-(CGPoint)projectViewPointOnMapImage:(CGPoint)pointInView {
    
    CGPoint result = CGPointMake(0, 0);

    if (mapViewScale != 0) {
        
        result.x = pointInView.x / mapViewScale;
        //flip the y coordinate to make it LLO
        result.y = mapRect.size.height - (pointInView.y / mapViewScale);
    }
    
    return result;
}

//in: ULO, out: LLO
-(ProjectedPoint)ProjectedPointForPointInView:(CGPoint)viewPoint {
    
    return [self projectMapImagePointOnMap:[self projectViewPointOnMapImage:viewPoint]];
}

-(CGPoint)projectedViewPointForMapPoint:(ProjectedPoint)mapPoint {
    
    return [self projectMapImagePointOnView:[self projectMapPointOnMapImage:mapPoint]];
}

//out: LLO
-(ProjectedPoint)maximumValueOfMapRect {
    
    CGPoint upperRightPoint = CGPointMake(0, 0);
    upperRightPoint.x = mapRect.size.width - mapRect.origin.x;
    upperRightPoint.y = mapRect.size.height - mapRect.origin.y;
    
    return [self projectMapImagePointOnMap:upperRightPoint];
}

//MARK: - map related
-(void)moveMapCenterTo:(AbsoluteLocationEntry *)location {
    
    ProjectedPoint mapPoint = {location.easting, location.northing};
    
    CGPoint pointOnMapImage = [self projectMapPointOnMapImage:mapPoint];
    CGPoint pointOnView = [self projectMapImagePointOnView:pointOnMapImage];
    
    CGRect toBeShown = CGRectMake(pointOnView.x - self.bounds.size.width / 2,
                                  pointOnView.y - self.bounds.size.height / 2,
                                  self.bounds.size.width,
                                  self.bounds.size.height);

    [self scrollRectToVisible:toBeShown
                     animated:YES];
}

-(void)addPathLineTo:(AbsoluteLocationEntry *)location {
    
    ProjectedPoint mapPoint = {location.easting, location.northing};
    
    CGPoint pointOnMapImage = [self projectMapPointOnMapImage:mapPoint];
    
    if (isPathOrigin) {
        
        isPathOrigin = NO;
        [path moveToPoint:pointOnMapImage];
    
    } else {
        
        [path addLineToPoint:pointOnMapImage];
        
        //update the background view in a background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
           
            [self renderNewBackgroundView];
        });
        
        //update only the visible part to save CPU time,
        //the rest is probably re-drawn anyway due to the very limited caching of CATiledLayer
        [mapView setNeedsDisplayInRect:CGRectMake([self contentOffset].x,
                                                  [self contentOffset].y,
                                                  self.bounds.size.width,
                                                  self.bounds.size.height)];
    }
}

-(void)clearPath {
    
    isPathOrigin = YES;
    [path removeAllPoints];
    
    //update the background view in a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
        
        [self renderNewBackgroundView];
    });
    
    //trigger a re-draw of the map
    [mapView setNeedsDisplay];
}

//MARK: - marker management
-(void)addMarker:(MapMarker *)mapMarker {
    
    [markers addObject:mapMarker];
    mapMarker.parentView = self;
    
    [self showMarker:mapMarker];
}

-(void)removeMarker:(MapMarker *)mapMarker {
    
    [mapMarker removeFromSuperview];
    mapMarker.parentView = nil;
    
    [markers removeObject:mapMarker];
    
}

-(void)removeAllMarkers {
    
    for (MapMarker *marker in markers) {
        
        [self removeMarker:marker];
    }
}

-(void)showMarker:(MapMarker *)mapMarker {
    
    //compute the new position
    CGPoint positionInView = [self projectedViewPointForMapPoint:mapMarker.projectedLocation];
    mapMarker.position = positionInView;
    
    [self addSubview:mapMarker];
    [self bringSubviewToFront:mapMarker];
}

-(void)showAllMarkers {
    
    for (MapMarker *marker in markers) {
        
        [self showMarker:marker];
    }
}

-(void)hideAllMarkers {
    
    for (MapMarker *marker in markers) {
        
        [marker removeFromSuperview];
    }
}

-(void)mapMarkerStoppedPanning:(MapMarker *)marker {
    
    ProjectedPoint point = self.correctedPositionMarker.projectedLocation;
    
    AbsoluteLocationEntry *location = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                          eastingDelta:point.easting
                                                                         northingDelta:point.northing
                                                                                origin:CLLocationCoordinate2DMake(0, 0)
                                                                             Deviation:0];
    
    [self.mapViewDelegate userCorrectedPositionTo:[location autorelease]
                                        onMapView:self];
}

-(void)moveCurrentPositionMarkerTo:(AbsoluteLocationEntry *)newPosition {
    
    ProjectedPoint point = {newPosition.easting, newPosition.northing};
    
    self.currentPositionMarker.projectedLocation = point;
}

-(void)startPositionCorrectionMode {
    
    CGPoint mapViewCenter;
    mapViewCenter.x = self.center.x + self.contentOffset.x;
    mapViewCenter.y = self.center.y + self.contentOffset.y;
    
    [self addMarker:self.correctedPositionMarker];
    
    //set it's position after adding it to the map, so that it can compute its projected location
    self.correctedPositionMarker.position = mapViewCenter;
    
    //give the delegate a valid position
    AbsoluteLocationEntry *location = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                          eastingDelta:self.correctedPositionMarker.projectedLocation.easting
                                                                         northingDelta:self.correctedPositionMarker.projectedLocation.northing
                                                                                origin:CLLocationCoordinate2DMake(0,0)
                                                                             Deviation:0];
    
    [self.mapViewDelegate userCorrectedPositionTo:[location autorelease]
                                        onMapView:self];
}

-(void)stopPositionCorrectionMode {
    
    [self removeMarker:self.correctedPositionMarker];
}

#pragma mark -
#pragma mark UIScrollView delegate methods

// A UIScrollView delegate callback, called when the user starts zooming. 
// We return our current TiledMapView.
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return mapView;
}

// A UIScrollView delegate callback, called when the user stops zooming.  When the user stops zooming
// we create a new TiledMapView based on the new zoom level and draw it on top of the old TiledMapView.
- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale
{
    
	CGFloat newScale = mapViewScale * scale;
   
    if (newScale <= minimumScale) {
        
        //limit the zooming-out to a level where the whole map fits the screen 
        mapViewScale = minimumScale;
        
        //Remove the now too small (due to zooming gesture) oldMapView
        //as it looks ugly
        [oldMapView removeFromSuperview];
        [oldMapView release];
        oldMapView = nil;
        
    } else {
        
        mapViewScale = newScale;
    }
    
    [self showNewTiledView];
    [self showAllMarkers];
}

// A UIScrollView delegate callback, called when the user begins zooming.  When the user begins zooming
// we remove the old TiledMapView and set the current TiledMapView to be the old view so we can create a
// a new TiledMapView when the zooming ends.
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view
{
    
	// Remove back tiled view.
	[oldMapView removeFromSuperview];
	[oldMapView release];
    
    [self hideAllMarkers];
	
	// Set the current TiledMapView to be the old view.
	oldMapView = mapView;
	[self addSubview:oldMapView];
}

@end
