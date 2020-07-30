//
//  MSSocketServer.m
//  MSocket
//
//  Created by alan on 2020/7/30.
//  Copyright © 2020 OceanMaster. All rights reserved.
//

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "MSSocketServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DDASLLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_INFO;

@interface MSSocketServer  ()<GCDAsyncSocketDelegate,NSNetServiceDelegate>
/** 端口 */
@property (nonatomic,assign)uint16_t port;
/** 监听地址 */
@property (nonatomic,copy) NSString *listenURL;
/** socket */
@property (nonatomic,strong) GCDAsyncSocket *asyncSocket;
/** 客户端socket数组 */
@property (nonatomic,strong)NSMutableArray *clientSockets;
/** 代理 */
@property (nonatomic,weak)id<MSSocketServerDelegate> delegate;

@end

@implementation MSSocketServer
{
    dispatch_queue_t socketQueue;
    NSNetService *netService;
}

+ (instancetype)shareServer:(NSString *)url port:(NSUInteger)port delegate:(nullable id<MSSocketServerDelegate>)delegate
{
    static dispatch_once_t onceToken;
    static MSSocketServer *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[MSSocketServer alloc] init];
        instance.port = port;
        instance.listenURL = url;
        instance.delegate = delegate;
    });
    return  instance;
}

+ (instancetype)shareServer:(nullable id<MSSocketServerDelegate>)delegate
{
    static dispatch_once_t onceToken;
    static MSSocketServer *instance = nil;
    
    dispatch_once(&onceToken, ^{
        instance = [[MSSocketServer alloc] init];
        // Now we tell the socket to accept incoming connections.
        // We don't care what port it listens on, so we pass zero for the port number.
        // This allows the operating system to automatically assign us an available port.
        
        NSError *err = nil;
        if ([instance.asyncSocket acceptOnPort:0 error:&err]){
            // So what port did the OS give us?
            
            UInt16 port = [instance.asyncSocket localPort];
            
            // Create and publish the bonjour service.
            // Obviously you will be using your own custom service type.
            
            instance->netService = [[NSNetService alloc] initWithDomain:@"local."
                                                         type:@"_YourServiceName._tcp."
                                                         name:@""
                                                         port:port];
            
            [instance->netService setDelegate:instance];
            [instance->netService publish];
            
            // You can optionally add TXT record stuff
            
            NSMutableDictionary *txtDict = [NSMutableDictionary dictionaryWithCapacity:2];
            
            [txtDict setObject:@"moo" forKey:@"cow"];
            [txtDict setObject:@"quack" forKey:@"duck"];
            
            NSData *txtData = [NSNetService dataFromTXTRecordDictionary:txtDict];
            [instance->netService setTXTRecordData:txtData];
        }
    });
    return  instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Create an array to hold accepted incoming connections.
        self.clientSockets = [[NSMutableArray alloc] init];
        socketQueue = dispatch_queue_create("socketQueue", NULL);
        self.asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    }
    return self;
}


- (void)startListen
{
    NSError *error = nil;
    
    [self.asyncSocket acceptOnInterface:self.listenURL port:self.port error:&error];

    if (error) {
        NSLog(@"开启监听失败 : %@",error);
    }else{
        NSLog(@"开启监听成功");
    }
}

- (void)stopListen
{
    // Stop accepting connections
    [self.asyncSocket disconnect];
    
    // Stop any client connections
    @synchronized(self.clientSockets)
    {
        NSUInteger i;
        for (i = 0; i < [self.clientSockets count]; i++)
        {
            // Call disconnect on the socket,
            // which will invoke the socketDidDisconnect: method,
            // which will remove the socket from the list.
            [[self.clientSockets objectAtIndex:i] disconnect];
        }
    }
}

#pragma mark - NSNetServiceDelegate
- (void)netServiceDidPublish:(NSNetService *)ns
{
    NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@) port(%i)",
              [ns domain], [ns type], [ns name], (int)[ns port]);
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
    // Override me to do something here...
    //
    // Note: This method in invoked on our bonjour thread.
    
    DDLogError(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@",
                [ns domain], [ns type], [ns name], errorDict);
}

#pragma mark - GCDAsyncSocketDelegate
-(void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    
    //存放客户端的socket对象。
    // This method is executed on the socketQueue (not the main thread)
    @synchronized(self.clientSockets)
    {
        [self.clientSockets addObject:newSocket];
    }
    
    [newSocket readDataWithTimeout:-1 tag:0];
    
    //向每一个客户端发送给在线客户端列表
    [self sendClientList];
}



#pragma mark - GCDAsyncSocketDelegate
-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{

    //每当有客户端断开连接的时候，客户端数组移除该socket
    @synchronized (self.clientSockets) {
        [self.clientSockets removeObject:sock];
    }
    
    
    //向每一个客户端发送给在线客户端列表
    [self sendClientList];
}



-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    if ([self.delegate respondsToSelector:@selector(socketServer:didReadData:withTag:)]) {
        [self.delegate socketServer:sock didReadData:data withTag:tag];
    }
    NSString *str = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSLog(@"data from client: %@",str);
    [self sendClientList];
    [sock readDataWithTimeout:-1 tag:tag];
}

/**
 *  向每一个连接的客户端发送所有
 */
-(void)sendClientList{
    //把socket对象中的host和post转化成字符串，存放到数组中
    NSMutableArray *hostArrM = [NSMutableArray array];
    for (GCDAsyncSocket *clientSocket in self.clientSockets) {
        NSString *host_port = [NSString stringWithFormat:@"%@:%d ======== %@",clientSocket.connectedHost,clientSocket.connectedPort, [[NSDate alloc] init]];
        [hostArrM addObject:host_port];
    }
    
    //再把数组发送给每一个连接的客户端
    NSData *clientData = [NSKeyedArchiver archivedDataWithRootObject:hostArrM];
    
    for (GCDAsyncSocket *clientSocket in self.clientSockets) {
        [clientSocket writeData:clientData withTimeout:-1 tag:0];
    }
}


@end
