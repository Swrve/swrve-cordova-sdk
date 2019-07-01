#import <Foundation/Foundation.h>
#import "HTTPConnection.h"
#import "HTTPMessage.h"

@interface TestHTTPConnection : HTTPConnection

@property (assign) int defaultResponseCode;
@property (nonatomic, retain) NSString* defaultResponseBody;

+(TestHTTPConnection*) sharedInstance;
+(void)setHandler:(NSString*)url handler:(NSObject<HTTPResponse>*(^)(NSString*, HTTPMessage *request))handler;
+(void)removeHandler:(NSString*)url;
+(void)clearHandlers;
+(void)setDefaultResponseCode:(int)code andBody:(NSString*)body;

@end
