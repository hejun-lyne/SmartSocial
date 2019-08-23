//
//  SSPlatformConfiguration.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSPlatformConfiguration.h"
#import "SSWechatAdaptor.h"
#import "SSWeiboAdaptor.h"
#import "SSQQAdaptor.h"
#import "SSFacebookAdaptor.h"
#import "SSWhatsAppAdaptor.h"
#import "SSTwitchAdaptor.h"
#import "SSGoogleAdaptor.h"
#import "SSInstagramAdaptor.h"
#import "SSTwitterAdaptor.h"
#import "SSVKAdaptor.h"
#import "SSLineAdaptor.h"
#import "SSRedditAdaptor.h"
#import "SSContext.h"

@implementation SSPlatformConfiguration

- (BOOL)setApplication:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions
{
    _application = application;
    _launchOptions = launchOptions;
    
    // Facebook
    SSFacebookAdaptor *fbAdaptor = [SSFacebookAdaptor new];
    if (fbAdaptor != nil) {
        [SSContext.shared registerAdaptor:fbAdaptor forPlatform:SSPlatformFacebook channels:@[@(SSShareChannelFacebook)]];
    }
    
    // Whatsapp
    SSWhatsAppAdaptor *waAdaptor = [SSWhatsAppAdaptor new];
    if (waAdaptor != nil) {
        [SSContext.shared registerAdaptor:waAdaptor forPlatform:SSPlatformWhatsApp channels:@[@(SSShareChannelWhatsApp)]];
    }
    
    // Line
    SSLineAdaptor *liAdaptor = [SSLineAdaptor new];
    if (liAdaptor != nil) {
        [SSContext.shared registerAdaptor:liAdaptor forPlatform:SSPlatformLine channels:@[@(SSShareChannelLine)]];
    }
    return YES;
}

- (BOOL)setWechatAppId:(NSString *)wechatAppId secret:(NSString *)secret
{
    _wechatAppId = wechatAppId;
    _weiboSecret = secret;
    
    SSWechatAdaptor *adaptor = [SSWechatAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformWechat channels:@[@(SSShareChannelWechatFriend), @(SSShareChannelWechatMoments)]];
    return YES;
}

- (BOOL)setWeiboAppKey:(NSString *)appKey secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl authPolicy:(SSAuthPolicy)authPolicy
{
    _weiboAppKey = appKey;
    _weiboSecret = secret;
    _weiboRedirectUrl = redirectUrl;
    _weiboAuthPolicy = authPolicy;
    
    SSWeiboAdaptor *adaptor = [SSWeiboAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformSinaWeibo channels:@[@(SSShareChannelSinaWeibo)]];
    return YES;
}

- (BOOL)setQQAppId:(NSString *)appId secret:(NSString *)secret
{
    _qqAppId = appId;
    _qqAppSecret = secret;
    
    SSQQAdaptor *adaptor = [SSQQAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformQQ channels:@[@(SSShareChannelQQFriend), @(SSShareChannelQQZone)]];
    return YES;
}

- (BOOL)setGoogleClientId:(NSString *)clientId
{
    _gooClientId = clientId;
    
    SSGoogleAdaptor *adaptor = [SSGoogleAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformGoogle channels:@[]];
    return YES;
}

- (BOOL)setInstagramClientId:(NSString *)clientId redirectUrl:(NSString *)redirectUrl
{
    _instagramClientId = clientId;
    _instagramRedirectUrl = redirectUrl;
    
    SSInstagramAdaptor *adaptor = [SSInstagramAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformInstagram channels:@[@(SSShareChannelInstagram)]];
    return YES;
}

- (BOOL)setTwitterConsumerKey:(NSString *)consumerKey secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl
{
    _twitterConsumerKey = consumerKey;
    _twitterSecret = secret;
    _twitterRedirectUrl = redirectUrl;
    
    SSTwitterAdaptor *adaptor = [SSTwitterAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformTwitter channels:@[@(SSShareChannelTwitter)]];
    return YES;
}

- (BOOL)setTwitchClientId:(NSString *)clientId secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl
{
    _twitchClientId = clientId;
    _twitchSecret = secret;
    _twitchRedirectUrl = redirectUrl;
    
    SSTwitchAdaptor *adaptor = [SSTwitchAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformTwitch channels:@[]];
    return YES;
}

- (BOOL)setVKAppId:(NSString *)appId
{
    _vkId = appId;
    
    SSVKAdaptor *adaptor = [SSVKAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformVK channels:@[@(SSShareChannelVK)]];
    return YES;
}

- (BOOL)setRedditClientId:(NSString *)clientId redirectUrl:(NSString *)redirectUrl
{
    _redClientId = clientId;
    _redRedirectUrl = redirectUrl;
    
    SSRedditAdaptor *adaptor = [SSRedditAdaptor new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformReddit channels:@[@(SSShareChannelReddit)]];
    return YES;
}

@end
