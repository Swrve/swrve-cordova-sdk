#import "TestHTTPConnection.h"
#import "HTTPLogging.h"
#import "TestHTTPResponse.h"

// TODO: Non static per server
static TestHTTPConnection *sharedInstance = nil;

@implementation TestHTTPConnection

@synthesize defaultResponseBody;
@synthesize defaultResponseCode;

NSData* receivedBodyData;
static NSMutableDictionary* handlers;

+ (void)initialize
{
    handlers = [[NSMutableDictionary alloc] init];
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
    if (self = [super initWithAsyncSocket:newSocket configuration:aConfig]) {
        defaultResponseCode = 200;
        defaultResponseBody = @"";
    }
    sharedInstance = self;
    return self;
}

+(TestHTTPConnection*) sharedInstance
{
    return sharedInstance;
}

+(void)setHandler:(NSString*)url handler:(NSObject<HTTPResponse>*(^)(NSString*, HTTPMessage *request))handler
{
    [handlers setValue:handler forKey:url];
}

+(void)removeHandler:(NSString*)url
{
    [handlers removeObjectForKey:url];
}

+(void)clearHandlers {
    [handlers removeAllObjects];
}

+(void)setDefaultResponseCode:(int)code andBody:(NSString*)body
{
    sharedInstance.defaultResponseCode = code;
    sharedInstance.defaultResponseBody = body;
}

- (NSObject<HTTPResponse>*)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    NSString *filePath = [self filePathForURI:path];
    NSString *documentRoot = [config documentRoot];
    NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];

    NSObject<HTTPResponse>* response = nil;
    NSString* key = nil;
    NSEnumerator *keyEnumerator = handlers.keyEnumerator;
    while ((key = (NSString*)[keyEnumerator nextObject]) != nil && response == nil) {
        if ([self containsString:key in:relativePath]) {
            NSObject<HTTPResponse>*(^handler)(NSString*, HTTPMessage *request) = [handlers objectForKey:key];
            // Fill request with data from POST
            request.body = receivedBodyData;
            receivedBodyData = nil;
            response = handler(relativePath, request);
        }
    }
    
    if (!response) {
        response = [[TestHTTPResponse alloc] initWithData:[self.defaultResponseBody dataUsingEncoding:NSUTF8StringEncoding]];
        ((TestHTTPResponse*)response).responseStatus = self.defaultResponseCode;
    }
    
    return response;
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    // Support POSTs too
    return YES;
}

- (void)processBodyData:(NSData *)postDataChunk
{
    receivedBodyData = postDataChunk;
}

- (BOOL)containsString:(NSString*)hay in:(NSString*)stack {
    NSRange range = [stack rangeOfString:hay];
    return range.length != 0;
}

@end
