#import <Foundation/Foundation.h>
#import <SwrveSDKCommon/SwrveSignatureProtectedFile.h>

extern int const waitShort;
extern int const waitMedium;
extern int const waitLong;

NS_ASSUME_NONNULL_BEGIN

@interface SwrveTestHelper : NSObject

+ (NSString*)fileContentsFromURL:(NSURL*)url;
+ (NSString*)fileContentsFromPath:(NSString*)path;
+ (NSString*)fileContentsFromProtectedFile:(SwrveSignatureProtectedFile*)file;

+ (void)writeData:(NSString*)content toURL:(NSURL*)url;
+ (void)writeData:(NSString*)content toPath:(NSString*)path;
+ (void)writeData:(NSString*)content toProtectedFile:(SwrveSignatureProtectedFile*)file;

+ (NSString*)rootCacheDirectory;
+ (NSString*)campaignCacheDirectory;

+ (void)removeSDKData;
+ (void)deleteFilesInDirectory:(NSString*)directory;
+ (void)createDirectory:(NSString*)path;
+ (NSArray*)getFilesInDirectory:(NSString*)directory;

+ (void)deleteUserDefaults;

@end

NS_ASSUME_NONNULL_END
