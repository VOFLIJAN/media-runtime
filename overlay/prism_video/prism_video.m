// libprism_video: CAMetalLayer host for mpv's prismvk context. Main thread only.
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#define EXPORT __attribute__((visibility("default")))

// Creates a CAMetalLayer under `nsview` (NSView*). Returns the layer pointer
// to pass to mpv as `wid`, or NULL.
EXPORT void *prism_layer_create(void *nsview)
{
    NSView *view = (__bridge NSView *)nsview;
    if (!view)
        return NULL;
    [view setWantsLayer:YES];
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.opaque = YES;
    layer.presentsWithTransaction = NO;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.contentsScale = view.window.backingScaleFactor ?: 1.0;
    layer.frame = view.bounds;
    layer.drawableSize = CGSizeMake(view.bounds.size.width * layer.contentsScale,
                                    view.bounds.size.height * layer.contentsScale);
    [view.layer insertSublayer:layer atIndex:0];
    return (void *)CFBridgingRetain(layer);
}

EXPORT void prism_layer_sync(void *layerp, void *nsview)
{
    CAMetalLayer *layer = (__bridge CAMetalLayer *)layerp;
    NSView *view = (__bridge NSView *)nsview;
    if (!layer || !view)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGFloat scale = view.window.backingScaleFactor ?: 1.0;
    layer.contentsScale = scale;
    layer.frame = view.bounds;
    layer.drawableSize = CGSizeMake(view.bounds.size.width * scale,
                                    view.bounds.size.height * scale);
    [CATransaction commit];
}

EXPORT void prism_layer_set_hdr(void *layerp, bool on)
{
    CAMetalLayer *layer = (__bridge CAMetalLayer *)layerp;
    if (!layer)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (on) {
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3_PQ);
        layer.colorspace = cs;
        if (cs)
            CGColorSpaceRelease(cs);
        layer.wantsExtendedDynamicRangeContent = YES;
    } else {
        layer.colorspace = nil;
        layer.wantsExtendedDynamicRangeContent = NO;
    }
    [CATransaction commit];
}

EXPORT void prism_layer_set_visible(void *layerp, bool visible)
{
    CAMetalLayer *layer = (__bridge CAMetalLayer *)layerp;
    if (!layer)
        return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.hidden = !visible;
    [CATransaction commit];
}

EXPORT void prism_layer_destroy(void *layerp)
{
    if (!layerp)
        return;
    CAMetalLayer *layer = (CAMetalLayer *)CFBridgingRelease(layerp);
    [layer removeFromSuperlayer];
}
