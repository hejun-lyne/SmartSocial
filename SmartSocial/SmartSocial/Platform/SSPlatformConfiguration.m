//
//  SSPlatformConfiguration.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSPlatformConfiguration.h"
#import "SSContext.h"

@implementation SSPlatformConfiguration

- (BOOL)setApplication:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions
{
    _application = application;
    _launchOptions = launchOptions;
    
    // Facebook
    Class fbClass = NSClassFromString(@"SSFacebookAdaptor");
    id fbAdaptor = [fbClass new];
    if (fbAdaptor != nil) {
        [SSContext.shared registerAdaptor:fbAdaptor forPlatform:SSPlatformFacebook channels:@[@(SSShareChannelFacebook)]];
    }
    
    // Whatsapp
    Class waClass = NSClassFromString(@"SSWhatsAppAdaptor");
    id waAdaptor = [waClass new];
    if (waAdaptor != nil) {
        [SSContext.shared registerAdaptor:waAdaptor forPlatform:SSPlatformWhatsApp channels:@[@(SSShareChannelWhatsApp)]];
    }
    
    // Line
    Class liClass = NSClassFromString(@"SSLineAdaptor");
    id liAdaptor = [liClass new];
    if (liAdaptor != nil) {
        [SSContext.shared registerAdaptor:liAdaptor forPlatform:SSPlatformLine channels:@[@(SSShareChannelLine)]];
    }
    return YES;
}

- (BOOL)setWechatAppId:(NSString *)wechatAppId secret:(NSString *)secret
{
    _wechatAppId = wechatAppId;
    _weiboSecret = secret;
    
    Class clazz = NSClassFromString(@"SSWechatAdaptor");
    id adaptor = [clazz new];
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
    
    Class clazz = NSClassFromString(@"SSWeiboAdaptor");
    id adaptor = [clazz new];
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
    
    Class clazz = NSClassFromString(@"SSQQAdaptor");
    id adaptor = [clazz new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformQQ channels:@[@(SSShareChannelQQFriend), @(SSShareChannelQQZone)]];
    return YES;
}

- (BOOL)setGoogleClientId:(NSString *)clientId
{
    _gooClientId = clientId;
    
    Class clazz = NSClassFromString(@"SSGoogleAdaptor");
    id adaptor = [clazz new];
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
    
    Class clazz = NSClassFromString(@"SSInstagramAdaptor");
    id adaptor = [clazz new];
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
    
    Class clazz = NSClassFromString(@"SSTwitterAdaptor");
    id adaptor = [clazz new];
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
    
    Class clazz = NSClassFromString(@"SSTwitchAdaptor");
    id adaptor = [clazz new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformTwitch channels:@[]];
    return YES;
}

- (BOOL)setVKAppId:(NSString *)appId
{
    _vkId = appId;
    
    Class clazz = NSClassFromString(@"SSVKAdaptor");
    id adaptor = [clazz new];
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
    
    Class clazz = NSClassFromString(@"SSRedditAdaptor");
    id adaptor = [clazz new];
    if (adaptor == nil) {
        return NO;
    }
    [SSContext.shared registerAdaptor:adaptor forPlatform:SSPlatformReddit channels:@[@(SSShareChannelReddit)]];
    return YES;
}

@end
