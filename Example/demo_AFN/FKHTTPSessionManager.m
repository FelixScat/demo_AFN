//
//  FKHTTPSessionManager.m
//  demo_AFN_Example
//
//  Created by Felix on 2019/9/12.
//  Copyright © 2019 felix. All rights reserved.
//

#import "FKHTTPSessionManager.h"

@interface FKHTTPSessionManager ()

@property (readwrite, nonatomic, strong) NSURL *baseURL;

@end

@implementation FKHTTPSessionManager

- (instancetype)initWithBaseURL:(NSURL *)url sessionConfig:(NSURLSessionConfiguration *)sessionConfig {
    
    self = [super init];
    if (!self) {
        return nil;
    }
    
    
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }
    
    self.baseURL = url;
    
    
    return self;
}

@end
