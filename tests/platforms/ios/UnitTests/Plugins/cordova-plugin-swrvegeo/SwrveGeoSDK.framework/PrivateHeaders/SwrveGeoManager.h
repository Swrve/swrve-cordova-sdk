#import <Foundation/Foundation.h>
#import "SwrveNotificationFetcher.h"
#import "SwrveGeoCustomFilterDelegate.h"

static NSString *const SWRVE_GEO_SDK_VERSION = @"2.3.1";

// Update the SwrveGEOSample README.md if min major/minor/patch version changes
static int const MIN_SWRVE_SDK_MAJOR_VERSION = 6;
static int const MIN_SWRVE_SDK_MINOR_VERSION = 2;
static int const MIN_SWRVE_SDK_PATCH_VERSION = 0;

static NSString *const DEVICE_UPDATE_API = @"/1/device_update";
static NSString *const PARAM_APIKEY = @"api_key";
static NSString *const PARAM_USER = @"user";
static NSString *const PARAM_UNIQUE_DEVICE_ID = @"unique_device_id";
static NSString *const PARAM_SEQNUM = @"seqnum";
static NSString *const PARAM_USER_INITIATED = @"user_initiated";
static NSString *const PARAM_CLIENT_TIME = @"client_time";

static NSString *const PROP_GEO_SDK_VERSION = @"swrve.geo_sdk_version";
static NSString *const PROP_GEO_PROVIDER_VERSION = @"swrve.geo_provider_version";

static NSString *const EVENT_TYPE_GEOPLACE = @"geoplace";
static NSString *const EVENT_ACTION_TYPE_NAME = @"actionType";
static NSString *const EVENT_ACTIONTYPE_ENTER = @"enter";
static NSString *const EVENT_ACTIONTYPE_EXIT = @"exit";
static NSString *const EVENT_ID_NAME = @"id";
static NSString *const EVENT_GEOFENCE_ID_NAME = @"geofenceId";
static NSString *const EVENT_PAYLOAD_NAME = @"payload";
static NSString *const EVENT_TYPE_NAME = @"type";
static NSString *const EVENT_TIME_NAME = @"time";
static NSString *const EVENT_SEQNUM_NAME = @"seqnum";
static NSString *const EVENT_USER_NAME = @"user";
static NSString *const EVENT_SESSION_TOKEN_NAME = @"session_token";
static NSString *const EVENT_VERSION_NAME = @"version";
static NSString *const EVENT_APP_VERSION_NAME = @"app_version";
static NSString *const EVENT_UNIQUE_DEVICE_ID_NAME = @"unique_device_id";
static NSString *const EVENT_DATA_NAME = @"data";

static NSString *const LOCAL_STORAGE_SDK_VERSION = @"swrve_geo_sdk_version.txt";
static NSString *const LOCAL_STORAGE_PROVIDER_VERSION = @"swrve_geo_provider_version.txt";

@interface SwrveGeoManager : NSObject

- (id) initWithCustomFilter:(id<SwrveGeoCustomFilterDelegate>)customFilter;

- (void)triggerEnterWithGeoplaceId:(NSString *)geoplaceId
                      geoplaceName:(NSString *)geoplaceName
                        geofenceId:(NSString *)geofenceId
                      openingHours:(NSDictionary *)openingHours
                           payload:(NSDictionary *)payload;

- (void)triggerExitWithGeoplaceId:(NSString *)geoplaceId
                     geoplaceName:(NSString *)geoplaceName
                       geofenceId:(NSString *)geofenceId
                     openingHours:(NSDictionary *)openingHours
                          payload:(NSDictionary *)payload;

- (void)deviceUpdate:(NSString *)providerVersion;

- (void)fetchNotifications:(SwrveNotificationFetcher *)fetcher
             forGeoplaceId:(NSString *)geoplaceId
              geoplaceName:(NSString *)geoplaceName
                geofenceId:(NSString *)geofenceId
              openingHours:(NSDictionary *)openingHours
                actiontype:(NSString *)actionType
           geoplacePayload:(NSDictionary *)geoplacePayload;

// Visible for testing
- (SwrveNotificationFetcher *)notificationFetcher;

@end
