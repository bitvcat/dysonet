#include "skynet.h"

#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

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

static int timestring(struct slogger *inst, char tmp[SIZETIMEFMT],
                      const char *fmt) {
    uint64_t now = skynet_now();
    time_t ti = now / 100 + inst->starttime;
    struct tm info;
    (void)localtime_r(&ti, &info);
    strftime(tmp, SIZETIMEFMT, fmt, &info);
    return now % 100;
}

static int copy_file(struct slogger *inst, const char *from) {
    FILE *fd_to, *fd_from;
    char buf[4096];
    ssize_t nread;
    int saved_errno;

    // cp log/skynet.log log/skynet2022-10-10-12-12-12.log
    fd_from = fopen(from, "rb");
    if (fd_from == NULL)
        return -1;

    char *filenamec = strdup(from);
    char *dirpath = dirname(filenamec); // libgen.h
    char tmp[128] = {0};
    timestring(inst, tmp, "%Y-%m-%d-%H-%M-%S");
    char toname[256] = {0};
    sprintf(toname, "%s/skynet%s.log", dirpath, tmp);

    fd_to = fopen(toname, "w");
    if (fd_to == NULL)
        goto out_error;

    while (nread = fread(buf, 1, sizeof(buf), fd_from), nread > 0) {
        char *out_ptr = buf;
        ssize_t nwritten;
        do {
            nwritten = fwrite(out_ptr, 1, nread, fd_to);
            if (nwritten >= 0) {
                nread -= nwritten;
                out_ptr += nwritten;
            } else if (errno != EINTR) {
                goto out_error;
            }
        } while (nread > 0);
    }

    if (nread == 0) {
        if (fclose(fd_to) < 0) {
            fd_to = NULL;
            goto out_error;
        }
        fclose(fd_from);
        free(filenamec);

        /* Success! */
        return 0;
    }

out_error:
    saved_errno = errno;

    free(filenamec);
    fclose(fd_from);
    if (fd_to != NULL)
        fclose(fd_to);

    errno = saved_errno;
    return -1;
}

static int slogger_cb(struct skynet_context *context, void *ud, int type,
                      int session, uint32_t source, const void *msg,
                      size_t sz) {
    int csec = 0;
    struct slogger *inst = ud;
    switch (type) {
    case PTYPE_SYSTEM:
        if (inst->filename) {
            inst->handle = freopen(inst->filename, "w", inst->handle);
        }
        break;
    case PTYPE_TEXT:
        if (inst->filename) {
            csec = timestring(ud, inst->timefmt, "%d/%m/%y %H:%M:%S");
            fprintf(inst->handle, "%s.%02d ", inst->timefmt, csec);
        }

        // 截取颜色代码
        int offset = 0;
        const char *_msg = msg;
        if (sz > 3 && _msg[0] == '#') {
            offset = 3 + 1;
        }
        fprintf(inst->handle, "[:%08x] ", source);
        fwrite(msg + offset, sz - offset, 1, inst->handle);
        fprintf(inst->handle, "\n");
        fflush(inst->handle);
        if (inst->both) {
            if (offset) {
                int color = (_msg[1] - '0') * 10 + _msg[2] - '0';
                fprintf(stdout, "\e[%dm", color);
            }
            fprintf(stdout, "%s.%02d ", inst->timefmt, csec);
            fprintf(stdout, "[:%08x] ", source);
            fwrite(msg + offset, sz - offset, 1, stdout);
            fprintf(stdout, "\n");
            if (offset) {
                fprintf(stdout, "\e[0m");
            }
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
        char *dirpath = dirname(filenamec); // libgen.h
        struct stat statbuf = {0};
        if (stat(dirpath, &statbuf) == -1 && mkdir(dirpath, 0777) == -1) {
            free(filenamec);
            fprintf(stderr, "Can't mkdir %s\n", dirpath);
            return 1;
        }
        free(filenamec);

        copy_file(inst, filename);
        inst->handle = fopen(filename, "w");
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
