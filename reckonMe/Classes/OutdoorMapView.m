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
#import "PeerAnnotation.h"
#import "FloorPlanOverlay.h"
#import "FloorPlanOverlayView.h"
#import "PathCopyAnnotation.h"
#import "GeodeticProjection.h"
#import "UIImage+PDF.h"
#import <QuartzCore/QuartzCore.h>

static NSString *startingPinTitle = @"Starting Position";
static NSString *currentPinTitle = @"Current Estimate";
static NSString *rotationAnchorPinTitle = @"Rotation Anchor";
static NSString *correctingPinSubtitle = @"Feel free to drag me.";
static NSString *currentGPSLocationTitle = @"Current GPS Location";

//path drawing properties
#define kPathStrokeRGBColor 1.0, 0.0, 1.0, 0.8
#define kPathLineCap kCGLineCapRound
#define kPathLineJoin kCGLineJoinRound
#define kPathLineWidth 6.0

@interface OutdoorMapView ()

@property(nonatomic, retain) MKPolyline *pathOverlay;

@property(nonatomic, retain) AbsoluteLocationEntry *rotationCenter;
@property(nonatomic, retain) MKPolyline *rotatableSubPath;
@property(nonatomic, retain) MKPolylineRenderer *rotatableSubPathView;
@property(nonatomic, retain) NSMutableArray *pinsMinusCorrectionPin;

@property(nonatomic, retain) PathCopyAnnotation *pathCopyAnnotation;
@property(nonatomic, retain) MKAnnotationView *pathCopy;
@property(nonatomic, retain) UIImage *pathImageCopy;

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
    
    NSMutableArray *exchangeAnnotations;
    
    BOOL startingPinDragged;
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
        mapView.zoomEnabled = YES;
        mapView.pitchEnabled = NO;
        mapView.rotateEnabled = YES;
        mapView.delegate = self;
        self.pathOverlay = nil;
        [self addSubview:mapView];
        
        exchangeAnnotations = [[NSMutableArray alloc] init];
        
        currentPosition = [[PinAnnotation alloc] init];
        currentPosition.title = startingPinTitle;
        currentPosition.subtitle = correctingPinSubtitle;
        
        startingPosition = [[PinAnnotation alloc] init];
        startingPosition.title = startingPinTitle;
        
        rotationAnchor = [[PinAnnotation alloc] init];
        rotationAnchor.title = rotationAnchorPinTitle;
        rotationAnchor.subtitle = correctingPinSubtitle;
        
        CLLocationCoordinate2D itzCenter = CLLocationCoordinate2DMake(48.565735, 13.450134);
        NSString *itzPath = [[NSBundle mainBundle] pathForResource:@"itz-floorplanRotated.pdf" //or @"itz-grayHalf.png"
                                                            ofType:nil];
        FloorPlanOverlay *itzOverlay = [[FloorPlanOverlay alloc] initWithCenter:itzCenter
                                                                       planPath:itzPath
                                                            scalePixelsPerMeter:8];
        [mapView addOverlay:itzOverlay];
        [itzOverlay release];
        
        //DFKI floor plan overlay
        CLLocationCoordinate2D dfkiCenter = CLLocationCoordinate2DMake(49.429298, 7.7513730);
        NSString *dfkiPath = [[NSBundle mainBundle] pathForResource:@"dfki-2.OG-trimmed.png"
                                                             ofType:nil];
        FloorPlanOverlay *dfkiOverlay = [[FloorPlanOverlay alloc] initWithCenter:dfkiCenter
                                                                        planPath:dfkiPath
                                                             scalePixelsPerMeter:35.1];
        [mapView addOverlay:dfkiOverlay];
        [dfkiOverlay release];
        
        startingPositionFixingMode = NO;
        startingPinDragged = NO;
        
        pathPoints = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    
    [mapView removeFromSuperview];
    [mapView release];
    
    //properties
    self.pathOverlay = nil;
    self.rotationCenter = nil;
    self.rotatableSubPath = nil;
    self.rotatableSubPathView = nil;
    self.pinsMinusCorrectionPin = nil;
    self.pathCopyAnnotation = nil;
    self.pathCopy = nil;
    self.pathCopyAnnotation = nil;
    self.pathImageCopy = nil;
    
    [pathPoints release];
    [currentPosition release];
    [startingPosition release];
    [rotationAnchor release];
    [exchangeAnnotations release];
    
    [super dealloc];
}


- (void)setAutoresizingMask:(UIViewAutoresizing)autoresizingMask {
    
    super.autoresizingMask = autoresizingMask;
    mapView.autoresizingMask = autoresizingMask;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [self.mapViewDelegate userTouchedMap];
}


//MARK: - MapView protocol
-(void)setShowGPSfix:(BOOL)showGPSfix {
    
    mapView.showsUserLocation = showGPSfix;
}

-(BOOL)showGPSfix {
    
    return mapView.showsUserLocation;
}

-(void)setShowSatelliteImages:(BOOL)showSatelliteImages {
    
    mapView.mapType = showSatelliteImages ? MKMapTypeHybrid : MKMapTypeStandard;
}

-(BOOL)showSatelliteImages {
    
    return (mapView.mapType == MKMapTypeHybrid);
}

-(void)updateGPSposition:(AbsoluteLocationEntry *)gpsPosition {
    
    static double lastDeviation = DBL_MAX;
    
    if (    startingPositionFixingMode
        && !startingPinDragged
        && (gpsPosition.deviation <= lastDeviation)) {
        
        lastDeviation = gpsPosition.deviation;
        [self moveCurrentPositionMarkerTo:gpsPosition];
        [self moveMapCenterTo:gpsPosition];
    }
}

-(void)addExchangeWithPeerAtPosition:(AbsoluteLocationEntry *)peerPosition peerName:(NSString *)peerName {
    
    PeerAnnotation *peer = [[PeerAnnotation alloc] initWithPosition:peerPosition
                                                           peerName:peerName];
    [mapView addAnnotation:peer];
    [exchangeAnnotations addObject:peer];
    [peer release];
}

-(void)removeExchanges {
    
    [mapView removeAnnotations:exchangeAnnotations];
    [exchangeAnnotations removeAllObjects];
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
        
        //remove everything but exchanges
        NSMutableSet *annotationsWithoutExchanges = [NSMutableSet setWithArray:mapView.annotations];
        [annotationsWithoutExchanges minusSet:[NSSet setWithArray:exchangeAnnotations]];
        [mapView removeAnnotations:[annotationsWithoutExchanges allObjects]];
        
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
        startingPinDragged = NO;
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

-(void)rotateMapByDegrees:(double)degrees timestamp:(NSTimeInterval)timestamp {
    
    static double lastMapRotationDegrees = 0;
    static double lastMapRotationTimestamp = 0;
    
    if (fabs(lastMapRotationDegrees - degrees) > 0.5) {
        
        lastMapRotationDegrees = degrees;
        lastMapRotationTimestamp = timestamp;
        
        //MKMapView "flickers" for values near North, as it is (un)hiding its small compass symbol
        const double threshold = 7;
        if (degrees > threshold && degrees < 360 - threshold) {
            
            mapView.camera.heading = degrees;
        }
    }
}

//MARK: - path rotation
-(void)startPathRotationModeForSubPath:(NSArray *)subPath aroundPosition:(AbsoluteLocationEntry *)_rotationCenter {
    
    //remove other pins as they might obstruct the path rotation pin 
    [mapView removeAnnotation:startingPosition];
    [mapView removeAnnotation:currentPosition];
    
    //disable zooming
    mapView.zoomEnabled = NO;
    mapView.rotateEnabled = NO;
    
    self.rotationCenter = _rotationCenter;
    
    //create a path overlay of the subPath
    self.rotatableSubPath = [self createPathOverlayFrom:subPath];
    
    if (self.rotatableSubPath) {
        
        //control flow:
        //   createScreenShotOfRotatableSubPath
        //-> [mapView addAnnotation:self.pathCopyAnnotation]
        //-> [mapView viewForAnnotation:self.pathCopyAnnotation]
        [self createScreenShotOfRotatableSubPath];
        
        rotationAnchor.coordinate = _rotationCenter.absolutePosition;
        [mapView addAnnotation:rotationAnchor];
    }
}

-(void)createScreenShotOfRotatableSubPath {
    
    MKMapRect pathBoundingBox = [self.rotatableSubPath boundingMapRect];
    CGRect pathRect = [mapView convertRegion:MKCoordinateRegionForMapRect(pathBoundingBox)
                                toRectToView:mapView];
    //compute the anchor point around which the path is rotated
    CGPoint anchorOnMapView = [mapView convertCoordinate:self.rotationCenter.absolutePosition
                                           toPointToView:mapView];
    CGPoint anchorInPathRect = CGPointMake(anchorOnMapView.x - pathRect.origin.x,
                                           anchorOnMapView.y - pathRect.origin.y);
    
    //Compute the deltas to enlarge a minimal bounding rect-sized canvas by, such that the rotation anchor lies exactly in the middle.
    //It would be easier to use the minimal bounding rect as canvas size and set MKAnnotationView.layer.anchor appropriately, but this broke in iOS>=7.
    CGFloat deltaX = 2 * anchorInPathRect.x - pathRect.size.width;
    CGFloat deltaY = 2 * anchorInPathRect.y - pathRect.size.height;
    
    CGRect canvasRect = CGRectMake(0,
                                   0,
                                   pathRect.size.width  + fabs(deltaX),
                                   pathRect.size.height + fabs(deltaY));
    
    UIGraphicsBeginImageContextWithOptions(canvasRect.size,
                                           NO, //opaque=NO
                                           [UIScreen mainScreen].scale);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //drawing properties
    const CGFloat colorArray[4] = {0.0, 1.0, 0.0, 0.8};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef color = CGColorCreate(colorSpace, colorArray);
    CGColorSpaceRelease(colorSpace);
    CGContextSetStrokeColorWithColor(context, color);
    CGColorRelease(color);
    CGContextSetLineWidth(context, kPathLineWidth);
    CGContextSetLineCap(context, kPathLineCap);
    CGContextSetLineJoin(context, kPathLineJoin);
    
    CGContextBeginPath(context);
    
    MKPolyline *polyline = self.rotatableSubPath;
    CLLocationCoordinate2D coordinates[[polyline pointCount]];
    [polyline getCoordinates:coordinates
                       range:NSMakeRange(0, [polyline pointCount])];
    
    for (int i = 0; i < [polyline pointCount]; i++) {
        
        CGPoint pointOnMapView = [mapView convertCoordinate:coordinates[i]
                                              toPointToView:mapView];
        CGPoint pointOnCanvas = CGPointMake(pointOnMapView.x - pathRect.origin.x - MIN(deltaX, 0),
                                            pointOnMapView.y - pathRect.origin.y - MIN(deltaY, 0));
        if (i == 0) {
            CGContextMoveToPoint(context, pointOnCanvas.x, pointOnCanvas.y);
        } else {
            CGContextAddLineToPoint(context, pointOnCanvas.x, pointOnCanvas.y);
        }
    }
    CGContextStrokePath(context);
    
    self.pathImageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //Create an annotation on the map on the same location as the path view.
    //MKAnnotationView has the advantage of being rotatable by CGAffineTransforms.
    self.pathCopyAnnotation = [[[PathCopyAnnotation alloc] init] autorelease];
    self.pathCopyAnnotation.coordinate = self.rotationCenter.absolutePosition;
    [mapView addAnnotation:self.pathCopyAnnotation];
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
    mapView.rotateEnabled = YES;
}

//MARK: - MKMapViewDelegate protocol
-(MKOverlayRenderer*)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    
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
    
    if ([overlay isKindOfClass:[MKCircle class]]) {
    
        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
//        CGFloat r = 20/255.0;
//        CGFloat g = 204/255.0;
//        CGFloat b = 180/255.0;
        CGFloat r = 255/255.0;
        CGFloat g = 207/255.0;
        CGFloat b = 25/255.0;
        
        UIColor *fillColor = [UIColor colorWithRed:r
                                             green:g
                                              blue:b
                                             alpha:0.3];
        UIColor *strokeColor = [UIColor colorWithRed:r
                                               green:g
                                                blue:b
                                               alpha:0.8];
        circleRenderer.fillColor = fillColor;
        circleRenderer.strokeColor = strokeColor;
        circleRenderer.lineWidth = 1;
        
        return [circleRenderer autorelease];
    }
    
    return nil;
}

-(MKAnnotationView *)mapView:(MKMapView *)_mapView viewForAnnotation:(id<MKAnnotation>)annotation {

    static NSString *currentIdentifier = @"curr";
    static NSString *startingIdentifier = @"start";
    static NSString *pathCopyIdentifier = @"pathCopy";
    static NSString *rotationAnchorIdentifier = @"rotAnchor";
    static NSString *peerIdentifier = @"peer";
    
    MKPinAnnotationView *aView = nil;
    
    if (annotation == mapView.userLocation) {
        
        [(MKUserLocation *)annotation setTitle:currentGPSLocationTitle];
        return [mapView viewForAnnotation:annotation];
    }
    
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
    if ([annotation isKindOfClass:[PeerAnnotation class]]) {
        
        MKAnnotationView *peerView = (MKAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:peerIdentifier];
        
        if (peerView == nil) {
            
            peerView = [[[MKAnnotationView alloc] initWithAnnotation:annotation
                                                     reuseIdentifier:peerIdentifier] autorelease];
            UIImage *pedestrian = [UIImage imageWithPDFNamed:@"pedestrian.pdf"
                                                    atHeight:25];
            
            peerView.image = pedestrian;
            
        }
        peerView.annotation = annotation;
        peerView.canShowCallout = YES;
        peerView.draggable = NO;
        
        return peerView;
    }
    return aView;
}

-(void)pinButtonPressed:(UIButton *)sender {
    
    [self.mapViewDelegate userTappedMoveToGPSbutton];
}

-(void)mapView:(MKMapView *)_mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {

    if (view.annotation == currentPosition) {
        
        startingPinDragged = YES;
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

-(void)mapView:(MKMapView *)_mapView didAddAnnotationViews:(NSArray *)views {
    
    for (MKAnnotationView *annotationView in views) {
        
        if (annotationView.annotation == mapView.userLocation) {
            
            [mapView selectAnnotation:mapView.userLocation
                             animated:YES];
        }
    }
}

-(void)mapView:(MKMapView *)_mapView didSelectAnnotationView:(MKAnnotationView *)view {
    
    if ([view.annotation isKindOfClass:[PeerAnnotation class]]) {
        
        //add the circle
        PeerAnnotation *peerAnnotation = (PeerAnnotation *) view.annotation;
        [mapView addOverlay:peerAnnotation.circleOverlay
                      level:MKOverlayLevelAboveRoads];
        
        //add a drop shadow
        view.layer.shadowColor = [UIColor blackColor].CGColor;
        view.layer.shadowOffset = CGSizeMake(2, -2);
        view.layer.shadowOpacity = 0.7;
        view.layer.shadowRadius = 3.0;
    }
}

-(void)mapView:(MKMapView *)_mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    
    if ([view.annotation isKindOfClass:[PeerAnnotation class]]) {
        
        //remove the circle
        PeerAnnotation *peerAnnotation = (PeerAnnotation *) view.annotation;
        [mapView removeOverlay:peerAnnotation.circleOverlay];
        
        //remove the shadow
        view.layer.shadowOpacity = 0;
    }
}

@end
