#include "../../vendor/ds4-ref/ds4.h"

#include <ctype.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    ds4_engine *engine;
    char *out;
    size_t len;
    size_t cap;
    int overflow;
    ds4_tokens *transcript;
    FILE *fp;
} uya_flash_emit;

void ds4_uya_ref_threads_shutdown(void);

static int bridge_append(uya_flash_emit *ctx, const char *text, size_t len) {
    if (!ctx || !text || len == 0) return 0;
    if (ctx->fp) {
        fwrite(text, 1, len, ctx->fp);
        fflush(ctx->fp);
    }
    if (ctx->out) {
        if (ctx->len + len + 1 > ctx->cap) {
            ctx->overflow = 1;
            return 11;
        }
        memcpy(ctx->out + ctx->len, text, len);
        ctx->len += len;
        ctx->out[ctx->len] = '\0';
    }
    return 0;
}

static void bridge_emit_token(void *ud, int token) {
    uya_flash_emit *ctx = (uya_flash_emit *)ud;
    if (!ctx || ctx->overflow) return;
    if (ctx->transcript) ds4_tokens_push(ctx->transcript, token);
    size_t len = 0;
    char *text = ds4_token_text(ctx->engine, token, &len);
    if (!text) return;
    (void)bridge_append(ctx, text, len);
    free(text);
}

static void bridge_done(void *ud) {
    uya_flash_emit *ctx = (uya_flash_emit *)ud;
    if (ctx && ctx->fp) {
        fputc('\n', ctx->fp);
        fflush(ctx->fp);
    }
}

static bool bridge_is_rendered_chat(const char *prompt) {
    if (!prompt) return false;
    return strstr(prompt, "<\xef\xbd\x9c" "User" "\xef\xbd\x9c>") != NULL ||
           strstr(prompt, "<|User|>") != NULL ||
           strstr(prompt, "<\xef\xbd\x9c" "Assistant" "\xef\xbd\x9c>") != NULL ||
           strstr(prompt, "<|Assistant|>") != NULL;
}

static int bridge_open_engine(ds4_engine **out, const char *model_path) {
    ds4_engine_options opt;
    memset(&opt, 0, sizeof(opt));
    opt.model_path = model_path;
    opt.backend = DS4_BACKEND_CPU;
    opt.n_threads = 0;
    opt.mtp_draft_tokens = 1;
    opt.mtp_margin = 3.0f;
    opt.warm_weights = false;
    opt.quality = true;
    return ds4_engine_open(out, &opt);
}

int ds4_uya_flash_generate(
        const char *model_path,
        const char *prompt,
        int max_new_tokens,
        int ctx_size,
        char *out,
        size_t out_cap) {
    if (!model_path || !prompt || !out || out_cap == 0 || max_new_tokens <= 0) {
        return 10;
    }
    out[0] = '\0';
    if (ctx_size <= 0) ctx_size = 4096;

    ds4_engine *engine = NULL;
    if (bridge_open_engine(&engine, model_path) != 0 || !engine) {
        ds4_uya_ref_threads_shutdown();
        return 12;
    }

    ds4_tokens tokens = {0};
    if (bridge_is_rendered_chat(prompt)) {
        ds4_tokenize_rendered_chat(engine, prompt, &tokens);
    } else {
        ds4_encode_chat_prompt(engine, NULL, prompt, DS4_THINK_NONE, &tokens);
    }

    uya_flash_emit emit;
    memset(&emit, 0, sizeof(emit));
    emit.engine = engine;
    emit.out = out;
    emit.cap = out_cap;

    int rc = ds4_engine_generate_argmax(engine, &tokens, max_new_tokens, ctx_size,
                                        bridge_emit_token, NULL, &emit, NULL, NULL);
    if (emit.overflow) rc = 11;
    ds4_tokens_free(&tokens);
    ds4_engine_close(engine);
    ds4_uya_ref_threads_shutdown();
    return rc == 0 ? 0 : rc;
}

static char *bridge_trim(char *s) {
    while (*s && isspace((unsigned char)*s)) s++;
    char *end = s + strlen(s);
    while (end > s && isspace((unsigned char)end[-1])) end--;
    *end = '\0';
    return s;
}

int ds4_uya_flash_chat(const char *model_path, int max_new_tokens, int ctx_size) {
    if (!model_path || max_new_tokens <= 0) return 10;
    if (ctx_size <= 0) ctx_size = 4096;

    ds4_engine *engine = NULL;
    if (bridge_open_engine(&engine, model_path) != 0 || !engine) {
        ds4_uya_ref_threads_shutdown();
        return 12;
    }

    ds4_tokens transcript = {0};
    ds4_chat_begin(engine, &transcript);

    fprintf(stdout, "ds4-uya flash chat ready. Type /quit to exit.\n");
    char line[4096];
    while (true) {
        fprintf(stdout, "> ");
        fflush(stdout);
        if (!fgets(line, sizeof(line), stdin)) break;
        char *text = bridge_trim(line);
        if (text[0] == '\0') continue;
        if (!strcmp(text, "/quit") || !strcmp(text, "/exit")) break;

        ds4_chat_append_message(engine, &transcript, "user", text);
        ds4_chat_append_assistant_prefix(engine, &transcript, DS4_THINK_NONE);

        uya_flash_emit emit;
        memset(&emit, 0, sizeof(emit));
        emit.engine = engine;
        emit.transcript = &transcript;
        emit.fp = stdout;

        int rc = ds4_engine_generate_argmax(engine, &transcript, max_new_tokens, ctx_size,
                                            bridge_emit_token, bridge_done, &emit, NULL, NULL);
        if (rc != 0) {
            ds4_tokens_free(&transcript);
            ds4_engine_close(engine);
            ds4_uya_ref_threads_shutdown();
            return rc;
        }
    }

    ds4_tokens_free(&transcript);
    ds4_engine_close(engine);
    ds4_uya_ref_threads_shutdown();
    return 0;
}
