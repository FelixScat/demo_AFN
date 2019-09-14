# AFN

## Why AFN

为什么

## AFN 解析

### 基本使用

**GET**

```objective-c
- (void)sendRequest {
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURLSessionDataTask *task = [manager GET:@"http://httpbin.org/get" parameters:@{@"arg1":@(100), @"arg2": @{@"foo":@"bar"}} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
}

```

**POST**

```objective-c

- (void)sendRequest {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURLSessionDataTask *task = [manager POST:@"http://httpbin.org/post" parameters:@{@"arg1":@(100), @"arg2": @{@"foo":@"bar"}} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {

    }];
}

```

这是最简单的使用方法，下面我们一层一层分析**AFN**是怎样处理一个请求的

### 接口部分 AFHTTPSessionManager & AFURLSessionManager

**AFHTTPSessionManager**

```objective-c
+ (instancetype)manager {
    return [[[self class] alloc] initWithBaseURL:nil];
}

- (instancetype)init {
    return [self initWithBaseURL:nil];
}

- (instancetype)initWithBaseURL:(NSURL *)url {
    return [self initWithBaseURL:url sessionConfiguration:nil];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    return [self initWithBaseURL:nil sessionConfiguration:configuration];
}

- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration
{
    self = [super initWithSessionConfiguration:configuration];
    if (!self) {
        return nil;
    }

    // 这里为baseURL做处理，如果传入的URL没有加最后的斜杠这里会补上
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }

    self.baseURL = url;
		
    // 这里初始化了请求和响应的序列化对象，默认使用json作为响应的序列化方式
    self.requestSerializer = [AFHTTPRequestSerializer serializer];
    self.responseSerializer = [AFJSONResponseSerializer serializer];

    return self;
}
```

由于**AFHTTPSessionManager**是继承于**AFURLSessionManager**，我们接下来看下**AFURLSessionManager**的初始化方法

**AFURLSessionManager**

```objective-c
- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super init];
    if (!self) {
        return nil;
    }
		// 如果没有传入 NSURLSessionConfiguration 则初始化为 defaultSessionConfiguration
    if (!configuration) {
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }

    self.sessionConfiguration = configuration;
		
  	// 初始化网络请求回调的队列
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 1;
		
  	// 初始化 NSURLSession
    self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];

    self.responseSerializer = [AFJSONResponseSerializer serializer];
		
  	// 默认安全策略 AFSSLPinningModeNone
    self.securityPolicy = [AFSecurityPolicy defaultPolicy];

#if !TARGET_OS_WATCH
    self.reachabilityManager = [AFNetworkReachabilityManager sharedManager];
#endif
		
  	// 初始化任务代理的Map
    self.mutableTaskDelegatesKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
		
  	// 初始化锁
    self.lock = [[NSLock alloc] init];
    self.lock.name = AFURLSessionManagerLockName;
		
  	// 后台进入时重新写入代理
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        for (NSURLSessionDataTask *task in dataTasks) {
            [self addDelegateForDataTask:task uploadProgress:nil downloadProgress:nil completionHandler:nil];
        }

        for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
            [self addDelegateForUploadTask:uploadTask progress:nil completionHandler:nil];
        }

        for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
            [self addDelegateForDownloadTask:downloadTask progress:nil destination:nil completionHandler:nil];
        }
    }];

    return self;
}
```

说完了初始化我们来看具体的一个请求发送

```objective-c
- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{

    return [self GET:URLString parameters:parameters progress:nil success:success failure:failure];
}
```

最终会进入这个方法

```objective-c
- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                  uploadProgress:(nullable void (^)(NSProgress *uploadProgress)) uploadProgress
                                downloadProgress:(nullable void (^)(NSProgress *downloadProgress)) downloadProgress
                                         success:(void (^)(NSURLSessionDataTask *, id))success
                                         failure:(void (^)(NSURLSessionDataTask *, NSError *))failure
{
    NSError *serializationError = nil;
		
		// 由 requestSerializer 负责具体请求的解析 ,requestSerializer 部分下面会说
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:parameters error:&serializationError];
                                          
		// 如果请求解析失败返回nil，直接通过block返回
    if (serializationError) {
        if (failure) {
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError);
            });
        }

        return nil;
    }

    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:request
                          uploadProgress:uploadProgress
                        downloadProgress:downloadProgress
                       completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
        if (error) {
            if (failure) {
                failure(dataTask, error);
            }
        } else {
            if (success) {
                success(dataTask, responseObject);
            }
        }
    }];

    return dataTask;
}
```

再之后会进入这个方法

```objective-c
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                               uploadProgress:(nullable void (^)(NSProgress *uploadProgress)) uploadProgressBlock
                             downloadProgress:(nullable void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                            completionHandler:(nullable void (^)(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error))completionHandler {

    __block NSURLSessionDataTask *dataTask = nil;
    url_session_manager_create_task_safely(^{
        dataTask = [self.session dataTaskWithRequest:request];
    });

    [self addDelegateForDataTask:dataTask uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];

    return dataTask;
}
```

这里 **url_session_manager_create_task_safely** 解决了iOS8.0之前并行创建出来的 **task** 的 **taskIdentifier** 不唯一的BUG，实现起来就是使用GCD创建了一个串行队列进行task的操作，如下所示

```objective-c
static dispatch_queue_t url_session_manager_creation_queue() {
    static dispatch_queue_t af_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_creation_queue = dispatch_queue_create("com.alamofire.networking.session.manager.creation", DISPATCH_QUEUE_SERIAL);
    });

    return af_url_session_manager_creation_queue;
}

static void url_session_manager_create_task_safely(dispatch_block_t block) {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_With_Fixed_5871104061079552_bug) {
        // Fix of bug
        // Open Radar:http://openradar.appspot.com/radar?id=5871104061079552 (status: Fixed in iOS8)
        // Issue about:https://github.com/AFNetworking/AFNetworking/issues/2093
        dispatch_sync(url_session_manager_creation_queue(), block);
    } else {
        block();
    }
}
```

接下来继续查看上面的为task添加代理的方法 **addDelegateForDataTask**

```objective-c
- (void)addDelegateForDataTask:(NSURLSessionDataTask *)dataTask
                uploadProgress:(nullable void (^)(NSProgress *uploadProgress)) uploadProgressBlock
              downloadProgress:(nullable void (^)(NSProgress *downloadProgress)) downloadProgressBlock
             completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    // 初始化代理对象，整个任务的进度和回调由代理负责管理
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:dataTask];
    delegate.manager = self;
    delegate.completionHandler = completionHandler;

    dataTask.taskDescription = self.taskDescriptionForSessionTasks;
    // 将代理与对象关联，存进Map
    [self setDelegate:delegate forTask:dataTask];

    delegate.uploadProgressBlock = uploadProgressBlock;
    delegate.downloadProgressBlock = downloadProgressBlock;
}
```

由于对字典的操作不是线程安全的，所以使用 **NSLock** 加锁

```objective-c
- (void)setDelegate:(AFURLSessionManagerTaskDelegate *)delegate
            forTask:(NSURLSessionTask *)task
{
    NSParameterAssert(task);
    NSParameterAssert(delegate);

    [self.lock lock];
    self.mutableTaskDelegatesKeyedByTaskIdentifier[@(task.taskIdentifier)] = delegate;
    [self addNotificationObserverForTask:task];
    [self.lock unlock];
}
```

添加监听

```objective-c
- (void)addNotificationObserverForTask:(NSURLSessionTask *)task {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidResume:) name:AFNSURLSessionTaskDidResumeNotification object:task];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidSuspend:) name:AFNSURLSessionTaskDidSuspendNotification object:task];
}
```

在监听到状态变化时向外部发出通知，方便外部处理

```objective-c
- (void)taskDidResume:(NSNotification *)notification {
    NSURLSessionTask *task = notification.object;
    if ([task respondsToSelector:@selector(taskDescription)]) {
        if ([task.taskDescription isEqualToString:self.taskDescriptionForSessionTasks]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidResumeNotification object:task];
            });
        }
    }
}

- (void)taskDidSuspend:(NSNotification *)notification {
    NSURLSessionTask *task = notification.object;
    if ([task respondsToSelector:@selector(taskDescription)]) {
        if ([task.taskDescription isEqualToString:self.taskDescriptionForSessionTasks]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidSuspendNotification object:task];
            });
        }
    }
}
```

下面主要看 **AFURLSessionManagerTaskDelegate** 实现的这个方法

```objective-c
#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(__unused NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
  	// 取出 AFURLSessionManager
    __strong AFURLSessionManager *manager = self.manager;

    __block id responseObject = nil;

    __block NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[AFNetworkingTaskDidCompleteResponseSerializerKey] = manager.responseSerializer;

    // 当请求完成后释放内存
    NSData *data = nil;
    if (self.mutableData) {
        data = [self.mutableData copy];
        //We no longer need the reference, so nil it out to gain back some memory.
        self.mutableData = nil;
    }

    if (self.downloadFileURL) {
        userInfo[AFNetworkingTaskDidCompleteAssetPathKey] = self.downloadFileURL;
    } else if (data) {
        userInfo[AFNetworkingTaskDidCompleteResponseDataKey] = data;
    }

    if (error) {
        userInfo[AFNetworkingTaskDidCompleteErrorKey] = error;
				
      	// 异步添加到GCD任务组，如果没有指定会默认生成一个，回调队列如果没有指定会默认为主队列
        dispatch_group_async(manager.completionGroup ?: url_session_manager_completion_group(), manager.completionQueue ?: dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responseObject, error);
            }
						
          	// 在主队列中发送AFNetworkingTaskDidCompleteNotification通知
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
            });
        });
    } else {
        dispatch_async(url_session_manager_processing_queue(), ^{
            NSError *serializationError = nil;
            responseObject = [manager.responseSerializer responseObjectForResponse:task.response data:data error:&serializationError];

            if (self.downloadFileURL) {
                responseObject = self.downloadFileURL;
            }

            if (responseObject) {
                userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey] = responseObject;
            }

            if (serializationError) {
                userInfo[AFNetworkingTaskDidCompleteErrorKey] = serializationError;
            }

            dispatch_group_async(manager.completionGroup ?: url_session_manager_completion_group(), manager.completionQueue ?: dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(task.response, responseObject, serializationError);
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
                });
            });
        });
    }
}
```

**manager** 和 **taskDelegate** 部分先看到这里

### 序列化部分 AFURLRequestSerialization & AFURLResponseSerialization

#### 先从 **AFURLRequestSerialization** 开始看起

首先，AFURLRequestSerialization 只是协议，具体实现由遵守协议的类来实现，我们主要看 **AFHTTPRequestSerializer** 这个类

```objective-c
- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
		
  	// 设置默认字符串编码
    self.stringEncoding = NSUTF8StringEncoding;
	
  	// 初始化请求头的Map
    self.mutableHTTPRequestHeaders = [NSMutableDictionary dictionary];
  	// 为头部Map的变动创建一个并行队列
    self.requestHeaderModificationQueue = dispatch_queue_create("requestHeaderModificationQueue", DISPATCH_QUEUE_CONCURRENT);

    // 设置头部的 acceptLanguages
    NSMutableArray *acceptLanguagesComponents = [NSMutableArray array];
    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        float q = 1.0f - (idx * 0.1f);
        [acceptLanguagesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
        *stop = q <= 0.5f;
    }];
    [self setValue:[acceptLanguagesComponents componentsJoinedByString:@", "] forHTTPHeaderField:@"Accept-Language"];
		
  	// UA 标识符
    NSString *userAgent = nil;
#if TARGET_OS_IOS
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
#elif TARGET_OS_WATCH
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; watchOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[WKInterfaceDevice currentDevice] model], [[WKInterfaceDevice currentDevice] systemVersion], [[WKInterfaceDevice currentDevice] screenScale]];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    userAgent = [NSString stringWithFormat:@"%@/%@ (Mac OS X %@)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
    if (userAgent) {
        if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSMutableString *mutableUserAgent = [userAgent mutableCopy];
            if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false)) {
                userAgent = mutableUserAgent;
            }
        }
        [self setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    }

    // HTTP Method Definitions; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html
  	// 只有这几种请求Type会将参数编码进URL中
    self.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", @"DELETE", nil];

  	监听 AFHTTPRequestSerializerObservedKeyPaths 包含的key
    self.mutableObservedChangedKeyPaths = [NSMutableSet set];
    for (NSString *keyPath in AFHTTPRequestSerializerObservedKeyPaths()) {
        if ([self respondsToSelector:NSSelectorFromString(keyPath)]) {
            [self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:AFHTTPRequestSerializerObserverContext];
        }
    }

    return self;
}
```

这里观察的有这些，观察这些也是为了能够在相关的属性被设置的时候可以及时更新

```objective-c
// 允许蜂窝网络访问
// 缓存策略
// 是否响应setCookie
// http 复用 tcp 连接
static NSArray * AFHTTPRequestSerializerObservedKeyPaths() {
    static NSArray *_AFHTTPRequestSerializerObservedKeyPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _AFHTTPRequestSerializerObservedKeyPaths = @[NSStringFromSelector(@selector(allowsCellularAccess)), NSStringFromSelector(@selector(cachePolicy)), NSStringFromSelector(@selector(HTTPShouldHandleCookies)), NSStringFromSelector(@selector(HTTPShouldUsePipelining)), NSStringFromSelector(@selector(networkServiceType)), NSStringFromSelector(@selector(timeoutInterval))];
    });

    return _AFHTTPRequestSerializerObservedKeyPaths;
}
```



### 安全策略部分 AFSecurityPolicy


