#include "skynet.h"

#include <libgen.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define SIZETIMEFMT 250

struct slogger {
    FILE *handle;
    char *filename;
    uint32_t starttime;
    int close;
    int both; // stdout 和 handle都输出日志（方便开发）
    char timefmt[SIZETIMEFMT];
};

struct slogger *slogger_create(void) {
    struct slogger *inst = skynet_malloc(sizeof(*inst));
    memset(inst, 0, sizeof(*inst));
    return inst;
}

void slogger_release(struct slogger *inst) {
    if (inst->close) {
        fclose(inst->handle);
    }
    skynet_free(inst->filename);
    skynet_free(inst);
}

static int timestring(struct slogger *inst, char tmp[SIZETIMEFMT]) {
    uint64_t now = skynet_now();
    time_t ti = now / 100 + inst->starttime;
    struct tm info;
    (void)localtime_r(&ti, &info);
    strftime(tmp, SIZETIMEFMT, "%d/%m/%y %H:%M:%S", &info);
    return now % 100;
}

static int slogger_cb(struct skynet_context *context, void *ud, int type,
                      int session, uint32_t source, const void *msg,
                      size_t sz) {
    int csec = 0;
    struct slogger *inst = ud;
    switch (type) {
    case PTYPE_SYSTEM:
        if (inst->filename) {
            inst->handle = freopen(inst->filename, "a", inst->handle);
        }
        break;
    case PTYPE_TEXT:
        if (inst->filename) {
            csec = timestring(ud, inst->timefmt);
            fprintf(inst->handle, "%s.%02d ", inst->timefmt, csec);
        }
        fprintf(inst->handle, "[:%08x] ", source);
        fwrite(msg, sz, 1, inst->handle);
        fprintf(inst->handle, "\n");
        fflush(inst->handle);
        if (inst->both) {
            fprintf(stdout, "%s.%02d ", inst->timefmt, csec);
            fprintf(stdout, "[:%08x] ", source);
            fwrite(msg, sz, 1, stdout);
            fprintf(stdout, "\n");
            fflush(stdout);
        }
        break;
    }
    return 0;
}

int slogger_init(struct slogger *inst, struct skynet_context *ctx,
                 const char *parm) {
    const char *r = skynet_command(ctx, "STARTTIME", NULL);
    inst->starttime = strtoul(r, NULL, 10);
    if (parm) {
        const char *filename = parm;
        if (parm[0] == '@') {
            filename = parm + 1;
            inst->both = 1;
        }

        char *filenamec = strdup(filename);
        char *dirpath = dirname(filenamec);
        char cmdstr[128] = {0};
        sprintf(cmdstr, "mkdir -p %s", dirpath);
        free(filenamec);
        int result = system(cmdstr);
        if (result != 0) {
            return 1;
        }

        inst->handle = fopen(filename, "a");
        if (inst->handle == NULL) {
            return 1;
        }
        inst->filename = skynet_malloc(strlen(filename) + 1);
        strcpy(inst->filename, filename);
        inst->close = 1;
    } else {
        inst->handle = stdout;
    }
    if (inst->handle) {
        skynet_callback(ctx, inst, slogger_cb);
        return 0;
    }
    return 1;
}
