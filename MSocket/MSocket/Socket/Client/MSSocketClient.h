//
//  MSSocketClient.h
//  MSocket
//
//  Created by alan on 2020/7/30.
//  Copyright © 2020 OceanMaster. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MSSocketClientDelegate <NSObject>

- (void)sendMessage:(NSData *)data;
- (void)receiveData:(NSData *)data;

@end

@interface MSSocketClient : NSObject
+ (instancetype)shareClient:(NSString *)url port:(NSUInteger)port;
+ (instancetype)shareClient;
- (void)connect;
- (void)disconnect;
@end

NS_ASSUME_NONNULL_END
