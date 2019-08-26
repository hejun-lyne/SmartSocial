//
//  SSAbstractAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSAbstractAdaptor.h"

#import <UIKit/UIKit.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>

#define MustOverrideMethod @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s must be overridden in a subclass/category", __PRETTY_FUNCTION__] userInfo:nil];

NSDictionary * URLQueryParameters(NSString *query)
{
    NSArray *items = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *resDict = [NSMutableDictionary new];
    for (NSString *item in items) {
        NSArray *keyval = [item componentsSeparatedByString:@"="];
        if (keyval.count != 2) {
            continue;
        }
        [resDict setObject:keyval[1] forKey:keyval[0]];
    }
    return [resDict copy];
}

NSString * SSRandomString(int length) {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: length];
    for (NSInteger i = 0; i<length; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((uint32_t)[letters length])]];
    }
    return randomString;
}

NSString * SSHMACSHA1(NSString *sign, NSString *data) {
    const char *cKey  = [sign cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
    //Sha256:
    // unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    //CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    //sha1
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString *hash = [HMAC base64EncodedStringWithOptions:0];//将加密结果进行一次BASE64编码。
    return hash;
}

@implementation SSAbstractAdaptor
@synthesize credential = _credential;

- (instancetype)init
{
    self = [super init];
    if (self) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    MustOverrideMethod
}

- (void)requestUserInfo
{
    MustOverrideMethod
}

- (void)shareInfo:(id<ISSShareInfo>)info
{
    MustOverrideMethod
}

- (void)applicationDidBecomeActive {}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return NO;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return NO;
}

- (SSPlatformConfiguration *)configuration
{
    return (SSPlatformConfiguration *)SSContext.shared.platformConfiguration;
}

#define CredentialKey [NSString stringWithFormat:@"SSCredential_%@", NSStringFromClass(self.class)]
- (SSAuthCredential *)credential
{
    if (_credential == nil) {
        // read from storage
        NSData *data = [NSUserDefaults.standardUserDefaults objectForKey:CredentialKey];
        if (data != nil) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
    }
    return _credential;
}

- (void)setCredential:(SSAuthCredential *)credential
{
    _credential = credential;
    if (credential == nil) {
        [self removeCredential];
    } else {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:credential];
        [NSUserDefaults.standardUserDefaults setObject:data forKey:CredentialKey];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}

- (void)removeCredential
{
    [NSUserDefaults.standardUserDefaults removeObjectForKey:CredentialKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)setAuthCompletion:(SSAuthCompletion)authCompletion
{
    if (authCompletion == nil) {
        _authCompletion = nil;
        return;
    }
    _authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            authCompletion(c, e);
        });
    };
}

- (void)setShareCompletion:(SSShareCompletion)shareCompletion
{
    if (shareCompletion == nil) {
        _shareCompletion = nil;
        return;
    }
    _shareCompletion = ^(BOOL s, NSError * _Nullable e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            shareCompletion(s, e);
        });
    };
}

- (void)setRequestUserInfoCompletion:(SSRequestUserInfoCompletion)requestUserInfoCompletion
{
    if (requestUserInfoCompletion == nil) {
        _requestUserInfoCompletion = nil;
        return;
    }
    self.requestUserInfoCompletion = ^(id<ISSUserInfo> _Nullable u, NSError * _Nullable e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            requestUserInfoCompletion(u, e);
        });
    };
}

- (UIViewController *)topViewController
{
    return [self topViewController:[self mainWindow].rootViewController];
}

- (UIWindow *)mainWindow
{
    NSArray<UIWindow *> * wins = UIApplication.sharedApplication.windows;
    if (wins.count == 0) {
        return nil;
    }
    
    for (NSInteger i = wins.count - 1; i >= 0; i --) {
        if ([NSStringFromClass(wins[i].class) containsString:@"UITextEffectsWindow"]) {
            continue;
        } else if ([NSStringFromClass(wins[i].class) containsString:@"UIRemoteKeyboardWindow"]) {
            continue;
        }
        return wins[i];
    }
    return UIApplication.sharedApplication.keyWindow;
}

- (UIViewController *)topViewController:(UIViewController *)rootViewController
{
    if (rootViewController.presentedViewController) {
        return [self topViewController:rootViewController.presentedViewController];
    }
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        return [self topViewController:[navigationController.viewControllers lastObject]];
    }
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)rootViewController;
        return [self topViewController:tabController.selectedViewController];
    }
    
    return rootViewController;
}

@end
