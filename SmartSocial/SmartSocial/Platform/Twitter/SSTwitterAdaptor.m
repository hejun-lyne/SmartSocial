//
//  SSTwitterAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSTwitterAdaptor.h"

#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKNavigationAction.h>

typedef void(^SSTwitterUploadCompletionBlock)(NSString *mediaId, NSError *error);

@interface SSTwitterAdaptor()<WKNavigationDelegate>
@end
@interface SSTwitterImageHolder : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *imageUrl;
@property (nonatomic, strong) NSString *mediaId;
@end
@implementation SSTwitterImageHolder
@end
@implementation SSTwitterAdaptor
{
    NSString *oauthToken, *oauthSecret, *oauthVerifier;
    UIViewController *authController;
}

#define AuthDomain @"TwitterAuth"
#define ShareDomain @"TwitterShare"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (![self.credential isTokenValid]) {
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
    
    NSMutableDictionary *params = @{@"status": [NSString stringWithFormat:@"%@ %@", info.content, info.url]}.mutableCopy;
    
    if (info.shareImages.count > 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray<SSTwitterImageHolder *> *imageHolders = [NSMutableArray arrayWithCapacity:info.shareImages.count];
            for (id obj in info.shareImages) {
                SSTwitterImageHolder *holder = [SSTwitterImageHolder new];
                if ([obj isKindOfClass:[NSString class]]) {
                    holder.imageUrl = obj;
                }else {
                    holder.image = obj;
                }
                [imageHolders addObject:holder];
            }
            
            __block NSError *uploadError = nil;
            dispatch_group_t uploadGroup = dispatch_group_create();
            void (^uploadImage)(SSTwitterImageHolder *) = ^(SSTwitterImageHolder *holder) {
                [self uploadImage:holder.image completion:^(NSString *mediaId, NSError *error) {
                    if (mediaId != nil) {
                        holder.mediaId = mediaId;
                    } else if (error != nil) {
                        uploadError = error;
                    }
                    dispatch_group_leave(uploadGroup);
                }];
            };
            for (SSTwitterImageHolder *holder in imageHolders) {
                dispatch_group_enter(uploadGroup);
                if (holder.image) {
                    uploadImage(holder);
                } else {
                    [SSImageDownloader downloadImageWithURL:holder.imageUrl completion:^(UIImage *image, NSError *error) {
                        if (error != nil) {
                            uploadError = error;
                            dispatch_group_leave(uploadGroup);
                            return;
                        }
                        holder.image = image;
                        uploadImage(holder);
                    }];
                }
            }
            
            dispatch_group_notify(uploadGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (uploadError != nil) {
                    self.shareCompletion(NO, uploadError);
                } else {
                    
                    NSMutableArray<NSString *> *mediaIds = [NSMutableArray arrayWithCapacity:imageHolders.count];
                    for (SSTwitterImageHolder *holder in imageHolders) {
                        if (holder.mediaId != nil) {
                            [mediaIds addObject:holder.mediaId];
                        }
                    }
                    if (mediaIds.count > 0) {
                        [params setObject:[mediaIds componentsJoinedByString:@","] forKey:@"media_ids"];
                    }
                    [self apiRequestWithCommand:@"/1.1/statuses/update.json"
                                         method:@"POST"
                                     authParams:@{@"oauth_token": self.credential.accessToken}
                                  requestParams:params
                                     completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                         self.shareCompletion(error == nil, error);
                                     }];
                    
                }
            });
        });
    } else {
        [self apiRequestWithCommand:@"/1.1/statuses/update.json"
                             method:@"POST"
                         authParams:@{@"oauth_token": self.credential.accessToken}
                      requestParams:params
                         completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                             self.shareCompletion(error == nil, error);
                         }];
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
    
    [self apiRequestWithCommand:@"/1.1/users/show.json"
                         method:@"GET"
                     authParams:@{@"oauth_token": self.credential.accessToken}
                  requestParams:@{ @"user_id": self.credential.twitterUid }
                     completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                         if (error != nil) {
                             self.requestUserInfoCompletion(nil, error);
                             return;
                         }
                         NSError *serializationError;
                         NSDictionary *userInfoDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&serializationError];
                         if (serializationError) {
                             self.requestUserInfoCompletion(nil, serializationError);
                         }
                         
                         SSUserInfo *info = [SSUserInfo new];
                         info.uid = userInfoDict[@"id_str"];
                         info.nickname = userInfoDict[@"name"];
                         info.gender = SSUserGenderUnknown;
                         info.avatarUrl = userInfoDict[@"profile_image_url_https"];
                         info.signature = userInfoDict[@"description"];
                         
                         self.requestUserInfoCompletion(info, nil);
                     }];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([self.credential isTokenValid]) {
        self.authCompletion(self.credential, nil);
        return;
    }
    
    // OAuth ：https://oauth.net/core/1.0/#anchor9
    [self apiRequestWithCommand:@"/oauth/request_token"
                         method:@"POST"
                     authParams:nil
                  requestParams:nil
                     completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                         if (error != nil) {
                             self.authCompletion(nil, error);
                             return;
                         }
                         
                         NSString *resString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                         NSDictionary *resDict = URLQueryParameters(resString);
                         NSString *oauthToken = resDict[@"oauth_token"];
                         NSString *oauthTokenSecret = resDict[@"oauth_token_secret"];
                         BOOL cbConfirmed = [resDict[@"oauth_callback_confirmed"] boolValue];
                         
                         if (oauthToken.length == 0 || oauthTokenSecret.length == 0 || !cbConfirmed) {
                             NSString *reason = [NSString stringWithFormat:@"Data Invalid: %@", resDict];
                             self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
                             return;
                         }
                         self->oauthToken = oauthToken;
                         self->oauthSecret = oauthTokenSecret;
                         
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self authInWeb];
                         });
                     }];
}

- (void)authInWeb
{
    SSWebViewController *webVc = [SSWebViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVc];
    
    NSString *authUrl = [NSString stringWithFormat:@"https://api.twitter.com/oauth/authenticate?oauth_token=%@", oauthToken];
    webVc.webview.navigationDelegate = self;
    [webVc.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:authUrl]]];
    webVc.title = @"Twitter";
    __weak UIViewController *weaknav = nav;
    __weak __typeof(self)weakSelf = self;
    webVc.onCancelled = ^{
        [weaknav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->authController = nil;
        self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
    };
    authController = nav;
    
    [self.topViewController presentViewController:nav animated:YES completion:nil];
}

- (void)onTokenVerify:(NSString *)resultString
{
    NSDictionary *resDict = URLQueryParameters(resultString);
    
    NSString *oToken = resDict[@"oauth_token"];
    NSString *oVerifier = resDict[@"oauth_verifier"];
    
    if (![oauthToken isEqualToString:oToken] || oVerifier.length == 0) {
        if (authController != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->authController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                self->authController = nil;
            });
        }
        self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Twitter token verifier error."}));
        return;
    }
    
    oauthVerifier = oVerifier;
    
    [self apiRequestWithCommand:@"/oauth/access_token"
                         method:@"POST"
                     authParams:@{
                                  @"oauth_verifier": oauthVerifier,
                                  @"oauth_token": oauthToken
                                  }
                  requestParams:nil
                     completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                         if (error != nil) {
                             self.authCompletion(nil, error);
                         } else {
                             [self onAccessToken:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                         }
                     }];
}

- (void)onAccessToken:(NSString *)resultString
{
    NSDictionary *resDict = URLQueryParameters(resultString);
    NSString *accessToken = resDict[@"oauth_token"];
    NSString *accessTokenSecret = resDict[@"oauth_token_secret"];
    NSString *uid = resDict[@"user_id"];
    NSString *userName = resDict[@"screen_name"];
    
    if (accessToken.length == 0
        || accessTokenSecret.length == 0
        || uid.length == 0
        || userName.length == 0) {
        self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Twitter accessToken bad data."}));
        return;
    }
    
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.platform = SSPlatformTwitter;
    credential.accessToken = accessToken;
    credential.twitterAccessTokenSecret = accessTokenSecret;
    credential.twitterUid = uid;
    credential.twitterUserName = userName;
    
    if (authController != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->authController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
            self->authController = nil;
        });
    }
    self.credential = credential;
    self.authCompletion(credential, nil);
}

- (BOOL)appInstalled
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([navigationAction.request.URL.absoluteString containsString:self.configuration.twitterRedirectUrl]) {
        NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:navigationAction.request.URL resolvingAgainstBaseURL:YES];
        [self onTokenVerify:urlComponents.query];
        
        decisionHandler(WKNavigationActionPolicyCancel);
        return ;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Network

- (void)uploadImage:(UIImage *)image completion:(SSTwitterUploadCompletionBlock)completion
{
    NSString *boundary = @"Boundary-ath";
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    NSString *contentType = @"Content-Type: image/jpeg";
    
    NSMutableData *requestData = [NSMutableData new];
    NSString *pair = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n",boundary,@"media"];
    [requestData appendData:[pair dataUsingEncoding:NSUTF8StringEncoding]];
    [requestData appendData:imageData];
    [requestData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [requestData appendData:[contentType dataUsingEncoding:NSUTF8StringEncoding]];
    [requestData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [self requestWithHost:@"https://upload.twitter.com"
                                command:@"/1.1/media/upload.json"
                                 method:@"POST"
                             authParams:@{@"oauth_token": self.credential.accessToken}
                          requestParams:nil
                           customHeader:@{@"Content-Type": [NSString stringWithFormat:@"multipart/form-data;boundary=%@",boundary]}
                                   body:requestData
                             completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                 if (error != nil) {
                                     completion(nil, error);
                                     return;
                                 }
                                 
                                 NSError *serializationError;
                                 NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
                                 if (serializationError != nil) {
                                     completion(nil, serializationError);
                                     return;
                                 }
                                 
                                 NSString *mediaId = dict[@"media_id_string"];
                                 if (mediaId != nil) {
                                     completion(mediaId, nil);
                                 } else {
                                     completion(nil, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Upload image responsed with nil mediaId"}));
                                 }
                             }];
}

- (void)apiRequestWithCommand:(NSString *)command
                       method:(NSString *)method
                   authParams:(NSDictionary *)authParams
                requestParams:(NSDictionary *)reqParam
                   completion:(void(^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completion
{
    [self requestWithHost:@"https://api.twitter.com"
                  command:command
                   method:method
               authParams:authParams
            requestParams:reqParam
             customHeader:nil
                     body:nil
               completion:completion];
}


- (void)requestWithHost:(NSString *)host
                command:(NSString *)command
                 method:(NSString *)method
             authParams:(NSDictionary *)authParams
          requestParams:(NSDictionary *)reqParam
           customHeader:(NSDictionary *)customHeader
                   body:(NSData *)body
             completion:(void(^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completion
{
    __block NSString *requestURL = [host stringByAppendingString:command];
    
    //encode first
    NSMutableDictionary *encodedParam = @{}.mutableCopy;
    __block NSString *query = @"";
    
    if (reqParam.count > 0) {
        [reqParam enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *encodedKey = [self stringByAddingPercentEncodingForRFC3986:key];
            NSString *encodedVal = [self stringByAddingPercentEncodingForRFC3986:obj];
            query = [query stringByAppendingString:[NSString stringWithFormat:@"%@=%@&",encodedKey,encodedVal]];
            [encodedParam setObject:encodedVal forKey:encodedKey];
        }];
        query = [query substringToIndex:query.length-1];
    }
    
    NSString *authString = [self httpHeaderWithMethod:method requestURL:requestURL customParamDict:authParams requestParamDict:encodedParam];
    
    if (![method isEqualToString:@"POST"]) {
        requestURL = [NSString stringWithFormat:@"%@?%@",requestURL,query];
    }
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestURL]];
    if ([method isEqualToString:@"POST"]) {
        if (query.length > 0 && body.length > 0) {
            //assert
        }
        URLRequest.HTTPBody = body?:[query dataUsingEncoding:NSUTF8StringEncoding];
    }
    URLRequest.HTTPMethod = method;
    NSMutableDictionary *headerFields = [NSMutableDictionary new];
    if (customHeader) {
        [headerFields addEntriesFromDictionary:customHeader];
    }
    [headerFields addEntriesFromDictionary:@{@"Authorization": authString}];
    URLRequest.allHTTPHeaderFields = [headerFields copy];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:URLRequest completionHandler:completion] resume] ;
}

- (NSString *)stringByAddingPercentEncodingForRFC3986:(NSString *)str
{
    NSString *unreserved = @"-._~";
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet
                                      decimalDigitCharacterSet];
    [allowed formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
    [allowed addCharactersInString:unreserved];
    [allowed removeCharactersInString:@"="];
    return [str
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowed];
}

- (NSString *)httpHeaderWithMethod:(NSString *)method requestURL:(NSString *)reqURLString customParamDict:(NSDictionary *)customParamDict requestParamDict:(NSDictionary *)requestParamDict
{
    NSString *consumerKey = self.configuration.twitterConsumerKey;
    NSString *consumerSecret = self.configuration.twitterSecret;
    NSString *nonce = SSRandomString(32);
    NSString *sigMethod = @"HMAC-SHA1";
    NSString *timestamp = [NSString stringWithFormat:@"%.0lf",[[NSDate date] timeIntervalSince1970]];
    NSString *version = @"1.0";
    
    NSDictionary *paramDict = @{
                                @"oauth_consumer_key": consumerKey,
                                @"oauth_nonce": nonce,
                                @"oauth_signature_method": sigMethod,
                                @"oauth_timestamp": timestamp,
                                @"oauth_version": version
                                };
    if (customParamDict) {
        NSMutableDictionary *mdict = paramDict.mutableCopy;
        [mdict addEntriesFromDictionary:customParamDict];
        paramDict = [mdict copy];
    }
    if (requestParamDict) {
        NSMutableDictionary *mdict = paramDict.mutableCopy;
        [mdict addEntriesFromDictionary:requestParamDict];
        paramDict = [mdict copy];
    }
    NSMutableDictionary *encodedParam = @{}.mutableCopy;
    //1.Percent encode every key and value that will be signed.
    for (NSString *key in paramDict.allKeys) {
        [encodedParam setObject:[self stringByAddingPercentEncodingForRFC3986:paramDict[key]]
                         forKey:[self stringByAddingPercentEncodingForRFC3986:key]];
    }
    NSArray *sortedKeys = [encodedParam.allKeys.mutableCopy sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    
    NSMutableArray *encodedParamArr = [NSMutableArray new];
    for (NSString *key in sortedKeys) {
        [encodedParamArr addObject:[NSString stringWithFormat:@"%@%@%@",key,[@"=" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet whitespaceCharacterSet]],encodedParam[key]]];
    }
    
    NSString *paramString = [encodedParamArr componentsJoinedByString:[@"&" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet whitespaceCharacterSet]]];
    
    NSString *urlString = [NSString stringWithFormat:@"%@&%@&%@",
                           method,
                           [self stringByAddingPercentEncodingForRFC3986:reqURLString],paramString];
    
    NSString *sigKey = [[self stringByAddingPercentEncodingForRFC3986:consumerSecret] stringByAppendingString:@"&"];
    if (self.credential.twitterAccessTokenSecret.length > 0) {
        sigKey = [sigKey stringByAppendingString:[self stringByAddingPercentEncodingForRFC3986:self.credential.twitterAccessTokenSecret]];
    }
    
    NSString *signature = [self stringByAddingPercentEncodingForRFC3986:SSHMACSHA1(sigKey, urlString)];
    NSDictionary *finalParamDict = @{
                                     @"oauth_consumer_key": consumerKey,
                                     @"oauth_nonce": nonce,
                                     @"oauth_signature_method": sigMethod,
                                     @"oauth_timestamp": timestamp,
                                     @"oauth_version": version,
                                     @"oauth_signature": signature
                                     };
    if (customParamDict) {
        NSMutableDictionary *mdict = finalParamDict.mutableCopy;
        [mdict addEntriesFromDictionary:customParamDict];
        finalParamDict = [mdict copy];
    }
    
    NSMutableString *str = [@"OAuth " mutableCopy];
    [finalParamDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [str appendString:[NSString stringWithFormat:@"%@=%@,",key,obj]];
    }];
    NSString *authString = [str substringToIndex:str.length-1];
    
    return authString;
}

@end
