//
//  SSLineAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSLineAdaptor.h"

#import <LineSDK/LineSDK.h>

@interface SSLineAdaptor()<LineSDKLoginDelegate>
@end
@implementation SSLineAdaptor
{
    LineSDKLogin *login;
    LineSDKAPI *api;
    NSArray *permissions;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        permissions = @[@"profile", @"friends", @"groups"];
        login = [LineSDKLogin sharedInstance];
        api = [[LineSDKAPI alloc] initWithConfiguration:[LineSDKConfiguration defaultConfig]];
    }
    return self;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // line sdk 内部有自己的超时失败，所以这里先不处理了
    // 发现 line 是异步调用 didLogin 回调的，所以这里即便授权成功也会先走。
    if (self.authing) {
        self.authing = NO;
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [[LineSDKLogin sharedInstance] handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [[LineSDKLogin sharedInstance] handleOpenURL:url];
}

#define AuthDomain @"LineAuth"
#define ShareDomain @"LineShare"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (!self.appInstalled) {
        self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeNotInstalled));
        return;
    }
    
    NSMutableCharacterSet *cSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [cSet formUnionWithCharacterSet:[NSCharacterSet URLPathAllowedCharacterSet]];
    // Images
    if (info.shareImages.count > 0) {
        void (^share)(UIImage *) = ^(UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                [pasteboard setData:UIImageJPEGRepresentation(img, 1.0) forPasteboardType:@"public.jpeg"];
                NSString *contentKey = [pasteboard.name stringByAddingPercentEncodingWithAllowedCharacters:cSet];
                NSString *shareURL = [NSString stringWithFormat:@"line://msg/image/%@", contentKey];
                
                if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:shareURL]]) {
                    self.shareCompletion(YES, nil);
                } else {
                    self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Send image to line failed!"}));
                }
            });
        };
        
        id imageObject = info.shareImages.firstObject;
        if ([imageObject isKindOfClass:NSString.class]) {
            [SSImageDownloader downloadImageWithURL:imageObject completion:^(UIImage *image, NSError *error) {
                if (error != nil) {
                    self.shareCompletion(NO, error);
                } else {
                    share(image);
                }
            }];
        } else {
            share(imageObject);
        }
    }
    // Text
    else if (info.content || info.url) {
        NSString *shareContent = [info.content?:info.url stringByAddingPercentEncodingWithAllowedCharacters:cSet];
        NSString *shareURL = [NSString stringWithFormat:@"line://msg/text/%@", shareContent];
        if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:shareURL]]) {
            self.shareCompletion(YES, nil);
        } else {
            self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Send Text to line failed!"}));
        }
    }
}

- (void)requestUserInfo
{
    if (![self.credential isTokenValid]) {
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (c != nil) {
                [weakSelf requestUserInfo];
            } else if (e != nil) {
                weakSelf.requestUserInfoCompletion(nil, e);
            } else {
                weakSelf.requestUserInfoCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    [api getProfileWithCompletion:^(LineSDKProfile * _Nullable profile, NSError * _Nullable error) {
        if (error != nil) {
            self.requestUserInfoCompletion(nil, error);
            return;
        }
        SSUserInfo *userInfo = [SSUserInfo new];
        userInfo.nickname = profile.displayName;
        userInfo.uid = profile.userID;
        userInfo.avatarUrl = profile.pictureURL.absoluteString;
        userInfo.gender = SSUserGenderUnknown;
        
        self.requestUserInfoCompletion(userInfo, nil);
    }];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([self.credential isTokenValid]) {
        [api verifyTokenWithCompletion:^(LineSDKVerifyResult * _Nullable result, NSError * _Nullable error) {
            if (error != nil) {
                self.authing = YES;
                [self->login startLoginWithPermissions:self->permissions];
            } else {
                self.authCompletion(self.credential, nil);
            }
        }];
        return;
    }
    
    self.authing = YES;
    [login startLoginWithPermissions:permissions];
}

- (BOOL)appInstalled
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"line://"]];
}

#pragma mark - Line SDK Delegate

- (void)didLogin:(nonnull LineSDKLogin *)login credential:(nullable LineSDKCredential *)credential profile:(nullable LineSDKProfile *)profile error:(nullable NSError *)error
{
    if (error != nil) {
        self.authCompletion(nil, error);
        self.authing = NO;
        return;
    }
    
    SSAuthCredential *cred = [SSAuthCredential new];
    cred.accessToken = credential.accessToken.accessToken;
    cred.estimatedExpireDate = credential.accessToken.estimatedExpiredDate;
    cred.platform = SSPlatformLine;
    self.authing = NO;
    self.authCompletion(cred, nil);
}

@end
