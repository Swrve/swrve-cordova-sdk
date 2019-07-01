#import <Foundation/Foundation.h>
#import "HTTPDataResponse.h"

@interface TestHTTPResponse : HTTPDataResponse

@property (assign) int responseStatus;
@property (nonatomic, retain) NSString* contentType;

-(id)initWithString:(NSString*)response;
-(NSInteger)status;

@end
