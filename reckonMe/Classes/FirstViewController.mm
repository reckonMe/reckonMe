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

#import "FirstViewController.h"
#import "LocationEntry.h"
#import "CompassAndGPS.h"
#import "P2PestimateExchange.h"
#import "Gyroscope.h"
#import "AlertSoundPlayer.h"
#import "MapMarker.h"
#import "OutdoorMapView.h"
#import "CompassViewController.h"
#import "SettingsViewController.h"
#import "Settings.h"

NSString* const PDRStatusChangedNotification = @"PDRStatusChangedNotification";
#define kInitialPathCapacity 2000
#define kStartPDRButtonTitle @"Start Dead-Reckoning"
#define kStartBeaconButtonTitle @"Start Beacon Mode"
#define kStopPDRButtonTitle @"Stop"

typedef enum {
    
    DoNothing,
    WaitingForStartingFix,
    WaitingForHeading,
    Tracking,
    TrackingPaused,
    HeadingCorrectionMode
    
} TrackingVCStatus;

typedef enum {
    
    StartPositionFixingMode,
    
    StartButtonPressed,
    StopButtonPressed,
    
    DetectedInPocket,
    DetectedOutOfPocket,
    
    UserUnlockedScreen,
    UserLockedScreen,
    
    CorrectHeadingAcquired,
    
    StartHeadingCorrectionMode,
    StopHeadingCorrectionMode
    
} TrackingVCEvent;

//MARK: private methods and properties
@interface FirstViewController ()

@property(nonatomic) TrackingVCStatus status;
-(void)didReceiveEvent:(TrackingVCEvent)event;

@property(nonatomic, retain) UIView<MapView> *mapView;

@property(nonatomic, retain) UIToolbar *toolbar;
@property(nonatomic, retain) UIBarButtonItem *toolbarSpacer;
@property(nonatomic, retain) UIBarButtonItem *followPositionButton;
@property(nonatomic, retain) UIBarButtonItem *correctHeadingButton;
@property(nonatomic, retain) UIBarButtonItem *pdrButton;
@property(nonatomic, retain) UIBarButtonItem *settingsButton;

@property(nonatomic, retain) NSArray *toolbarItemsWhenPDRon;
@property(nonatomic, retain) NSArray *toolbarItemsWhenPDRoff;
@property(nonatomic, retain) UIActionSheet *correctHeadingActionSheet, *stopPDRactionSheet, *moveToGPSactionSheet, *moveToGPSdestructiveActionSheet;

@property(nonatomic, retain) AbsoluteLocationEntry *lastPosition;
@property(nonatomic, retain) AbsoluteLocationEntry *correctedPosition;
@property(nonatomic, retain) AbsoluteLocationEntry *lastGPSfix;

@property(nonatomic, retain) NSTimer *pocketDetectorStarter;

@property(nonatomic, retain) CompassViewController *compassView;

-(void)commonInit;

-(void)followPositionButtonPressed:(UIBarButtonItem *)sender;
-(void)correctHeadingButtonPressed:(UIBarButtonItem *)sender;
-(void)pdrButtonPressed:(UIBarButtonItem *)sender;
-(void)lockScreenButtonPressed:(UIBarButtonItem *)sender;
-(void)settingsButtonPressed:(UIBarButtonItem *)settings;
-(void)preferencesChanged:(NSNotification *)notification;
-(void)updateStartButton;

-(void)startPDR;
-(void)stopPDR;

-(void)startSensors;
-(void)pauseSensors;

-(void)startPocketDetectorDelayed:(BOOL)delayed;
-(void)stopPocketDetector;

-(void)startFollowPositionMode;
-(void)stopFollowPositionMode;

-(void)stopHeadingCorrectionMode;
-(BOOL)startHeadingCorrectionMode;

-(void)startStartingPositionFixingMode;
-(void)stopStartingPositionFixingMode;

-(void)startWaitingForHeading;
-(void)stopWaitingForHeading;

-(void)correctPositionTo:(AbsoluteLocationEntry *)correctTo;
-(void)lockScreen;

-(void)releaseSubviews;

@end

//MARK: -
@implementation FirstViewController

@synthesize status;

@synthesize mapView;  
@synthesize toolbar;
@synthesize followPositionButton;
@synthesize correctHeadingButton;
@synthesize pdrButton;
@synthesize settingsButton;
@synthesize toolbarSpacer;
@synthesize toolbarItemsWhenPDRon, toolbarItemsWhenPDRoff;
@synthesize correctHeadingActionSheet, stopPDRactionSheet, moveToGPSactionSheet, moveToGPSdestructiveActionSheet;
@synthesize compassView;

//the last position obtained by PDR computation
@synthesize lastPosition;
//the last position manually corrected by the user
@synthesize correctedPosition;
//the last GPS fix
@synthesize lastGPSfix;
@synthesize pocketDetectorStarter;

@synthesize pdrOn;

//MARK: -
-(id)initWithCoder:(NSCoder *)aDecoder {
    
    if (self = [super initWithCoder:aDecoder]) {
        
        [self commonInit];
    }
    return self;
}

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        
        [self commonInit];
    }
    return self;
}

-(id)init {
    
    if (self = [super init]) {
        
        [self commonInit];
    }
    return self;
}

-(void)commonInit {
    
    mapFollowsPosition = NO;
    pdrOn = NO;
    
    path = [[NSMutableArray alloc] initWithCapacity:kInitialPathCapacity];
    
    CLLocationCoordinate2D passau = CLLocationCoordinate2DMake(48.565720, 13.450176);
    AbsoluteLocationEntry *passauLocation = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                                eastingDelta:0
                                                                               northingDelta:0
                                                                                      origin:passau
                                                                                   Deviation:1];
    [self.mapView moveMapCenterTo:passauLocation];
    
    self.lastPosition = [passauLocation autorelease];
    self.correctedPosition = self.lastPosition;
    
    fileWriter = [[FileWriter alloc] init];
    pdr = [PDRController sharedInstance];
    pdr.view = self;
    pdr.logger = fileWriter;
    
    pocketDetector = [[PantsPocketDetector alloc] init];
    pocketDetector.delegate = self;
    
    [Gyroscope sharedInstance].frequency = 50;
    
    [[Gyroscope sharedInstance] addListener:fileWriter];
    [[CompassAndGPS sharedInstance] addListener:fileWriter];
    [[CompassAndGPS sharedInstance] addListener:(id<SensorListener>) self];
    
    [P2PestimateExchange sharedInstance].delegate = pdr;
    
    self.compassView = nil;
    
    self.status = DoNothing;
}

-(void)dealloc {

    [self didReceiveEvent:StopButtonPressed];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [pdr release];
    [fileWriter release];
    [pocketDetector release];
    
    [self releaseSubviews];
    
    [path release];
    self.lastGPSfix = self.lastPosition = self.correctedPosition = nil;
    
    [[CompassAndGPS sharedInstance] removeListener:(id<SensorListener>) self];
    
    [super dealloc];
}

//MARK: - view lifecycle
-(void)loadView {
       
    CGRect fullscreen = [[UIScreen mainScreen] applicationFrame];
    CGFloat toolbarHeight = 44;
    
    UIView *compositeView = [[UIView alloc] initWithFrame:fullscreen];
    compositeView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    self.view = [compositeView autorelease];
    
    CGRect mapViewFrame = CGRectMake(self.view.bounds.origin.x,
                                     self.view.bounds.origin.y,
                                     self.view.bounds.size.width,
                                     self.view.bounds.size.height - toolbarHeight);

    //"itz-floorplan.pdf" scale:8.09
    //itz-floorplan.png scale:36.63

    //KL_Hauptgebaeude_EG-rotated scale:615 pixel / 28(?)m = 21.96
    /*NSString *mapPath = [[NSBundle mainBundle] pathForResource:@"itz-floorplan1bit.tiff"
                                                       ofType:nil];
    
    self.mapView = [[[MapScrollView alloc] initWithFrame:mapViewFrame
                                             mapFilePath:mapPath
                                                mapScale:36.63//pixels per meter (measured with inkscape)
                     ] autorelease];
    */
    
    self.mapView = [[[OutdoorMapView alloc] initWithFrame:mapViewFrame] autorelease];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.mapView.mapViewDelegate = self;
    
    //create the toolbar and its buttons
    self.toolbar = [[[UIToolbar alloc] initWithFrame:CGRectMake(self.view.bounds.origin.x,
                                                                self.view.bounds.size.height - toolbarHeight,
                                                                self.view.bounds.size.width,
                                                                toolbarHeight)] autorelease];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    
    self.followPositionButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gps-arrow.png"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(followPositionButtonPressed:)] autorelease];
    self.followPositionButton.style = mapFollowsPosition ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
    
    self.toolbarSpacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil 
                                                                            action:nil] autorelease];
    
    self.correctHeadingButton = [[[UIBarButtonItem alloc] initWithTitle:@"Correct Heading"
                                                                        style:UIBarButtonItemStyleBordered
                                                                       target:self 
                                                                       action:@selector(correctHeadingButtonPressed:)] autorelease];
    self.correctHeadingButton.style = UIBarButtonItemStyleBordered;
    //we end position correction mode when the view unloads, hence we don't need to set the buttons status here

    
    self.pdrButton = [[[UIBarButtonItem alloc] initWithTitle:kStartPDRButtonTitle
                                                                  style:UIBarButtonItemStyleBordered
                                                                 target:self
                                                                 action:@selector(pdrButtonPressed:)] autorelease];
    self.pdrButton.title = pdrOn ? kStopPDRButtonTitle : kStartPDRButtonTitle;
    self.pdrButton.style = pdrOn ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
    
    self.settingsButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPageCurl
                                                                         target:self
                                                                         action:@selector(settingsButtonPressed:)] autorelease];
    
    self.toolbarItemsWhenPDRon = [NSArray arrayWithObjects:
                                  self.followPositionButton,
                                  self.toolbarSpacer,
                                  self.correctHeadingButton,
                                  self.toolbarSpacer,
                                  self.pdrButton,
                                  nil];
    
    self.toolbarItemsWhenPDRoff = [NSArray arrayWithObjects:
                                   self.followPositionButton,
                                   self.toolbarSpacer,
                                   self.pdrButton,
                                   self.toolbarSpacer,
                                   self.settingsButton,
                                   nil];
    
    self.toolbar.items = pdrOn ? self.toolbarItemsWhenPDRon : self.toolbarItemsWhenPDRoff;
    
    //create the UIActionSheets
    self.correctHeadingActionSheet =  [[[UIActionSheet alloc] initWithTitle:nil
                                                                    delegate:self
                                                           cancelButtonTitle:@"Cancel"
                                                      destructiveButtonTitle:@"Correct Heading"
                                                           otherButtonTitles:nil] autorelease];
    
    self.stopPDRactionSheet =  [[[UIActionSheet alloc] initWithTitle:nil
                                                            delegate:self
                                                   cancelButtonTitle:@"Cancel"
                                              destructiveButtonTitle:@"Stop Dead-Reckoning"
                                                   otherButtonTitles:nil] autorelease];
    
    NSString* const moveToGPStitle = @"Move to GPS Position";
    self.moveToGPSactionSheet = [[[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:moveToGPStitle, nil] autorelease];
    
    self.moveToGPSdestructiveActionSheet = [[[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:moveToGPStitle
                                                    otherButtonTitles:nil] autorelease];
    
    //assemble the view
    [self.view addSubview:self.mapView];
    [self.view addSubview:self.toolbar];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.mapView moveMapCenterTo:self.lastPosition];
    
    if (pdrOn) {
        
        //reconstruct the path
        for (AbsoluteLocationEntry *location in path) {
            
            [self.mapView addPathLineTo:location];
        }
        
        [self.mapView moveCurrentPositionMarkerTo:self.lastPosition];
    }
    
    [self didReceiveEvent:StartPositionFixingMode];
    
    //make the starting pin move to GPS location
    if (self.status == WaitingForStartingFix) {
        
        [self startFollowPositionMode];
    }
}

- (void)updateStartButton {
   
    if (pdrOn) {
        
        self.pdrButton.title = kStopPDRButtonTitle;
        
    } else {
        
        if ([Settings sharedInstance].beaconMode) {
            
            self.pdrButton.title = kStartBeaconButtonTitle;
            
        } else {
            
            self.pdrButton.title = kStartPDRButtonTitle;
        }
    }
}

- (void)preferencesChanged:(NSNotification *)notification {
    
    [self updateStartButton];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    //make the status bar appear normal again when returning from a modalViewController
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault 
                                                animated:animated];
    
    [self updateStartButton];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    if (mapFollowsPosition && pdrOn) {
        
        //the scrolling only takes place when mapView is on screen
        [self.mapView moveMapCenterTo:lastPosition];
    }
    
    //listen for changes in preferences.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferencesChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    //end position correction mode when the view unloads
    [self didReceiveEvent:StopHeadingCorrectionMode];
    
    [self releaseSubviews];
}

-(void)releaseSubviews {
    
    self.mapView = nil;
    
    self.toolbar = nil;
    self.toolbarSpacer = nil;
    self.followPositionButton = nil;
    self.correctHeadingButton = nil;
    self.pdrButton = nil;
    self.settingsButton = nil;
    
    self.toolbarItemsWhenPDRoff = nil;
    self.toolbarItemsWhenPDRon = nil;
    
    self.stopPDRactionSheet = nil;
    self.correctHeadingActionSheet = nil;
    self.moveToGPSactionSheet = nil;
    self.moveToGPSdestructiveActionSheet = nil;
    
    self.compassView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//MARK: - session logic
-(void)didReceiveEvent:(TrackingVCEvent)event {
    
    //lock the status as calls might come from several threads
    @synchronized(self) {
        
        switch (event) {
                
            case StartPositionFixingMode:
                
                if (self.status == DoNothing) {
                    
                    [self startStartingPositionFixingMode];
                    self.status = WaitingForStartingFix;
                }
                break;
                
            case StartButtonPressed:
                
                if (self.status == WaitingForStartingFix) {
                    
                    [self stopStartingPositionFixingMode];
                    self.status = WaitingForHeading;
                    
                    if ([Settings sharedInstance].beaconMode) {
                        
                        //skip the waiting-for-heading screen
                        [self didReceiveEvent:CorrectHeadingAcquired];
                        [self didReceiveEvent:UserLockedScreen];
                        
                    } else {
                        
                        [self startWaitingForHeading];
                    }
                }
                break;
                
            case StopButtonPressed:
                
                switch (self.status) {

                    case WaitingForHeading:
                        [self stopWaitingForHeading];
                        break;
                    case HeadingCorrectionMode:
                        [self stopHeadingCorrectionMode];
                        break;
                    default:
                        break;
                }
                [self stopPocketDetector];
                [self stopPDR];
                self.status = DoNothing;
                
                //return to default state
                [self didReceiveEvent:StartPositionFixingMode];
                break;
                
            case CorrectHeadingAcquired:
                
                if (self.status == WaitingForHeading) {
                    
                    [self stopWaitingForHeading];
                    [self startPDR];
                    [self startPocketDetectorDelayed:NO];
                    self.status = TrackingPaused;
                }
                break;
                
            case DetectedInPocket:
            case UserLockedScreen:
                
                if (self.status == TrackingPaused) {
                    
                    [self stopPocketDetector];
                    [self startSensors];
                    [self lockScreen];
                    self.status = Tracking;
                }
                break;
                
            case DetectedOutOfPocket:
            case UserUnlockedScreen:
                
                if (self.status == Tracking) {
                    
                    [self pauseSensors];
                    [self startPocketDetectorDelayed:YES];
                    self.status = TrackingPaused;
                }
                break;
                
            case StartHeadingCorrectionMode:
                
                if (self.status == TrackingPaused) {
                        
                    if ([self startHeadingCorrectionMode]){
                        
                        [self stopPocketDetector];
                        self.status = HeadingCorrectionMode;
                    }
                }
                break;
                
            case StopHeadingCorrectionMode:
                
                if (self.status == HeadingCorrectionMode) {
                    
                    [self stopHeadingCorrectionMode];
                    [self startPocketDetectorDelayed:YES];
                    self.status = TrackingPaused;
                }
                break;

            default:
                break;
        }
    }
}

//MARK: session management
-(void)startSensors {
    
    /* this method may be invoked from a thread other than the main thread,
     * as a precaution we schedule potentially thread-unsafe methods on the main thread
     */
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [[Gyroscope sharedInstance] addListener:pdr];
        
        [AlertSoundPlayer.sharedInstance playSound:startingSound 
                                         vibrating:YES];
        [[SecondViewController sharedInstance] addToLog:@"Starting sensors."];
        
    });
}

-(void)pauseSensors {
    
    /* this method may be invoked from a thread other than the main thread,
     * as a precaution we schedule potentially thread-unsafe methods on the main thread
     */
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        //remove the pdr as a listener, but continue
        [[Gyroscope sharedInstance] removeListener:pdr];
        [[CompassAndGPS sharedInstance] removeListener:pdr];
        
        [AlertSoundPlayer.sharedInstance playSound:pausingSound
                                         vibrating:YES];
        
        [[SecondViewController sharedInstance] addToLog:@"Pausing sensors."];
    });
}

-(void)startPocketDetectorDelayed:(BOOL)delayed {
    
    if (delayed) {
        
        self.pocketDetectorStarter = [NSTimer scheduledTimerWithTimeInterval:5
                                                                      target:pocketDetector
                                                                    selector:@selector(start)
                                                                    userInfo:nil
                                                                     repeats:NO];
    } else {
        
        [pocketDetector start];
    }
}

-(void)stopPocketDetector {
    
    if (self.pocketDetectorStarter) {
        
        [self.pocketDetectorStarter invalidate];
        self.pocketDetectorStarter = nil;
    }
    [pocketDetector stop];
}

-(void)startFollowPositionMode {
    
    if (!mapFollowsPosition) {
        
        self.mapView.showGPSfix = YES;
        
        self.followPositionButton.style = UIBarButtonItemStyleDone;//blue
        
        mapFollowsPosition = YES;
    }
}

-(void)stopFollowPositionMode {
    
    if (mapFollowsPosition) {
        
        self.mapView.showGPSfix = NO;
        self.followPositionButton.style = UIBarButtonItemStyleBordered;//"normal"
        
        mapFollowsPosition = NO;
    }
}

-(void)startStartingPositionFixingMode {

    [[CompassAndGPS sharedInstance] startGPS];
    
    [self.mapView startStartingPositionFixingMode];
}

-(void)stopStartingPositionFixingMode {
    
    [[CompassAndGPS sharedInstance] stopGPS];
    
    [self.mapView stopStartingPositionFixingMode];
}

-(void)startWaitingForHeading {
    
    if (!self.compassView) {
        
        self.compassView = [[[CompassViewController alloc] initWithNibName:nil
                                                                    bundle:nil] autorelease];
        self.compassView.delegate = self;
        self.compassView.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    
    [self presentModalViewController:self.compassView
                            animated:YES];
    
    [[CompassAndGPS sharedInstance] startCompass];
}

-(void)stopWaitingForHeading {
    
    [self dismissModalViewControllerAnimated:YES];
    
    [[CompassAndGPS sharedInstance] stopCompass];
}

-(BOOL)startHeadingCorrectionMode {
    
    NSMutableArray *newRotatablePath = [pdr partOfPathToBeManuallyRotatedWithPinLocation:nil];
    
    if ([newRotatablePath count] > 1) {
        
        [self.mapView startPathRotationModeForSubPath:newRotatablePath
                                       aroundPosition:[newRotatablePath objectAtIndex:0]];
        
        [[Gyroscope sharedInstance] addListener:(id<SensorListener>) self];
        [[Gyroscope sharedInstance] start];
        
        yawOffset = 0;
        lastYaw = 0;
        
        self.correctHeadingButton.style = UIBarButtonItemStyleDone;//make button blue
        
        return YES;
    
    } else {
        
        return NO;
    }
}

-(void)stopHeadingCorrectionMode {
    
    [[Gyroscope sharedInstance] removeListener:(id<SensorListener>) self];
    
    [mapView stopPathRotationMode];
    
    self.correctHeadingButton.style = UIBarButtonItemStyleBordered;//make button look normal again
}

-(void)lockScreen {
    
    [SecondViewController sharedInstance].delegate = self;
    [SecondViewController sharedInstance].modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentModalViewController:[SecondViewController sharedInstance]
                            animated:NO];
}


//MARK: - responding to buttons
-(void)followPositionButtonPressed:(UIBarButtonItem *)sender {
    
    if (mapFollowsPosition) {
        
        [self stopFollowPositionMode];
    
    } else {
        
        [self startFollowPositionMode];
    }
}

-(void)correctHeadingButtonPressed:(UIBarButtonItem *)sender {
    
    if (self.status != HeadingCorrectionMode) {
        
        [self didReceiveEvent:StartHeadingCorrectionMode];
        
    } else {//stop

        [self.correctHeadingActionSheet showFromToolbar:self.toolbar];        
        //removing the marker and notifying PDR of the new position takes place in actionSheet:clickedButtonAtIndex:
    }
}

-(void)pdrButtonPressed:(UIBarButtonItem *)sender {
    
    if (!pdrOn) {
        
        [self didReceiveEvent:StartButtonPressed];
    
    } else {
        
        //ask for confirmation, actually stopping takes place in actionSheet:clickedButtonAtIndex: 
        [self.stopPDRactionSheet showFromToolbar:self.toolbar];  
    }
}

-(void)settingsButtonPressed:(UIBarButtonItem *)settings {
    
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithNibName:nil
                                                                                  bundle:nil];
    
    settingsVC.modalTransitionStyle = UIModalTransitionStylePartialCurl;
    
    [self presentModalViewController:settingsVC
                            animated:YES];
    [settingsVC release];
}

//MARK: - MapViewDelegate
-(void)userCorrectedPositionTo:(AbsoluteLocationEntry *)newCorrectedPosition onMapView:(id<MapView>)view {
    
    self.correctedPosition = newCorrectedPosition;
    self.correctedPosition.timestamp = [[NSDate date] timeIntervalSince1970];
    
    [self correctPositionTo:self.correctedPosition];
}

-(void)userTappedMoveToGPSbutton {
    
    if (pdrOn) {
        
        [self.moveToGPSdestructiveActionSheet showFromToolbar:self.toolbar];
    
    } else {
        
        [self.moveToGPSactionSheet showFromToolbar:self.toolbar];
    }
}

-(void)userMovedRotationAnchorTo:(AbsoluteLocationEntry *)rotationAnchor {
    
    if (self.status == HeadingCorrectionMode) {
        
        NSMutableArray *newRotatablePath = [pdr partOfPathToBeManuallyRotatedWithPinLocation:rotationAnchor];
        
        if ([newRotatablePath count] > 0) {
            
            [self.mapView startPathRotationModeForSubPath:newRotatablePath
                                           aroundPosition:[newRotatablePath objectAtIndex:0]];
        }
    }
}

//MARK: -
-(void)correctPositionTo:(AbsoluteLocationEntry *)correctTo {
    
    if (self.status == WaitingForStartingFix) {
        
        [self.mapView moveMapCenterTo:correctTo];
        
    } else {
        
        if ([Settings sharedInstance].beaconMode) {
            
            [P2PestimateExchange sharedInstance].beaconPosition = correctTo;
        
        } else {
            
            [pdr didReceiveManualPostionCorrection:correctTo];
        }
    }
}

//MARK: - ActionSheetDelegate
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    
    if (actionSheet == self.correctHeadingActionSheet) {
        
        if (buttonIndex == actionSheet.destructiveButtonIndex) {//for us, the destructive action actually is a confirmation
            
            //throw away the path as it is redrawn
            [self.mapView clearPath];
            [pdr rotatePathBy:-lastYaw];
        }
        
        [self didReceiveEvent:StopHeadingCorrectionMode];
    }
    
    
    if (actionSheet == self.stopPDRactionSheet) {
        
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            
            [self didReceiveEvent:StopButtonPressed];        
        }
    }
    
    if (actionSheet == self.moveToGPSactionSheet || actionSheet == self.moveToGPSdestructiveActionSheet) {
        
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            
            [self correctPositionTo:self.lastGPSfix];
        }
    }
}

-(void)lockScreenButtonPressed:(UIBarButtonItem *)sender {
    
    [self didReceiveEvent:UserLockedScreen];
}


//MARK: - PantsPocketStatusDelegate (switching all other sensors on and off)
-(void)devicesPocketStatusChanged:(BOOL)isInPocket {
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        if (isInPocket) {
            
            [self didReceiveEvent:DetectedInPocket];
            
        } else {
            
            [self didReceiveEvent:DetectedOutOfPocket];
        }
    });
}

//MARK: - lock screen delegate
-(void)userUnlockedScreen {

    [self dismissModalViewControllerAnimated:YES];

    [self didReceiveEvent:UserUnlockedScreen];
}

//MARK: - CompassViewDelegate
-(void)compassPointingNorthwards {
    
    [self didReceiveEvent:CorrectHeadingAcquired];
}

-(void)userAbortedWaitingForHeading {
    
    [self didReceiveEvent:StopButtonPressed];
}

//MARK: - PDR
-(void)startPDR {
    
    [self startPDR:NO];
}

-(void)testPDR {
    
    [self startPDR:YES];
}

-(void)startPDR:(BOOL)testing {
    
    if (!pdrOn) {
        
        self.pdrButton.style = UIBarButtonItemStyleDone;//blue
        self.pdrButton.title = kStopPDRButtonTitle;
        
        //turn auto-lock off
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        
        //update the view
        [self.toolbar setItems:self.toolbarItemsWhenPDRon animated:YES];
        [self.mapView clearPath];
        [[SecondViewController sharedInstance] clearLog];
        
        [self.mapView stopStartingPositionFixingMode];
        [fileWriter startRecording];
        
        //todo: clean up this whole mess!
        if (testing) {
            
            self.correctedPosition = self.lastPosition;

        } else {
            
            if ([Settings sharedInstance].beaconMode) {
                
                [[P2PestimateExchange sharedInstance] startBeaconModeAtPosition:self.correctedPosition];
                
            } else {
                
                //start the sensors
                [[Gyroscope sharedInstance] start];
                [[CompassAndGPS sharedInstance] start];
                
                [[P2PestimateExchange sharedInstance] startWalkerModeOnChannel:[Settings sharedInstance].audioChannel];
            }
        }
        
        //determine the starting point and start PDR
        self.lastPosition = self.correctedPosition;
        [self.mapView setStartingPosition:self.lastPosition];

        [pdr startPDRsessionWithGPSfix:self.lastPosition];
        [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Starting PDR at x=%.0fm y=%.0fm", 
                                                  lastPosition.easting,
                                                  lastPosition.northing]];
        
        NSNotification *notification = [NSNotification notificationWithName:PDRStatusChangedNotification
                                                                     object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:notification 
                                                   postingStyle:NSPostWhenIdle];
        
        //<debug>
        /*dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            AbsoluteLocationEntry *p1 = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                            eastingDelta:10
                                                                           northingDelta:10
                                                                                  origin:self.lastPosition.absolutePosition
                                                                               Deviation:0];
            AbsoluteLocationEntry *p2 = [[AbsoluteLocationEntry alloc] initWithTimestamp:0
                                                                            eastingDelta:20
                                                                           northingDelta:0
                                                                                  origin:self.lastPosition.absolutePosition
                                                                               Deviation:0];
            [self didReceivePosition:[p1 autorelease]];
            [self didReceivePosition:[p2 autorelease]];
         });*/
        
        //</debug>
    }
    
    pdrOn = YES;
}


-(void)stopPDR {
    
    if (pdrOn) {
        
        pdrOn = NO;
        
        self.pdrButton.style = UIBarButtonItemStyleBordered;//normal
        self.pdrButton.title = kStartPDRButtonTitle;
        
        [[Gyroscope sharedInstance] stop];
        [[CompassAndGPS sharedInstance] stop];
        
        [[P2PestimateExchange sharedInstance] stop];
        
        [pdr stopPDRsession];
        
        [fileWriter stopRecording];
        
        //update the toolbar items
        [self.toolbar setItems:self.toolbarItemsWhenPDRoff animated:YES];
            
        [path removeAllObjects];
        
        NSNotification *notification = [NSNotification notificationWithName:PDRStatusChangedNotification
                                                                     object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:notification 
                                                   postingStyle:NSPostWhenIdle];
        
        //allow auto-lock again
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    }
}

-(void)didReceiveCompassValueWithMagneticHeading:(double)magneticHeading trueHeading:(double)trueHeading headingAccuracy:(double)headingAccuracy X:(double)x Y:(double)y Z:(double)z timestamp:(NSTimeInterval)timestamp label:(int)label {
    
    if (self.status == WaitingForHeading) {
        
#warning dirty workaround
        //hard-code the offset for Passau to circumvent situations where the true heading is not available (== -1) and waiting would take forever
        double trueHeadingForPassau = magneticHeading + 2.871399;
        [self.compassView didReceiveCompassValueWithTrueHeading:(trueHeadingForPassau < 360) ? trueHeadingForPassau : trueHeadingForPassau - 360
                                                headingAccuracy:headingAccuracy
                                                      timestamp:timestamp];
    }
}

-(void)didReceiveGPSvalueWithLongitude:(double)longitude latitude:(double)latitude altitude:(double)altitude speed:(double)speed course:(double)course horizontalAccuracy:(double)horizontalAccuracy verticalAccuracy:(double)verticalAccuracy timestamp:(NSTimeInterval)timestamp label:(int)label {
    
    CLLocationCoordinate2D gpsLocation = CLLocationCoordinate2DMake(latitude, longitude);
    AbsoluteLocationEntry *currentLocation = [[AbsoluteLocationEntry alloc] initWithTimestamp:timestamp
                                                                                 eastingDelta:0
                                                                                northingDelta:0
                                                                                       origin:gpsLocation
                                                                                    Deviation:1];
    
    //first GPS fix?
    if (!self.lastGPSfix) {
        
        [self.mapView moveMapCenterTo:currentLocation];
    }
    
    self.lastGPSfix = currentLocation;
    [currentLocation release];
}

-(void)didReceiveDeviceMotion:(CMDeviceMotion *)motion timestamp:(NSTimeInterval)timestamp {
    
    if (self.status == HeadingCorrectionMode){
        
        if (yawOffset == 0) {
            
            yawOffset = motion.attitude.yaw;
        }
        lastYaw = motion.attitude.yaw - yawOffset;
        
        [self.mapView rotatePathViewBy:lastYaw];
    }
}

- (void)didReceivePosition:(AbsoluteLocationEntry *)position {
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        /*NSString *logString = [NSString stringWithFormat:@"x=%.0fm y=%.0fm d=%.0f",
                               position.eastingDelta, position.northingDelta, position.deviation];
        [[SecondViewController sharedInstance] addToLog:logString];*/
        
        self.lastPosition = position;
        
        //update path
        [path addObject:position];
        [mapView addPathLineTo:position];
        
        self.correctHeadingButton.enabled = [path count] >= 2;
        
        if (mapFollowsPosition) {
            
            [mapView moveMapCenterTo:position];
        }
        
        [self.mapView moveCurrentPositionMarkerTo:position];
    });
}

- (void)didReceiveCompletePath:(NSArray *)newPath {
    
    [path setArray:newPath];
    [self.mapView replacePathBy:newPath];
    [self.mapView moveCurrentPositionMarkerTo:[newPath lastObject]];
        
    self.correctHeadingButton.enabled = [newPath count] >= 2;

}

@end
