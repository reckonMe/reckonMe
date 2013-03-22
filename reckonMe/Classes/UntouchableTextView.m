//
//  UntouchableTextView.m
//  reckonMe
//
//  Created by Benjamin Thiel on 22.03.13.
//
//

#import "UntouchableTextView.h"

@implementation UntouchableTextView

//prevents the user from interacting with this view
- (BOOL)canBecomeFirstResponder {
    
    return NO;
}

@end
