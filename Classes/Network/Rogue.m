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

static NSDictionary *mimeTypes = nil;

@implementation Rogue

- (id)initWithNativeSocket:(CFSocketNativeHandle)nativeSocket {
	self = [super init];
	if (self) {
		request = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
		
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
	
	if (!mimeTypes)
		mimeTypes  = [[NSDictionary dictionaryWithObjectsAndKeys:
						@"text/plain", @"txt",
						@"text/html", @"html",
						@"text/html", @"htm",
						@"image/jpeg", @"jpg",
						@"image/jpeg", @"jpeg",
						@"image/gif", @"gif",
						@"image/tiff", @"tiff",
						@"image/png", @"png",
						nil
						] retain];
	return self;
}

- (void)dealloc {
	if (request)
		CFRelease(request);
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
	// NSLog(@"Socket is writable");
}

- (void)socket:(CFSocketRef)socket connectedWithError:(NSInteger)error {
	// NSLog(@"Connect with code %d", error);
	if (error != 0)
		[self release];
}

- (void)processRequest {
	if (!fileManager)
		fileManager = [[[NSFileManager alloc] init] autorelease];
	
	int code = 200;
	BOOL isDir;
	NSString *method = (NSString*) CFHTTPMessageCopyRequestMethod (request);
	NSURL *url = (NSURL*) CFHTTPMessageCopyRequestURL (request);
	
	if ([method isEqualToString:@"GET"]) {
		NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *filePath = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:[url path]];
		// NSLog(@"Looking at path %@", filePath);
		
		if ([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir)
			filePath = [filePath stringByAppendingPathComponent:@"index.html"];
		
		NSData *data = [fileManager contentsAtPath:filePath];
		if (!data) {
			code = 400;
			data = [NSData dataWithBytes:"file not found" length:14];
		}
		
		if (data) {
			CFHTTPMessageRef response = CFHTTPMessageCreateResponse (kCFAllocatorDefault, code, (CFStringRef)@"OK", kCFHTTPVersion1_0);
			NSString *type = [mimeTypes valueForKey:[filePath pathExtension]];
			if (!type)
				type = @"text/html";

			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef) type);
			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%ld",[data length]]);
			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Location", (CFStringRef) [url path]);

			// Sun, 06 Nov 1994 08:49:37 GMT
			time_t now = time(NULL);
			struct tm timeptr;
			char rawstring[64];
			gmtime_r(&now, &timeptr);
			long len = strftime(rawstring, 64, "%a, %d %b %Y %H:%M:%S %Z", &timeptr);
			if (len>0)
				CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Date", 
												 (CFStringRef)[NSString stringWithCString:rawstring encoding:NSASCIIStringEncoding]);
			
			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Server", 
											 (CFStringRef)@"RogueHTTP/0.1");
			
			
			CFHTTPMessageSetBody (response, (CFDataRef)data);
			CFDataRef output = CFHTTPMessageCopySerializedMessage (response);
			CFSocketSendData (socket, NULL, output, 100.0);
			CFRelease(response);
		}
	}
	CFSocketInvalidate(socket);
}

@end
