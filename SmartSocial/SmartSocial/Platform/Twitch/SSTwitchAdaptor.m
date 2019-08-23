//
//  SSTwitchAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSTwitchAdaptor.h"

#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKNavigationAction.h>

@interface SSTwitchAdaptor()<WKNavigationDelegate>
@end
@implementation SSTwitchAdaptor
{
    NSArray *scopes;
    UIViewController *webController;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        scopes = @[@"user:edit", @"chat_login", @"user_read"];
    }
    return self;
}

#define AuthDomain @"TwitchAuth"
#define ShareDomain @"TwitchShare"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeNotSupportted));
}

- (void)requestUserInfo
{
    if (![self.credential isTokenValid]) {
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (c != nil) {
                [weakSelf requestUserInfo];
            } else {
                weakSelf.requestUserInfoCompletion(nil, e);
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    NSString *reqUrl = @"https://api.twitch.tv/kraken/user";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    
    NSMutableDictionary *dict = req.allHTTPHeaderFields ? req.allHTTPHeaderFields.mutableCopy : @{}.mutableCopy;
    [dict setObject:self.configuration.twitchClientId ? : @"" forKey:@"Client-ID"];
    [dict setObject:[NSString stringWithFormat:@"OAuth %@",self.credential.accessToken] forKey:@"Authorization"];
    [dict setObject:@"application/vnd.twitchtv.v5+json" forKey:@"Accept"];
    req.allHTTPHeaderFields = [dict copy];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && !error) {
            NSError *serializationError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
            if (serializationError == nil) {
                SSUserInfo *userInfo = [SSUserInfo new];
                userInfo.nickname = resultDict[@"display_name"] ? : resultDict[@"name"];
                userInfo.uid = [NSString stringWithFormat:@"%li",[resultDict[@"_id"] integerValue]];
                userInfo.gender = SSUserGenderUnknown;
                userInfo.avatarUrl = resultDict[@"logo"];
                userInfo.signature = resultDict[@"bio"];
                
                self.requestUserInfoCompletion(userInfo, nil);
            } else {
                self.requestUserInfoCompletion(nil, serializationError);
            }
        }else {
            self.requestUserInfoCompletion(nil, error);
        }
    }] resume];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([self.credential isTokenValid]) {
        self.authCompletion(self.credential, nil);
        return;
    }
    
    if (self.credential != nil) {
        [self refreshToken:^(BOOL s, NSError *e) {
            if (s) {
                self.authCompletion(self.credential, nil);
            } else {
                self.authCompletion(nil, e);
            }
        }];
    }
    
    SSWebViewController *webVc = [SSWebViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVc];
    
    NSString *encodedRedirectUrl = [self.configuration.twitchRedirectUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *authUrl = [NSString stringWithFormat:@"https://id.twitch.tv/oauth2/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@&state=%@",
                         self.configuration.twitchClientId,
                         encodedRedirectUrl,
                         [scopes componentsJoinedByString:@"+"],
                         [[NSUUID UUID] UUIDString]];
    
    webVc.webview.navigationDelegate = self;
    [webVc.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:authUrl]]];
    webVc.title = @"Twitch";
    __weak UIViewController *weaknav = nav;
    __weak __typeof(self)weakSelf = self;
    webVc.onCancelled = ^{
        [weaknav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->webController = nil;
        strongSelf.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
    };
    webController = nav;
    [self.topViewController presentViewController:nav animated:YES completion:nil];
}

- (void)refreshToken:(void (^)(BOOL, NSError *))completion
{
    NSParameterAssert(self.credential.refreshToken);
    
    NSString *encodedRefreshToken = [self.credential.refreshToken stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *reqUrl = [NSString stringWithFormat:@"https://id.twitch.tv/oauth2/token?grant_type=refresh_token&refresh_token=%@&client_id=%@&client_secret=%@",
                        encodedRefreshToken,
                        self.configuration.twitchClientId,
                        self.configuration.twitchSecret];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    req.HTTPMethod = @"POST";
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && !error) {
            NSError *serializationError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
            if (serializationError == nil) {
                NSString *accessToken = resultDict[@"access_token"];
                NSString *refreshToken = resultDict[@"refresh_token"];
                NSInteger expiresIn = [resultDict[@"expires_in"] integerValue];
                
                if (accessToken.length == 0 || refreshToken.length == 0) {
                    NSString *reason = [NSString stringWithFormat:@"Token refresh data invalid: %@",resultDict];
                    completion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                
                SSAuthCredential *credential = [SSAuthCredential new];
                credential.accessToken = accessToken;
                credential.estimatedExpireDate = [[NSDate date] dateByAddingTimeInterval:(NSTimeInterval)expiresIn];
                credential.refreshToken = refreshToken;
                credential.platform = SSPlatformTwitch;
                self.credential = credential;
                
                completion(YES, nil);
            } else {
                completion(NO, serializationError);
            }
        } else {
            completion(NO, error);
        }
    }] resume];
}

- (void)onAccessCode:(NSString *)codeResultString
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->webController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    });
    
    NSDictionary *dict = URLQueryParameters(codeResultString);
    NSString *code = dict[@"code"];
    if (code == nil) {
        self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
        return;
    }
    
    NSString *encodedRedirectUrl = [self.configuration.twitchRedirectUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *reqUrl = [NSString stringWithFormat:@"https://id.twitch.tv/oauth2/token?client_id=%@&client_secret=%@&code=%@&grant_type=authorization_code&redirect_uri=%@",
                        self.configuration.twitchClientId,
                        self.configuration.twitchSecret,
                        code,
                        encodedRedirectUrl];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqUrl]];
    req.HTTPMethod = @"POST";
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && !error) {
            NSError *serializationError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
            if (serializationError == nil) {
                NSString *accessToken = resultDict[@"access_token"];
                NSString *refreshToken = resultDict[@"refresh_token"];
                NSInteger expiresIn = [resultDict[@"expires_in"] integerValue];
                
                if (accessToken.length == 0 || refreshToken.length == 0 || expiresIn <= 0) {
                    NSString *reason = [NSString stringWithFormat:@"Token refresh data invalid: %@",resultDict];
                    self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                    return;
                }
                
                SSAuthCredential *credential = [SSAuthCredential new];
                credential.accessToken = accessToken;
                credential.estimatedExpireDate = [[NSDate date] dateByAddingTimeInterval:(NSTimeInterval)expiresIn];
                credential.refreshToken = refreshToken;
                credential.platform = SSPlatformTwitch;
                self.credential = credential;
                
                self.authCompletion(credential, nil);
            } else {
                self.authCompletion(nil, serializationError);
            }
        } else {
            self.authCompletion(nil, error);
        }
    }] resume] ;
}

- (BOOL)appInstalled
{
    SSNotSupportMethod
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([navigationAction.request.URL.absoluteString hasPrefix:self.configuration.twitchRedirectUrl]) {
        NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:navigationAction.request.URL resolvingAgainstBaseURL:YES];
        [self onAccessCode:urlComponents.fragment?:urlComponents.query];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return ;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {}

@end
