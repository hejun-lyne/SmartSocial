//
//  SSAuthCredential.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSAuthCredential.h"

@implementation SSAuthCredential
@synthesize accessToken, estimatedExpireDate, platform, extraInfo;

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        accessToken = [coder decodeObjectForKey:@"accessToken"];
        estimatedExpireDate = [coder decodeObjectForKey:@"estimatedExpireDate"];
        platform = [coder decodeIntegerForKey:@"platform"];
        extraInfo = [coder decodeObjectForKey:@"extraInfo"];
        
        _refreshToken = [coder decodeObjectForKey:@"refreshToken"];
        _wechatOpenId = [coder decodeObjectForKey:@"wechatOpenId"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:accessToken forKey:@"accessToken"];
    [aCoder encodeObject:estimatedExpireDate forKey:@"estimatedExpireDate"];
    [aCoder encodeInteger:platform forKey:@"platform"];
    [aCoder encodeObject:extraInfo forKey:@"extraInfo"];
    
    [aCoder encodeObject:_refreshToken forKey:@"refreshToken"];
    [aCoder encodeObject:_wechatOpenId forKey:@"wechatOpenId"];
}

- (BOOL)isTokenValid
{
    if (self.platform & SSPlatformTwitter || self.platform & SSPlatformInstagram) {
        /*
         How long does an access token last?
         Access tokens are not explicitly expired. An access token will be invalidated if a user explicitly revokes an application in the their Twitter account settings, or if Twitter suspends an application. If an application is suspended, there will be a note on the apps.twitter.com page stating that it has been suspended.
         */
        return YES;
    }
    
    // nil equal to zero
    NSTimeInterval interval = [self.estimatedExpireDate timeIntervalSinceDate:[NSDate date]];
    
    // special platform
    if(self.platform & SSPlatformGoogle
       || self.platform & SSPlatformTwitch
       || self.platform & SSPlatformWechat) {
        return interval > 30 * 60; // half hour
    }
    
    if (self.platform == SSPlatformReddit) {
        return interval > 0; // reddit 不超时，refresh 到的 token 和过期时间也不会更新，等于白请求。
    }
    
    // normal situation
    return interval >= 2 * 24 * 60 * 60;
}

@end
