//
//  SSInterfaces.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#ifndef SSInterfaces_h
#define SSInterfaces_h

#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSInteger, SSPlatform) {
    SSPlatformInvalid    = 0,
    SSPlatformSinaWeibo  = 1 << 0,
    SSPlatformWechat     = 1 << 1,
    SSPlatformQQ         = 1 << 2,
    SSPlatformGoogle     = 1 << 3,
    SSPlatformFacebook   = 1 << 4,
    SSPlatformTwitter    = 1 << 5,
    SSPlatformInstagram  = 1 << 6,
    SSPlatformVK         = 1 << 7,
    SSPlatformTwitch     = 1 << 8,
    SSPlatformAll        = NSIntegerMax
};

typedef NS_ENUM (NSInteger, SSShareChannel) {
    SSShareChannelInvalid            = 0,
    SSShareChannelSinaWeibo          = 1,
    SSShareChannelWechatFriend       = 2,
    SSShareChannelWechatMoments      = 3,
    SSShareChannelQQFriend           = 4,
    SSShareChannelQQZone             = 5,
    SSShareChannelFacebook           = 6,
    SSShareChannelTwitter            = 7,
    SSShareChannelInstagram          = 8,
    SSShareChannelVK                 = 9,
};

typedef NS_ENUM(NSInteger, SSAuthPolicy) {
    SSAuthPolicySSOOnly       = 0,
    SSAuthPolicyAll           = 1,
};

typedef NS_ENUM(NSUInteger, SSUserGender){
    SSUserGenderUnknown = 0,
    SSUserGenderMale    = 1,
    SSUserGenderFemale  = 2,
};

/**
 * Share info, collection of all different platform
 */
@protocol SSShareInfo <NSObject>
/// Title
@property (nonatomic, strong) NSString *title;
/// Subtitle
@property (nonatomic, strong) NSString *subTitle;
/// Text content
@property (nonatomic, strong) NSString *content;
/// url content
@property (nonatomic, strong) NSString *url;
/// Images<UIImage || NSString(url)>
@property (nonatomic, strong) NSArray <id> *shareImages;

@end

@protocol SSAuthCredential <NSObject>
/// Access token
@property (nonatomic, strong) NSString *token;
/// Token expireDate
@property (nonatomic, strong) NSDate *estimatedExpireDate;
/// Platform
@property (nonatomic, assign) SSPlatform platform;
/// Other info
@property (nonatomic, strong) NSDictionary *extraInfo;

@end

@protocol SSUserInfo <NSObject>
/// Nick
@property (nonatomic, strong) NSString *nickname;
/// UserId
@property (nonatomic, strong) NSString *uid;
/// Avatar url
@property (nonatomic, strong) NSString *avatarUrl;
/// Gender
@property (nonatomic, assign) SSUserGender gender;
/// Signature
@property (nonatomic, strong) NSString *signature;

@end

@protocol ISSPlatformConfiguration <NSObject>

- (void)setWechatAppId:(NSString *)appId;
- (void)setWeiboAppKey:(NSString *)weiboAppKey secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl authPolicy:(SSAuthPolicy)authPolicy;

@end

@protocol SSInterfaces <NSObject>

/**
 * Get platform configuration
 */
- (id<ISSPlatformConfiguration>)platformConfiguration;

/**
 * Sharing
 */
- (void)shareToChannel:(SSShareChannel)channel
                  info:(id<SSShareInfo>)info
            completion:(void(^)(BOOL success, NSError *error))completion;


/**
 * Authentication
 */
- (void)requestAuthForPlatform:(SSPlatform)platform
                    extendInfo:(NSDictionary *)extendInfo
                completion:(void(^)(id<SSAuthCredential> credential, NSError *error))completion;


/**
 * Request user info
 */
- (void)requestUserInfoForPlatform:(SSPlatform)platform
                        completion:(void(^)(id<SSUserInfo> userInfo, NSError *error))completion;

/**
 * Clean auth
 */
- (void)cleanAuthCacheForPlatforms:(SSPlatform)platforms;


/// Redirection
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation;
/// Redirection
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;
/// Redirection
- (void)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

@end

#endif /* SSInterfaces_h */
