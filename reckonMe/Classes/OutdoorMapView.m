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

#import "OutdoorMapView.h"
#import "PinAnnotation.h"
#import "FloorPlanOverlay.h"
#import "FloorPlanOverlayView.h"
#import "PathCopyAnnotation.h"
#import <QuartzCore/QuartzCore.h>

static NSString *startingPinTitle = @"Starting Position";
static NSString *currentPinTitle = @"Current Position";
static NSString *rotationAnchorPinTitle = @"Rotation anchor";
static NSString *correctingPinSubtitle = @"Tap and hold to drag me.";

@interface OutdoorMapView ()

@property(nonatomic, retain) MKPolyline *pathOverlay;

@property(nonatomic, retain) AbsoluteLocationEntry *rotationCenter;
@property(nonatomic, retain) MKPolyline *rotatableSubPath;
@property(nonatomic, retain) MKPolylineRenderer *rotatableSubPathView;
@property(nonatomic, retain) NSMutableArray *pinsMinusCorrectionPin;

@property(nonatomic, retain) PathCopyAnnotation *pathCopyAnnotation;
@property(nonatomic, retain) MKAnnotationView *pathCopy;
@property(nonatomic, retain) UIImage *pathImageCopy;

-(void)setAnchorPoint:(CGPoint)anchorPoint forView:(UIView *)view;

-(MKPolyline *)createPathOverlayFrom:(NSArray *)points;
-(void)updatePathOverlay;

-(void)correctedPosition;

-(void)pinButtonPressed:(UIButton *)sender; 

@end

@implementation OutdoorMapView {
    
    @private
    
    MKMapView *mapView;
    NSMutableArray *pathPoints;
    PinAnnotation *currentPosition;
    PinAnnotation *startingPosition;
    PinAnnotation *rotationAnchor;
    
    FloorPlanOverlay *floorPlanOverlay;
    
    BOOL startingPositionFixingMode;
}

@synthesize mapViewDelegate;
@synthesize pathOverlay;
@synthesize pinsMinusCorrectionPin;
@synthesize pathCopy;
@synthesize pathImageCopy;
@synthesize pathCopyAnnotation;

@synthesize rotatableSubPath, rotatableSubPathView, rotationCenter;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        mapView = [[MKMapView alloc] initWithFrame:frame];
        //mapView.mapType = MKMapTypeHybrid;
        mapView.zoomEnabled = YES;
        mapView.delegate = self;
        self.pathOverlay = nil;
        
        [self addSubview:mapView];
        
        currentPosition = [[PinAnnotation alloc] init];
        currentPosition.title = startingPinTitle;
        currentPosition.subtitle = correctingPinSubtitle;
        
        startingPosition = [[PinAnnotation alloc] init];
        startingPosition.title = startingPinTitle;
        
        rotationAnchor = [[PinAnnotation alloc] init];
        rotationAnchor.title = rotationAnchorPinTitle;
        rotationAnchor.subtitle = correctingPinSubtitle;
        
        CLLocationCoordinate2D itzCenter = CLLocationCoordinate2DMake(48.565735,13.450134);
        /*NSString *path = [[NSBundle mainBundle] pathForResource:@"itz-floorplanRotated.pdf"
                                                         ofType:nil];
        floorPlanOverlay = [[FloorPlanOverlay alloc] initWithCenter:itzCenter
                                                           planPath:path
                                                scalePixelsPerMeter:8.09];*/
        NSString *path = [[NSBundle mainBundle] pathForResource:@"itz-grayHalf.png"
                                                         ofType:nil];
        floorPlanOverlay = [[FloorPlanOverlay alloc] initWithCenter:itzCenter
                                                           planPath:path
                                                scalePixelsPerMeter:8];
        
        [mapView addOverlay:floorPlanOverlay];
        
        startingPositionFixingMode = NO;
        
        pathPoints = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    
    [mapView removeFromSuperview];
    
    [mapView release];
    [pathPoints release];
    self.pathOverlay = nil;
    self.pinsMinusCorrectionPin = nil;
    [currentPosition release];
    [startingPosition release];
    [rotationAnchor release];
    
    [super dealloc];
}


- (void)setAutoresizingMask:(UIViewAutoresizing)autoresizingMask {
    
    super.autoresizingMask = autoresizingMask;
    mapView.autoresizingMask = autoresizingMask;
}


//MARK: - MapView protocol
-(void)setShowGPSfix:(BOOL)showGPSfix {
    
    mapView.showsUserLocation = showGPSfix;
}

-(BOOL)showGPSfix {
    
    return mapView.showsUserLocation;
}

-(void)moveMapCenterTo:(AbsoluteLocationEntry *)mapPoint {
    
    static BOOL alreadyZoomed = NO;
    
    CLLocationCoordinate2D moveToCoords = mapPoint.absolutePosition;
    
    if (alreadyZoomed) {
        
        mapView.centerCoordinate = moveToCoords;
    
    } else {
        
        static int spanInMetres = 20;
        
        ProjectedPoint plusSpan = {mapPoint.easting + spanInMetres, mapPoint.northing + spanInMetres};
        CLLocationCoordinate2D coordsPlusSpan = [GeodeticProjection cartesianToCoordinates:plusSpan];
        
        MKCoordinateSpan span = {coordsPlusSpan.latitude - moveToCoords.latitude,
                                 coordsPlusSpan.longitude - moveToCoords.longitude};
        
        MKCoordinateRegion region = MKCoordinateRegionMake(moveToCoords, span);
        
        [mapView setRegion:region
                  animated:YES];
        
        alreadyZoomed = YES;
    }
    
    if (startingPositionFixingMode) {
        
        currentPosition.coordinate = moveToCoords;
    }

}

-(void)addPathLineTo:(AbsoluteLocationEntry *)mapPoint {
    
    [pathPoints addObject:mapPoint];
    
    [self updatePathOverlay];
}

-(void)replacePathBy:(NSArray *)path {
    
    [pathPoints setArray:path];
    
    [self updatePathOverlay];
}

-(void)updatePathOverlay {
    
    MKPolyline *newPath = [self createPathOverlayFrom:pathPoints];
    
    [self replacePathOverlayWith:newPath];
}

-(void)replacePathOverlayWith:(MKPolyline *)newPath {
    
    if (newPath.pointCount >= 2) {
        
        //add new and then remove old path to prevent flickering
        MKPolyline *oldPath = self.pathOverlay;
        self.pathOverlay = newPath;
        [mapView addOverlay:self.pathOverlay];
        
        if (oldPath) {
            
            [mapView removeOverlay:oldPath];
        }
    }
}

-(MKPolyline *)createPathOverlayFrom:(NSArray *)points {
    
    NSUInteger numPoints = [points count];
    
    if (numPoints >= 2) {
        
        CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *) malloc(sizeof(CLLocationCoordinate2D) * numPoints);
        
        //fill an array with coordinates
        for (NSUInteger i = 0; i < numPoints; i++) {
            
            AbsoluteLocationEntry *location = [points objectAtIndex:i];
            coordinates[i] = location.absolutePosition;
        }
        
        MKPolyline *path = [MKPolyline polylineWithCoordinates:coordinates
                                                         count:numPoints];
        free(coordinates);
        
        return path;
    
    } else {
        
        return nil;
    }
}

-(void)clearPath {
    
    [pathPoints removeAllObjects];
    
    [mapView removeOverlay:self.pathOverlay];
    self.pathOverlay = nil;
    
}

-(void)setStartingPosition:(AbsoluteLocationEntry *)mapPoint {
    
    startingPosition.coordinate = mapPoint.absolutePosition;
}

-(void)moveCurrentPositionMarkerTo:(AbsoluteLocationEntry *)newPosition {
    
    currentPosition.coordinate = newPosition.absolutePosition;

    [mapView addAnnotation:currentPosition];
}

-(void)startStartingPositionFixingMode {
    
    if (!startingPositionFixingMode) {
        
        startingPositionFixingMode = YES;
        
        [mapView removeAnnotations:mapView.annotations];
        
        currentPosition.title = startingPinTitle;
        currentPosition.subtitle = correctingPinSubtitle;
        [mapView addAnnotation:currentPosition];
    }
}

-(void)stopStartingPositionFixingMode {
    
    if (startingPositionFixingMode) {
        
        currentPosition.title = currentPinTitle;
        currentPosition.subtitle = correctingPinSubtitle;
        
        [mapView addAnnotation:startingPosition];
            
        [self correctedPosition];
        
        startingPositionFixingMode = NO;
    }
}

-(void)correctedPosition {
    
    CLLocationCoordinate2D droppedAt = currentPosition.coordinate;
    AbsoluteLocationEntry *correctedLocation = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                                   eastingDelta:0
                                                                                  northingDelta:0
                                                                                         origin:droppedAt
                                                                                      Deviation:1];
    
    [self.mapViewDelegate userCorrectedPositionTo:[correctedLocation autorelease] 
                                        onMapView:self];
}

//MARK: - path rotation
-(void)startPathRotationModeForSubPath:(NSArray *)subPath aroundPosition:(AbsoluteLocationEntry *)_rotationCenter {
    
    //remove other pins as they might obstruct the path rotation pin 
    [mapView removeAnnotation:startingPosition];
    [mapView removeAnnotation:currentPosition];
    
    //disable zooming
    mapView.zoomEnabled = NO;
    
    self.rotationCenter = _rotationCenter;
    
    //create a path overlay of the subPath
    self.rotatableSubPath = [self createPathOverlayFrom:subPath];
    
    if (self.rotatableSubPath) {
        
        //control flow: 
        //   mapView:viewForOverlay:
        //-> mapView:didAddOverlayViews:
        //-> createScreenShotOfRotatableSubPath
        [mapView addOverlay:self.rotatableSubPath];
        [self createScreenShotOfRotatableSubPath];
        
        rotationAnchor.coordinate = _rotationCenter.absolutePosition;
        [mapView addAnnotation:rotationAnchor];
    }
}

-(void)createScreenShotOfRotatableSubPath {
    
    MKPolylineRenderer *subPathView = self.rotatableSubPathView;
       
//    MKZoomScale currentZoomScale = (CGFloat)(mapView.bounds.size.width / mapView.visibleMapRect.size.width);
//    CGRect pathrect = CGPathGetBoundingBox(subPathView.path);/*CGRectMake(subPathView.bounds.origin.x,
//                                 subPathView.bounds.origin.y,
//                                 subPathView.bounds.size.width * currentZoomScale,
//                                 subPathView.bounds.size.height * currentZoomScale);*/
//    
//    //create a graphics context
//    /*
//     * for reasons unknown:
//     * UIGraphicsBeginImageContextWithOptions(subPathView.bounds.size, NO, 0);
//     * CGContextRef context = UIGraphicsGetCurrentContext();
//     * wouldn't work
//     */
//    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB(); 
//    CGContextRef context = CGBitmapContextCreate(NULL,                          //void *data
//                                                 pathrect.size.width,
//                                                 pathrect.size.height,
//                                                 8,                             //bits per component
//                                                 4 * (size_t) pathrect.size.width, //bytes per row
//                                                 colorSpaceRef,
//                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
//    CGColorSpaceRelease(colorSpaceRef);
//    
//    // Turn the provided context upside down, to match the native origin of Quartz which is lower left.
//    //CGContextTranslateCTM(context, 0.0, pathrect.size.height);
//    //CGContextScaleCTM(context, 1.0, -1.0);
//    
//    //scale the coordinate system to the current zoom level
//    //CGContextScaleCTM(context, currentZoomScale, currentZoomScale);
//    
//    //draw the path    
//    NSLog(@"strokeColor: %@", subPathView.strokeColor);
//    [subPathView strokePath:subPathView.path
//                  inContext:context];
//    [subPathView fillPath:subPathView.path
//                inContext:context];
//    
//    //fetch the image
//	CGImageRef cgImage = CGBitmapContextCreateImage(context);
//    UIImage *pathImage = [[UIImage alloc] initWithCGImage:cgImage];
//    CGImageRelease(cgImage);
//    CGContextRelease(context);
//    
//    self.pathImageCopy = [pathImage autorelease];
    
    MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];
    options.region = mapView.region;
    options.scale = [UIScreen mainScreen].scale;
    options.size = mapView.frame.size;
    
    MKMapSnapshotter *snapshotter = [[MKMapSnapshotter alloc] initWithOptions:options];
    [snapshotter startWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
              completionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
                  if (error) {
                      NSLog(@"[Error] %@", error);
                      return;
                  }
                  
                  //MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:nil];
                  
                  UIImage *image = snapshot.image;
                  UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
                  {
                      [image drawAtPoint:CGPointMake(0.0f, 0.0f)];
                      
                      CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
//                      for (id <MKAnnotation> annotation in self.mapView.annotations) {
//                          CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
//                          if (CGRectContainsPoint(rect, point)) {
//                              point.x = point.x + pin.centerOffset.x -
//                              (pin.bounds.size.width / 2.0f);
//                              point.y = point.y + pin.centerOffset.y -
//                              (pin.bounds.size.height / 2.0f);
//                              [pin.image drawAtPoint:point];
//                          }
//                      }
                      
                      UIImage *compositeImage = UIGraphicsGetImageFromCurrentImageContext();
                      self.pathImageCopy = compositeImage;
                      
                      
                  }
                  UIGraphicsEndImageContext();
                  
                  //Create an annotation on the map on the same location as the path view.
                  //MKAnnotationView has the advantage of being rotatable by CGAffineTransforms.
                  self.pathCopyAnnotation = [[[PathCopyAnnotation alloc] init] autorelease];
                  MKMapPoint pathCenter = MKMapPointMake(self.rotatableSubPath.boundingMapRect.origin.x + self.rotatableSubPath.boundingMapRect.size.width / 2,
                                                         self.rotatableSubPath.boundingMapRect.origin.y + self.rotatableSubPath.boundingMapRect.size.height / 2);
                  self.pathCopyAnnotation.coordinate = MKCoordinateForMapPoint(pathCenter);
                  
                  //set the anchor point (=starting point) around which the view will be rotated
                  MKMapPoint startingPoint = MKMapPointForCoordinate(self.rotationCenter.absolutePosition);
                  CGPoint anchor = CGPointMake((startingPoint.x - self.rotatableSubPath.boundingMapRect.origin.x) / self.rotatableSubPath.boundingMapRect.size.width,
                                               (startingPoint.y - self.rotatableSubPath.boundingMapRect.origin.y) / self.rotatableSubPath.boundingMapRect.size.height);
                  self.pathCopyAnnotation.pathCopyAnchorPoint = anchor;
                  
                  [mapView addAnnotation:self.pathCopyAnnotation];
                  [mapView removeOverlay:self.rotatableSubPath];

              }];
    
}

-(void)rotatePathViewBy:(CGFloat)radians {
    
    self.pathCopy.transform = CGAffineTransformMakeRotation(radians);
}

-(void)stopPathRotationMode {
    
    if (self.pathCopyAnnotation) {
        
        [mapView removeAnnotation:self.pathCopyAnnotation];
        self.pathCopyAnnotation = nil;
    }
    
    //re-add pins and enable zoom
    [mapView removeAnnotation:rotationAnchor];
    [mapView addAnnotation:startingPosition];
    [mapView addAnnotation:currentPosition];
    mapView.zoomEnabled = YES;
}

-(void)setAnchorPoint:(CGPoint)anchorPoint forView:(UIView *)view
{
    CGPoint newPoint = CGPointMake(view.bounds.size.width * anchorPoint.x, view.bounds.size.height * anchorPoint.y);
    CGPoint oldPoint = CGPointMake(view.bounds.size.width * view.layer.anchorPoint.x, view.bounds.size.height * view.layer.anchorPoint.y);
    
    newPoint = CGPointApplyAffineTransform(newPoint, view.transform);
    oldPoint = CGPointApplyAffineTransform(oldPoint, view.transform);
    
    CGPoint position = view.layer.position;
    
    position.x -= oldPoint.x;
    position.x += newPoint.x;
    
    position.y -= oldPoint.y;
    position.y += newPoint.y;
    
    view.layer.position = position;
    view.layer.anchorPoint = anchorPoint;
}
 
//MARK: - MKMapViewDelegate protocol
-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay {
    
    if (overlay == self.pathOverlay) {
        
        MKPolylineRenderer *pathView = [[MKPolylineRenderer alloc] initWithPolyline:self.pathOverlay];
        
        //set the drawing properties
        const CGFloat colorArray[4] = {kPathStrokeRGBColor};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGColorRef color = CGColorCreate(colorSpace, colorArray);
        
        pathView.strokeColor = [UIColor colorWithCGColor:color];
        CGColorSpaceRelease(colorSpace);
        CGColorRelease(color);
        
        pathView.lineCap = kPathLineCap;
        pathView.lineJoin = kPathLineJoin;
        pathView.lineWidth = kPathLineWidth;
        
        return [pathView autorelease];
    }
    
    if (overlay == self.rotatableSubPath) {
        
        self.rotatableSubPathView = [[[MKPolylineRenderer alloc] initWithPolyline:overlay] autorelease];
        
        //set the drawing properties
        const CGFloat colorArray[4] = {0.0, 1.0, 0.0, 0.8};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGColorRef color = CGColorCreate(colorSpace, colorArray);
        
        self.rotatableSubPathView.strokeColor = [UIColor colorWithCGColor:color];
        CGColorSpaceRelease(colorSpace);
        CGColorRelease(color);
        
        self.rotatableSubPathView.lineCap = kPathLineCap;
        self.rotatableSubPathView.lineJoin = kPathLineJoin;
        self.rotatableSubPathView.lineWidth = kPathLineWidth;
        
        return self.rotatableSubPathView;
    }
    
    if ([overlay isKindOfClass:[FloorPlanOverlay class]]) {
        
        FloorPlanOverlayView *floorPlan = [[FloorPlanOverlayView alloc] initWithOverlay:overlay];
        
        return [floorPlan autorelease];
    }
    
    return nil;
}

-(MKAnnotationView *)mapView:(MKMapView *)_mapView viewForAnnotation:(id<MKAnnotation>)annotation {

    static NSString *currentIdentifier = @"curr";
    static NSString *startingIdentifier = @"start";
    static NSString *pathCopyIdentifier = @"pathCopy";
    static NSString *rotationAnchorIdentifier = @"rotAnchor";
    
    MKPinAnnotationView *aView = nil;
    
    if (annotation == currentPosition) {
        
        aView = (MKPinAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:currentIdentifier];
        
        if (aView == nil) {
            
            aView = [[[MKPinAnnotationView alloc] initWithAnnotation:annotation 
                                                     reuseIdentifier:currentIdentifier] autorelease];
            
            UIButton *leftButton = [UIButton buttonWithType:UIButtonTypeCustom];
            UIImage *gpsImageDepressed = [UIImage imageNamed:@"gps-round-button-depressed.png"];
            UIImage *gpsImagePressed = [UIImage imageNamed:@"gps-round-button-pressed.png"];
            [leftButton setImage:gpsImageDepressed forState:UIControlStateNormal];
            [leftButton setImage:gpsImagePressed forState:UIControlStateHighlighted];
            leftButton.frame = CGRectMake(0, 0, 31, 31);
            
            [leftButton addTarget:self
                            action:@selector(pinButtonPressed:)
                  forControlEvents:UIControlEventTouchUpInside];
            
            aView.leftCalloutAccessoryView = leftButton;
        }
        aView.annotation = annotation;
        aView.canShowCallout = YES;
        aView.draggable = YES;
        aView.animatesDrop = YES;
        aView.pinColor = MKPinAnnotationColorRed;
    }
    
    if (annotation == startingPosition) {
        
        aView = (MKPinAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:startingIdentifier];
        
        if (aView == nil) {
            
            aView = [[[MKPinAnnotationView alloc] initWithAnnotation:annotation 
                                                     reuseIdentifier:startingIdentifier] autorelease];
            
        }
        aView.annotation = annotation;
        aView.canShowCallout = YES;
        aView.draggable = NO;
        aView.animatesDrop = NO;
        aView.pinColor = MKPinAnnotationColorGreen;
    }
    
    if (annotation == rotationAnchor) {
        
        aView = (MKPinAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:rotationAnchorIdentifier];
        
        if (aView == nil) {
            
            aView = [[[MKPinAnnotationView alloc] initWithAnnotation:annotation 
                                                     reuseIdentifier:rotationAnchorIdentifier] autorelease];
            
        }
        aView.annotation = annotation;
        aView.canShowCallout = YES;
        aView.draggable = YES;
        aView.animatesDrop = YES;
        aView.pinColor = MKPinAnnotationColorPurple;
    }
    
    if (annotation == pathCopyAnnotation) {
        
        if (!self.pathCopy || self.pathCopy.annotation != annotation) {
            
            self.pathCopy = [[[MKAnnotationView alloc] initWithAnnotation:annotation 
                                                          reuseIdentifier:pathCopyIdentifier] autorelease];
            
            self.pathCopy.annotation = annotation;
            self.pathCopy.canShowCallout = NO;
            self.pathCopy.draggable = NO;
            self.pathCopy.image = self.pathImageCopy;
        }
        return pathCopy;
    }
    return aView;
}

-(void)pinButtonPressed:(UIButton *)sender {
    
    [self.mapViewDelegate userTappedMoveToGPSbutton];
}

-(void)mapView:(MKMapView *)_mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {

    if (view.annotation == currentPosition) {
        
        if (   oldState == MKAnnotationViewDragStateEnding
            && newState == MKAnnotationViewDragStateNone) {
            
            [self correctedPosition];
        }
    }
    
    if (view.annotation == rotationAnchor) {
        
        //begin dragging? remove old path copy
        if (   oldState == MKAnnotationViewDragStateNone
            && newState == MKAnnotationViewDragStateStarting) {
            
            //"old" path?
            if (self.pathCopyAnnotation) {
                
                [mapView removeAnnotation:self.pathCopyAnnotation];
                self.pathCopyAnnotation = nil;
            }
        }
        
        //done?
        if (   oldState == MKAnnotationViewDragStateEnding
            && newState == MKAnnotationViewDragStateNone) {

            AbsoluteLocationEntry *newAnchor = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                                   eastingDelta:0
                                                                                  northingDelta:0
                                                                                         origin:rotationAnchor.coordinate
                                                                                      Deviation:1];
            [self.mapViewDelegate userMovedRotationAnchorTo:[newAnchor autorelease]];
        }
    }
}

-(void)mapView:(MKMapView *)mapView didAddOverlayViews:(NSArray *)overlayViews {
    
    if ([overlayViews containsObject:self.rotatableSubPathView]) {
        
        [self createScreenShotOfRotatableSubPath];
    }
}

-(void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
    
    if ([views containsObject:self.pathCopy]) {
        
        //set the anchor point to the right position
        [self setAnchorPoint:self.pathCopyAnnotation.pathCopyAnchorPoint
                     forView:self.pathCopy];
    }
}

@end
