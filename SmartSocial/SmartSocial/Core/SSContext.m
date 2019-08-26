//
//  SSContext.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSContext.h"
#import "SSPlatformConfiguration.h"
#import "SSAbstractAdaptor.h"

NSString * const SSScopesKey = @"scopes";

@interface SSContext()
@property (nonatomic, strong) SSPlatformConfiguration *configuration;
@end
@implementation SSContext
{
    NSMutableDictionary<NSNumber *, SSAbstractAdaptor *> *adaptors;
    NSMutableDictionary<NSNumber *, SSAbstractAdaptor *> *channelAdaptors;
    SSAbstractAdaptor *activeAdaptor;
}

+ (instancetype)shared
{
    static SSContext *s_sscontext = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sscontext = [SSContext new];
    });
    return s_sscontext;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        adaptors = [NSMutableDictionary dictionary];
        channelAdaptors = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id<ISSPlatformConfiguration>)platformConfiguration
{
    if (_configuration == nil) {
        _configuration = [SSPlatformConfiguration new];
    }
    return _configuration;
}

- (void)registerAdaptor:(SSAbstractAdaptor *)adaptor forPlatform:(SSPlatform)platform channels:(nonnull NSArray<NSNumber *> *)channels
{
    @synchronized (adaptors) {
        [adaptors setObject:adaptor forKey:@(platform)];
    }
    @synchronized (channelAdaptors) {
        for (NSNumber *c in channels) {
            [channelAdaptors setObject:adaptor forKey:c];
        }
    }
}

- (void)makeAdaptorActive:(SSPlatform)platform orChannel:(SSShareChannel)channel
{
    SSAbstractAdaptor *adaptor;
    if (platform > 0 && platform <= SSPlatformReddit) {
        @synchronized (adaptors) {
            adaptor = [adaptors objectForKey:@(platform)];
        }
    } else if (channel > 0 && channel <= SSShareChannelReddit) {
        @synchronized (channelAdaptors) {
            adaptor = [channelAdaptors objectForKey:@(channel)];
        }
    }
    
    activeAdaptor = adaptor;
}

- (void)requestAuthForPlatform:(SSPlatform)platform parameters:(NSDictionary *)parameters completion:(SSAuthCompletion)completion
{
    NSParameterAssert(completion != nil);
    
    [self makeAdaptorActive:platform orChannel:0];
    if (activeAdaptor == nil) {
        completion(nil, MakeError(@"SSAuth", SSAuthErrorCodeUnknown, @{@"reason": @"Platform implemetation not found"}));
        return;
    }
    activeAdaptor.authCompletion = completion;
    [activeAdaptor requestAuthWithParameters:parameters];
}

- (void)requestUserInfoForPlatform:(SSPlatform)platform completion:(SSRequestUserInfoCompletion)completion
{
    NSParameterAssert(completion != nil);
    
    [self makeAdaptorActive:platform orChannel:0];
    if (activeAdaptor == nil) {
        completion(nil, MakeError(@"SSAuth", SSAuthErrorCodeUnknown, @{@"reason": @"Platform implemetation not found"}));
        return;
    }
    activeAdaptor.requestUserInfoCompletion = completion;
    [activeAdaptor requestUserInfo];
}

- (void)shareToChannel:(SSShareChannel)channel info:(id<ISSShareInfo>)info completion:(SSShareCompletion)completion
{
    NSParameterAssert(completion != nil);
    
    [self makeAdaptorActive:0 orChannel:channel];
    if (activeAdaptor == nil) {
        completion(nil, MakeError(@"SSShare", SSAuthErrorCodeUnknown, @{@"reason": @"Platform implemetation not found"}));
        return;
    }
    activeAdaptor.shareCompletion = completion;
    [activeAdaptor shareInfo:info];
}

- (void)cleanAuthForPlatforms:(SSPlatform)platforms
{
    [adaptors enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, SSAbstractAdaptor * _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key unsignedIntegerValue] & platforms) {
            [obj removeCredential];
        }
    }];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [activeAdaptor application:application handleOpenURL:url sourceApplication:sourceApp annotation:annotation];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [activeAdaptor application:app openURL:url options:options];
}

@end
