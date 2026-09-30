#pragma once

extern "C" {
#include <libavutil/hwcontext_drm.h>
}

#include <libdrm/drm_fourcc.h>
#include <cstdint>
#include <limits>

// KMS framebuffer imports require one composed layer, at most four planes,
// and one consistent modifier across the referenced objects. Keep this check
// independent of a DRM device so malformed/unsupported layouts can be tested.
inline bool isDrmPrimeFrameSupported(const AVDRMFrameDescriptor& frame, bool supportsModifiers)
{
    if (frame.nb_objects < 1 || frame.nb_objects > AV_DRM_MAX_PLANES || frame.nb_layers != 1) {
        return false;
    }

    const auto& layer = frame.layers[0];
    if (layer.nb_planes < 1 || layer.nb_planes > 4 || layer.nb_planes > AV_DRM_MAX_PLANES) {
        return false;
    }

    uint64_t modifier = DRM_FORMAT_MOD_INVALID;
    for (int i = 0; i < layer.nb_planes; i++) {
        const auto& plane = layer.planes[i];
        if (plane.object_index < 0 || plane.object_index >= frame.nb_objects ||
                plane.pitch <= 0 || uint64_t(plane.pitch) > std::numeric_limits<uint32_t>::max() ||
                plane.offset < 0 || uint64_t(plane.offset) > std::numeric_limits<uint32_t>::max()) {
            return false;
        }

        const auto& object = frame.objects[plane.object_index];
        if (object.fd < 0 || uint64_t(plane.offset) >= object.size) {
            return false;
        }

        if (i == 0) {
            modifier = object.format_modifier;
        }
        else if (object.format_modifier != modifier) {
            return false;
        }

        // Never silently treat a tiled/compressed buffer as linear when the
        // kernel does not support framebuffer modifiers. Implicit layouts and
        // explicit linear buffers can still use the legacy AddFB2 path.
        if (!supportsModifiers && modifier != DRM_FORMAT_MOD_INVALID && modifier != DRM_FORMAT_MOD_LINEAR) {
            return false;
        }
    }

    return true;
}
