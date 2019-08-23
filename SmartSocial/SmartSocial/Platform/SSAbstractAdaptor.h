//
//  SSAbstractAdaptor.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSContext.h"
#import "SSImageDownloader.h"
#import "UIImage+SSCompress.h"
#import "SSPlatformConfiguration.h"
#import "SSAuthCredential.h"
#import "SSUserInfo.h"
#import "SSWebViewController.h"

#define MakeErrorS(domain, c) MakeError(domain, c, nil)
#define MakeError(domain, c, info) [NSError errorWithDomain:domain code:c userInfo:info]

#define SSNotSupportMethod @throw [NSException exceptionWithName:@"SSNotSupportedMethod" reason:nil userInfo:nil];

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif
    NSDictionary * URLQueryParameters(NSString *query);
    NSString * SSRandomString(int length);
    NSString * SSHMACSHA1(NSString *sign, NSString *data);
#if __cplusplus
}
#endif

@interface SSAbstractAdaptor : NSObject
@property (nonatomic, readonly) SSPlatformConfiguration *configuration;
@property (nonatomic, strong) SSAuthCredential *credential;
@property (nonatomic, copy) SSAuthCompletion authCompletion;
@property (nonatomic, copy) SSRequestUserInfoCompletion requestUserInfoCompletion;
@property (nonatomic, copy) SSShareCompletion shareCompletion;
@property (nonatomic, readonly) UIViewController *topViewController;
@property (nonatomic, assign) BOOL authing;
@property (nonatomic, assign) BOOL sharing;
@property (nonatomic, readonly) BOOL appInstalled;

- (void)requestAuthWithParameters:(nullable NSDictionary *)params;
- (void)requestUserInfo;
- (void)shareInfo:(id<ISSShareInfo>)info;

- (void)removeCredential;

// App callbacks
- (void)applicationDidBecomeActive;
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation;
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

NS_ASSUME_NONNULL_END
