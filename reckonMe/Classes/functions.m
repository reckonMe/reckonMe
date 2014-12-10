//
//  functions.m
//  reckonMe
//
//  Created by Benjamin Thiel on 10.12.14.
//
//

#include "functions.h"
#import <AdSupport/ASIdentifierManager.h>

NSString* getMacAddress() {
    
    return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}