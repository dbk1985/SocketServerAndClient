//
//  MSSocketClient.m
//  MSocket
//
//  Created by alan on 2020/7/30.
//  Copyright © 2020 OceanMaster. All rights reserved.
//

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "MSSocketClient.h"

#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DDASLLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface MSSocketClient ()<GCDAsyncSocketDelegate,NSNetServiceBrowserDelegate, NSNetServiceDelegate>
/** client_socket */
@property (nonatomic,strong) GCDAsyncSocket *asyncSocket;
@property (nonatomic, strong) NSString *serverHost;
@property (nonatomic, assign) NSUInteger port;

@end

@implementation MSSocketClient
{
    NSNetServiceBrowser *netServiceBrowser;
    NSNetService *serverService;
    NSMutableArray *serverAddresses;
    BOOL connected;
}

+ (instancetype)shareClient:(NSString *)url port:(NSUInteger)port
{
    static dispatch_once_t onceToken;
    static MSSocketClient *client = nil;
    dispatch_once(&onceToken, ^{
        client = [[MSSocketClient alloc] init];
        client.serverHost = url;
        client.port = port;
    });
    return client;
}
+ (instancetype)shareClient
{
    static dispatch_once_t onceToken;
    static MSSocketClient *client = nil;
    dispatch_once(&onceToken, ^{
        client = [[MSSocketClient alloc] init];
        // Start browsing for bonjour services
        client.asyncSocket = nil;
        client->netServiceBrowser = [[NSNetServiceBrowser alloc] init];
        
        [client->netServiceBrowser setDelegate:client];
        [client->netServiceBrowser searchForServicesOfType:@"_YourServiceName._tcp." inDomain:@"local."];
    });
    return client;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.asyncSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    }
    return self;
}

- (void)connect {
    NSError *error = nil;
    [self.asyncSocket connectToHost:self.serverHost onPort:self.port error:&error];
    if (error) {
        
    }
}

- (void)disconnect {
    [self.asyncSocket disconnect];
}

#pragma mark - NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)sender didNotSearch:(NSDictionary *)errorInfo
{
    DDLogError(@"DidNotSearch: %@", errorInfo);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    DDLogVerbose(@"DidFindService: %@", [netService name]);
    
    // Connect to the first service we find
    if (serverService == nil)  {
        DDLogVerbose(@"Resolving...");
        serverService = netService;
        
        [serverService setDelegate:self];
        [serverService resolveWithTimeout:5.0];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
         didRemoveService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    DDLogVerbose(@"DidRemoveService: %@", [netService name]);
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)sender
{
    DDLogInfo(@"DidStopSearch");
}

#pragma mark - NSNetServiceDelegate
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    DDLogError(@"DidNotResolve");
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    DDLogInfo(@"DidResolve: %@", [sender addresses]);
    if (serverAddresses == nil) {
        serverAddresses = [[sender addresses] mutableCopy];
    }
    
    if (self.asyncSocket == nil) {
        self.asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
        [self connectToNextAddress];
    }
}

#pragma mark - GCDAsyncSocketDelegate
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    //再把数组发送给每一个连接的客户端
    NSArray *dataFromServer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSLog(@"data from server: %@",dataFromServer);
    
    // 向服务器发送数据
    NSData *clientData = [NSKeyedArchiver archivedDataWithRootObject:[NSString stringWithFormat:@"你好服务器：%@",[NSDate new]]];
    [self.asyncSocket writeData:clientData withTimeout:-1 tag:321];
    // 处理收到的数据
    [sock readDataWithTimeout:-1 tag:0];
}


-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    connected = YES;
    DDLogInfo(@"Socket:DidConnectToHost: %@ Port: %hu", host, port);
    NSString *sendStr = @"eqrwerqwerqwerqwerwq";
    //根据当前选中的客户端socket来发送消息
    [/*self.asyncSocket*/sock writeData:[sendStr dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:321];
    [sock readDataWithTimeout:-1 tag:0];
}

-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    //断开连接时，清空数据源
    
    if (serverAddresses && serverAddresses.count > 0 && !connected){
        [self connectToNextAddress];
    }
}


#pragma mark - Private
- (void)connectToNextAddress
{
    BOOL done = NO;
    
    while (!done && ([serverAddresses count] > 0)) {
        NSData *addr;
        
        // Note: The serverAddresses array probably contains both IPv4 and IPv6 addresses.
        //
        // If your server is also using GCDAsyncSocket then you don't have to worry about it,
        // as the socket automatically handles both protocols for you transparently.
        
        if (YES) // Iterate forwards
        {
            addr = [serverAddresses firstObject];
            [serverAddresses removeObjectAtIndex:0];
        }
        else // Iterate backwards
        {
            addr = [serverAddresses lastObject];
            [serverAddresses removeLastObject];
        }
        
        DDLogVerbose(@"Attempting connection to %@", addr);
        
        NSError *err = nil;
        if ([self.asyncSocket connectToAddress:addr error:&err])
        {
            done = YES;
        }
        else
        {
            DDLogWarn(@"Unable to connect: %@", err);
        }
        
    }
    
    if (!done)
    {
        DDLogWarn(@"Unable to connect to any resolved address");
    }
}


@end
