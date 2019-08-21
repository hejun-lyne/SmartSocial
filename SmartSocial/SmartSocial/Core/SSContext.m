//
//  SSContext.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSContext.h"
#import "SSPlatformConfiguration.h"

@interface SSContext()
@property (nonatomic, strong) SSPlatformConfiguration *configuration;
@end
@implementation SSContext

- (id<ISSPlatformConfiguration>)platformConfiguration
{
    if (_configuration) {
        _configuration = [SSPlatformConfiguration new];
    }
    return _configuration;
}

@end
