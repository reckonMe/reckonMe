//
//  Ble.m
//  rssi
//
//  Created by Hussein Aboelseoud on 5/10/13.
//  Copyright (c) 2013 Hussein Aboelseoud. All rights reserved.
//

#import "Ble.h"
#import <ios-ntp/ios-ntp.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <ios-ntp/NSDate+NetworkClock.h>
#include "functions.h"

@interface Ble () <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@property (strong, retain) CBCentralManager      *centralManager;
@property (strong, retain) CBPeripheralManager   *peripheralManager;
@property (strong, retain) NSMutableArray        *peripherals;
@property (strong, retain) NSMutableArray        *RSSIs;
@property (strong, nonatomic) NSMutableArray     *dictionaries;

@end


@implementation Ble

@synthesize couch;

#pragma mark - View Lifecycle

-(id)init {
    self = [super init];
	
    if (self != nil) {
    
        // Initialize Arrays
        _peripherals = [[NSMutableArray alloc]init];
        _RSSIs = [[NSMutableArray alloc]init];
        _dictionaries = [[NSMutableArray alloc]init];
    
        // Start up the CBCentralManager
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
        // Start up the CBPeripheralManager
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        
        couch = [CouchDBController sharedInstance];
        
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self  selector:@selector(sync) userInfo:nil repeats:YES];
    }
    return self;
}

// Display an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal {
    if (error) {
        message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedDescription];
    }
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: (fatal ? @"Fatal Error" : @"Error")
                                                    message: message
                                                   delegate: (fatal ? self : nil)
                                          cancelButtonTitle: (fatal ? @"Quit" : @"Sorry")
                                          otherButtonTitles: nil];
    [alert show];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    
    // The state must be CBCentralManagerStatePoweredOn...
    // Start scanning
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NBULogInfo(@"Scanning started");
}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    NSString *name = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    
    if(name == nil)
        return;
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSDate *date = [NSDate networkDateWithServer:@"iphone"];
    
    NSString *milliseconds;
    NSString *test = [NSString stringWithFormat:@"%f", [date timeIntervalSinceReferenceDate]];
    for (int c = 0; c < test.length; c++){
        if([test characterAtIndex:c] == '.'){
            milliseconds = [test substringWithRange:NSMakeRange(c+1, 3)];
            break;
        }
    }
    
    NBULogInfo(@"%@:%@ %@ %@", [dateFormatter stringFromDate: date], milliseconds, name , RSSI);
    
    NSDictionary *contents = [NSDictionary dictionaryWithObjectsAndKeys:
                              name, @"dest-mac",
                              RSSI, @"rssi",
                              [NSString stringWithFormat:@"%@:%@",[dateFormatter stringFromDate: date], milliseconds], @"timestamp",
                              nil];
    
    [_dictionaries addObject:contents];
    
    //search for the new peripheral in the list of old peripherals
    Boolean flag = false;
    int i;
    for(i = 0; i < _peripherals.count; i++) {
        NSString *per = [_peripherals objectAtIndex:i];
        if([per isEqualToString:name] ||[peripheral.name isEqualToString:per]) {
            flag = true;
            break;
        }
    }
    // if peripheral is new
    if(!flag){
        //add peripheral to array
        [_peripherals addObject:[NSString stringWithFormat:@"%@", name]];
        [_RSSIs addObject:RSSI.description];
    } else {
        _peripherals [i] = name;
        // update RSSI
        _RSSIs[i] = RSSI.description;
    }
    
    // Start advertising
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey : getMacAddress()}];
    
    
    // Start scanning
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
}

- (void) sync
{
    if([_dictionaries count] > 0){
        NSDictionary *contents = [NSDictionary dictionaryWithObjectsAndKeys:
                                  getMacAddress(), @"source_id",
                                  _dictionaries, @"ble",
                                  nil];
        
        [couch pushBluetoothDataDocument:contents];
        
        _dictionaries = [[NSMutableArray alloc]init];
    }
    
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    // Opt out from any other state
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    // We're in CBPeripheralManagerStatePoweredOn state...
    
    // Start advertising
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey : getMacAddress()}];
    NBULogInfo(@"Advertising started");
}

@end
