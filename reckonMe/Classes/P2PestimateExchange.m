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

#import "P2PestimateExchange.h"
#import "SecondViewController.h"
#import "AlertSoundPlayer.h"
#import "PositionPacket.h"
#import "Settings.h"

//the key used for saving the ID in NSUserDefaults
NSString* const kUniqueDeviceIdentifierKey = @"uniqueDeviceIdentifierKey";
NSString* const kDisplayNamesCache = @"displayNamesCache";
const int kConnectionTimeout = 4;
const int kTransmissionTimeout = 5;

const int kSilenceDuration = 5;//seconds
const double kProximityCapturingInterval = 1;

const double kDeemedProximateThreshold = 10;

//anonymous category extending the class with "private" methods
@interface P2PestimateExchange () 

@property(nonatomic, retain) NSTimer *proximityCaptureTimer;
@property(nonatomic, retain) NSTimer *silenceTimer;
@property(nonatomic, retain) NSString *currentGKPeerIDconnectedTo;

- (void)sendPacketOfType:(PacketType)type toPeer:(NSString *)GKpeerID;

- (void)initiateExchangeWithPeerOnChannel:(audioChannel)channelOfPeer;
- (BOOL)exchangePendingWithPeer:(NSString *)uniquePeerID;
- (BOOL)anyExchangesPending;
- (BOOL)isConnectedOrConnecting;

-(audioChannel)channelForUniquePeerID:(NSString *)uniquePeerID;

-(void)clearHistogram;
-(audioChannel)maxForHistogram:(double *)histogram;
-(void)checkHistogram;

-(void)pauseEmissionForSeconds:(int)seconds;
-(void)restartEmission;

- (void)teardownExchangeWithGKPeerID:(NSString *)gkPeerID;

//session management
- (void)stopGKSession;
- (void)startGKSession;
- (void)restartGKSession;
- (void)gentlyRestartGKSession;

//name conversions
-(NSString *)displayNameForGKPeerID:(NSString *)GKpeerID;
-(NSString *)uniqueIDforGKPeerID:(NSString *)GKPeerID;
-(NSString *)displayNameForUniquePeerID:(NSString *)uniquePeerID;

-(void)logStatus:(NSString *)status forGKPeer:(NSString *)gkPeerID;

@end


@implementation P2PestimateExchange

@synthesize delegate;
@synthesize proximityCaptureTimer, silenceTimer;
@synthesize currentGKPeerIDconnectedTo;
@synthesize proximityDetectionMode;
@synthesize beaconPosition;

static P2PestimateExchange *sharedSingleton;

+(P2PestimateExchange *)sharedInstance {
    
    return sharedSingleton;
}


#pragma mark -
#pragma mark initialization methods

//Is called by the runtime in a thread-safe manner exactly once, before the first use of the class.
//This makes it the ideal place to set up the singleton.
+ (void)initialize
{
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[P2PestimateExchange alloc] init];
    }
}

-(id)init {
    
    self = [super init];
    
    if (self != nil) {
        
        p2pSession = nil;
        
        connectionState = Disconnected;
        
        exchangesPendingACK = [[NSMutableSet alloc] init];
        exchangesPendingACKACK = [[NSMutableDictionary alloc] init];
        
        timestampsOfLastSuccessfulExchanges = [[NSMutableDictionary alloc] init];
        
        isStarted = NO;
        shouldNagToTurnBluetoothOn = YES;
        
        isBeacon = NO;
        isWalker = NO;
        
        self.currentGKPeerIDconnectedTo = nil;
        self.proximityDetectionMode = NO;
        
        self.delegate = nil;
        
        soundDetector = [SoundDetector sharedInstance];
        soundDetector.delegate = self;
        
        ownUniquePeerID = [[[NSUserDefaults standardUserDefaults] stringForKey:kUniqueDeviceIdentifierKey] retain];
        
        //doesn't exist? create one and save it in NSUserDefaults
        if (!ownUniquePeerID) {
            
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            ownUniquePeerID = (NSString *) CFUUIDCreateString(NULL, uuid);
            
            [[NSUserDefaults standardUserDefaults] setObject:ownUniquePeerID
                                                      forKey:kUniqueDeviceIdentifierKey];
            
            //release the uuid but not the string, as this is done in dealloc
            CFRelease(uuid);
        }

        displayNamesForUniquePeerIDs = [[NSMutableDictionary alloc] init];
        
        //fetch the display names cache from disk
        NSDictionary *savedDisplayNames = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDisplayNamesCache];
        if (savedDisplayNames) {
            
            if ([savedDisplayNames count] <= 50) {
                
                //use it
                [displayNamesForUniquePeerIDs setDictionary:savedDisplayNames];
            
            } else {
                
                //purge the dictionary and start collecting anew
                [[NSUserDefaults standardUserDefaults] setObject:nil
                                                          forKey:kDisplayNamesCache];
            }
        }
    }
    return self;
}

-(void)dealloc{
    
	[self stop]; //also releases p2pSession
    [exchangesPendingACK release];
    [exchangesPendingACKACK release];
    
    [timestampsOfLastSuccessfulExchanges release];
    
    [displayNamesForUniquePeerIDs release];
    [ownUniquePeerID release];
    
	[super dealloc];
}


#pragma mark -
#pragma mark managing the session

- (void) startBeaconModeAtPosition:(AbsoluteLocationEntry *)position {
    
    if (!isStarted && !isWalker) {
        
        isBeacon = YES;
        self.beaconPosition = position;
        [self clearHistogram];
        
        [self startGKSession];
        
#ifndef SOUND_TESTS
        [soundDetector startDetection];
#endif

        self.proximityCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:kProximityCapturingInterval
                                                                      target:self 
                                                                    selector:@selector(checkHistogram) 
                                                                    userInfo:nil
                                                                     repeats:YES];
        
        isStarted = YES;
        
    }
}

- (void)startWalkerModeOnChannel:(audioChannel)_channel {
    
    if (!isStarted && !isBeacon) {
        
        isWalker = YES;
        channel = _channel;

        [self startGKSession];
        
        //[soundDetector startEmissionOnChannel:channel];
        
        isStarted = YES;
    }
}

- (void) stop {
    
    if (isStarted) {
        
        [self.proximityCaptureTimer invalidate];
        self.proximityCaptureTimer = nil;
        
        [self.silenceTimer invalidate];
        self.silenceTimer = nil;
        
        [soundDetector stopDetection];
        [soundDetector stopEmission];
        
        [self stopGKSession];
        
        //save the display names cache
        [[NSUserDefaults standardUserDefaults] setObject:displayNamesForUniquePeerIDs
                                                  forKey:kDisplayNamesCache];
        //force writing to disk NOW!
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        isStarted = NO;
        isWalker = NO;
        isBeacon = NO;
        connectionState = Off;
    }
}

- (void)startGKSession {
    
    if (isWalker) {
        
        p2pSession = [[GKSession alloc] initWithSessionID:SESSIONID
                                              displayName:[NSString stringWithFormat:@"%d%@", channel, ownUniquePeerID]
                                              sessionMode:GKSessionModePeer];
    }
    
    if (isBeacon) {
        
        p2pSession = [[GKSession alloc] initWithSessionID:SESSIONID
                                              displayName:[NSString stringWithFormat:@"B%@", ownUniquePeerID]
                                              sessionMode:GKSessionModeClient];
    }

    p2pSession.disconnectTimeout = kConnectionTimeout;
    
    p2pSession.delegate = self;
    [p2pSession setDataReceiveHandler:self withContext:nil];
    
    p2pSession.available = YES;
    
    connectionState = Disconnected;

}


- (void)stopGKSession {
    
    connectionState = Off;
    
    self.currentGKPeerIDconnectedTo = nil;
    
    p2pSession.available = NO;
    [p2pSession disconnectFromAllPeers];
    
    p2pSession.delegate = nil;
    [p2pSession setDataReceiveHandler:nil withContext:nil];
    
    [p2pSession release];
    p2pSession = nil;
    
    [exchangesPendingACKACK removeAllObjects];
    [exchangesPendingACK removeAllObjects];
}

-(void)restartGKSession {
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
#ifdef P2P_TESTS
        [[SecondViewController sharedInstance] addToLog:@"Restarting GKSession."];
#endif
       
        [self stopGKSession];
        [self startGKSession];
    });
}

- (void)gentlyRestartGKSession {
    
    NSUInteger availableCount = [[p2pSession peersWithConnectionState:GKPeerStateAvailable] count];
    NSUInteger connectingCount = [[p2pSession peersWithConnectionState:GKPeerStateConnecting] count];
    NSUInteger connectedCount = [[p2pSession peersWithConnectionState:GKPeerStateConnected] count];
    NSUInteger disconnectedCount = [[p2pSession peersWithConnectionState:GKPeerStateDisconnected] count];
    NSUInteger unavailableCount = [[p2pSession peersWithConnectionState:GKPeerStateUnavailable] count];
    
#ifdef P2P_TESTS
    [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"[%d, %d, %d, %d, %d]",
                                                     availableCount,
                                                     connectingCount,
                                                     connectedCount,
                                                     disconnectedCount,
                                                     unavailableCount]];
#endif
    
    if (   availableCount
        == connectingCount
        == connectedCount
        == disconnectedCount
        == unavailableCount
        == 0) {
        
        [self restartGKSession];
    }
    
}

//MARK: - ID and naming conversions
-(NSString *)uniqueIDforGKPeerID:(NSString *)GKPeerID {
    
    return [p2pSession displayNameForPeer:GKPeerID];
}

-(NSString *)displayNameForUniquePeerID:(NSString *)uniquePeerID {
    
    NSString *result = [displayNamesForUniquePeerIDs objectForKey:uniquePeerID];
    
    if (result) {
        
        return result;
        
    } else {
        
        return [NSString stringWithFormat:@"unknown (ID: %@)", uniquePeerID];
    }
}

-(NSString *)displayNameForGKPeerID:(NSString *)GKpeerID {
    
    return [self displayNameForUniquePeerID:[self uniqueIDforGKPeerID:GKpeerID]];
}

-(audioChannel)channelForUniquePeerID:(NSString *)uniquePeerID {
    
    NSString *firstChar = [uniquePeerID substringToIndex:1];
    
    if ([firstChar isEqualToString:@"B"]) {
        
        //anther beacon we don't care about
        return UCHAR_MAX;
        
    } else {
        
        NSInteger channelNumber = [firstChar integerValue];
        if (   channelNumber >= 0
            && channelNumber < kNumChannels) {
            
            return channelNumber;
        
        } else { 
        
            return UCHAR_MAX;
        }
    }
}

-(void)logStatus:(NSString *)status forGKPeer:(NSString *)gkPeerID {
    
#ifdef P2P_TESTS
    [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"[%@] %@",
                                              status,
                                              [self displayNameForGKPeerID:gkPeerID]]];
#endif
}

//MARK: -
-(BOOL)exchangePendingWithPeer:(NSString *)uniquePeerID {
    
    return [exchangesPendingACK containsObject:uniquePeerID] || [exchangesPendingACKACK objectForKey:uniquePeerID];
}

-(BOOL)anyExchangesPending {
    
    return ([exchangesPendingACK count] > 0) || ([exchangesPendingACKACK count] > 0);
}

-(void)teardownExchangeWithGKPeerID:(NSString *)gkPeerID {
    
    NSString *uniquePeerID = [self uniqueIDforGKPeerID:gkPeerID];
    
    if (uniquePeerID) {
        
        //delete its position
        [exchangesPendingACKACK removeObjectForKey:uniquePeerID];
        [exchangesPendingACK removeObject:uniquePeerID];
    }
}

-(BOOL)isConnectedOrConnecting {
    
    return (connectionState == Connected) || (connectionState == Connecting);
}

-(void)initiateExchangeWithPeerOnChannel:(audioChannel)channelOfPeer {
    
    NSString *channelNumber = [[NSNumber numberWithInt:channelOfPeer] stringValue];
    
    if (![self isConnectedOrConnecting]) {
        
        //connect to the peer if not already done so
        for (NSString *gkPeerID in [p2pSession peersWithConnectionState:GKPeerStateAvailable]) {
            
            NSString *uniqueID = [self uniqueIDforGKPeerID:gkPeerID];
            
            if ([uniqueID hasPrefix:channelNumber]) {

#ifdef P2P_TESTS
                [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Connecting to: %@",
                                                                 [self displayNameForGKPeerID:gkPeerID]]];
#endif
                connectionState = Connecting;
                [p2pSession connectToPeer:gkPeerID
                              withTimeout:kConnectionTimeout];
                break;
            }
        }
    }
    
    //if already connected and allowed to, initiate exchange
    for (NSString *gkPeerID in [p2pSession peersWithConnectionState:GKPeerStateConnected]) {
        
        NSString *uniqueID = [self uniqueIDforGKPeerID:gkPeerID];
        
        if ([uniqueID hasPrefix:channelNumber]) {
            
            if (![self exchangePendingWithPeer:uniqueID]) {

                if ([self shouldConnectToPeerWithGKPeerID:gkPeerID]) {
                    
                    [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"trying: %@", [self displayNameForUniquePeerID:uniqueID]]];
                    [self sendPacketOfType:PositionEstimate
                                    toPeer:gkPeerID];
                    
                }
            }
            break;
        }
    }
}

-(BOOL)shouldConnectToPeerWithGKPeerID:(NSString *)gkPeerID {
    
    if (isBeacon) {
        
        return YES;
    }
    
    NSString *uniquePeerID = [self uniqueIDforGKPeerID:gkPeerID];
    
    //do we know the peer
    if (uniquePeerID) {
        
        //it is not an old session of ourself? (which seems to happen)
        if (![uniquePeerID isEqualToString:ownUniquePeerID]) {
            
            BOOL shouldConnect = [self.delegate shouldConnectToPeerID:uniquePeerID];
            BOOL alreadyExchanging = [self exchangePendingWithPeer:uniquePeerID];
            
            return (shouldConnect && !alreadyExchanging);
            
        } else {
            
            return NO;
        }
        
    } else {
        
        return NO;
    }
}

//MARK: - sound related
-(void)soundDetector:(SoundDetector *)detector didDetectSoundOnChannel:(audioChannel)_channel withAverageVolume:(float)avgVolume {
    
    if (isBeacon) {
        
        //add to histograms and check later in checkHistogram
        soundHistogram[_channel]++;
        soundVolumes[_channel] += avgVolume;
    }

    if (isWalker) {
        
        [self initiateExchangeWithPeerOnChannel:_channel];
    }
}

-(void)clearHistogram {
    
    memset(soundHistogram, 0, kNumChannels * sizeof(NSInteger));
    memset(soundVolumes, 0, kNumChannels * sizeof(double));
}

-(audioChannel)maxForHistogram:(double *)histogram {
    
    double max = 0;
    NSInteger maxIndex = 0;
    
    for (int i = 0; i < kNumChannels; i++) {
        
        if (histogram[i] >= max) {
            
            max = histogram[i];
            maxIndex = i;
        }
    }
    return maxIndex;
}

-(void)checkHistogram {
    
    double multipliedHistograms[kNumChannels];
    
    for (int i = 0; i < kNumChannels; i++) {
        
        multipliedHistograms[i] = soundHistogram[i] * soundVolumes[i];
    }

    /*NSLog(@"det=[%d,%d,%d,%d,%d,%d]", soundHistogram[0], soundHistogram[1], soundHistogram[2], soundHistogram[3], soundHistogram[4], soundHistogram[5]);
    NSLog(@"vol=[%.0f,%.0f,%.0f,%.0f,%.0f,%.0f]", soundVolumes[0], soundVolumes[1], soundVolumes[2], soundVolumes[3], soundVolumes[4], soundVolumes[5]);
        NSLog(@"mult=[%.0f,%.0f,%.0f,%.0f,%.0f,%.0f]", multipliedHistograms[0], multipliedHistograms[1], multipliedHistograms[2], multipliedHistograms[3], multipliedHistograms[4], multipliedHistograms[5]);*/
    [self clearHistogram];
    
#ifdef SOUND_TESTS
    if ([[p2pSession peersWithConnectionState:GKPeerStateAvailable] count] > 0) {
        
        [soundDetector startDetection];
        for (int i = 0; i < kNumChannels; i++) {
            
            [soundDetector listenForChannel:i];
        }
        
            [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"[%.0f,%.0f,%.0f,%.0f,%.0f,%.0f]", multipliedHistograms[0], multipliedHistograms[1], multipliedHistograms[2], multipliedHistograms[3], multipliedHistograms[4], multipliedHistograms[5]]];
    } else {
        
            [soundDetector stopDetection];
    }
#else
    if ([self isConnectedOrConnecting]) return;
    
    audioChannel maxChannel = [self maxForHistogram:multipliedHistograms];

    if (multipliedHistograms[maxChannel] >= kDeemedProximateThreshold) {
        
        [self initiateExchangeWithPeerOnChannel:maxChannel];
        [self clearHistogram];
    }
#endif
}

-(void)pauseEmissionForSeconds:(int)seconds {
    
    [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Be quiet for %d sec", seconds]];
    
    [soundDetector stopEmission];
    self.silenceTimer = [NSTimer scheduledTimerWithTimeInterval:seconds
                                                         target:self
                                                       selector:@selector(restartEmission)
                                                       userInfo:nil
                                                        repeats:NO];
}

-(void)restartEmission {
    
    if (isWalker) {
        
        [soundDetector startEmissionOnChannel:channel];
    }
}

-(BOOL)isReceiver:(audioChannel)_channel {
    
    //todo: think of more sophisticated role assignment
    return (_channel % 2) == 0;
}

//MARK: - UIAlertViewDelegate
//called when the user clicked a button on the "turn bluetooth on" nag-screen
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    
    if (buttonIndex == 1) {// = "yes, I will turn bluetooth on
        
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"prefs:root=General&path=Bluetooth"]];
        
    }
    
    if (buttonIndex == 0) {//NO
        
        shouldNagToTurnBluetoothOn = NO;
    }
    
    [NSTimer scheduledTimerWithTimeInterval:30
                                     target:self
                                   selector:@selector(restartGKSession)
                                   userInfo:nil
                                    repeats:NO];
}

#pragma mark -
#pragma mark GKSessionDelegate methods

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error{
    
    NSString *errorMessage = [NSString stringWithFormat:@"Connection with \"%@\" failed. Reason: %@", 
                              [self displayNameForGKPeerID:peerID],
                              [error localizedDescription]];
    
    [[SecondViewController sharedInstance] addToLog:errorMessage];
    
    [self teardownExchangeWithGKPeerID:peerID];
    
    if (isBeacon) {
        
        [self clearHistogram];
    }
    connectionState = Disconnected;
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error {
    
    connectionState = Off;
	
    NSString *errorMessage = [NSString stringWithFormat:@"GKSession failed. Reason: %@",
                              [error localizedDescription]];
    NSLog(@"%@", errorMessage);
    
    
    //Did the session fail due to Bluetooth and WiFi being turned off?
    if (shouldNagToTurnBluetoothOn && (error.code == GKSessionCannotEnableError) && [error.domain isEqualToString:GKSessionErrorDomain]) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"Please turn on Bluetooth in the Settings app."
                                                       delegate:self
                                              cancelButtonTitle:@"No, I won't."
                                              otherButtonTitles:@"Yes, I will.", nil];
        alert.delegate = self;
        [alert show];
        [alert release];
        
        
    } else {//silently retry
        
        //log it on the screen
        [[SecondViewController sharedInstance] addToLog:errorMessage];
        
        //try to restart the session later and pray that it works
        [NSTimer scheduledTimerWithTimeInterval:30
                                         target:self
                                       selector:@selector(startGKSession)
                                       userInfo:nil
                                        repeats:NO];
    }
    
    //dispatch the release of the gksession for later, as we are being called by it
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [self stopGKSession]; 
    });
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID{
	
    //no other connections?
    if (isWalker) {// && connectionState != Connected) {
     
        [session acceptConnectionFromPeer:peerID
                                    error:NULL];
    } else {
        
        [session denyConnectionFromPeer:peerID];
    }
}


- (void)session:(GKSession *)session peer:(NSString *)GKpeerID didChangeState:(GKPeerConnectionState)state{
	
    NSString *stateString = nil;
    
    //retain the ID and display name as they might get deallocated in [self restart];
    NSString *uniquePeerID = [[self uniqueIDforGKPeerID:GKpeerID] retain];
    NSString *peerDisplayName = [[self displayNameForUniquePeerID:uniquePeerID] retain];
    
    //do we actually know who it is and it is not ourself?
    if (uniquePeerID && ![uniquePeerID isEqualToString:ownUniquePeerID]) {
        
        switch (state) {
                
            case GKPeerStateAvailable: // not connected to session, but available for connectToPeer:withTimeout:
            {
                audioChannel peerChannel = [self channelForUniquePeerID:uniquePeerID];
                
                if (isBeacon) {
#ifdef SOUND_TESTS

#else
                    [soundDetector listenForChannel:peerChannel];
#endif
                }
                if (isWalker) {
                    
                    if ([self isReceiver:channel]) {
                        
                        if (![self isReceiver:peerChannel]) {
                            
                            [soundDetector startDetection];
                            [soundDetector listenForChannel:peerChannel];
#ifdef P2P_TESTS
                            [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Connecting to: %@",
                                                                             [self displayNameForGKPeerID:GKpeerID]]];
#endif
                            connectionState = Connecting;
                            [p2pSession connectToPeer:GKpeerID
                                          withTimeout:kConnectionTimeout];
                        }

                    } else {
                        
                        [soundDetector startEmissionOnChannel:channel];
                    }
                }
                stateString = @"A";
            }
                    break;
            case GKPeerStateUnavailable:  // no longer available
                
                //delete its position
                [self teardownExchangeWithGKPeerID:GKpeerID];
                [session cancelConnectToPeer:GKpeerID];
                
                if ([self isReceiver:channel] ) {
                    
                    //stop listening for the peer
                    audioChannel toRemove = [self channelForUniquePeerID:uniquePeerID];
                    if ((toRemove < kNumChannels) && ![self isReceiver:toRemove]) {
                        
                        soundHistogram[toRemove] = 0;
                        
                        [soundDetector stopListeningForChannel:toRemove];
                    }
                }
                stateString = @"U";
                break;
                
            case GKPeerStateConnected: // connected to the session
                
                self.currentGKPeerIDconnectedTo = GKpeerID;
                connectionState = Connected;
                
                break;
                
            case GKPeerStateDisconnected: // disconnected from the session
                
                connectionState = Disconnected;
                
                //delete its position
                [self teardownExchangeWithGKPeerID:GKpeerID];
                self.currentGKPeerIDconnectedTo = nil;
                
                [self gentlyRestartGKSession];
                
                stateString = @"D";
                break;
                
            case GKPeerStateConnecting: // waiting for accept, or deny response
                
                connectionState = Connecting;
                
                break;
                
            default:
                break;
        }

        if (stateString) {
            
            [self logStatus:stateString
                  forGKPeer:GKpeerID];
        }

    }
    [uniquePeerID release];
    [peerDisplayName release];
}

#pragma mark -
#pragma mark GKSession dataHandler
- (void) receiveData:(NSData *)data fromPeer:(NSString *)peer inSession: (GKSession *)session context:(void *)context {
    
    NSString *uniquePeerID = [self uniqueIDforGKPeerID:peer];
    PacketType header;
    int payloadLength = [data length] - sizeof(header_t);
    
    //data contains at least a header and we know the unique peer ID?
    if (payloadLength >= 0 && uniquePeerID) {
        
        //get the header
        NSRange headerRange = {0, sizeof(header_t)};
        header_t headerValue;
        [data getBytes:&headerValue range:headerRange];
        header = (PacketType) headerValue;
        
        switch (header) {
                
            case Pling:
                [[AlertSoundPlayer sharedInstance] playSound:cymbalsSound
                                                   vibrating:NO];
                break;
                
            case StartSoundEmission:
                //todo: remove?
                break;
                
            case PositionEstimate:
                
                if (payloadLength > 0) {//unfortunately we don't know what size to expect
                    
                    NSMutableData *payload = [NSMutableData dataWithData:data];
                    //remove the header
                    [payload replaceBytesInRange:headerRange
                                       withBytes:NULL 
                                          length:0];
                    
                    @try {//to unpack the data
                        
                        PositionPacket *positionPacket = [NSKeyedUnarchiver unarchiveObjectWithData:payload];
                        
                        //remember the peer's name
                        [displayNamesForUniquePeerIDs setObject:positionPacket.displayName
                                                         forKey:uniquePeerID];
                        
                        AbsoluteLocationEntry *peerLocation = positionPacket.location;
                        
                        //have we already send our estimate?
                        if (![self exchangePendingWithPeer:uniquePeerID]) {
                            
                            [self sendPacketOfType:PositionEstimate
                                            toPeer:peer];
                        }
                        
                        //save the position and wait for the ACKACK of our position
                        [exchangesPendingACKACK setObject:peerLocation
                                                   forKey:uniquePeerID];
                        
                        //acknowledge the reception
                        [self sendPacketOfType:PositionEstimateACK
                                        toPeer:peer];
                    }
                    @catch (NSException *exception) {
                        //ToDo: think of something useful to do here
                    }
                    @finally {
                        //and here
                    }
                }
                break;
                
            case PositionEstimateACK:
                
                if (payloadLength == 0) {
                    
                    //acknowledge the reception of the acknowledgement :)
                    [self sendPacketOfType:PositionEstimateACKACK
                                    toPeer:peer];
                    
                    //removing uniquePeerID from exchangesPendingACK takes places when receiving ACKACK in order to prevent both exchangesPendingACK and exchangesPendingACKACK from not contaning the uniquePeerID, which would be interpreted as no exchange going on in exchangePendingWithPeer
                }  
                break;
                
            case PositionEstimateACKACK://Situation: We have the peers position and we know he has ours -> we're done!
                
                if (payloadLength == 0) {
                    
                    AbsoluteLocationEntry *peerLocation = [exchangesPendingACKACK objectForKey:uniquePeerID];
                    
                    if (peerLocation) {
                        
                        [timestampsOfLastSuccessfulExchanges setObject:[NSDate date]
                                                                forKey:uniquePeerID];
                        
                        [self.delegate didReceivePosition:peerLocation
                                                   ofPeer:uniquePeerID];
                        
                        if (isWalker) {
                            
                            if (![self isReceiver:channel]) {
                                
                                [self pauseEmissionForSeconds:kSilenceDuration];
                            }
                        }
                        
                        if (isBeacon) {
                            
                            [self clearHistogram];
                            dispatch_async(dispatch_get_main_queue(), ^(void) {
                                
                                [self restartGKSession];
                            });
                        }
                        
                        [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Exchanged position estimates with \"%@\" at (%.1fm, %.1fm).",
                                                                  [self displayNameForUniquePeerID:uniquePeerID], 
                                                                  peerLocation.northing, 
                                                                  peerLocation.easting]];
                        
                        [AlertSoundPlayer.sharedInstance playSound:exchangedPositionsSound
                                                         vibrating:YES];
                        
                        [exchangesPendingACKACK removeObjectForKey:uniquePeerID];
                        [exchangesPendingACK removeObject:uniquePeerID];
                    }
                }
                break;
                
            default:
                return;
        }
    }
}

- (void)sendPacketOfType:(PacketType)type toPeer:(NSString *)GKpeerID {
    
    NSData *payload = nil;
    NSString *uniquePeerID = [self uniqueIDforGKPeerID:GKpeerID];
    
    switch (type) {
            
        case PositionEstimate:
        {
            if (uniquePeerID) {
                
                AbsoluteLocationEntry *toSend = nil;
                
                if (isWalker) {
                    toSend = [self.delegate positionForExchange];
                }
                if (isBeacon) {
                    toSend = self.beaconPosition;
                }
                
                PositionPacket *positionPacket = [[PositionPacket alloc] initWithLocation:toSend
                                                                              displayName:[UIDevice currentDevice].name];
                
                payload = [NSKeyedArchiver archivedDataWithRootObject:positionPacket];
                [positionPacket release];
                
                [exchangesPendingACK addObject:uniquePeerID];
            }
        }
            break;
            
        case PositionEstimateACK:
            break;
        case PositionEstimateACKACK:
            break;
        case Pling:
            break;
        case StartSoundEmission:
            break;
        default:
            return;
    }
    
    NSMutableData *packet = [PacketEncoderDecoder startNewPacketOfType:type
                                                     withPayloadLength:[payload length]];
    if (payload) {
        
        [packet appendData:payload];
    }
    
    [p2pSession sendData:packet
                 toPeers:[NSArray arrayWithObject:GKpeerID]
            withDataMode:(type == Pling) ? GKSendDataUnreliable : GKSendDataReliable
                   error:NULL];
}

@end
