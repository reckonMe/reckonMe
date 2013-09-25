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
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

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

- (NSString *)getMacAddress
{
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = NULL;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0)
        errorFlag = @"if_nametoindex failure";
    else
    {
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0)
            errorFlag = @"sysctl mgmtInfoBase failure";
        else
        {
            // Alloc memory based on above call
            msgBuffer =(char *) malloc(length);
            if (msgBuffer == NULL)
                errorFlag = @"buffer allocation failure";
            else
            {
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0)
                    errorFlag = @"sysctl msgBuffer failure";
            }
        }
    }
    
    // Befor going any further...
    if (errorFlag != NULL)
    {
        NBULogError(@"error: %@", errorFlag);
        return errorFlag;
    }
    
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    
    // Copy link layer address data in socket structure to an array
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                  macAddress[0], macAddress[1], macAddress[2],
                                  macAddress[3], macAddress[4], macAddress[5] + 1];
    
    // Release the buffer memory
    free(msgBuffer);
    
    return macAddressString;
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
    
    NSDate *date = [NSDate networkDate];
    
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
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey : [self getMacAddress]}];
    
    
    // Start scanning
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
}

- (void) sync
{
    if([_dictionaries count] > 0){
        NSDictionary *contents = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [self getMacAddress], @"source-mac",
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
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey : [self getMacAddress]}];
    NBULogInfo(@"Advertising started");
}

@end
