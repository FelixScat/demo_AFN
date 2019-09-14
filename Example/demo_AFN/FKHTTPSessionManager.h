//
//  FKHTTPSessionManager.h
//  demo_AFN_Example
//
//  Created by Felix on 2019/9/12.
//  Copyright © 2019 felix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FKHTTPSessionManager : NSObject

@property (readonly, nonatomic, strong, nullable) NSURL *baseURL;

@end

NS_ASSUME_NONNULL_END
