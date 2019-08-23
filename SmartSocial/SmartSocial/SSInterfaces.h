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
    SSPlatformWhatsApp   = 1 << 9,
    SSPlatformLine       = 1 << 10,
    SSPlatformReddit     = 1 << 11,
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
    SSShareChannelWhatsApp           = 10,
    SSShareChannelLine               = 11,
    SSShareChannelReddit             = 12,
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

typedef NS_ENUM(NSInteger, SSAuthErrorCode) {
    SSAuthErrorCodeUnknown         = -1,
    SSAuthErrorCodeCancelled       = -2,
    SSAuthErrorCodeNotInstalled    = -3,
    SSAuthErrorCodeBusy            = -4,
    SSAuthErrorCodeNetwork         = -5,
    SSAuthErrorCodeNotSupportted   = -5,
};

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SSScopesKey;

/**
 * Share info, collection of all different platform
 */
@protocol ISSShareInfo <NSObject>
/// Title
@property (nonatomic, strong, nullable) NSString *title;
/// Subtitle
@property (nonatomic, strong, nullable) NSString *subTitle;
/// Text content
@property (nonatomic, strong, nullable) NSString *content;
/// url content
@property (nonatomic, strong, nullable) NSString *url;
/// Images<UIImage || NSString(url)>
@property (nonatomic, strong, nullable) NSArray <id> *shareImages;
/// Share channel
@property (nonatomic, assign) SSShareChannel channel;
/// Wechat mini program (class WXMiniProgramObject)
@property (nonatomic, strong, nullable) id wxMiniProgramObject;

@end

@protocol ISSAuthCredential <NSObject>
/// Access token
@property (nonatomic, strong) NSString *accessToken;
/// Token expireDate
@property (nonatomic, strong) NSDate *estimatedExpireDate;
/// Platform
@property (nonatomic, assign) SSPlatform platform;
/// Other info
@property (nonatomic, strong, nullable) NSDictionary *extraInfo;

@end

@protocol ISSUserInfo <NSObject>
/// Nick
@property (nonatomic, strong, nullable) NSString *nickname;
/// UserId
@property (nonatomic, strong) NSString *uid;
/// Avatar url
@property (nonatomic, strong, nullable) NSString *avatarUrl;
/// Gender
@property (nonatomic, assign) SSUserGender gender;
/// Signature
@property (nonatomic, strong, nullable) NSString *signature;

@end

@protocol ISSPlatformConfiguration <NSObject>

- (BOOL)setApplication:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions;
- (BOOL)setWechatAppId:(NSString *)appId secret:(NSString *)secret;
- (BOOL)setWeiboAppKey:(NSString *)appKey secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl authPolicy:(SSAuthPolicy)authPolicy;
- (BOOL)setQQAppId:(NSString *)appId secret:(NSString *)secret;
- (BOOL)setGoogleClientId:(NSString *)clientId;
- (BOOL)setInstagramClientId:(NSString *)clientId redirectUrl:(NSString *)redirectUrl;
- (BOOL)setTwitterConsumerKey:(NSString *)consumerKey secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl;
- (BOOL)setTwitchClientId:(NSString *)clientId secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl;
- (BOOL)setVKAppId:(NSString *)appId;
- (BOOL)setRedditClientId:(NSString *)clientId redirectUrl:(NSString *)redirectUrl;

@end

typedef void(^SSAuthCompletion)(_Nullable id<ISSAuthCredential>,  NSError * _Nullable );
typedef void(^SSRequestUserInfoCompletion)(_Nullable id<ISSUserInfo>,  NSError * _Nullable );
typedef void(^SSShareCompletion)(BOOL,  NSError * _Nullable );

@protocol SSInterfaces <NSObject>

/**
 * Get platform configuration
 */
- (id<ISSPlatformConfiguration>)platformConfiguration;

/**
 * Sharing
 */
- (void)shareToChannel:(SSShareChannel)channel
                  info:(id<ISSShareInfo>)info
            completion:(SSShareCompletion)completion;


/**
 * Authentication
 */
- (void)requestAuthForPlatform:(SSPlatform)platform
                    parameters:(NSDictionary *)parameters
                completion:(SSAuthCompletion)completion;


/**
 * Request user info
 */
- (void)requestUserInfoForPlatform:(SSPlatform)platform
                        completion:(SSRequestUserInfoCompletion)completion;

/**
 * Clean auth
 */
- (void)cleanAuthForPlatforms:(SSPlatform)platforms;


/// Redirection
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation;
/// Redirection
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

NS_ASSUME_NONNULL_END

#endif /* SSInterfaces_h */
