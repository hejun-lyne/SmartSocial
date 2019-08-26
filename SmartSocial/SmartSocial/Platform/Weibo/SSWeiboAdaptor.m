//
//  SSWeiboAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSWeiboAdaptor.h"

#import <Weibo_SDK/WeiboSDK.h>

@interface SSWeiboAdaptor()<WeiboSDKDelegate, WBHttpRequestDelegate, WBMediaTransferProtocol>
@end
@implementation SSWeiboAdaptor
{
    WBSendMessageToWeiboRequest *waitingRequest;
}
- (instancetype)init
{
    SSPlatformConfiguration *config = SSContext.shared.platformConfiguration;
    if (![WeiboSDK registerApp:config.weiboAppKey]) {
        return nil;
    }
    self = [super init];
    return self;
}

#define AuthDomain @"WeiboAuth"
#define ShareDomain @"WeiboShare"
#define UserInfoDomain @"WeiboUserInfo"

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (!self.sharing || self.authing) {
        return;
    }
    if ([WeiboSDK isCanShareInWeiboAPP]) {
        if (self.authing) {
            self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
            self.authing = NO;
        }
        
        if (self.sharing) {
            self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
            self.sharing = NO;
        }
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [WeiboSDK handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [WeiboSDK handleOpenURL:url delegate:self];
}

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (self.sharing) {
        self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeBusy, @{@"reason" : @"The Last Share Actions hasn't complete yet!"}));
    }
    
//    if (![self.credential isTokenValid]) {
//        __weak __typeof(self)weakSelf = self;
//        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
//            if (c == nil) {
//                weakSelf.shareCompletion(NO, e);
//            } else {
//                [weakSelf shareInfo:info];
//            }
//        };
//        [self requestAuthWithParameters:nil];
//        return;
//    }
    
    WBMessageObject *msgObject = [WBMessageObject message];
    msgObject.text = info.content;
    
    if (info.url.length > 0) {
        if (info.shareImages.count <= 0) {
            WBWebpageObject *webObject = [WBWebpageObject object];
            webObject.webpageUrl = info.url;
            webObject.objectID = info.url;
            webObject.title = info.title;
            webObject.description = info.subTitle;
            msgObject.mediaObject = webObject;
        } else {
            msgObject.text = [msgObject.text stringByAppendingString:[NSString stringWithFormat:@" %@",info.url]];
        }
    }
    
    if (info.shareImages.count > 0) {
        [SSImageDownloader downloadImagesWithArray:info.shareImages completion:^(NSArray<UIImage *> *images, NSError *error) {
            [self shareImages:images messageObject:msgObject];
        }];
    } else {
        [self shareImages:nil messageObject:msgObject];
    }
}

- (void)shareImages:(NSArray<UIImage *> *)images messageObject:(WBMessageObject *)messageObject
{
    self.sharing = YES;
    WBImageObject *imgObject = [WBImageObject object];
    imgObject.delegate = self;
    messageObject.imageObject = imgObject;
    
    if (images.count > 0 && ![WeiboSDK isCanShareInWeiboAPP]) {
        //神之微博，没装客户端只能用 data 分享一张图片
        imgObject.imageData = UIImageJPEGRepresentation(images.firstObject, 0.9);
        [WeiboSDK sendRequest: [WBSendMessageToWeiboRequest requestWithMessage:messageObject authInfo:nil access_token:self.credential.accessToken]];
        return;
    }
    
    //辣鸡微博不会按 images 数组顺序分享
    [imgObject addImages:images];
    // 在回调里面 sendRequest
    waitingRequest = [WBSendMessageToWeiboRequest requestWithMessage:messageObject authInfo:nil access_token:self.credential.accessToken];
}

- (void)requestUserInfo
{
    NSParameterAssert(self.credential != nil);
    
    [WBHttpRequest
     requestWithURL:@"https://api.weibo.com/2/users/show.json"
     httpMethod:@"GET"
     params:@{
              @"uid": self.credential.weiboUid,
              @"access_token": self.credential.accessToken
              }
     delegate:self
     withTag:@"userInfoQuery"];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    SSAuthCredential *credential = (SSAuthCredential *)self.credential;
    if ([credential isTokenValid]) {
        self.authCompletion(credential, nil);
        [self refreshAccessToken:credential];
        return;
    }
    
    WBAuthorizeRequest *authRequest = [WBAuthorizeRequest request];
    authRequest.scope = @"all";
    authRequest.redirectURI = self.configuration.weiboRedirectUrl;
    authRequest.shouldShowWebViewForAuthIfCannotSSO = self.configuration.weiboAuthPolicy != SSAuthPolicySSOOnly;
    [WeiboSDK sendRequest:authRequest];
    self.authing = YES;
}

- (void)refreshAccessToken:(SSAuthCredential *)credential
{
    NSParameterAssert(credential);
    
    if (credential.refreshToken == nil) {
        return;
    }
    
    NSString *requestURL = [NSString stringWithFormat:@"https://api.weibo.com/oauth2/access_token?client_id=%@&client_secret=%@&grant_type=refresh_token&redirect_uri=%@&refresh_token=%@",self.configuration.weiboAppKey,self.configuration.weiboSecret,self.configuration.weiboRedirectUrl,credential.refreshToken];
    [WBHttpRequest requestWithURL:requestURL
                       httpMethod:@"POST"
                           params:@{}
                         delegate:self
                          withTag:@"refreshToken"];
}

- (void)removeCredential
{
    [WeiboSDK logOutWithToken:self.credential.accessToken delegate:self withTag:nil];
    [super removeCredential];
}

- (BOOL)appInstalled
{
    return [WeiboSDK isWeiboAppInstalled];
}

#pragma mark - WeiboSDKDelegate

- (void)didReceiveWeiboRequest:(WBBaseRequest *)request {}

- (void)didReceiveWeiboResponse:(WBBaseResponse *)response
{
    // Auth
    if ([response isKindOfClass:[WBAuthorizeResponse class]]) {
        WBAuthorizeResponse *weiboAuthResponse = (WBAuthorizeResponse *)response;
        if (response.statusCode != WeiboSDKResponseStatusCodeSuccess) {
            NSString *reason = [NSString stringWithFormat:@"WeiboStatusCode: %ld", (long)response.statusCode];
            if (self.authing) {
                self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            } else if (self.sharing) {
                self.shareCompletion(NO, MakeError(AuthDomain, response.statusCode == WeiboSDKResponseStatusCodeUserCancel ? SSAuthErrorCodeCancelled : SSAuthErrorCodeUnknown, @{@"reason": reason}));
            }
            return;
        }
        
        SSAuthCredential *credential = [SSAuthCredential new];
        credential.platform = SSPlatformSinaWeibo;
        credential.accessToken = weiboAuthResponse.accessToken;
        credential.estimatedExpireDate = weiboAuthResponse.expirationDate;
        credential.refreshToken = weiboAuthResponse.refreshToken;
        credential.weiboUid = weiboAuthResponse.userID;
        self.credential = credential;
    }
    // Share
    else if ([response isKindOfClass:[WBSendMessageToWeiboResponse class]]) {
        NSString *reason = [NSString stringWithFormat:@"WeiboStatusCode: %ld", (long)response.statusCode];
        SSAuthErrorCode code = response.statusCode == WeiboSDKResponseStatusCodeUserCancel ? SSAuthErrorCodeCancelled : SSAuthErrorCodeUnknown;
        NSError *err = response.statusCode == WeiboSDKResponseStatusCodeSuccess ? nil : MakeError(AuthDomain, code, @{@"reason": reason});
        self.shareCompletion(err == nil, err);
    }
}

#pragma mark - WeiboHTTPRequestDelegate

- (void)request:(WBHttpRequest *)request didFailWithError:(NSError *)error
{
    if ([request.tag isEqualToString:@"userInfoQuery"]) {
        self.requestUserInfoCompletion(nil, error);
    }
}

- (void)request:(WBHttpRequest *)request didFinishLoadingWithResult:(NSString *)result
{
    // UserInfoQuery
    if ([request.tag isEqualToString:@"userInfoQuery"]) {
        NSError *decodeError;
        NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&decodeError];
        if (decodeError != nil) {
            self.requestUserInfoCompletion(nil, decodeError);
            return;
        }
        
        SSUserInfo *userInfo = [SSUserInfo new];
        userInfo.nickname = json[@"name"];
        userInfo.avatarUrl = json[@"avatar_hd"];
        userInfo.uid = self.credential.weiboUid;
        userInfo.gender = SSUserGenderUnknown;
        if ([json[@"gender"] length] > 0) {
            userInfo.gender = [json[@"gender"] isEqualToString:@"m"] ? SSUserGenderMale : SSUserGenderFemale;
        }
        userInfo.signature = json[@"description"];
        self.requestUserInfoCompletion(userInfo, nil);
    }
    // RefreshToken
    else if ([request.tag isEqualToString:@"refreshToken"]) {
        NSError *decodeError;
        NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&decodeError];
        
        if (decodeError != nil) {
            NSLog(@"Weibo refreshToken error: %@", decodeError);
            return;
        }
        
        SSAuthCredential *credential = [SSAuthCredential new];
        credential.platform = SSPlatformSinaWeibo;
        credential.accessToken = json[@"access_token"];
        credential.estimatedExpireDate = [NSDate dateWithTimeIntervalSinceNow: [json[@"expires_in"] doubleValue]];
        credential.refreshToken = json[@"refresh_token"];
        credential.weiboUid = json[@"uid"];
        self.credential = credential;
    }
}

#pragma mark - WBMediaTransferProtocol

- (void)wbsdk_TransferDidReceiveObject:(id)object
{
    if (!self.sharing) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [WeiboSDK sendRequest:self->waitingRequest];
    });
}

- (void)wbsdk_TransferDidFailWithErrorCode:(WBSDKMediaTransferErrorCode)errorCode andError:(NSError *)error
{
    if (!self.sharing) {
        return;
    }
    self.sharing = NO;
    waitingRequest = nil;
    self.shareCompletion(NO, error);
}

@end
