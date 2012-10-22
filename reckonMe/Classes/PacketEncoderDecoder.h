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

#import <Foundation/Foundation.h>

//Bonjour-name of the service advertised
#define SESSIONID @"iphonePDR"

typedef enum {
	
    Off,
    Disconnected,
    Connecting,
	Connected
    
} ConnectionState;

typedef enum {
    
    PositionEstimate,
    PositionEstimateACK,
    PositionEstimateACKACK,
    
    Pling = 123,
    StartSoundEmission

} PacketType;

//packet header type
typedef uint8_t header_t;	//"256 values ought to be enough for anybody!" hahaha 


//NSData objects encoded/decoded with this class basically consist of a header of "PacketType",
//followed by the respective integer types in little endian and the doubles in a -- according to Apple --
//"platform-independant" representation (presumably big endian?)
@interface PacketEncoderDecoder : NSObject {
	
}
+(NSMutableData *)startNewPacketOfType:(PacketType)type withPayloadLength:(int)length;

+(void)encodeDouble:(double)value into:(NSMutableData *)data;
+(double)decodeDoubleFrom:(NSData *)data atOffset:(int *)offset;

+(void)encodeInt32:(uint32_t)value into:(NSMutableData *)data;
+(uint32_t)decodeInt32From:(NSData *)data atOffset:(int *)offset;

@end
