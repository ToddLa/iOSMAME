//
//  MameDraw.h
//  IOSMAME
//
//  Created by ToddLa on 4/11/21.
//
#import "MetalView.h"
#import "libmame.h"

NS_ASSUME_NONNULL_BEGIN

@interface MetalView (MameDraw)

- (void)drawMamePrimitives:(myosd_render_primitive*)prim_list size:(CGSize)size;
- (void)dumpMamePrimitives:(myosd_render_primitive*)prim_list size:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
