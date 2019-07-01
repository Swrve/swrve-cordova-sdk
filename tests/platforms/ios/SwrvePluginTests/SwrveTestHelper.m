#import "SwrveTestHelper.h"
#import <SwrveSDKCommon/SwrveLocalStorage.h>

int const waitShort = 15;
int const waitMedium = 30;
int const waitLong = 60;

@implementation SwrveTestHelper

+ (NSString*) fileContentsFromURL:(NSURL*)url
{
    return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
}

+ (NSString*) fileContentsFromPath:(NSString*)path
{
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

+ (NSString*) fileContentsFromProtectedFile:(SwrveSignatureProtectedFile*)file
{
    NSData* data = [file readWithRespectToPlatform];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (void) writeData:(NSString*)content toURL:(NSURL*)url
{
    [content writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

+ (void) writeData:(NSString*)content toPath:(NSString*)path
{
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

+ (void) writeData:(NSString*)content toProtectedFile:(SwrveSignatureProtectedFile*)file
{
    NSData* data = [content dataUsingEncoding:NSUTF8StringEncoding];
    [file writeWithRespectToPlatform:data];
}

+ (NSString*) rootCacheDirectory
{
    static NSString * _dir = nil;
    if (!_dir) {
        _dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    }
    return _dir;
}

+ (NSString*) campaignCacheDirectory
{
    return [[SwrveTestHelper rootCacheDirectory] stringByAppendingPathComponent:@"com.ngt.msgs"];
}

+ (void) removeSDKData {
    [SwrveTestHelper deleteUserDefaults];
    [SwrveTestHelper deleteFilesInDirectory:[SwrveTestHelper rootCacheDirectory]];
    [SwrveTestHelper deleteFilesInDirectory:[SwrveLocalStorage applicationSupportPath]];
    [SwrveTestHelper deleteFilesInDirectory:[SwrveLocalStorage documentPath]];
}

+ (void) deleteFilesInDirectory:(NSString*)directory {
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    NSArray* fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
    for (NSString* filename in fileArray)  {
        [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
    }
}

+ (void)createDirectory:(NSString*)path {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
}

+ (NSArray*)getFilesInDirectory:(NSString*)directory {
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    return [fileMgr contentsOfDirectoryAtPath:directory error:nil];
}

+ (void) deleteUserDefaults {
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
