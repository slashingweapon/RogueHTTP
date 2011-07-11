//
//  Rogue.h
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFHTTPMessage.h>


#define ROGUE_BUFFER_SIZE 4098

typedef enum {
	RogueStateStartup,
	RogueStateReceiveRequestHeader,
	RogueStateReceiveRequestBody,
	RogueStateProcessRequest,
	RogueStateSendResponseHeader,
	RogueStateSendResponseBody,
	RogueStateStreamError,
	RogueStateShutDown,
	RogueStatePostShutdown
} RogueState;

@interface Rogue : NSObject <NSStreamDelegate> {
	CFSocketNativeHandle sockHandle;
	
	RogueState state;
	CFHTTPMessageRef request;

	NSInputStream *netInStream;
	NSData *netInBuffer;
	BOOL netInReady;
	
	NSInputStream *headerInStream;
	BOOL headerInReady;
	
	NSInputStream *fileInStream;
	NSData *fileInBuffer;
	BOOL fileInReady;
	NSUInteger fileInOffset;
	
	NSOutputStream *netOutStream;
	BOOL netOutReady;
}

- (id)initWithNativeSocket:(CFSocketNativeHandle)nativeSocket;
- (void)closeStream:(NSStream **)targetStream;
- (void)advanceState;
- (void)processRequest;

@end
