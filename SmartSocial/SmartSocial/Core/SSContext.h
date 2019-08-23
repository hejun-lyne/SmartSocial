//
//  SSContext.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/21.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSInterfaces.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSContext : NSObject<SSInterfaces>

+ (instancetype)shared;

- (void)registerAdaptor:(id)adaptor forPlatform:(SSPlatform)platform channels:(NSArray<NSNumber *> *)channels;

@end

NS_ASSUME_NONNULL_END
