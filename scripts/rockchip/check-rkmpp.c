#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>

#if LIBAVCODEC_VERSION_INT != AV_VERSION_INT(61, 19, 101)
#error "check-rkmpp must be built against libavcodec 61.19.101"
#endif

int main(void)
{
    const char *names[] = {"h264_rkmpp", "hevc_rkmpp"};
    Dl_info info;
    int missing = 0;
    unsigned int version = avcodec_version();

    if (dladdr((void *)avcodec_version, &info)) {
        printf("libavcodec: %s\n", info.dli_fname);
    }
    if (dladdr((void *)avutil_version, &info)) {
        printf("libavutil: %s\n", info.dli_fname);
    }
    printf("FFmpeg configuration: %s\n", avcodec_configuration());
    printf("libavcodec version: %u.%u.%u (required: 61.19.101)\n",
           version >> 16, (version >> 8) & 0xff, version & 0xff);
    if (version != AV_VERSION_INT(61, 19, 101)) {
        fputs("Unexpected runtime libavcodec version\n", stderr);
        missing = 1;
    }
    for (unsigned int i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        const AVCodec *codec = avcodec_find_decoder_by_name(names[i]);
        printf("%s: %s\n", names[i], codec ? "present" : "MISSING");
        missing |= codec == NULL;
    }
    puts("This check enumerates decoders; it does not test hardware decoding.");
    return missing;
}
