//
//  MameDraw.m
//  IOSMAME
//
//  Created by ToddLa on 4/11/21.
//
#import "MameDraw.h"

@implementation MetalView (MameDraw)

#pragma mark - texture conversion

static void load_texture_prim(id<MTLTexture> texture, myosd_render_primitive* prim) {
    
    NSUInteger width = texture.width;
    NSUInteger height = texture.height;

    #define TEMP_BUFFER_WIDTH  4096
    #define TEMP_BUFFER_HEIGHT 2048
    static uint32_t temp_buffer[TEMP_BUFFER_WIDTH * TEMP_BUFFER_HEIGHT];

    NSCParameterAssert(texture.pixelFormat == MTLPixelFormatBGRA8Unorm);
    NSCParameterAssert(texture.width == prim->texture_width);
    NSCParameterAssert(texture.height == prim->texture_height);

    static char* texture_format_name[] = {"UNDEFINED", "PAL16", "PALA16", "555", "RGB", "ARGB", "YUV16"};
    texture.label = [NSString stringWithFormat:@"MAME %08lX:%d %dx%d %s", (NSUInteger)prim->texture_base, prim->texture_seqid, prim->texture_width, prim->texture_height, texture_format_name[prim->texformat]];

    switch (prim->texformat) {
        case MYOSD_TEXFORMAT_RGB15:
        {
            // map 0-31 -> 0-255
            static uint32_t pal_ident[32] = {0,8,16,24,32,41,49,57,65,74,82,90,98,106,115,123,131,139,148,156,164,172,180,189,197,205,213,222,230,238,246,255};
            uint16_t* src = prim->texture_base;
            uint32_t* dst = (uint32_t*)temp_buffer;
            const uint32_t* pal = prim->texture_palette ?: pal_ident;
            for (NSUInteger y=0; y<height; y++) {
                for (NSUInteger x=0; x<width; x++) {
                    uint16_t u16 = *src++;
                    *dst++ = (pal[(u16 >>  0) & 0x1F] >>  0) |
                             (pal[(u16 >>  5) & 0x1F] <<  8) |
                             (pal[(u16 >> 10) & 0x1F] << 16) |
                             0xFF000000;
                }
                src += prim->texture_rowpixels - width;
            }
            [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:temp_buffer bytesPerRow:width*4];
            break;
        }
        case MYOSD_TEXFORMAT_RGB32:
        case MYOSD_TEXFORMAT_ARGB32:
        {
            if (prim->texture_palette == NULL) {
                [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:prim->texture_base bytesPerRow:prim->texture_rowpixels*4];
            }
            else {
                uint32_t* src = prim->texture_base;
                uint32_t* dst = (uint32_t*)temp_buffer;
                const uint32_t* pal = prim->texture_palette;
                for (NSUInteger y=0; y<height; y++) {
                    for (NSUInteger x=0; x<width; x++) {
                        uint32_t rgba = *src++;
                        *dst++ = (pal[(rgba >>  0) & 0xFF] <<  0) |
                                 (pal[(rgba >>  8) & 0xFF] <<  8) |
                                 (pal[(rgba >> 16) & 0xFF] << 16) |
                                 (pal[(rgba >> 24) & 0xFF] << 24) ;
                    }
                    src += prim->texture_rowpixels - width;
                }
                [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:temp_buffer bytesPerRow:width*4];
            }
            break;
        }
        case MYOSD_TEXFORMAT_PALETTE16:
        case MYOSD_TEXFORMAT_PALETTEA16:
        {
            uint16_t* src = prim->texture_base;
            uint32_t* dst = (uint32_t*)temp_buffer;
            const uint32_t* pal = prim->texture_palette;
            for (NSUInteger y=0; y<height; y++) {
                NSUInteger dx = width;
                if ((intptr_t)dst % 8 == 0) {
                    while (dx >= 4) {
                        uint64_t u64 = *(uint64_t*)src;
                        ((uint64_t*)dst)[0] = ((uint64_t)pal[(u64 >>  0) & 0xFFFF]) | (((uint64_t)pal[(u64 >> 16) & 0xFFFF]) << 32);
                        ((uint64_t*)dst)[1] = ((uint64_t)pal[(u64 >> 32) & 0xFFFF]) | (((uint64_t)pal[(u64 >> 48) & 0xFFFF]) << 32);
                        dst += 4; src += 4; dx -= 4;
                    }
                    if (dx >= 2) {
                        uint32_t u32 = *(uint32_t*)src;
                        ((uint64_t*)dst)[0] = ((uint64_t)pal[(u32 >>  0) & 0xFFFF]) | (((uint64_t)pal[(u32 >> 16) & 0xFFFF]) << 32);
                        dst += 2; src += 2; dx -= 2;
                    }
                }
                while (dx-- > 0)
                    *dst++ = pal[*src++];
                src += prim->texture_rowpixels - width;
            }
            [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:temp_buffer bytesPerRow:width*4];
            break;
        }
        case MYOSD_TEXFORMAT_YUY16:
        {
            // this texture format is only used for AVI files and LaserDisc player!
            NSCParameterAssert(FALSE);
            break;
        }
        default:
            NSCParameterAssert(FALSE);
            break;
    }
}

#pragma mark - draw MAME primitives

- (void)drawMamePrimitives:(myosd_render_primitive*)prim_list size:(CGSize)size {
    static Shader shader_map[] = {ShaderNone, ShaderAlpha, ShaderMultiply, ShaderAdd};
    static Shader shader_tex_map[]  = {ShaderTexture, ShaderTextureAlpha, ShaderTextureMultiply, ShaderTextureAdd};

    if (![self drawBegin]) {
        NSLog(@"drawBegin *FAIL* dropping frame on the floor.");
        return;
    }
    
    [self setViewRect:CGRectMake(0, 0, size.width, size.height)];
    
    CGFloat scale_x = self.drawableSize.width  / size.width;
    CGFloat scale_y = self.drawableSize.height / size.height;
    CGFloat scale   = MIN(scale_x, scale_y);
    
    // walk the primitive list and render
    for (myosd_render_primitive* prim = prim_list; prim != NULL; prim = prim->next) {
        
        VertexColor color = VertexColor(prim->color_r, prim->color_g, prim->color_b, prim->color_a);
        
        CGRect rect = CGRectMake(floor(prim->bounds_x0 + 0.5),  floor(prim->bounds_y0 + 0.5),
                                 floor(prim->bounds_x1 + 0.5) - floor(prim->bounds_x0 + 0.5),
                                 floor(prim->bounds_y1 + 0.5) - floor(prim->bounds_y0 + 0.5));

        if (prim->type == MYOSD_RENDER_PRIMITIVE_QUAD && prim->texture_base != NULL) {
            
            // set the texture
            [self setTexture:0 texture:prim->texture_base hash:prim->texture_seqid
                       width:prim->texture_width height:prim->texture_height
                      format:MTLPixelFormatBGRA8Unorm
                texture_load:^(id<MTLTexture> texture) {load_texture_prim(texture, prim);} ];

            // set the shader
            if (prim->screentex) {
                [self setTextureFilter:MTLSamplerMinMagFilterLinear];
                [self setShader:ShaderTexture];
            }
            else {
                // render of artwork (or mame text). use normal shader with no filtering
                [self setTextureFilter:MTLSamplerMinMagFilterNearest];
                [self setShader:shader_tex_map[prim->blendmode]];
            }
            
            // set the address mode.
            if (prim->texwrap)
                [self setTextureAddressMode:MTLSamplerAddressModeRepeat];
            else
                [self setTextureAddressMode:MTLSamplerAddressModeClampToZero];

            // draw a textured rect.
            [self drawPrim:MTLPrimitiveTypeTriangleStrip vertices:(Vertex2D[]){
                Vertex2D(rect.origin.x,                  rect.origin.y,                   prim->texcoords[0].u,prim->texcoords[0].v,color),
                Vertex2D(rect.origin.x + rect.size.width,rect.origin.y,                   prim->texcoords[1].u,prim->texcoords[1].v,color),
                Vertex2D(rect.origin.x,                  rect.origin.y + rect.size.height,prim->texcoords[2].u,prim->texcoords[2].v,color),
                Vertex2D(rect.origin.x + rect.size.width,rect.origin.y + rect.size.height,prim->texcoords[3].u,prim->texcoords[3].v,color),
            } count:4];
        }
        else if (prim->type == MYOSD_RENDER_PRIMITIVE_QUAD) {
            // solid color quad. only ALPHA or NONE blend mode.
            
            if (prim->blendmode != MYOSD_BLENDMODE_ALPHA || prim->color_a == 1.0) {
                [self setShader:ShaderNone];
                [self drawRect:rect color:color];
            }
            else if (prim->color_a != 0.0) {
                [self setShader:ShaderAlpha];
                [self drawRect:rect color:color];
            }
        }
        else if (prim->type == MYOSD_RENDER_PRIMITIVE_LINE && (prim->width * scale) <= 1.0) {
            // single pixel line.
            [self setShader:shader_map[prim->blendmode]];
            [self drawLine:CGPointMake(prim->bounds_x0, prim->bounds_y0) to:CGPointMake(prim->bounds_x1, prim->bounds_y1) color:color];
        }
        else if (prim->type == MYOSD_RENDER_PRIMITIVE_LINE) {
            // wide line, if the blendmode is ADD this is a VECTOR line, else a UI line.
            [self setShader:shader_map[prim->blendmode]];
            
            if (prim->blendmode == MYOSD_BLENDMODE_NONE)
                [self drawLine:CGPointMake(prim->bounds_x0, prim->bounds_y0) to:CGPointMake(prim->bounds_x1, prim->bounds_y1) width:prim->width color:color];
            else
                [self drawLine:CGPointMake(prim->bounds_x0, prim->bounds_y0) to:CGPointMake(prim->bounds_x1, prim->bounds_y1) width:prim->width color:color edgeAlpha:0.0];
        }
        else {
            NSLog(@"Unknown RENDER_PRIMITIVE!");
            NSParameterAssert(FALSE);  // bad primitive
        }
    }
    
    [self drawEnd];
}

- (void)dumpMamePrimitives:(myosd_render_primitive*)prim_list size:(CGSize)size {
    
    static char* texture_format_name[] = {"UNDEFINED", "PAL16", "PALA16", "555", "RGB", "ARGB", "YUV16"};
    static char* blend_mode_name[] = {"NONE", "ALPHA", "MUL", "ADD"};
    
    int count = 0;
    for (myosd_render_primitive* prim = prim_list; prim != NULL; prim = prim->next)
        count++;
    
    NSLog(@"Draw Screen: %dx%d (%d prims)",(int)size.width,(int)size.height, count);
    
    for (myosd_render_primitive* prim = prim_list; prim != NULL; prim = prim->next) {
        
        NSParameterAssert(prim->type == MYOSD_RENDER_PRIMITIVE_LINE || prim->type == MYOSD_RENDER_PRIMITIVE_QUAD);
        NSParameterAssert(prim->blendmode <= MYOSD_BLENDMODE_ADD);
        NSParameterAssert(prim->texformat <= MYOSD_TEXFORMAT_YUY16);
        NSParameterAssert(prim->unused == 0);
        
        int blend = prim->blendmode;
        int fmt = prim->texformat;
        int aa = prim->antialias;
        int screen = prim->screentex;
        int orient = prim->texorient;
        int wrap = prim->texwrap;
        
        if (prim->type == MYOSD_RENDER_PRIMITIVE_LINE) {
            NSLog(@"    LINE (%.0f,%.0f) -> (%.0f,%.0f) (%0.2f,%0.2f,%0.2f,%0.2f) %f %s%s%s",
                  prim->bounds_x0, prim->bounds_y0, prim->bounds_x1, prim->bounds_y1,
                  prim->color_r, prim->color_g, prim->color_b, prim->color_a,
                  prim->width, blend_mode_name[blend], aa ? " AA" : "", screen ? " SCREEN" : "");
        }
        else if (prim->type == MYOSD_RENDER_PRIMITIVE_QUAD && prim->texture_base == NULL) {
            NSLog(@"    QUAD [%.0f,%.0f,%.0f,%.0f] (%0.2f,%0.2f,%0.2f,%0.2f) %s%s",
                  prim->bounds_x0, prim->bounds_y0, prim->bounds_x1 - prim->bounds_x0, prim->bounds_y1 - prim->bounds_y0,
                  prim->color_r, prim->color_g, prim->color_b, prim->color_a,
                  blend_mode_name[blend], aa ? " AA" : "");
        }
        else if (prim->type == MYOSD_RENDER_PRIMITIVE_QUAD) {
            NSLog(@"    TEXQ [%.0f,%.0f,%.0f,%.0f] [(%.0f,%.0f),(%.0f,%.0f),(%.0f,%.0f),(%.0f,%.0f)] %s %dx%d (%lX:%d) %s%s%s%s%s%s%s%s",
                  prim->bounds_x0, prim->bounds_y0, prim->bounds_x1 - prim->bounds_x0, prim->bounds_y1 - prim->bounds_y0,
                  prim->texcoords[0].u, prim->texcoords[0].v,
                  prim->texcoords[1].u, prim->texcoords[1].v,
                  prim->texcoords[2].u, prim->texcoords[2].v,
                  prim->texcoords[3].u, prim->texcoords[3].v,
                  blend_mode_name[blend],
                  prim->texture_width, prim->texture_height, (intptr_t)prim->texture_base, prim->texture_seqid,
                  texture_format_name[fmt],
                  prim->texture_palette ? " PALLETE" : "",
                  aa ? " AA" : "",
                  screen ? " SCREEN" : "", wrap ? " WRAP" : "",
                  (orient & MYOSD_ORIENTATION_FLIP_X) ? " FLIPX" : "",
                  (orient & MYOSD_ORIENTATION_FLIP_Y) ? " FLIPY" : "",
                  (orient & MYOSD_ORIENTATION_SWAP_XY) ? " SWAPXY" : ""
                  );
        }
    }
}

@end
