#import "TestHTTPResponse.h"

@implementation TestHTTPResponse {
}

@synthesize responseStatus;
@synthesize contentType;

- (id)initWithData:(NSData *)d {
    if (self = [super initWithData:d]) {
        self.responseStatus = 200;
    }
    return self;
}

-(id)initWithString:(NSString*)response {
    if (self = [super initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]]) {
        self.responseStatus = 200;
    }
    return self;
}

- (NSDictionary *)httpHeaders {
    if (self.contentType != nil) {
        return [NSDictionary dictionaryWithObjectsAndKeys:contentType, @"Content-Type", nil];
    }
    return nil;
}

-(NSInteger)status {
    return self.responseStatus;
}
@end
