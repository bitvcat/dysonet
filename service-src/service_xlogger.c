#include "skynet.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct loghandle {
    FILE *handle;
    uint32_t date;
    int32_t shard;
    uint32_t line_nums;
    char name[64];
    char filename[128];
};

struct xlogger {
    struct loghandle *handles;
    int32_t handle_cap;
    int32_t handle_count;
    uint32_t starttime;
    int close;
    char logpath[64];
};

struct xlogger *xlogger_create(void) {
    struct xlogger *inst = skynet_malloc(sizeof(*inst));
    inst->handle_cap = 4;
    inst->handle_count = 0;

    // handles
    size_t handles_size = sizeof(struct loghandle) * inst->handle_cap;
    inst->handles = skynet_malloc(handles_size);
    memset(inst->handles, 0, handles_size);
    memset(inst->logpath, 0, sizeof(inst->logpath));
    return inst;
}

void xlogger_release(struct xlogger *inst) {
    if (inst->close) {
        for (int i = 0; i < inst->handle_cap; i++) {
            FILE *file = inst->handles[i].handle;
            if (file) {
                fclose(file);
            }
        }
    }
    skynet_free(inst->handles);
    skynet_free(inst);
}

static int create_folder(const char *path) {
    char cmdstr[128] = {0};
    sprintf(cmdstr, "mkdir -p %s", path);
    int result = system(cmdstr);
    if (result == 0) {
        return 0;
    }
    return -1;
}

#define SIZETIMEFMT 250
static int timestring(struct xlogger *inst, const char *fmt,
                      char tmp[SIZETIMEFMT]) {
    uint64_t now = skynet_now();
    time_t ti = now / 100 + inst->starttime;
    struct tm info;
    (void)localtime_r(&ti, &info);
    strftime(tmp, SIZETIMEFMT, fmt, &info);
    return now % 100;
}

struct loghandle *grab_handle(struct xlogger *inst, const char *name) {
    struct loghandle *h = NULL;

    int begin = 0;
    int end = inst->handle_count - 1;
    while (begin <= end) {
        int mid = (begin + end) / 2;
        h = &inst->handles[mid];
        int c = strcmp(h->name, name);
        if (c == 0) {
            return h;
        }
        if (c < 0) {
            begin = mid + 1;
        } else {
            end = mid - 1;
        }
    }

    if (inst->handle_count >= inst->handle_cap) {
        inst->handle_cap *= 2;
        assert(inst->handle_cap <= 128);
        struct loghandle *handles =
            skynet_malloc(sizeof(struct loghandle) * inst->handle_cap);

        int i;
        for (i = 0; i < begin; i++) {
            handles[i] = inst->handles[i];
        }
        for (i = begin; i < inst->handle_count; i++) {
            handles[i + 1] = inst->handles[i];
        }
        skynet_free(inst->handles);
        inst->handles = handles;
    } else {
        int i;
        for (i = inst->handle_count; i > begin; i--) {
            inst->handles[i] = inst->handles[i - 1];
        }
    }
    h = &inst->handles[begin];
    memset(h, 0, sizeof(struct loghandle));
    memcpy(h->name, name, strlen(name) + 1);
    inst->handle_count++;
    return h;
}

static FILE *judg_handle(struct xlogger *inst, struct loghandle *h) {
    if (h == NULL)
        return NULL;

    char timefmt[SIZETIMEFMT] = {0};
    timestring(inst, "%Y%m%d", timefmt);
    uint32_t today = strtoul(timefmt, NULL, 10);
    if (h->date != today) {
        // 创建新的文件， eg. ./log/debug/debug2022-07-04.log
        h->date = today;

        char path[128] = {0};
        sprintf(path, "%s/%s", inst->logpath, h->name);
        if (create_folder(path) != 0) {
            return NULL;
        }
        timestring(inst, "%Y-%m-%d", timefmt);
        sprintf(h->filename, "%s/%s%s.log", path, h->name, timefmt);
        printf("filename = %s\n", h->filename);
        if (h->handle) {
            fclose(h->handle);
        }
        h->handle = fopen(h->filename, "a");
    }
    return h->handle;
}

// callback
static int xlogger_cb(struct skynet_context *context, void *ud, int type,
                      int session, uint32_t source, const void *msg,
                      size_t sz) {
    struct xlogger *inst = ud;
    char *real_msg = NULL;

    switch (type) {
    case PTYPE_TEXT:
        real_msg = strchr(msg, ' ');
        if (real_msg && real_msg != msg) {
            char name[64] = {0};
            size_t name_len = real_msg - (const char *)msg;
            memcpy(name, msg, name_len);
            struct loghandle *h = grab_handle(inst, name);
            FILE *handle = judg_handle(inst, h);
            if (handle) {
                char tmp[SIZETIMEFMT];
                int csec = timestring(ud, "%y-%m-%d %H:%M:%S", tmp);
                fprintf(handle, "[%s.%02d] [:%08x]", tmp, csec, source);
                fwrite(real_msg, sz - name_len, 1, handle);
                fprintf(handle, "\n");
                fflush(handle);
            }
        }
        break;
    default:
        printf("invalid ptype = %d\n", type);
        break;
    }
    return 0;
}

// init
int xlogger_init(struct xlogger *inst, struct skynet_context *ctx,
                 const char *parm) {
    const char *r = skynet_command(ctx, "STARTTIME", NULL);
    inst->starttime = strtoul(r, NULL, 10);
    if (parm) {
        inst->close = 1;
        memcpy(inst->logpath, parm, strlen(parm) + 1);
        if (create_folder(parm) == 0) {
            skynet_callback(ctx, inst, xlogger_cb);
            return 0;
        }
    }
    return 1;
}
