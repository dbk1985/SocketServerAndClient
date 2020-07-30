//
//  SMSocketServer.h
//  MSocket
//
//  Created by alan on 2020/7/30.
//  Copyright © 2020 OceanMaster. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GCDAsyncSocket;
@protocol SMSocketServerDelegate <NSObject>
@optional
-(void)socketServer:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;
@end

@interface MSSocketServer : NSObject

/**
 *  单例类方法
 *
 *  @return 单例对象
 */
+(instancetype)shareServer:(NSString *)url port: (NSUInteger)port delegate:(nullable id<SMSocketServerDelegate>)delegate;

+(instancetype)shareServer:(nullable id<SMSocketServerDelegate>)delegate;

/**
 *  开始监听
 */
-(void)startListen;

@end

NS_ASSUME_NONNULL_END
