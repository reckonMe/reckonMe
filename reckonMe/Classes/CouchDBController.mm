//
//  CouchDBController.m
//  reckonMe
//
//  Created by Hussein Aboelseoud on 7/3/13.
//
//


#import "CouchDBController.h"
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

static CouchDBController *sharedSingleton;

@implementation CouchDBController

@synthesize database;
@synthesize pull;
@synthesize push;
@synthesize remoteURL;
@synthesize pdr;
@synthesize query;
@synthesize dataSource;
@synthesize notyet; 

+ (void)initialize {
    
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[CouchDBController alloc] init];
    }
}

- (id)init {
    
    self = [super init];
    if (self) {
        
        NSError* error;
        self.database = [[CBLManager sharedInstance] createDatabaseNamed: @"ble"
                                                                   error: &error];
        
        remoteURL = [NSURL URLWithString:@"http://dfki-1239.dfki.uni-kl.de:5984/ble"];
        //    remoteURL = [NSURL URLWithString:@"http://192.168.31.201:5984/ble"];
        
        NSArray *repls = [database replicateWithURL:remoteURL exclusively: NO];
        pull = [repls objectAtIndex: 0];
        pull.filter = @"ble/myposition";
        push = [repls objectAtIndex: 1];
        [pull start];
        
        CBLView* view = [database viewNamed: @"dest"];
        [view setMapBlock: MAPBLOCK({
            id dest = [doc objectForKey: @"dest"];
            if (dest && [dest isEqualToString: [self getMacAddress]])
                emit(dest, doc);
        }) version: @"1.0"];
        
        query = [[[database viewNamed:@"dest"] query] asLiveQuery];
        query.descending = YES;
        
        dataSource = [[CBLUITableSource alloc] init];
        dataSource.query = query;
        
        pdr = [PDRController sharedInstance];
        
        notyet = TRUE;
        
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self  selector:@selector(sync) userInfo:nil repeats:YES];

    }
    
    return self;
}


+(CouchDBController *)sharedInstance {
    if (sharedSingleton == nil) {
        sharedSingleton = [[CouchDBController alloc] init];
    }
    return sharedSingleton;
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
        NSLog(@"Error: %@", errorFlag);
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

- (void)pushStepWithSource:(NSString*)macAddress location:(CLLocationCoordinate2D)location timestamp:(NSString*)timestamp{
    
    CBLDocument* doc = [database untitledDocument];
        
    NSDictionary *position = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithDouble:location.latitude], @"latitude",
                              [NSNumber numberWithDouble:location.longitude], @"longitude",
                              nil];
    
    NSDictionary *contents = [NSDictionary dictionaryWithObjectsAndKeys:
                              macAddress, @"source",
                              @"elvis", @"dest",
                              position, @"location",
                              timestamp, @"timestamp",
                              nil];
    NSError *error;

    [doc putProperties: contents error: &error];
}

- (void)pushBluetoothDataDocument:(NSDictionary*)dictionary{
    
    CBLDocument* doc = [database untitledDocument];
    NSError *error;
    [doc putProperties: dictionary error: &error];
    
}

- (void)sync{
    if(notyet && [[dataSource rows]count] > 0){
        CBLQueryRow *row = [dataSource rowAtIndex:0];
        CBLDocument *doc = [row document];

        NSMutableDictionary *docContent = [doc.properties mutableCopy];
        NSMutableDictionary *location = [docContent valueForKey:@"location"];
        NSMutableArray *positions = [location valueForKey:@"positions"];
        pdr.LatArray = [[NSMutableArray alloc]init];
        pdr.LonArray = [[NSMutableArray alloc]init];
        for(int i = 0; i < positions.count ; i++){
            double lat = [[positions[i] valueForKey:@"latitude"] doubleValue];
            double lon = [[positions[i] valueForKey:@"longitude"] doubleValue];
            [pdr addLocationWithLat:lat Lon:lon];
        }
        notyet = FALSE;
    }
    [pull start];
    [push start];
}

@end