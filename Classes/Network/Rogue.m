//
//  Rogue.m
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//

#import "Rogue.h"

static void socketHandler (CFSocketRef socket, 
						   CFSocketCallBackType callbackType, 
						   CFDataRef address, 
						   const void *data, 
						   void *info) 
{
	CFSocketContext ctx;
	int code = 0;
	Rogue *rogue = (Rogue*) info;
	
	CFSocketGetContext(socket, &ctx);
	
	if ([rogue isKindOfClass:[Rogue class]]) {
		switch (callbackType) {
			case kCFSocketDataCallBack:
				[rogue socket:socket hasData:(NSData*)data];
				break;
			case kCFSocketConnectCallBack:
				if (data != NULL)
					code = *((int*)data);
				break;
			case kCFSocketWriteCallBack:
				[rogue socket:socket isWritable:YES];
				break;
			default:
				NSLog(@"Unexpected callback %d", callbackType);
				break;
		}
	}
}

@implementation Rogue

- (id)initWithNativeSocket:(CFSocketNativeHandle)nativeSocket {
	self = [super init];
	if (self) {
		request = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
		response = CFHTTPMessageCreateResponse (kCFAllocatorDefault, 200, (CFStringRef)@"OK", kCFHTTPVersion1_1);
		
		CFSocketContext ctx = { 0, self, 0, 0, 0 };

		socket = CFSocketCreateWithNative (
					kCFAllocatorDefault,
					nativeSocket,
					kCFSocketDataCallBack|kCFSocketConnectCallBack|kCFSocketWriteCallBack,
					socketHandler,
					&ctx
				);
		CFRunLoopSourceRef loopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0);
		CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, kCFRunLoopCommonModes);
		CFRelease(loopSource);
		
		[self retain];	// we own ourselves, which I'm not sure is kosher in iOS-land
	}
	
	return self;
}

- (void)dealloc {
	if (request)
		CFRelease(request);
	if (response)
		CFRelease(response);
	if (socket) {
		CFRelease(socket);
	}
	if (fileManager)
		[fileManager release];
	[super dealloc];
}

- (void)socket:(CFSocketRef)socket hasData:(NSData*)data {
	CFHTTPMessageAppendBytes (request, [data bytes], [data length]);
	if (CFHTTPMessageIsHeaderComplete (request))
		[self processRequest];
}

- (void)socket:(CFSocketRef)socket isWritable:(BOOL)writable {
	NSLog(@"Socket is writable");
}

- (void)socket:(CFSocketRef)socket connectedWithError:(NSInteger)error {
	NSLog(@"Connect with code %d", error);
	if (error != 0)
		[self release];
}

- (void)processRequest {
	if (!fileManager)
		fileManager = [[[NSFileManager alloc] init] autorelease];
	
	BOOL isDir;
	NSString *method = (NSString*) CFHTTPMessageCopyRequestMethod (request);
	NSURL *url = (NSURL*) CFHTTPMessageCopyRequestURL (request);
	
	if ([method isEqualToString:@"GET"]) {
		NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *filePath = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:[url path]];
		NSLog(@"Looking at path %@", filePath);
		
		if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir)
			filePath = [filePath stringByAppendingPathComponent:@"index.html"];
		
		NSData *data = [fileManager contentsAtPath:filePath];
		if (!data)
			data = [NSData dataWithBytes:"file not found" length:14];
		
		if (data) {
			CFHTTPMessageSetBody (response, (CFDataRef)data);
			CFDataRef output = CFHTTPMessageCopySerializedMessage (response);
			CFSocketSendData (socket, NULL, output, 100.0);
		}
	}
	CFSocketInvalidate(socket);
}

@end
