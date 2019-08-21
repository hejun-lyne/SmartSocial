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
// Wechat
@property (nonatomic, strong) NSString *wechatAppId;
// Weibo
@property (nonatomic, strong) NSString *weiboAppKey;
@property (nonatomic, strong) NSString *weiboSecret;
@property (nonatomic, strong) NSString *weiboRedirectUrl;

@end

NS_ASSUME_NONNULL_END
