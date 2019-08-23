//
//  SSRedditAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSRedditAdaptor.h"

#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKNavigationAction.h>

@interface SSRedditAdaptor()<WKNavigationDelegate>
@end
@implementation SSRedditAdaptor
{
    UIViewController *authController;
    NSString *reqIdentifier;
    NSString *subredditDisplayName;
}

#define AuthDomain @"RedditAuth"
#define ShareDomain @"RedditShare"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (![self.credential isTokenValid] || subredditDisplayName == nil) {
        // 分享需要 subreddit，没有的话走一次 requestuserinfo 的流程，里面也会确保 token ok
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (c != nil) {
                [weakSelf shareInfo:info];
            } else if (e != nil) {
                weakSelf.requestUserInfoCompletion(nil, e);
            } else {
                weakSelf.requestUserInfoCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    // check image url
    NSString *shareImgUrl = nil;
    // share image link, and set type to image?
    for (id obj in info.shareImages) {
        if ([obj isKindOfClass:NSString.class]) {
            shareImgUrl = obj;
            break;
        }
    }
    
    // do post
    NSString *reqUrl = @"https://oauth.reddit.com/api/submit";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    req.HTTPMethod = @"POST";
    req.allHTTPHeaderFields = [self httpHeader:req.allHTTPHeaderFields];
    
    NSString *bodyString = [NSString stringWithFormat: @"title=%@&sr=%@", info.title ?: @"", subredditDisplayName];
    if (shareImgUrl.length > 0) {
        NSString *encodedURL = [shareImgUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
        bodyString = [bodyString stringByAppendingString:[NSString stringWithFormat:@"&kind=image&resubmit=true&url=%@", encodedURL]];
    } else if (info.url.length > 0) {
        NSString *encodedURL = [info.url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
        bodyString = [bodyString stringByAppendingString:[NSString stringWithFormat:@"&kind=link&resubmit=true&url=%@", encodedURL]];
    } else {
        bodyString = [bodyString stringByAppendingString:[NSString stringWithFormat:@"&kind=self&text=%@", info.content ?: @""]];
    }
    
    req.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            self.shareCompletion(NO, error);
            return;
        }
        if (data == nil) {
            self.shareCompletion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Invalid data"}));
            return;
        }
        NSError *serializationError;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
        if (serializationError != nil) {
            self.shareCompletion(NO, serializationError);
            return;
        }
        BOOL success = [resultDict[@"success"] boolValue];
        if (success) {
            self.shareCompletion(YES, nil);
        }else {
            NSString *reason = [NSString stringWithFormat:@"Share failed: %@", resultDict];
            self.shareCompletion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
        }
    }] resume];
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
    
    // do request
    NSString *reqUrl = @"https://oauth.reddit.com/api/v1/me";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    req.allHTTPHeaderFields = [self httpHeader:req.allHTTPHeaderFields];
    req.HTTPMethod = @"GET";
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            self.requestUserInfoCompletion(nil, error);
            return;
        }
        if (data == nil) {
            self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Invalid data"}));
            return;
        }
        NSError *serializationError;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
        if (serializationError != nil) {
            self.requestUserInfoCompletion(nil, serializationError);
            return;
        }
        
        NSDictionary *infoDict = resultDict[@"subreddit"];
        if (![infoDict isKindOfClass:NSDictionary.class]) {
            infoDict = nil; // NSNull
        }
        
        if ([infoDict allKeys].count == 0) {
            NSString *reason = [NSString stringWithFormat:@"Response with invalid: %@", resultDict];
            self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            return;
        }
        
        // for sharing
        self->subredditDisplayName = infoDict[@"display_name"];
        
        // assemble
        SSUserInfo *userInfo = [SSUserInfo new];
        userInfo.nickname = infoDict[@"title"];
        if (userInfo.nickname.length < 0) {
            userInfo.nickname = resultDict[@"name"];
            if (userInfo.nickname.length < 0) {
                userInfo.nickname = infoDict[@"display_name"];
            }
        }
        userInfo.gender = SSUserGenderUnknown;
        NSString *avatarUrl = resultDict[@"icon_img"];
        if ([avatarUrl containsString:@"?"]) {
            avatarUrl = [[avatarUrl componentsSeparatedByString:@"?"] firstObject];
        }
        userInfo.avatarUrl = avatarUrl;
        userInfo.uid = resultDict[@"id"];
        userInfo.signature = infoDict[@"public_description"];
        self.requestUserInfoCompletion(userInfo, nil);
    }] resume];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([self.credential isTokenValid]) {
        self.authCompletion(self.credential, nil);
        return;
    }
    
    if (self.credential != nil) {
        [self refreshToken:^(BOOL success, NSError *error) {
            if (success) {
                self.authCompletion(self.credential, nil);
            } else {
                [self authInWeb];
            }
        }];
    } else {
        [self authInWeb];
    }
}

- (void)authInWeb
{
    if (authController != nil) {
        // duplicated
        return;
    }
    
    SSWebViewController *webVc = [SSWebViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVc];
    
    NSString *encodedRedirectUrl = [self.configuration.redRedirectUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *identifier = [[NSUUID UUID] UUIDString];
    NSString *authUrl = [NSString stringWithFormat:@"https://ssl.reddit.com/api/v1/authorize?client_id=%@&response_type=code&state=%@&redirect_uri=%@&duration=permanent&scope=read,identity,submit", self.configuration.redClientId, identifier, encodedRedirectUrl];
    
    webVc.webview.navigationDelegate = self;
    [webVc.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:authUrl]]];
    webVc.title = @"Reddit";
    __weak UIViewController *weaknav = nav;
    __weak __typeof(self)weakSelf = self;
    webVc.onCancelled = ^{
        [weaknav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf->authController != nil) {
            strongSelf->authController = nil;
        }
        strongSelf.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
    };
    authController = nav;
    reqIdentifier = identifier;
    [self.topViewController presentViewController:nav animated:YES completion:nil];
}

- (void)refreshToken:(void(^)(BOOL success, NSError *error))completion
{
    NSString *reqUrl = @"https://www.reddit.com/api/v1/access_token";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    req.HTTPMethod = @"POST";
    NSString *bodyString = [NSString stringWithFormat:
                            @"grant_type=refresh_token&refresh_token=%@",
                            self.credential.refreshToken];
    req.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *headers = [req.allHTTPHeaderFields?:@{} mutableCopy];
    NSString *authField = [NSString stringWithFormat:@"%@:\"\"", self.configuration.redClientId];
    NSString *b64AuthField = [[authField dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [headers setObject:[NSString stringWithFormat:@"Basic %@", b64AuthField] forKey:@"Authorization"];
    req.allHTTPHeaderFields = headers.copy;
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            completion(NO, error);
            return;
        }
        if (data == nil) {
            completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Invalid data"}));
            return;
        }
        NSError *serializationError;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
        if (serializationError != nil) {
            completion(NO, serializationError);
            return;
        }
        NSString *accessToken = resultDict[@"access_token"];
        NSString *refreshToken = resultDict[@"refresh_token"];
        NSInteger expiresIn = [resultDict[@"expires_in"] integerValue];
        
        if (accessToken.length == 0 || refreshToken.length == 0) {
            NSString *reason = [NSString stringWithFormat:@"token data invalid: %@", resultDict];
            completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            return;
        }
        
        SSAuthCredential *credential = [SSAuthCredential new];
        credential.accessToken = accessToken;
        credential.refreshToken = refreshToken;
        credential.estimatedExpireDate = [[NSDate date] dateByAddingTimeInterval:(NSTimeInterval)expiresIn];
        credential.platform = SSPlatformReddit;
        self.credential = credential;
        completion(YES, nil);
    }] resume];
}

- (void)onTokenVerify:(NSString *)resultString
{
    NSDictionary *resDict = URLQueryParameters(resultString);
    NSString *code = resDict[@"code"];
    NSString *reqId = resDict[@"state"];
    if (![reqId isEqualToString:reqIdentifier]) {
        //mismatch，忽略
        return ;
    }
    
    if (code.length <= 0) {
        NSString *reason = [NSString stringWithFormat:@"Reddit response error: %@", resDict];
        self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
        if (authController != nil) {
            UIViewController *nav = authController;
            dispatch_async(dispatch_get_main_queue(), ^{
                [nav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
            });
            authController = nil;
        }
        return;
    }
}

- (void)onAccessToken:(NSString *)code
{
    // Request token
    NSString *encodedRedirectUrl = [self.configuration.redRedirectUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *reqUrl = @"https://www.reddit.com/api/v1/access_token";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    req.HTTPMethod = @"POST";
    
    NSString *bodyString = [NSString stringWithFormat:
                            @"grant_type=authorization_code&code=%@&redirect_uri=%@",
                            code,
                            encodedRedirectUrl];
    req.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *headers = [req.allHTTPHeaderFields?:@{} mutableCopy];
    NSString *authField = [NSString stringWithFormat:@"%@:\"\"", self.configuration.redClientId];
    NSString *b64AuthField = [[authField dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [headers setObject:[NSString stringWithFormat:@"Basic %@", b64AuthField] forKey:@"Authorization"];
    req.allHTTPHeaderFields = headers.copy;
    
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (self->authController != nil) {
            UIViewController *nav = self->authController;
            dispatch_async(dispatch_get_main_queue(), ^{
                [nav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
            });
            self->authController = nil;
        }
        if (error != nil) {
            self.authCompletion(nil, error);
            return;
        }
        if (data == nil) {
            self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Response with invalid data!"}));
            return;
        }
        NSError *serializationError;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
        if (serializationError != nil) {
            self.authCompletion(nil, serializationError);
            return;
        }
        NSString *accessToken = resultDict[@"access_token"];
        NSString *refreshToken = resultDict[@"refresh_token"];
        NSInteger expiresIn = [resultDict[@"expires_in"] integerValue];
        if (accessToken.length == 0 || refreshToken.length == 0) {
            NSString *reason = [NSString stringWithFormat:@"token data invalid: %@", resultDict];
            self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            return;
        }
        
        SSAuthCredential *credential = [SSAuthCredential new];
        credential.accessToken = accessToken;
        credential.refreshToken = refreshToken;
        credential.estimatedExpireDate = [[NSDate date] dateByAddingTimeInterval:(NSTimeInterval)expiresIn];
        credential.platform = SSPlatformReddit;
        self.credential = credential;
        self.authCompletion(credential, nil);
    }] resume];
}

- (NSDictionary *)httpHeader:(NSDictionary *)headers
{
    NSMutableDictionary *dict = headers?:@{}.mutableCopy;
    [dict setObject:[NSString stringWithFormat: @"bearer %@", self.credential.accessToken] forKey:@"Authorization"];
    [dict setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    return dict;
}

- (BOOL)appInstalled
{
    SSNotSupportMethod
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([navigationAction.request.URL.absoluteString hasPrefix:self.configuration.redRedirectUrl]) {
        NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:navigationAction.request.URL resolvingAgainstBaseURL:YES];
        [self onTokenVerify:urlComponents.query];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return ;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end
