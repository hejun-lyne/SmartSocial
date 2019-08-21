//
//  SSPlatformConfiguration.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSPlatformConfiguration.h"

@implementation SSPlatformConfiguration

- (void)setWechatAppId:(NSString *)wechatAppId
{
    _wechatAppId = wechatAppId;
}

- (void)setWeiboAppKey:(NSString *)weiboAppKey secret:(NSString *)secret redirectUrl:(NSString *)redirectUrl authPolicy:(SSAuthPolicy)authPolicy
{
    _weiboAppKey = weiboAppKey;
    _weiboSecret = secret;
    _weiboRedirectUrl = redirectUrl;
}

@end
