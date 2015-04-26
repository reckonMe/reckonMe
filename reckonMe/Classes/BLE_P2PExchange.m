//
//  BLE_P2PExchange.m
//  reckonMe
//
//  Created by Benjamin Thiel on 10.12.14.
//
//
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

#import "BLE_P2PExchange.h"
#import "AlertSoundPlayer.h"
#import "Settings.h"

//random UUID generated with uuidgen
NSString *reckonMeUUID = @"97FD5E48-639B-489F-B2F3-3A99C126512C";


//anonymous category extending the class with "private" methods
@interface BLE_P2PExchange ()

@property(nonatomic, retain) NSArray *services;
@property(nonatomic, retain) NSString *advertisement;

@property(nonatomic, retain) CBCentralManager *centralManager;
@property(nonatomic, retain) CBPeripheralManager *peripheralManager;
@property(nonatomic, assign) BOOL shouldAdvertise;
@property(nonatomic, assign) BOOL shouldScan;

-(void)startAdvertising;
-(void)stopAdvertising;
-(void)startScanning;
-(void)stopScanning;

@end

@implementation BLE_P2PExchange

+(instancetype)sharedInstance {
    
    static BLE_P2PExchange *mySharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        mySharedInstance = [[self alloc] init];
    });
    
    return mySharedInstance;
}

//as of iOS8, CBCentralManager- and CBPeripheralManagerState enums have equal values
+ (NSDictionary *)coreBluetoothStateDisplayNames
{
    return @{@(CBCentralManagerStateUnknown) : @"unknown",
             @(CBCentralManagerStateResetting) : @"resetting",
             @(CBCentralManagerStateUnsupported) : @"unsupported",
             @(CBCentralManagerStateUnauthorized) : @"unauthorized",
             @(CBCentralManagerStatePoweredOff) : @"powered off",
             @(CBCentralManagerStatePoweredOn) : @"powered on"};
}

-(instancetype)init {
    
    if (self = [super init]) {
        
        self.shouldAdvertise = NO;
        self.shouldScan = NO;
        
        self.services = @[[CBUUID UUIDWithString:reckonMeUUID]];
        self.advertisement = @"foobar";
        
        self.centralManager = [[[CBCentralManager alloc] initWithDelegate:self
                                                                    queue:nil] autorelease];
        
        self.peripheralManager = [[[CBPeripheralManager alloc] initWithDelegate:self
                                                                          queue:nil] autorelease];
        self.rssiThreshold = [Settings sharedInstance].rssi;
    }
    
    return self;
}

-(void)dealloc {
    
    self.delegate = nil;
    self.services = nil;
    self.advertisement = nil;
    self.advertisedPosition = nil;
    
    self.centralManager = nil;
    self.peripheralManager = nil;
    
    [super dealloc];
}

-(void)setAdvertisedPosition:(AbsoluteLocationEntry *)advertisedPosition {
    
    if (_advertisedPosition != advertisedPosition)
    {
        [_advertisedPosition release];
        _advertisedPosition = advertisedPosition;
        [_advertisedPosition retain];
        
        self.advertisement = [_advertisedPosition toBase64Encoding];
        
        if (self.shouldAdvertise) {
            
            [self stopAdvertising];
            [self startAdvertising];
        }
    }
}

//MARK: - start/stop
-(void)startAdvertising {
    
    [self.peripheralManager startAdvertising:@{   CBAdvertisementDataLocalNameKey : self.advertisement,
                                               CBAdvertisementDataServiceUUIDsKey : self.services}];
}

-(void)stopAdvertising {
    
    [self.peripheralManager stopAdvertising];
}

-(void)startScanning {
    
    self.rssiThreshold = [Settings sharedInstance].rssi;
    [self.centralManager scanForPeripheralsWithServices:self.services
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}]; //allow "duplicates" for constant updates
}

-(void)stopScanning {
    
    [self.centralManager stopScan];
}

-(void)startStationaryBeaconMode {
    
    self.shouldAdvertise = YES;
    self.shouldScan = NO;
    
    [self startAdvertising];
}

-(void)startWalkerMode {
    
    self.shouldAdvertise = YES;
    self.shouldScan = YES;
    
    [self startAdvertising];
    [self startScanning];
}

-(void)stop {
    
    self.shouldAdvertise = NO;
    self.shouldScan = NO;
    
    [self stopAdvertising];
    [self stopScanning];
}

//MARK: - CBCentralManagerDelegate
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    NSLog(@"%@ %@ %@", RSSI, peripheral.name, [advertisementData objectForKey:CBAdvertisementDataLocalNameKey]);
    
    NSInteger signalStrength = [RSSI integerValue];
    if (signalStrength < self.rssiThreshold) return;
    if (signalStrength == 127) return; //occurs quite often and seems to indicate an invalid value
    
    NSString *advertisedData = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if(!advertisedData) return;
    
    NSString *deviceName = peripheral.name;
    if (!deviceName || [deviceName isEqualToString:@""]) return;
    
    if ([self.delegate shouldConnectToPeerID:deviceName]) {
        
        AbsoluteLocationEntry *peerPosition = [[AbsoluteLocationEntry alloc] initWithBase64String:advertisedData];
        BOOL isRealDeviceName = ![deviceName isEqualToString:advertisedData];
        
        //dispatch async??
        [self.delegate didReceivePosition:peerPosition
                                   ofPeer:deviceName
                               isRealName:isRealDeviceName];
        [peerPosition release];
    }
}

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    NSLog(@"CBCentral state: %@", [[[self class] coreBluetoothStateDisplayNames] objectForKey:@(central.state)]);
    
    if (central.state == CBCentralManagerStatePoweredOn
        && self.shouldScan) {
        
        [self startScanning];
        
    }
}

//MARK: - CBPeripheralManagerDelegate
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    
    NSLog(@"CBPeripheral state: %@", [[[self class] coreBluetoothStateDisplayNames] objectForKey:@(peripheral.state)]);
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn
        && self.shouldAdvertise) {
        
        [self startAdvertising];
    }
}

@end
