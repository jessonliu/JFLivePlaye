//
//  NSMutableArray+JFAdd.m
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/12.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import "NSMutableArray+JFAdd.h"

@implementation NSMutableArray (JFAdd)

- (void)JF_RemoveFirstObject {
    if (self.count) {
        [self removeObjectAtIndex:0];
    }
}

- (id)JF_PopFirstObject {
    id obj = nil;
    if (self.count) {
        obj = self.firstObject;
        [self JF_RemoveFirstObject];
    }
    return obj;
}

@end
