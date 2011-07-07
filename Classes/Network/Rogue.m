//
//  Rogue.m
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//

#import "Rogue.h"

/*	This is the code that gets called by our run loop when something intereting happens to our socked.
	We dereference the info pointer to our class pointer, and call an approprite method.
 
	Note the toll-free bridging between CFDataRef and NSData.  You'll a lot off that here.  We're getting
	closer to the OS than iOS programs usually need to.
 */
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
		state = RogueStateStartup;
		
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
		
		state = RogueStateReceivingRequest;
		[self retain];
	}
	
	if (!mimeTypes)
		mimeTypes  = [[NSDictionary dictionaryWithObjectsAndKeys:
					   @"audio/mpeg", @"mp3",
					   @"audio/vnd.wave", @"wav",
					   @"application/javascript", @"js",
					   @"application/pdf", @"pdf",
					   @"text/plain", @"txt",
					   @"text/html", @"html",
					   @"text/html", @"htm",
					   @"text/xml", @"xml",
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
	if (socket)
		CFRelease(socket);
	if (fileManager)
		[fileManager release];
	if (outputData)
		CFRelease(outputData);
	
	[super dealloc];
}

- (void)socket:(CFSocketRef)leSocket hasData:(NSData*)data {
	if (state == RogueStateReceivingRequest) {
		CFHTTPMessageAppendBytes (request, [data bytes], [data length]);
		if (CFHTTPMessageIsHeaderComplete (request))
			[self processRequest];
	} else {
		NSLog(@"Extra data on %d in state %d", CFSocketGetNative(leSocket), state);
		NSString *huh = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
		NSLog(@"%@", huh);
		[huh release];
	}
}

- (void)socket:(CFSocketRef)leSocket isWritable:(BOOL)writable {
	NSLog(@"Socket %d is writable in state %d", CFSocketGetNative(leSocket), state);	
}

- (void)socket:(CFSocketRef)leSocket connectedWithError:(NSInteger)error {
	if (error != 0) {
		state = RogueStateShuttingDown;
		CFSocketInvalidate(socket);
		[self autorelease];
	}
}

- (void)processRequest {
	if (!fileManager)
		fileManager = [[NSFileManager alloc] init];
	
	int code = 200;
	BOOL isDir;
	NSString *method = (NSString*) CFHTTPMessageCopyRequestMethod (request);
	NSURL *url = (NSURL*) CFHTTPMessageCopyRequestURL (request);
	NSLog(@"Socket %d wants %@", CFSocketGetNative(socket), [url path]);
	
	if ([method isEqualToString:@"GET"]) {
		NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *filePath = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:[url path]];
		
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
			outputData = CFHTTPMessageCopySerializedMessage (response);

			NSLog(@"Sending output to %d", CFSocketGetNative(socket));
			state = RogueStateSendingResponse;
			CFSocketEnableCallBacks(socket, kCFSocketWriteCallBack);
			CFSocketError err = CFSocketSendData (socket, NULL, outputData, 100.0);
			if (err)
				NSLog(@"Socket %d error %d", CFSocketGetNative(socket), err);
			
			CFRelease(response);
		}
	}
	
	state = RogueStateShuttingDown;
	CFSocketInvalidate(socket);
	[self autorelease];
}

@end
