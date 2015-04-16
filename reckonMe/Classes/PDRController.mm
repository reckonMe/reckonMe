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

#import <MapKit/MapKit.h>
#import "PDRController.h"
#import "GeodeticProjection.h"
#import "Settings.h"
#include <vector>
#include <string>
#include <cmath>
#include <map>
#include "matlab-utils.h"

using namespace std;

//  size [s] of the data in the front to discard in on-line filtering
const double kFrontOverlapTime = 1.5;

//  size [s] of the buffer on the back to minimize filtering artifacts
const double kBackBufferSize = 4.0;

// size [s] of the on-line window filtering size
const double kWindowSize = 1.5;

// minimum sampling rate 
const double kMinSamplingRate = 20;

// threshold for unwrapping quaternion (x, y, z) coordinates
const double kQuaternionFlipThreshold = 0.4;

// threshold for detecting peaks in Z-axis gravity 
const double kThresholdPeaksGravity = 0.25;

// threshold for detecting peaks in user acceleration
const double kThresholdPeaksUserAcc = 0.25;

// threshold for X- and  Y-axis of user gravity
const double kUserGravityThresholdX = 0.5;
const double kUserGravityThresholdY = 0.5;

// min user acceleration for the peak to be recognized as a step
const double kUserAccThreshold = 0.1;

// max distance between the user acceleration peak and the user gravity peak 
// for which the forward direction is determined by the sign of the acceleration peak
const double kDistanceToAccPeakThreshold = -6.0;

// time [s] which has to pass between meeting the same person next time
const int kMinTimeBetweenConsecutiveMeetings = 1;

// below kMinAngleForStepLength steps are of minimal length, 
// above kMaxAngleForStepLength steps are of maximal length 
const double kMinAngleForStepLength = 20.0;
const double kMaxAngleForStepLength = 55.0;

// if (stepAngle <= kMinAngleStrideThreshold || stepAngle >= kMaxAngleStrideThreshold )
//    then the step is omitted
const double kMinAngleStrideThreshold = 10.0;
const double kMaxAngleStrideThreshold = 80.0;

// maximal time distance [s] between the peaks to be recognised as a step
const double kMaxStepDuration = 2.0;


struct MotionManagerEntry {
    double timestamp;
    GLKQuaternion quaternion;
    GLKVector3 userAcceleration;
    
    MotionManagerEntry(NSTimeInterval _timestamp, CMQuaternion q, CMAcceleration acc) :
    timestamp(_timestamp),
    quaternion(GLKQuaternionMake(q.x, q.y, q.z, q.w)),
    userAcceleration(GLKVector3Make(acc.x, acc.y, acc.z))
    {}
};

struct TraceEntry {
    double timestamp;
    double x, y;
    double deviation;
    TraceEntry(const double time, double _x, double _y, double _deviation) : 
    timestamp(time), x(_x), y(_y), deviation(_deviation) {}
    TraceEntry() : x(0), y(0), deviation(1.0) {}  
};

@interface PDRController () 

- (void)runPdrWithTimestamp:(NSTimeInterval) timestamp;
- (id)absoluteLocationEntryFrom:(TraceEntry) location;
- (void)writeVector:(vector<double>) data ToFile:(string) _filename resetFileContents:(bool) resetFile;
- (void)pruneDataOlderThan:(double) timestamp;
- (void)resetPDR;
- (void)computePDR;
- (NSMutableArray *)collaborativeTraceToNSMutableArrayStartingAt:(list<TraceEntry>::iterator) startingPosition;

@end

static PDRController *sharedSingleton;

@implementation PDRController {

@private
    list<MotionManagerEntry> motionManagerData;
    list<TraceEntry> pdrTrace;
    list<TraceEntry> collaborativeTrace;

    // point last used as the origin during the last user-defined manual rotation
    list<TraceEntry>::iterator collaborativeTraceRotationIndex;

    map<string, double> timestampsOfLastMeetings;
    
    double timestampOfLastInformationExchange;
    bool lastStepWasManualCorrection;
    
    dispatch_queue_t computePDRqueue;
    
    double stepLength;
    NSInteger distanceBetweenConsecutiveMeetings;
}

@synthesize view;
@synthesize logger;
@synthesize pdrRunning;
@synthesize originEasting;
@synthesize originNorthing;

//Is called by the runtime in a thread-safe manner exactly once, before the first use of the class.
//This makes it the ideal place to set up the singleton.
+ (void)initialize {
    
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[PDRController alloc] init];
    }
}


+(PDRController *)sharedInstance {
    
    return sharedSingleton;
}

#pragma mark -
#pragma mark PDRDataListener


- (void)didReceiveDeviceMotion:(CMDeviceMotion *)motionTN timestamp:(NSTimeInterval)timestampTN {

    if (!motionManagerData.empty() && motionManagerData.back().timestamp >= timestampTN)
        return;
    if (pdrRunning) 
        motionManagerData.push_back(
                                    MotionManagerEntry(timestampTN, motionTN.attitude.quaternion, motionTN.userAcceleration)
                                    );
    
    dispatch_async(computePDRqueue, ^(void) {
        [self runPdrWithTimestamp:timestampTN];
    });
}
 
    
#pragma mark -
#pragma mark PDRControllerProtocol


- (void)startPDRsessionWithGPSfix:(AbsoluteLocationEntry *)location {

    [self resetPDR];
    
    distanceBetweenConsecutiveMeetings = [Settings sharedInstance].distanceBetweenConsecutiveMeetings;
    stepLength = [Settings sharedInstance].stepLength;
    
    originEasting = location.easting;
    originNorthing = location.northing;
   
    // TEMPORARY CHANGE
    double timestamp = location.timestamp;
        
    TraceEntry initialPosition(timestamp, 0, 0, 1.0);
    pdrTrace.push_back(initialPosition);
    collaborativeTrace.push_back(initialPosition);
    
    collaborativeTraceRotationIndex = collaborativeTrace.begin();
    
    // notify logger & view of the initial step
    AbsoluteLocationEntry *entry = [self absoluteLocationEntryFrom:initialPosition];
    [view didReceivePosition:entry
          isResultOfExchange:NO];
    [logger didReceivePDRPosition:entry];
    [logger didReceiveCollaborativeLocalisationPosition:entry];
    
    // add fake steps for view debugging
//    TraceEntry fakeStep1(timestamp + 3, pdrTrace.back().x + 20, pdrTrace.back().y + 20,
//                       pdrTrace.back().deviation + 0);
//    TraceEntry fakeStep2(timestamp + 6, pdrTrace.back().x + 40, pdrTrace.back().y - 0,
//                        pdrTrace.back().deviation + 0);
//    
//    // add the step to pdrTrace
//    pdrTrace.push_back(fakeStep1);
//    pdrTrace.push_back(fakeStep2);
//    collaborativeTrace.push_back(fakeStep1);
//    collaborativeTrace.push_back(fakeStep2); 
//    AbsoluteLocationEntry *entry1 = [self absoluteLocationEntryFrom:fakeStep1];
//    AbsoluteLocationEntry *entry2 = [self absoluteLocationEntryFrom:fakeStep2];
//    
//    [view didReceivePosition:entry1];
//    [logger didReceivePDRPosition:entry1];
//    [logger didReceiveCollaborativeLocalisationPosition:entry1];
//    [view didReceivePosition:entry2];
//    [logger didReceivePDRPosition:entry2];
//    [logger didReceiveCollaborativeLocalisationPosition:entry2];
    
    pdrRunning = true;
}

    
- (void)stopPDRsession {
    
    [self resetPDR];
}

    
- (void)didReceiveManualPostionCorrection:(AbsoluteLocationEntry *)position {
    
    if(!pdrRunning)
        return;

    // convert absoluteEasting & absoluteNorthing into delta coordinates to origin coordinates unchanged
    // deltas have to be scaled back to "normal" metres as they are enlarged by mercatorScaleFactor

    double deltaEasting = (position.easting - originEasting) / position.mercatorScaleFactor;
    double deltaNorthing = (position.northing - originNorthing) / position.mercatorScaleFactor;
    TraceEntry newPosition(position.timestamp, deltaEasting, deltaNorthing, 1.0);
    
    // clear all the meeting history, we know exactly where we are, we can correct others
    timestampsOfLastMeetings.clear();
    
    if (lastStepWasManualCorrection) {
        collaborativeTrace.pop_back();
    }
    
    collaborativeTrace.push_back(newPosition);
    
    lastStepWasManualCorrection = YES;

    AbsoluteLocationEntry *entry = [self absoluteLocationEntryFrom:newPosition];
    
    [logger didReceiveManualPositionCorrection:entry];
    
    NSMutableArray *completePath = [self collaborativeTraceToNSMutableArrayStartingAt:collaborativeTrace.begin()];
    [logger didReceiveCompleteCollaborativePath:completePath];
    [view didReceiveCompletePath:completePath];
}

    
- (bool)shouldConnectToPeerID:(NSString *) peerID {
    
#ifdef P2P_TESTS
    distanceBetweenConsecutiveMeetings = 1;
#endif

    bool shouldConnect = false;
    
    if (!pdrRunning) {
        shouldConnect = false;
    }
    else if (timestampOfLastInformationExchange + 1 > collaborativeTrace.back().timestamp) {

        // allow at most one exchange per 1s
        shouldConnect = false;
    }
    else {
        
        auto it = timestampsOfLastMeetings.find([peerID cStringUsingEncoding: [NSString defaultCStringEncoding]]);
        
        // if we have not met the person before, approve connection if we have walked long enough
        if (it == timestampsOfLastMeetings.end()) {

            shouldConnect = (pdrTrace.size() > distanceBetweenConsecutiveMeetings);
        
        } else {
        
            double last_meeting = it->second;
            // keep the min time between the meetings
            if (collaborativeTrace.back().timestamp < last_meeting + kMinTimeBetweenConsecutiveMeetings) {
                shouldConnect = false;
            }
            else {
            
                /* check if we have walked long enough since the last meeting */
                auto it = pdrTrace.rbegin();
                int numStepsWalked = 0;
                
                // count the number of steps
                while (it != pdrTrace.rend() && it->timestamp >= last_meeting) {
                
                    ++it;
                    ++numStepsWalked;
                }                             
                shouldConnect = (numStepsWalked > distanceBetweenConsecutiveMeetings);
            }
        }
    }

    [logger didReceiveConnectionQueryToPeer:peerID
                              WithTimestamp:motionManagerData.back().timestamp
                              ShouldConnect:shouldConnect];

    return shouldConnect;
}

    
- (void)didReceivePosition:(AbsoluteLocationEntry *)position ofPeer:(NSString *)peerID isRealName:(BOOL)isRealName {
    
    if(!pdrRunning)
        return;
    
    TraceEntry oldPosition(collaborativeTrace.back());
    
    double absoluteEasting = originEasting + oldPosition.x * position.mercatorScaleFactor;
    double absoluteNorthing = originNorthing + oldPosition.y * position.mercatorScaleFactor;
    double deviation = collaborativeTrace.back().deviation;
    
    // compute new location by multiplying two Gaussian PDFs.
    
    double deviationSquared = deviation * deviation;
    double peerDeviationSquared = position.deviation * position.deviation;
    
    double newAbsoluteEasting = (absoluteEasting * peerDeviationSquared + 
                                 position.easting * deviationSquared) / 
                                 (deviationSquared + peerDeviationSquared);
    
    double newAbsoluteNorthing = (absoluteNorthing * peerDeviationSquared + 
                                  position.northing * deviationSquared) / 
                                 (deviationSquared + peerDeviationSquared);
    
    double newDeviation = (deviation * position.deviation) / (sqrt(deviationSquared + peerDeviationSquared));
    double newDeltaEasting = (newAbsoluteEasting - originEasting) / position.mercatorScaleFactor;
    double newDeltaNorthing = (newAbsoluteNorthing - originNorthing) / position.mercatorScaleFactor;
    
    // make the position change happen 0.1s past the last logged position
    double newTimestamp = motionManagerData.back().timestamp + 0.1;
    
    TraceEntry newPosition(newTimestamp, newDeltaEasting, newDeltaNorthing, newDeviation);
    
    // log the timestamp
    timestampsOfLastMeetings[[peerID cStringUsingEncoding: [NSString defaultCStringEncoding]]] = newTimestamp;
    timestampOfLastInformationExchange = newTimestamp;
    
    collaborativeTrace.push_back(newPosition);
    
    // push data to logger & view
    
    AbsoluteLocationEntry *beforeEntry = [self absoluteLocationEntryFrom:oldPosition];    
    AbsoluteLocationEntry *afterEntry = [self absoluteLocationEntryFrom:newPosition];    
    
    [logger didReceiveCollaborativePositionCorrectionFrom:beforeEntry 
                                               ToPosition:afterEntry 
                                               FromPeer:peerID];
    
    //instead of only appending afterEntry to the collaborative path, make logger start a new file with the complete path (including afterEntry)
    NSMutableArray *completePath = [self collaborativeTraceToNSMutableArrayStartingAt:collaborativeTrace.begin()];
    [logger didReceiveCompleteCollaborativePath:completePath];

    [view didReceivePosition:afterEntry
          isResultOfExchange:YES];
    [view didReceivePeerPosition:position
                          ofPeer:peerID
                      isRealName:isRealName];
}

    
- (AbsoluteLocationEntry *)positionForExchange {
    
    TraceEntry lastPosition = collaborativeTrace.back();
    AbsoluteLocationEntry *result = [self absoluteLocationEntryFrom:lastPosition];
    return result;
}

    
- (void)rotatePathBy:(double) radians {
   
    // rotates the collaborative path, starting from the collaborativeTraceRotationIndex
    // pushes the full path to the view
    
    pdrRunning = NO;
    
    // cumulative rotation amount [rad] modulo 2*Pi
    self.pathRotationAmount = fmod(self.pathRotationAmount + radians, 2 * M_PI);
    AbsoluteLocationEntry *rotationCenter = [self absoluteLocationEntryFrom:*collaborativeTraceRotationIndex];
    
    //notify the logger
    [logger didReceiveManualHeadingCorrectionAround:rotationCenter
                                                 By:radians
                                         Cumulative:self.pathRotationAmount];
    
    for (auto it = collaborativeTraceRotationIndex; it != collaborativeTrace.end(); ++it) {

        double oldX = it->x - collaborativeTraceRotationIndex->x;
        double oldY = it->y - collaborativeTraceRotationIndex->y;
        it->x = cos(radians) * oldX - sin(radians) * oldY + collaborativeTraceRotationIndex->x;
        it->y = sin(radians) * oldX + cos(radians) * oldY + collaborativeTraceRotationIndex->y;
    }
    
    NSMutableArray *rotatedViewPath = [self collaborativeTraceToNSMutableArrayStartingAt:collaborativeTrace.begin()];
    
    [logger didReceiveCompleteCollaborativePath:rotatedViewPath];
    [view didReceiveCompletePath:rotatedViewPath];
    
    pdrRunning = YES;
}

    
- (NSMutableArray *)partOfPathToBeManuallyRotatedWithPinLocation:(AbsoluteLocationEntry *)pinLocation {

    if (NULL != pinLocation && collaborativeTrace.size() > 2) {
        
        double minDistSquared = HUGE_VALF;
        MKMapPoint pinCartesian = MKMapPointForCoordinate(pinLocation.absolutePosition);    
        auto end = collaborativeTrace.end();
        --end; --end;
        
        for (auto it = collaborativeTrace.begin(); it != end; ++it) {
            
            AbsoluteLocationEntry* pointAbsoluteLocation = [self absoluteLocationEntryFrom:*it];
            MKMapPoint pointCartesian = MKMapPointForCoordinate(pointAbsoluteLocation.absolutePosition);
            double distSquared = (pointCartesian.x - pinCartesian.x) * (pointCartesian.x - pinCartesian.x) + 
                                 (pointCartesian.y - pinCartesian.y) * (pointCartesian.y - pinCartesian.y);

            if (distSquared < minDistSquared) {
            
                collaborativeTraceRotationIndex = it;
                minDistSquared = distSquared;
            }
        }
    }
    
    return [self collaborativeTraceToNSMutableArrayStartingAt:collaborativeTraceRotationIndex];
}

    
#pragma mark -
#pragma mark private methods

    
- (void)runPdrWithTimestamp:(NSTimeInterval)timestamp {
    
    static NSTimeInterval lastTimeRun = 0;
    static NSTimeInterval threshold = 2; // [s]
    
    if (pdrRunning && (timestamp > lastTimeRun + threshold)) {
        
        lastTimeRun = timestamp;
        
        //WARNING: don't do anything in this method that involves autoreleased objects before the following line
        //we are not in the main thread -> we need our own pool
        @autoreleasepool {
            
            [self computePDR];
        }
    }
}

    
- (id)absoluteLocationEntryFrom:(TraceEntry) location {

    ProjectedPoint originProjected;
    originProjected.easting = self.originEasting;
    originProjected.northing = self.originNorthing;
    
    CLLocationCoordinate2D origin = [GeodeticProjection cartesianToCoordinates:originProjected];
    
    return [[[AbsoluteLocationEntry alloc] initWithTimestamp:location.timestamp
                                                eastingDelta:location.x
                                               northingDelta:location.y
                                                      origin:origin
                                                   Deviation:location.deviation]
            autorelease];
}

    
- (void)writeVector:(vector<double>) data ToFile:(string) _filename resetFileContents:(bool) resetFile {
    
    static map<string, int> filenames;
    
    filenames[_filename]++;
    
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filename = [[NSString stringWithCString:_filename.c_str() encoding:[NSString defaultCStringEncoding]] 
                          stringByAppendingString: [NSString stringWithFormat:@"-%d.txt", filenames[_filename]]];

    NSString *destinationFilePath = [NSString stringWithFormat: @"%@/%@", documentsDirectory, filename];
    const char *accessMode = resetFile ? "w" : "wa";
    FILE *log = fopen([destinationFilePath cStringUsingEncoding: [NSString defaultCStringEncoding]], accessMode);
    if (log) {
        
        for (int i = 0; i < data.size(); ++i) 
            fprintf(log, "%lf\n", data[i]);
    }

    fclose(log);
    NSLog(@"log: %@ %d", filename, filenames[_filename]);
}

    
- (void)resetPDR {
    
    pdrRunning = NO;
    lastStepWasManualCorrection = NO;
    self.pathRotationAmount = 0;
    pdrTrace.clear();
    collaborativeTrace.clear();
    collaborativeTraceRotationIndex = collaborativeTrace.begin();
    motionManagerData.clear();
    timestampsOfLastMeetings.clear();
    timestampOfLastInformationExchange = -1000;
}

    
- (void)pruneDataOlderThan:(double) timestamp {
    
    auto it = motionManagerData.cbegin();
    while (it != motionManagerData.cend() && it->timestamp < timestamp) {
        
        ++it;
    }
    
    motionManagerData.erase(motionManagerData.begin(), it);
}

    
- (void)computePDR {
    
    if (!pdrRunning) 
        return;
    
    // check if there is enough data to run the algorithm
    double minTime = kWindowSize + kFrontOverlapTime + kBackBufferSize;
    if (motionManagerData.back().timestamp - motionManagerData.front().timestamp < minTime || 
        motionManagerData.size() < minTime * kMinSamplingRate) {
        return;
    }
    
    size_t dataSize = motionManagerData.size();
    
    vector<double> qx(dataSize), qy(dataSize), qz(dataSize), qw(dataSize);
    vector<double> normAcc(dataSize);
    vector<double> timestamps(dataSize);
    
    //  copy quaternion data into vectors, compute norm of acceleration,
    //  extract timestamps into a single vector    
    auto it = motionManagerData.begin();
    for (int i = 0; i < dataSize; ++i) {
        
        qx[i] = it->quaternion.x;
        qy[i] = it->quaternion.y;
        qz[i] = it->quaternion.z;
        qw[i] = it->quaternion.w;
        normAcc[i] = sqrt(it->userAcceleration.x * it->userAcceleration.x + 
                          it->userAcceleration.y * it->userAcceleration.y +
                          it->userAcceleration.z * it->userAcceleration.z);
        timestamps[i] = it->timestamp;
        ++it;
    }
    
    // unwrap quaternion (x, y, z) coordinates
    for (int i = 1; i < dataSize; ++i)
        if (fabs(qx[i] - qx[i-1]) > kQuaternionFlipThreshold ||
            fabs(qy[i] - qy[i-1]) > kQuaternionFlipThreshold ||
            fabs(qz[i] - qz[i-1]) > kQuaternionFlipThreshold) 
        { 
            qx[i] = -qx[i];
            qy[i] = -qy[i];
            qz[i] = -qz[i];
            qw[i] = -qw[i];
        }

    // a & b arrays generated by the Matlab command '[b, a] = butter(10, 2.0/25)'
    static const double quaternion_a_arr[] = {1, -8.39368255078838, 31.8158646581919, -71.702656982143, 
        106.381617694638, -108.553825650279, 77.1444606240243, -37.6960546719427, 
        12.1197601392884, -2.31493776310228, 0.199454975553811};
    static const double quaternion_b_arr[] = {4.62344829088579E-10, 4.62344829088579E-09, 2.08055173089861E-08, 
        5.54813794906295E-08, 9.70924141086016E-08, 1.16510896930322E-07, 9.70924141086016E-08, 
        5.54813794906295E-08, 2.08055173089861E-08, 4.62344829088579E-09, 4.62344829088579E-10};
    static const vector<double> quaternion_a_vec(quaternion_a_arr, quaternion_a_arr+sizeof(quaternion_a_arr)/sizeof(double));
    static const vector<double> quaternion_b_vec(quaternion_b_arr, quaternion_b_arr+sizeof(quaternion_b_arr)/sizeof(double));

    // a & b arrays generated by the Matlab command '[b, a] = butter(10, 1.6/25)'
    static const double acc_a_arr[] = {1.000000000000000E+00, -9.196736167550716E+00, 3.809105883695972E+01, 
        -9.356278085796347E+01, 1.509311663652506E+02, -1.670769732545971E+02, 1.285295680551103E+02, 
        -6.784797569549585E+01, 2.352000945584866E+01, -4.834875109002173E+00, 4.475383721056476E-01};
    static const double acc_b_arr[] = {6.500355809180292E-13, 6.500355809180292E-12, 2.925160114131131E-11, 
        7.800426971016350E-11, 1.365074719927861E-10, 1.638089663913433E-10, 1.365074719927861E-10, 
        7.800426971016350E-11, 2.925160114131131E-11, 6.500355809180292E-12, 6.500355809180292E-13};
    
    // a & b arrays generated by the Matlab command '[b, a] = butter(10, 1.0/25)'
//    static const double acc_a_arr[] = {1.000000000000000E+00, -9.196736167550716E+00, 3.809105883695972E+01,
//        -9.356278085796347E+01, 1.509311663652506E+02, -1.670769732545971E+02, 1.285295680551103E+02,
//        -6.784797569549585E+01, 2.352000945584866E+01, -4.834875109002173E+00, 4.475383721056476E-01};
//    static const double acc_b_arr[] = {6.500355809180292E-13, 6.500355809180292E-12, 2.925160114131131E-11,
//        7.800426971016350E-11, 1.365074719927861E-10, 1.638089663913433E-10, 1.365074719927861E-10,
//        7.800426971016350E-11, 2.925160114131131E-11, 6.500355809180292E-12, 6.500355809180292E-13};
    static const vector<double> acc_a_vec(acc_a_arr, acc_a_arr+sizeof(acc_a_arr)/sizeof(double));
    static const vector<double> acc_b_vec(acc_b_arr, acc_b_arr+sizeof(acc_b_arr)/sizeof(double));

    // filter quaternions & norm of accelereation
    vector<double> filtAcc = filtfilt(acc_a_vec, acc_b_vec, normAcc);
    vector<double> filtQx = filtfilt(quaternion_a_vec, quaternion_b_vec, qx);
    vector<double> filtQy = filtfilt(quaternion_a_vec, quaternion_b_vec, qy);
    vector<double> filtQz = filtfilt(quaternion_a_vec, quaternion_b_vec, qz);
    vector<double> filtQw = filtfilt(quaternion_a_vec, quaternion_b_vec, qw);
    
    // combine filtered vectors back into quaternions
    vector<GLKQuaternion> filtQ(dataSize);
    for (int i = 0; i < dataSize; ++i) 
        filtQ[i] = GLKQuaternionNormalize(GLKQuaternionMake(filtQx[i], filtQy[i], filtQz[i], filtQw[i]));
                                                                             
    // compute filtered X-, Y-, Z-axis gravity (in device reference frame)
    vector<double> filtGravityX (dataSize), filtGravityY (dataSize), filtGravityZ (dataSize);
    static const GLKVector3 oneG = GLKVector3Make(0, 0, -1);
    for (int i = 0; i < dataSize; ++i) {
        GLKVector3 filtG = GLKQuaternionRotateVector3(GLKQuaternionConjugate(filtQ[i]), oneG);
        filtGravityX[i] = filtG.x;
        filtGravityY[i] = filtG.y;
        filtGravityZ[i] = filtG.z;
    }

#ifdef DEBUG_MODE   
    vector<double> gravityX (dataSize), gravityY (dataSize), gravityZ (dataSize);
    for (int i = 0; i < dataSize; ++i) {
        
        GLKVector3 userG = GLKQuaternionRotateVector3(GLKQuaternionConjugate(GLKQuaternionMake(qx[i], qy[i], qz[i], qw[i])), oneG);
        gravityX[i] = userG.x;
        gravityY[i] = userG.y;
        gravityZ[i] = userG.z;
    }    
#endif
        
    // strip data from the from the front to minimize boundary effects caused by filtering
    int margin = kFrontOverlapTime * kMinSamplingRate;
    size_t rightIndex = dataSize - margin;
          
    // double check if we are left with enough data
    if (rightIndex < kWindowSize * kMinSamplingRate) 
        return;
    
    // detect Z-axis gravity peaks
    vector<PeakEntry> gravityPeakIndices = peakdet(filtGravityZ, 0, rightIndex, kThresholdPeaksGravity);
    
    // detect user acceleration peaks
    vector<PeakEntry> userAccPeakIndices = peakdet(filtAcc, 0, rightIndex, kThresholdPeaksUserAcc);
    
    // fast forward to the last step detected in previous run
    int firstNewPeakIndex = 0;
    double epsilon = 0.2f;
    while (firstNewPeakIndex < gravityPeakIndices.size() && 
           timestamps[gravityPeakIndices[firstNewPeakIndex].index] < pdrTrace.back().timestamp - epsilon) {
        
        firstNewPeakIndex++;
    }
   
    
    // filter gravityPeakIndices:
    // set threshold for gravity in device' s X and Y axis
    // make sure that we get alternating up- & down peaks 
    vector<PeakEntry> filteredGravityPeakIndices;
    filteredGravityPeakIndices.reserve(gravityPeakIndices.size());
    
    for (int i = firstNewPeakIndex; i < gravityPeakIndices.size(); ++i) {
        
        size_t j = gravityPeakIndices[i].index;
        
        if ((fabs(filtGravityX[j]) > kUserGravityThresholdX ||
             fabs(filtGravityY[j]) > kUserGravityThresholdY) &&
             filtAcc[j] > kUserAccThreshold) {
            
            filteredGravityPeakIndices.push_back(gravityPeakIndices[i]);
        }
    }

    // replace gravityPeakIndices with filteredGravityPeakIndices
    filteredGravityPeakIndices.swap(gravityPeakIndices);        
    
    if (gravityPeakIndices.size() < 2) {

        // not enough steps have been detected, prune all data except for the overlap window
        [self pruneDataOlderThan:(timestamps[rightIndex] - 2 * kBackBufferSize)];
        return; 
    }    
   
    //  Skip the first peak in gravityPeakIndices, if it has already been detected as a step in the previous run
    int startingIndex = 0;
    if (fabs(timestamps[gravityPeakIndices[0].index] - pdrTrace.back().timestamp) < epsilon)
        startingIndex = 1;
    
    // acceleration peak with the minimum distance to the gravity peak
    int nearestAccPeakIdx = 0;
    
    // static to maintain status during the procedure calls
    static PeakEntry::PeakType lastPeakType = PeakEntry::undefined;
    
#ifdef DEBUG_MODE    
    
    static bool resetFiles = YES;
    
    int startIndex = gravityPeakIndices[startingIndex].index;
    int endIndex = gravityPeakIndices[gravityPeakIndices.size()-1].index;
    
    vector<double> gravityPeakIndicesDouble;
    gravityPeakIndicesDouble.reserve(gravityPeakIndices.size());
    
    for (int i = 0; i < gravityPeakIndices.size(); ++i) 
        gravityPeakIndicesDouble.push_back(gravityPeakIndices[i].index - startIndex);
        
    vector<double> userAccPeakIndicesDouble;
    userAccPeakIndicesDouble.reserve(userAccPeakIndices.size());
    
    for (int i = 0; i < userAccPeakIndices.size(); ++i) 
        userAccPeakIndicesDouble.push_back(userAccPeakIndices[i].index);
    
    [self writeVector:userAccPeakIndicesDouble ToFile:"userAccPeakIndices" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&gravityPeakIndicesDouble[startingIndex], &gravityPeakIndicesDouble[gravityPeakIndices.size()-1]) ToFile:"gravityPeakIndices" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&timestamps[startIndex], &timestamps[endIndex]) ToFile:"timestamps" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&filtGravityZ[startIndex], &filtGravityZ[endIndex]) ToFile:"filtGravityZ" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&gravityZ[startIndex], &gravityZ[endIndex]) ToFile:"gravityZ" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&qx[startIndex], &qx[endIndex]) ToFile:"qx" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&filtQx[startIndex], &filtQx[endIndex]) ToFile:"filtQx" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&normAcc[startIndex], &normAcc[endIndex]) ToFile:"normAcc" resetFileContents:resetFiles];
    [self writeVector:vector<double>(&filtAcc[startIndex], &filtAcc[endIndex]) ToFile:"filtAcc" resetFileContents:resetFiles];
    
    NSLog(@"peak diff: %lf", (-pdrTrace.back().timestamp + timestamps[gravityPeakIndicesDouble[0]]));
        
    assert(!pdrTrace.empty());
    
#endif // DEBUG_MODE    
    
    for (int i = startingIndex; i < gravityPeakIndices.size()-1; ++i) {

        size_t j1 = gravityPeakIndices[i].index;
        size_t j2 = gravityPeakIndices[i+1].index;
        
        // check for consecutive up- and down-peaks
        if (gravityPeakIndices[i].peakType == gravityPeakIndices[i+1].peakType) 
            continue;
        
        // skip unnaturally long steps
        if (fabs(timestamps[j1] - timestamps[j2]) > kMaxStepDuration)
            continue;
        
        double timestamp = timestamps[j1];
        
        GLKQuaternion q1, q2;
        
        // acceleration peaks determine the forward walking direction, if only 
        // an acceleration peak lies close enough to the gravity peak
        size_t userAccPeakIndicesSize = userAccPeakIndices.size();
        while (nearestAccPeakIdx + 1 < userAccPeakIndicesSize &&
               ( fabs(timestamps[userAccPeakIndices[nearestAccPeakIdx].index] - timestamp) > 
                 fabs(timestamps[userAccPeakIndices[nearestAccPeakIdx+1].index] - timestamp) )) {
               
            nearestAccPeakIdx++;
        }
        
        if (!userAccPeakIndices.empty() && 
            (fabs(userAccPeakIndices[nearestAccPeakIdx].index - j1) <= kDistanceToAccPeakThreshold ||
            lastPeakType == PeakEntry::undefined)) {
      
            // change forward direction according to the user acceleration peak
            lastPeakType = userAccPeakIndices[nearestAccPeakIdx].peakType;
#ifdef DEBUG_MODE
            NSLog(@"\n\n   Forward direction change");
#endif // DEBUG_MODE
        } else {
            
            // flip 
            if (lastPeakType == PeakEntry::up) 
                lastPeakType = PeakEntry::down;
            else
                lastPeakType = PeakEntry::up;
        }
        
#warning Temporary workaround
        // determine the walking direction basing on the Z-gravity peak type
        lastPeakType = gravityPeakIndices[i].peakType;
        
        if (lastPeakType == PeakEntry::up) {
            q1 = filtQ[j1];
            q2 = filtQ[j2];
        }
        else {
            q2 = filtQ[j1];
            q1 = filtQ[j2];
        }
        
        GLKQuaternion mulQ = GLKQuaternionMultiply(q2, GLKQuaternionConjugate(q1));
        
        // make mulQ.w non-negative by possibly flipping all 4 signs
        if (mulQ.w < 0) {
            mulQ = GLKQuaternionConjugate(mulQ); // flip x, y, z
            mulQ.w = -mulQ.w; // flip w
        }
  
        double stepAngle = GLKMathRadiansToDegrees(acos(mulQ.w));

#ifdef DEBUG_MODE        
        NSLog(@"stepAngle: %lf", stepAngle);
#endif 
        
        // skip the step if the stepAngle is too large/small
        if (stepAngle <= kMinAngleStrideThreshold || stepAngle >= kMaxAngleStrideThreshold)
            continue;
        
        // adjust step length according to the step angle
            
        if (stepAngle < kMinAngleForStepLength)
            stepAngle = kMinAngleForStepLength;
        if (stepAngle > kMaxAngleForStepLength)
            stepAngle = kMaxAngleForStepLength;

        double stepLengthFactor = stepAngle / kMaxAngleForStepLength;
                
        GLKVector2 v = GLKVector2Normalize(GLKVector2Make(mulQ.x, mulQ.y));

        // scale the step & rotate it by -90 Degrees
        double dx = 2.4 * stepLengthFactor * self->stepLength * v.y;
        double dy = 2.4 * stepLengthFactor * self->stepLength * -v.x;
        
        static double deltaDeviation = 1;
    
        TraceEntry pdrStep(timestamp, pdrTrace.back().x + dx, pdrTrace.back().y + dy, 
                           pdrTrace.back().deviation + deltaDeviation);
        
        // add the step to pdrTrace
        pdrTrace.push_back(pdrStep);
                
        double rotatedX = cos(self.pathRotationAmount) * dx - sin(self.pathRotationAmount) * dy;
        double rotatedY = sin(self.pathRotationAmount) * dx + cos(self.pathRotationAmount) * dy;
        
        TraceEntry collaborativeStep(timestamp, collaborativeTrace.back().x + rotatedX, 
                                     collaborativeTrace.back().y + rotatedY,
                                     collaborativeTrace.back().deviation + deltaDeviation);
        
        // add the step to collaborativeTrace
        collaborativeTrace.push_back(collaborativeStep);
        
        // notify logger & view 
        AbsoluteLocationEntry *pdrEntry = [self absoluteLocationEntryFrom:pdrStep];
        AbsoluteLocationEntry *collaborativeEntry = [self absoluteLocationEntryFrom:collaborativeStep];
        [view didReceivePosition:collaborativeEntry
              isResultOfExchange:NO];
        [logger didReceivePDRPosition:pdrEntry];
        [logger didReceiveCollaborativeLocalisationPosition:collaborativeEntry];            
        
        lastStepWasManualCorrection = NO;
    }
    
    [self pruneDataOlderThan:(timestamps[rightIndex] - 2 * kBackBufferSize)];
}

    
- (NSMutableArray *)collaborativeTraceToNSMutableArrayStartingAt:(list<TraceEntry>::iterator) startingPosition {

    NSMutableArray *rotatedPath = [NSMutableArray array];
    
    for (auto it = startingPosition; it != collaborativeTrace.cend(); ++it) {
        [rotatedPath addObject:[self absoluteLocationEntryFrom:*it]];
    }
    
    return rotatedPath;    
}

    
#pragma mark -

    
- (id)init {
    
    self = [super init];
    if (self) {
        view = nil;
        logger = nil;
        
        lastStepWasManualCorrection = NO;
        
        computePDRqueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);//dispatch_queue_create("PDR computation queue", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

    
- (void)dealloc {
    
    //dispatch_release(computePDRqueue);
    [super dealloc];
}

@end
