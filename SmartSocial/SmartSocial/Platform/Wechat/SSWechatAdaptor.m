//
//  SSWechatAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSWechatAdaptor.h"

#import <WechatOpenSDK/WXApi.h>
#import <WechatOpenSDK/WXApiObject.h>

//128KB
#define MP_MAX_IMG_SIZE 128 * 1024
//32KB
#define MP_MAX_THUMB_SIZE 32 * 1024

@interface SSWechatAdaptor()<WXApiDelegate>
@end
@implementation SSWechatAdaptor

- (instancetype)init
{
    SSPlatformConfiguration *config = SSContext.shared.platformConfiguration;
    if (![WXApi registerApp:config.wechatAppId]) {
        return nil;
    }
    self = [super init];
    return self;
}

#define AuthDomain @"WechatAuth"
#define ShareDomain @"WechatShare"

- (void)applicationDidBecomeActive
{
    if (self.authing && self.authCompletion != nil) {
        self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
        self.authing = NO;
    }
    
    if (self.sharing && self.shareCompletion != nil) {
        self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
        self.sharing = NO;
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [WXApi handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [WXApi handleOpenURL:url delegate:self];
}

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (!self.appInstalled) {
        self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeNotInstalled));
        return;
    }
    if (self.sharing) {
        self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeBusy, @{@"reason" : @"The Last Share Actions hasn't complete yet!"}));
    }
    
    SendMessageToWXReq *req = [SendMessageToWXReq new];
    WXMediaMessage *mediaMsg = [WXMediaMessage message];
    mediaMsg.title = info.title;
    mediaMsg.description = info.subTitle;
    
    dispatch_group_t resourcePrepareGroup = dispatch_group_create();
    __block NSError *err = nil;
    
    // Mini program
    if (info.wxMiniProgramObject != nil) {
        WXMiniProgramObject *program = (WXMiniProgramObject *)info.wxMiniProgramObject;
        if (program.hdImageData.length > MP_MAX_IMG_SIZE) {
            program.hdImageData = SSCompressImageData(program.hdImageData, MP_MAX_IMG_SIZE);
        }
        mediaMsg.mediaObject = program;
    }
    // Url
    else if (info.url.length > 0) {
        WXWebpageObject *webObject = [WXWebpageObject object];
        webObject.webpageUrl = info.url;
        mediaMsg.mediaObject = webObject;
        
        if (info.shareImages.count > 0) {
            void (^installThumbImg)(UIImage *) = ^(UIImage *img) {
                if (img == nil) {
                    return;
                }
                NSData *imgData = [img compressWithinBytes:MP_MAX_IMG_SIZE];
                [mediaMsg setThumbData:imgData];
            };
            
            id img = info.shareImages.firstObject;
            if ([img isKindOfClass:UIImage.class]) {
                installThumbImg(img);
            }else {
                NSString *url = img;
                dispatch_group_enter(resourcePrepareGroup);
                [SSImageDownloader downloadImageWithURL:url completion:^(UIImage *image, NSError *error) {
                    installThumbImg(image);
                    dispatch_group_leave(resourcePrepareGroup);
                }];
            }
        }
    }
    // Images
    else if (info.shareImages.count > 0) { // 图片
        WXImageObject *imgObject = [WXImageObject object];
        void (^installShareImage)(UIImage *image) = ^(UIImage *image) {
            imgObject.imageData = UIImageJPEGRepresentation(image, 1.0);
            mediaMsg.mediaObject = imgObject;
        };
        
        id img = info.shareImages.firstObject;
        if ([img isKindOfClass:UIImage.class]) {
            installShareImage(img);
        }else {
            NSString *url = img;
            dispatch_group_enter(resourcePrepareGroup);
            [SSImageDownloader downloadImageWithURL:url completion:^(UIImage *image, NSError *error) {
                if (error) {
                    err = error;
                } else if (image == nil) {
                    err = MakeError(ShareDomain, SSAuthErrorCodeNetwork, @{@"reason": @"Downloaded image is nil!"});
                } else {
                    installShareImage(image);
                }
                dispatch_group_leave(resourcePrepareGroup);
            }];
        }
    }
    
    dispatch_group_notify(resourcePrepareGroup, dispatch_get_main_queue(), ^{
        if (err != nil) {
            self.shareCompletion(NO, err);
            return;
        }
        req.message = mediaMsg;
        req.text = info.content;
        
        if (info.channel == SSShareChannelWechatFriend) {
            req.scene = WXSceneSession;
        }else if (info.channel == SSShareChannelWechatMoments) {
            req.scene = WXSceneTimeline;
        }
        
        if (![WXApi sendReq:req]) {
            self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Wechat send request failed"}));
        }
        self.sharing = YES;
    });
}

- (void)requestUserInfo
{
    NSParameterAssert(self.credential != nil);
    
    // check access token first
    if (!self.credential.isTokenValid) {
        [self refreshToken:^(BOOL s, NSError *e) {
            if (s) {
                [self requestUserInfo];
            } else {
                self.requestUserInfoCompletion(nil, e);
            }
        }];
        return;
    }
    
    NSString *accessToken = self.credential.accessToken;
    NSString *openid = self.credential.wechatOpenId;
    NSString *urlString =[NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@",accessToken, openid];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable err) {
        if (data && !err) {
            NSError *serializationError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
            if (serializationError == nil) {
                if (resultDict[@"errcode"]) {
                    NSString *reason = [NSString stringWithFormat:@"requestUserInfo error: %@",resultDict];
                    self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                
                SSUserInfo *userInfo = [SSUserInfo new];
                userInfo.nickname = resultDict[@"nickname"];
                userInfo.gender = SSUserGenderUnknown;
                if (resultDict[@"sex"]) {
                    userInfo.gender = [resultDict[@"sex"] integerValue] == 1 ? SSUserGenderMale : SSUserGenderFemale;
                }
                userInfo.avatarUrl = resultDict[@"headimgurl"];
                userInfo.uid = resultDict[@"unionid"];
                
                self.requestUserInfoCompletion(userInfo, nil);
            }else {
                NSString *reason = [NSString stringWithFormat:@"requestUserInfo error: %@", serializationError];
                self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            }
        }else {
            NSString *reason = [NSString stringWithFormat:@"requestUserInfo error: %@", err];
            self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
        }
    }] resume];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if (![WXApi isWXAppInstalled]) {
        self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"Reason": @"Wechat App not installed."}));
        return;
    }
    
    SSAuthCredential *credential = (SSAuthCredential *)self.credential;
    if ([credential isTokenValid]) {
        self.authCompletion(credential, nil);
        return;
    }
    
    dispatch_block_t request = ^{
        // Make new auth
        NSArray *scopes = params[SSScopesKey];
        if (scopes == nil || ![scopes isKindOfClass:NSArray.class]) {
            self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"Reason": @"Invalid scopes."}));
            return;
        }
        
        // delay callback
        self.authing = YES;
        [self requestAuthWithScopes:scopes];
    };
    
    if (self.credential.refreshToken == nil) {
        request();
    } else {
        // Always refresh token ?
        [self refreshToken:^(BOOL success, NSError *err) {
            if (success) {
                self.authCompletion(credential, nil);
                return;
            }
            
            NSLog(@"%@", err);
            request();
        }];
    }
    
}

- (void)requestAuthWithScopes:(NSArray<NSString *> *)scopes
{
    SendAuthReq *req = [SendAuthReq new];
    req.scope = [scopes componentsJoinedByString:@","];
    [WXApi sendReq:req];
}

static inline SSAuthCredential * AssetCredential(NSDictionary *resultDict) {
    NSString *refreshToken = resultDict[@"refresh_token"];
    NSString *accessToken = resultDict[@"access_token"];
    NSInteger expiresIn = [resultDict[@"expires_in"] integerValue];
    NSString *openId = resultDict[@"openid"];
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.accessToken = accessToken;
    credential.refreshToken = refreshToken;
    credential.estimatedExpireDate = [[NSDate date] dateByAddingTimeInterval:(NSTimeInterval)expiresIn];
    credential.wechatOpenId = openId;
    credential.platform = SSPlatformWechat;
    return credential;
}

- (void)refreshToken:(void (^)(BOOL, NSError *))completion
{
    NSString *urlString =[NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/refresh_token?appid=%@&grant_type=refresh_token&refresh_token=%@",self.configuration.wechatAppId, self.credential.refreshToken];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable err) {
        if (data && !err) {
            NSError *serializationError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
            if (serializationError == nil) {
                if (resultDict[@"errcode"]) {
                    NSString *reason = [NSString stringWithFormat:@"tokenRefresh error: %@",resultDict];
                    completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                
                SSAuthCredential *credential = AssetCredential(resultDict);
                if (credential.accessToken.length <= 0 || credential.refreshToken.length <= 0) {
                    NSString *reason = [NSString stringWithFormat:@"Token refresh data invalid: %@",resultDict];
                    completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                self.credential = credential;
                
                completion(YES, nil);
            } else {
                NSString *reason = [NSString stringWithFormat:@"tokenRefresh error: %@",serializationError];
                completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                return;
            }
        } else {
            NSString *reason = [NSString stringWithFormat:@"tokenRefresh error: %@",err];
            completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            return;
        }
    }] resume];
}

- (BOOL)appInstalled
{
    return [WXApi isWXAppInstalled];
}

#pragma mark - WXApiDelegate

- (void)onReq:(BaseReq *)req {}
- (void)onResp:(BaseResp *)resp
{
    if ([resp isKindOfClass:[SendAuthResp class]]) {
        [self onAuthResponse:(SendAuthResp *)resp];
    }else if ([resp isKindOfClass:[SendMessageToWXResp class]]) {
        [self onShareResponse:(SendMessageToWXResp *)resp];
    }
}

- (void)onAuthResponse:(SendAuthResp *)response
{
    self.authing = NO;
    NSString *urlString =[NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code",self.configuration.wechatAppId, self.configuration.wechatAppSecret, response.code];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && !error) {
            NSError *serializationError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
            if (serializationError == nil) {
                if (resultDict[@"errcode"]) {
                    NSString *reason = [NSString stringWithFormat:@"Response error: %@", resultDict];
                    self.authCompletion(nil,  MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                
                SSAuthCredential *credential = AssetCredential(resultDict);
                if (credential.accessToken.length <= 0 || credential.refreshToken.length <= 0) {
                    NSString *reason = [NSString stringWithFormat:@"Token data invalid: %@",resultDict];
                    self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                self.credential = credential;
                self.authCompletion(credential, nil);
                
            } else {
                NSString *reason = [NSString stringWithFormat:@"Response error: %@", serializationError];
                self.authCompletion(nil,  MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            }
            
        } else {
            NSString *reason = [NSString stringWithFormat:@"Response error: %@", error];
            self.authCompletion(nil,  MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
        }
    }] resume];
}

- (void)onShareResponse:(SendMessageToWXResp *)response
{
    self.sharing = NO;
    BOOL success = response.errCode == 0;
    NSError *err = success ? nil : MakeErrorS(ShareDomain, SSAuthErrorCodeUnknown);
    self.shareCompletion(success, err);
}

@end
