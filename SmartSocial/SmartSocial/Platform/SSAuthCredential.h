//
//  SSAuthCredential.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSInterfaces.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSAuthCredential : NSObject<ISSAuthCredential, NSCoding>
@property (nonatomic, strong) NSString *refreshToken;
@property (nonatomic, strong) NSString *wechatOpenId;
@property (nonatomic, strong) NSString *weiboUid;
@property (nonatomic, strong) NSString *qqOpenId;
@property (nonatomic, strong) NSString *fbAppId;
@property (nonatomic, strong) NSString *fbUserId;
@property (nonatomic, strong) NSArray<NSString *> *fbGrantedPermissions;
@property (nonatomic, strong) NSArray<NSString *> *fbDeclinedPermissions;
@property (nonatomic, strong) NSDate *fbTokenRefreshDate;
@property (nonatomic, strong) NSString *twitterAccessTokenSecret;
@property (nonatomic, strong) NSString *twitterUid;
@property (nonatomic, strong) NSString *twitterUserName;
@property (nonatomic, strong) NSString *vkUserId;

- (BOOL)isTokenValid;

@end

NS_ASSUME_NONNULL_END
