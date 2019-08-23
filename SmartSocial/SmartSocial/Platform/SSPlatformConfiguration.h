//
//  SSPlatformConfiguration.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSInterfaces.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSPlatformConfiguration : NSObject <ISSPlatformConfiguration>
// For facebook && whatsapp
@property (nonatomic, weak) UIApplication *application;
@property (nonatomic, strong) NSDictionary *launchOptions;
// Wechat
@property (nonatomic, strong) NSString *wechatAppId;
@property (nonatomic, strong) NSString *wechatAppSecret;
// Weibo
@property (nonatomic, strong) NSString *weiboAppKey;
@property (nonatomic, strong) NSString *weiboSecret;
@property (nonatomic, strong) NSString *weiboRedirectUrl;
@property (nonatomic, assign) SSAuthPolicy weiboAuthPolicy;
// QQ
@property (nonatomic, strong) NSString *qqAppId;
@property (nonatomic, strong) NSString *qqAppSecret;
// Google
@property (nonatomic, strong) NSString *gooClientId;
// Instagram
@property (nonatomic, strong) NSString *instagramClientId;
@property (nonatomic, strong) NSString *instagramRedirectUrl;
// Twitter
@property (nonatomic, strong) NSString *twitterConsumerKey;
@property (nonatomic, strong) NSString *twitterSecret;
@property (nonatomic, strong) NSString *twitterRedirectUrl;
// Twitch
@property (nonatomic, strong) NSString *twitchClientId;
@property (nonatomic, strong) NSString *twitchSecret;
@property (nonatomic, strong) NSString *twitchRedirectUrl;
// VK
@property (nonatomic, strong) NSString *vkId;
// Reddit
@property (nonatomic, strong) NSString *redClientId;
@property (nonatomic, strong) NSString *redRedirectUrl;

@end

NS_ASSUME_NONNULL_END
