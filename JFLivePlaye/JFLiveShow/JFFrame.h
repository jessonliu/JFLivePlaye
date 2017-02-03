//
//  JFFrame.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/9.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JFFrame : NSObject

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
// flv或者rtmp包头
@property (nonatomic, strong) NSData *header;

@end
