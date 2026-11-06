/*
 * Vulkan context for an embedded CAMetalLayer.
 * The host creates the layer and passes its pointer through the "wid" option.
 * LGPL-2.1-or-later, same as mpv.
 */

#import <QuartzCore/QuartzCore.h>

#include "video/out/gpu/context.h"
#include "video/out/vo.h"
#include "options/m_config.h"

#include "common.h"
#include "context.h"
#include "utils.h"

struct priv {
    struct mpvk_ctx vk;
    CAMetalLayer *layer;
    int w, h;
};

static void prism_uninit(struct ra_ctx *ctx)
{
    struct priv *p = ctx->priv;
    ra_vk_ctx_uninit(ctx);
    mpvk_uninit(&p->vk);
}

static void prism_swap_buffers(struct ra_ctx *ctx) {}

static int prism_color_depth(struct ra_ctx *ctx)
{
    return 0;
}

static void layer_size(struct priv *p, int *w, int *h)
{
    CGSize s = p->layer.drawableSize;
    *w = (int)s.width;
    *h = (int)s.height;
}

static bool prism_resize(struct ra_ctx *ctx)
{
    struct priv *p = ctx->priv;
    layer_size(p, &p->w, &p->h);
    if (p->w <= 0 || p->h <= 0)
        return true;
    return ra_vk_ctx_resize(ctx, p->w, p->h);
}

static bool prism_init(struct ra_ctx *ctx)
{
    struct priv *p = ctx->priv = talloc_zero(ctx, struct priv);
    struct mpvk_ctx *vk = &p->vk;

    int64_t wid = ctx->vo->opts->WinID;
    if (wid == 0 || wid == -1) {
        MP_ERR(ctx, "prismvk: 'wid' must hold a CAMetalLayer pointer\n");
        return false;
    }
    p->layer = (__bridge CAMetalLayer *)(void *)(intptr_t)wid;

    if (!mpvk_init(vk, ctx, VK_EXT_METAL_SURFACE_EXTENSION_NAME)) {
        MP_ERR(ctx, "prismvk: Vulkan instance creation failed (MoltenVK missing?)\n");
        goto error;
    }

    VkMetalSurfaceCreateInfoEXT info = {
        .sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT,
        .pLayer = (__bridge const CAMetalLayer *)p->layer,
    };
    VkResult res = vkCreateMetalSurfaceEXT(vk->vkinst->instance, &info, NULL,
                                           &vk->surface);
    if (res != VK_SUCCESS) {
        MP_ERR(ctx, "prismvk: failed creating Metal surface (%d)\n", (int)res);
        goto error;
    }

    struct ra_ctx_params params = {
        .swap_buffers = prism_swap_buffers,
        .color_depth = prism_color_depth,
    };
    if (!ra_vk_ctx_init(ctx, vk, params, VK_PRESENT_MODE_FIFO_KHR)) {
        MP_ERR(ctx, "prismvk: ra_vk_ctx_init failed\n");
        goto error;
    }
    return true;
error:
    prism_uninit(ctx);
    return false;
}

static bool prism_reconfig(struct ra_ctx *ctx)
{
    return prism_resize(ctx);
}

static int prism_control(struct ra_ctx *ctx, int *events, int request, void *arg)
{
    struct priv *p = ctx->priv;
    int w, h;
    layer_size(p, &w, &h);
    if (w != p->w || h != p->h) {
        *events |= VO_EVENT_RESIZE;
        if (!prism_resize(ctx))
            return VO_ERROR;
    }
    return VO_NOTIMPL;
}

const struct ra_ctx_fns ra_ctx_vulkan_prism = {
    .type           = "vulkan",
    .name           = "prismvk",
    .description    = "Vulkan on embedded CAMetalLayer",
    .reconfig       = prism_reconfig,
    .control        = prism_control,
    .init           = prism_init,
    .uninit         = prism_uninit,
};
