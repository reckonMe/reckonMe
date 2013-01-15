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

#import "FileWriter.h"
#import "Gyroscope.h"
#import "P2PestimateExchange.h"
#import "Settings.h"
#import <QuartzCore/QuartzCore.h>

NSString* const kAccelerometerFileAppendix = @"_Accel";
NSString* const kGyroscopeFileAppendix = @"_Gyro";
NSString* const kCompassFileAppendix = @"_Comp";
NSString* const kGpsFileAppendix = @"_GPS";


NSString *const kPdrPositionFileAppendix = @"_PdrTrace";
NSString *const kPdrManualPositionCorrectionFileAppendix = @"_PdrManualCorrection";
NSString *const kPdrManualHeadingCorrectionFileAppendix = @"_PdrManualHeadingCorrection";
NSString *const kPdrCollaborativePositionCorrectionUpdateFileAppendix = @"_PdrCollaborativeCorrection";
NSString *const kPdrConnectionQueryFileAppendix = @"_PdrConnectionQuerys";
NSString *const kPdrCompleteCollaborativeTracesFileAppendixFormat = @"_PdrCollaborativeTrace_%d";

//anonymous category extending the class with "private" methods
//MARK: private methods
@interface FileWriter ()

@property(nonatomic, retain) NSString *currentRecordingDirectory;
@property(nonatomic, retain) NSString *accelerometerFileName;
@property(nonatomic, retain) NSString *gpsFileName;
@property(nonatomic, retain) NSString *gyroFileName;
@property(nonatomic, retain) NSString *compassFileName;
@property(nonatomic, retain) NSString *pdrPositionFileName, 
*pdrCollaborativeTraceFileName, 
*pdrManualPositionCorrectionFileName,
*pdrManualHeadingCorrectionFileName,
*pdrCollaborativePositionCorrectionUpdateFileName, 
*pdrConnectionQueryFileName;

-(NSString *)setupTextFile:(FILE **)file withBaseFileName:(NSString *)baseFileName appendix:(NSString *)appendix dataDescription:(NSString *) description subtitle:(NSString *) subtitle columnDescriptions:(NSArray *)columnDescriptions;

- (void)initAccelerometerFile:(NSString*)name;
- (void)initGpsFile:(NSString*)name;
- (void)initGyroFile:(NSString*)name;
- (void)initCompassFile:(NSString*)name;

- (void)initPdrPositionFile:(NSString *)name;
- (void)initPdrCollaborativeTraceFile:(NSString *)name;
- (void)initPdrManualPositionCorrectionFile:(NSString *)name;
- (void)initPdrManualHeadingCorrectionFile:(NSString *)name;
- (void)initPdrCollaborativePositionCorrectionUpdateFile:(NSString *)name;
- (void)initPdrConnectionQueryFile:(NSString *)name;

@end


@implementation FileWriter

@synthesize isRecording;

@synthesize currentFilePrefix, currentRecordingDirectory;
@synthesize accelerometerFileName;
@synthesize gpsFileName;
@synthesize gyroFileName;
@synthesize compassFileName;

@synthesize pdrPositionFileName, 
pdrCollaborativeTraceFileName, 
pdrManualPositionCorrectionFileName,
pdrManualHeadingCorrectionFileName,
pdrCollaborativePositionCorrectionUpdateFileName, 
pdrConnectionQueryFileName;

#pragma mark -
#pragma mark initialization methods
-(id)init {
    
    self = [super init];
    
    if (self != nil) {
        
        //The alloc-inited NSFileManager is thread-safe in contrast to the singleton (see documentation)
        fileManager = [[NSFileManager alloc] init];
    }
    
    return self;
}

-(void)dealloc {
    
    [self stopRecording];
    
    //release by setting to nil with the synthesized (retain)-setter
    self.currentFilePrefix = nil;
    self.accelerometerFileName = nil;
    self.gpsFileName = nil;
    self.gyroFileName = nil;
    self.compassFileName = nil;
    
    self.pdrPositionFileName = nil;
    self.pdrCollaborativeTraceFileName = nil; 
    self.pdrManualPositionCorrectionFileName = nil;
    self.pdrManualHeadingCorrectionFileName = nil;
    
    self.pdrCollaborativePositionCorrectionUpdateFileName = nil; 
    self.pdrConnectionQueryFileName = nil;
    
    [fileManager release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark recording methods

-(void)startRecording {
    
    if (!isRecording) {
        
        //use the current date and time as a basis for the filename and directory
        NSDate *now = [NSDate date];
        
        //remove colons (which are represented as slashes in HFS+ and vice versa) from the directory name, as they might be interpreted as actual directory seperators
        self.currentFilePrefix = [[now description] stringByReplacingOccurrencesOfString:@":" withString:@"."];
        
        //create a directory for the recordings and the file name
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [paths lastObject];
        //we're also using the file prefix as the name for our new directory
        self.currentRecordingDirectory = [documentDirectory stringByAppendingPathComponent:self.currentFilePrefix];
        [fileManager createDirectoryAtPath:self.currentRecordingDirectory withIntermediateDirectories:NO attributes:nil error:NULL];
        
        //init the files (and their filenames)
        [self initAccelerometerFile:self.currentFilePrefix];
        [self initGyroFile:self.currentFilePrefix];
        [self initGpsFile:self.currentFilePrefix];
        [self initCompassFile:self.currentFilePrefix];
        
        [self initPdrPositionFile:self.currentFilePrefix];
        [self initPdrCollaborativeTraceFile:self.currentFilePrefix];
        [self initPdrManualPositionCorrectionFile:self.currentFilePrefix];
        [self initPdrManualHeadingCorrectionFile:self.currentFilePrefix];
        [self initPdrCollaborativePositionCorrectionUpdateFile:self.currentFilePrefix];
        [self initPdrConnectionQueryFile:self.currentFilePrefix];
        
        //used to determine whether the respective file has been written to
        usedAccelerometer = NO;
        usedGyro = NO;
        usedGPS = NO;
        usedCompass = NO;
        
        isRecording = YES;
    }
}

-(void)saveScreenshot {
    
    // Create a graphics context with the target size
    CGSize imageSize = [[UIScreen mainScreen] bounds].size;
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen])
        {
            // -renderInContext: renders in the coordinate space of the layer,
            // so we must first apply the layer's geometry to the graphics context
            CGContextSaveGState(context);
            // Center the context around the window's anchor point
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            // Apply the window's transform about the anchor point
            CGContextConcatCTM(context, [window transform]);
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context,
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);
            
            // Render the layer hierarchy to the current context
            [[window layer] renderInContext:context];
            
            // Restore the context
            CGContextRestoreGState(context);
        }
    }
    
    // Retrieve the screenshot image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //defer the saving to unlock the current thread ASAP
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        NSData *data = UIImagePNGRepresentation(image);
        [data writeToFile:[self.currentRecordingDirectory stringByAppendingPathComponent:@"screenshot.png"]
               atomically:NO];
    });
}

-(void)stopRecording {
    
    if (isRecording) {
        
        isRecording = NO;
        
        //close all open files
        fclose(accelerometerFile);
        fclose(gyroFile);
        fclose(gpsFile);
        fclose(compassFile);
        
        fclose(pdrPositionFile);
        fclose(pdrCollaborativeTraceFile);
        fclose(pdrManualPositionCorrectionFile);
        fclose(pdrManualHeadingCorrectionFile);
        fclose(pdrCollaborativePositionCorrectionUpdateFile);
        fclose(pdrConnectionQueryFile);
        
        //check for usage of files and delete them if unused
        //no check if label file has been used, it is always kept
        if (!usedAccelerometer) [fileManager removeItemAtPath:self.accelerometerFileName error:NULL];
        if (!usedGyro) {
            
            [fileManager removeItemAtPath:self.gyroFileName error:NULL];
        }
        if (!usedCompass) [fileManager removeItemAtPath:self.compassFileName error:NULL];
        if (!usedGPS) [fileManager removeItemAtPath:self.gpsFileName error:NULL];
        
        //always keep the pdr files
    }
}


#pragma mark -
#pragma mark file initialization methods

//creates "file", returns its "filename" and writes a header to the file containing the information provided in the arguments
-(NSString *)setupTextFile:(FILE **)file withBaseFileName:(NSString *)baseFileName appendix:(NSString *)appendix dataDescription:(NSString *) description subtitle:(NSString *) subtitle columnDescriptions:(NSArray *)columnDescriptions {
    
    
    NSString *fileName = [[baseFileName stringByAppendingString:appendix] stringByAppendingPathExtension:@"txt"];
	NSString *completeFilePath = [currentRecordingDirectory stringByAppendingPathComponent:fileName];
	
	// create the file for the record
	*file = fopen([completeFilePath UTF8String],"a");
	
	// write an initial header
    NSString *version = [NSString stringWithFormat:@"v%@ (%@)",
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	fprintf(*file, "%% %s recorded with %s %s\n%% \n", [description UTF8String], [PRODUCT_NAME UTF8String], [version UTF8String]);
	
    if (subtitle) {
        
        fprintf(*file, "%s", [subtitle UTF8String]);
    }
    
    fprintf(*file, "%% \n%% \n");
    fprintf(*file, "%% Step length: %f \n", [Settings sharedInstance].stepLength);
    fprintf(*file, "%% Position exchange: %s \n", [Settings sharedInstance].exchangeEnabled ? "ON" : "OFF");
    fprintf(*file, "%% Minimum metres between consecutive exchanges: %d \n", [Settings sharedInstance].distanceBetweenConsecutiveMeetings);
	
	fprintf(*file, "%% \n%% Column description:\n");
    
    for (int i = 0; i < [columnDescriptions count]; i++) {
        
        fprintf(*file, "%% \t %i: %s\n", i + 1, [[columnDescriptions objectAtIndex:i] UTF8String]);
    }
	
	fprintf(*file, "%% \n%% \n");
    
    return completeFilePath;
}

- (void)initAccelerometerFile:(NSString*)name {
    
    self.accelerometerFileName = [self setupTextFile:&accelerometerFile 
                                    withBaseFileName:name 
                                            appendix:kAccelerometerFileAppendix
                                     dataDescription:@"Accelerometer data"
                                            subtitle:[NSString stringWithFormat:@"%% Sampling frequency: %i Hz\n", 
                                                      [Gyroscope sharedInstance].frequency]
                                  columnDescriptions:[NSArray arrayWithObjects:
                                                      @"Seconds.milliseconds since 1970",
                                                      @"Queue size of CMController",
                                                      @"Acceleration value in x-direction",
                                                      @"Acceleration value in y-direction",
                                                      @"Acceleration value in z-direction",
                                                      @"Label used for the current sample",
                                                      nil]
                                  ];
	
}


- (void)initGyroFile:(NSString*)name {
    
    self.gyroFileName = [self setupTextFile:&gyroFile
                           withBaseFileName:name
                                   appendix:kGyroscopeFileAppendix
                            dataDescription:@"Gyrometer data"
                                   subtitle:nil
                         columnDescriptions:[NSArray arrayWithObjects:
                                             @"Seconds.milliseconds since 1970",
                                             @"Queue size of CMController",
                                             @"Gyro X",
                                             @"Gyro Y",
                                             @"Gyro Z",
                                             @"Roll of the device",
                                             @"Pitch of the device",
                                             @"Yaw of the device",
                                             @"Quaternion X",
                                             @"Quaternion Y",
                                             @"Quaternion Z",
                                             @"Quaternion W",
                                             @"X-axis magnetic field in microteslas",
                                             @"Y-axis magnetic field in microteslas",
                                             @"Z-axis magnetic field in microteslas",
                                             [NSString stringWithFormat:@"Magnetic field accuracy (%i: not calibrated, %i: low, %i: medium, %i: high)", 
                                              CMMagneticFieldCalibrationAccuracyUncalibrated,
                                              CMMagneticFieldCalibrationAccuracyLow,
                                              CMMagneticFieldCalibrationAccuracyMedium,
                                              CMMagneticFieldCalibrationAccuracyHigh],
                                             @"Label used for the current sample",
                                             nil]
                         ];
}


- (void)initGpsFile:(NSString*)name {
	
    self.gpsFileName = [self setupTextFile:&gpsFile
                          withBaseFileName:name
                                  appendix:kGpsFileAppendix
                           dataDescription:@"GPS data"
                                  subtitle:nil
                        columnDescriptions:[NSArray arrayWithObjects:
                                            @"Seconds.milliseconds since 1970",
                                            @"Longitude - east/west location measured in degrees (positive values: east / negative values: west)",
                                            @"Latitude - north/south location measured in degrees (positive values: north / negative values: south)",
                                            @"Altitude - hight above sea level measured in meters",
                                            @"Speed - measured in meters per second",
                                            @"Course - direction measured in degrees starting at due north and continuing clockwise (e.g. east = 90) - negative values indicate invalid values",
                                            @"Horizontal accuracy - negative values indicate invalid values",
                                            @"Vertical accuracy - negative values indicate invalid values",
                                            @"Label used for the current sample",
                                            nil]
                        ];	
}


- (void)initCompassFile:(NSString*)name {
    
    self.compassFileName = [self setupTextFile:&compassFile
                              withBaseFileName:name
                                      appendix:kCompassFileAppendix 
                               dataDescription:@"Compass data"
                                      subtitle:nil
                            columnDescriptions:[NSArray arrayWithObjects:
                                                @"Seconds.milliseconds since 1970",
                                                @"Magnetic heading in degrees starting at due north and continuing clockwise (e.g. east = 90) - negative values indicate invalid values\n% \t\t NOTE: True heading only provides valid values when GPS is activated at same time!",
                                                @"True heading in degrees starting at due north and continuing clockwise (e.g. east = 90) - negative values indicate invalid values",
                                                
                                                @"Error likelihood - negative values indicate invalid values",
                                                @"Geomagnetic data for the x-axis measured in microteslas",
                                                @"Geomagnetic data for the y-axis measured in microteslas",
                                                @"Geomagnetic data for the z-axis measured in microteslas",
                                                @"Label used for the current sample"
                                                , nil]
                            ];	
}


- (void)initPdrPositionFile:(NSString *)name {
    
    self.pdrPositionFileName = [self setupTextFile:&pdrPositionFile
                                  withBaseFileName:name
                                          appendix:kPdrPositionFileAppendix 
                                   dataDescription:@"PDR positions"
                                          subtitle:nil
                                columnDescriptions:[NSArray arrayWithObjects:
                                                    @"Seconds.milliseconds since 1970",
                                                    @"Northing delta in m",
                                                    @"Easting delta in m",
                                                    @"Northing origin in m",
                                                    @"Easting origin in m",
                                                    @"Deviation in m"
                                                    , nil]
                                ];	
}


- (void)initPdrCollaborativeTraceFile:(NSString *)name {
    
	pdrCollaborativeTraceFile = NULL;
    completePathCounter = 0;
    
    [self startNewCollaborativeTraceFile];
}

- (void)startNewCollaborativeTraceFile {
    
    if (pdrCollaborativeTraceFile) {
        
        fclose(pdrCollaborativeTraceFile);
    }
    
    self.pdrCollaborativeTraceFileName = [self setupTextFile:&pdrCollaborativeTraceFile
                                            withBaseFileName:self.currentFilePrefix
                                                    appendix:[NSString stringWithFormat:kPdrCompleteCollaborativeTracesFileAppendixFormat, completePathCounter++]
                                             dataDescription:@"Complete path after a manual position, manual heading or P2P correction"
                                                    subtitle:nil
                                          columnDescriptions:[NSArray arrayWithObjects:
                                                              @"Seconds.milliseconds since 1970",
                                                              @"Northing delta in m",
                                                              @"Easting delta in m",
                                                              @"Northing origin in m",
                                                              @"Easting origin in m",
                                                              @"Deviation in m"
                                                              , nil]
                                          ];
}


- (void)initPdrManualPositionCorrectionFile:(NSString *)name {
    
    self.pdrManualPositionCorrectionFileName = [self setupTextFile:&pdrManualPositionCorrectionFile
                                                  withBaseFileName:name
                                                          appendix:kPdrManualPositionCorrectionFileAppendix 
                                                   dataDescription:@"Manual corrections of PDR positions"
                                                          subtitle:nil
                                                columnDescriptions:[NSArray arrayWithObjects:
                                                                    @"Seconds.milliseconds since 1970",
                                                                    @"Northing delta in m",
                                                                    @"Easting delta in m",
                                                                    @"Northing origin in m",
                                                                    @"Easting origin in m",
                                                                    @"Deviation in m"
                                                                    , nil]
                                                ];	
}

- (void)initPdrManualHeadingCorrectionFile:(NSString *)name {
    
    self.pdrManualHeadingCorrectionFileName = [self setupTextFile:&pdrManualHeadingCorrectionFile
                                                 withBaseFileName:name
                                                         appendix:kPdrManualHeadingCorrectionFileAppendix
                                                  dataDescription:@"Manual corrections of PDR heading around the specified point"
                                                         subtitle:nil
                                               columnDescriptions:[NSArray arrayWithObjects:
                                                                   @"Seconds.milliseconds since 1970",
                                                                   @"Northing delta in m",
                                                                   @"Easting delta in m",
                                                                   @"Northing origin in m",
                                                                   @"Easting origin in m",
                                                                   @"Deviation in m",
                                                                   @"Rotation amount in radians"
                                                                   , nil]
                                               ];
}

- (void)initPdrCollaborativePositionCorrectionUpdateFile:(NSString *)name {
    
    self.pdrCollaborativePositionCorrectionUpdateFileName = [self setupTextFile:&pdrCollaborativePositionCorrectionUpdateFile
                                                               withBaseFileName:name
                                                                       appendix:kPdrCollaborativePositionCorrectionUpdateFileAppendix 
                                                                dataDescription:@"Collaborative corrections of PDR positions"
                                                                       subtitle:nil
                                                             columnDescriptions:[NSArray arrayWithObjects:
                                                                                 @"Seconds.milliseconds since 1970 before exchange",
                                                                                 @"Northing delta in m before exchange",
                                                                                 @"Easting delta in m before exchange",
                                                                                 @"Northing origin in m before exchange",
                                                                                 @"Easting origin in m before exchange",
                                                                                 @"Deviation in m before exchange",
                                                                                 
                                                                                 @"Seconds.milliseconds since 1970 after exchange",
                                                                                 @"Northing delta in m after exchange",
                                                                                 @"Easting delta in m after exchange",
                                                                                 @"Northing origin in m after exchange",
                                                                                 @"Easting origin in m after exchange",
                                                                                 @"Deviation in m after exchange",
                                                                                 
                                                                                 @"Peer ID",
                                                                                 @"Name of the peer's device"
                                                                                 , nil]
                                                             ];	
}


- (void)initPdrConnectionQueryFile:(NSString *)name {
    
    self.pdrConnectionQueryFileName = [self setupTextFile:&pdrConnectionQueryFile
                                         withBaseFileName:name
                                                 appendix:kPdrConnectionQueryFileAppendix 
                                          dataDescription:@"Connection querys for collaborative corrections of PDR positions"
                                                 subtitle:nil
                                       columnDescriptions:[NSArray arrayWithObjects:
                                                           @"Seconds.milliseconds since 1970 before exchange",
                                                           @"Peer ID",
                                                           @"Name of the peer's device",
                                                           @"Decided to try to connect YES/NO"
                                                           , nil]
                                       ];	
}


#pragma mark -
#pragma mark implementation of Listener protocol (writing the data)

-(void)didReceiveDeviceMotion:(CMDeviceMotion *)motionTN timestamp:(NSTimeInterval)timestampTN
{
    if (isRecording) {
        
		fprintf(accelerometerFile,
                "%10.3f\t %i\t %f\t %f\t %f\t %i\n",
                timestampTN,
                0,
                motionTN.userAcceleration.x,
                motionTN.userAcceleration.y,
                motionTN.userAcceleration.z,
                0);
        
        CMAttitude *attitude = motionTN.attitude;
        CMRotationRate rate = motionTN.rotationRate;
        CMQuaternion quaternion = motionTN.attitude.quaternion;
        CMCalibratedMagneticField magneticField = motionTN.magneticField;
        
        double x = rate.x;
        double y = rate.y;
        double z = rate.z;
        
        double roll = attitude.roll;
        double pitch = attitude.pitch;
        double yaw = attitude.yaw;
        
        fprintf(gyroFile,
                "%10.3f\t %i\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %i\t %i\n",
                timestampTN,
                0,
                x,
                y,
                z,
                roll,
                pitch,
                yaw,
                quaternion.x,
                quaternion.y,
                quaternion.z, 
                quaternion.w,
                magneticField.field.x,
                magneticField.field.y,
                magneticField.field.z,
                magneticField.accuracy,
                0);
                
        usedAccelerometer = YES;
        usedGyro = YES;
	}
    
}

-(void)didReceiveGPSvalueWithLongitude:(double)longitude latitude:(double)latitude altitude:(double)altitude speed:(double)speed course:(double)course horizontalAccuracy:(double)horizontalAccuracy verticalAccuracy:(double)verticalAccuracy timestamp:(NSTimeInterval)timestamp label:(int)label {
    
    if (isRecording) {
        
        fprintf(gpsFile,"%10.3f\t %f\t %f\t %f\t %f\t %f\t %f\t %f\t %i\n", timestamp, longitude, latitude, altitude, speed, course, horizontalAccuracy, verticalAccuracy, label);
        usedGPS = YES;
    }
    
}

-(void)didReceiveCompassValueWithMagneticHeading:(double)magneticHeading trueHeading:(double)trueHeading headingAccuracy:(double)headingAccuracy X:(double)x Y:(double)y Z:(double)z timestamp:(NSTimeInterval)timestamp label:(int)label {
    
    if (isRecording) {
        
        fprintf(compassFile,"%10.3f\t %f\t %f\t %f\t %f\t %f\t %f\t %i\n", timestamp, magneticHeading, trueHeading, headingAccuracy, x, y, z, label);
        usedCompass = YES;
        
    }
}

//MARK: PDRLogger implementation

// raw PDR trace
- (void)didReceivePDRPosition:(AbsoluteLocationEntry *)position {
    
    if (isRecording) {
        
        fprintf(pdrPositionFile, "%s\n", [[position stringRepresentationForRecording] UTF8String]);
    }
}

// collaborative localisation trace
- (void)didReceiveCollaborativeLocalisationPosition:(AbsoluteLocationEntry *)position {
    
    if (isRecording) {
        
        fprintf(pdrCollaborativeTraceFile, "%s\n", [[position stringRepresentationForRecording] UTF8String]);
    }
}

// manual position corrections of the user
- (void)didReceiveManualPositionCorrection:(AbsoluteLocationEntry *)position {
    
    if (isRecording) {
        
        fprintf(pdrManualPositionCorrectionFile, "%s\n", [[position stringRepresentationForRecording] UTF8String]);
    }
    
}

// manual heading corrections of the user
- (void)didReceiveManualHeadingCorrectionAround:(AbsoluteLocationEntry *)position By:(double)radians {
    
    if (isRecording) {
        
        fprintf(pdrManualHeadingCorrectionFile, "%s\t%f\n", [[position stringRepresentationForRecording] UTF8String], radians);
    }
}

// collaborative localisation position update
- (void)didReceiveCollaborativePositionCorrectionFrom:(AbsoluteLocationEntry *)before ToPosition:(AbsoluteLocationEntry *)after FromPeer:(NSString *) peerID {
    
    if (isRecording) {
        
        NSString *result = [NSString stringWithFormat:@"%@\t %@\t %@\t %@\n", 
                            [before stringRepresentationForRecording], 
                            [after stringRepresentationForRecording],
                            peerID,
                            [[P2PestimateExchange sharedInstance] displayNameForUniquePeerID:peerID]];
        
        fprintf(pdrCollaborativePositionCorrectionUpdateFile, "%s", [result UTF8String]);
    }
}

// track of connection queries
- (void)didReceiveConnectionQueryToPeer:(NSString *) peerID WithTimestamp:(NSTimeInterval) timestamp ShouldConnect:(bool) shouldConnect {
    
    if (isRecording) {
        
        NSString *result = [NSString stringWithFormat:@"%10.3f\t %@\t %@\t %d\n",
                            timestamp,
                            peerID,
                            [[P2PestimateExchange sharedInstance] displayNameForUniquePeerID:peerID],
                            shouldConnect ? 1 : 0];
        
        fprintf(pdrConnectionQueryFile, "%s", [result UTF8String]);
    }
}

// complete path collaborative path (rotated / manually corrected)
- (void)didReceiveCompleteCollaborativePath:(NSArray *)path {
    
    //start a new file
    [self startNewCollaborativeTraceFile];
    
    //fill it with the whole (changed) path
    for (AbsoluteLocationEntry *entry in path) {
        
        [self didReceiveCollaborativeLocalisationPosition:entry];
    }
}



@end
