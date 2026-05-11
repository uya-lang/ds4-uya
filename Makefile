UYA ?= /home/winger/uya/uya/bin/uya
CC ?= cc
SRC := src/main.uya
BIN := build/ds4-uya
FLASH_REF_DIR := vendor/ds4-ref
FLASH_BRIDGE_OBJS := $(CURDIR)/build/ds4_ref.o $(CURDIR)/build/ds4_flash_bridge.o
FLASH_BRIDGE_CFLAGS ?= -O2 -std=c99 -D_POSIX_C_SOURCE=200809L -DDS4_NO_METAL -I$(FLASH_REF_DIR)
FLASH_BRIDGE_LDFLAGS := $(FLASH_BRIDGE_OBJS) -pthread -lm

.PHONY: build test help clean flash-q2-audit flash-q2-smoke flash-q2-perf

$(CURDIR)/build/ds4_ref.o: $(FLASH_REF_DIR)/ds4.c $(FLASH_REF_DIR)/ds4.h $(FLASH_REF_DIR)/ds4_metal.h
	mkdir -p build
	$(CC) $(FLASH_BRIDGE_CFLAGS) -c $(FLASH_REF_DIR)/ds4.c -o $@

$(CURDIR)/build/ds4_flash_bridge.o: src/ds4/flash_bridge.c $(FLASH_REF_DIR)/ds4.h
	mkdir -p build
	$(CC) $(FLASH_BRIDGE_CFLAGS) -c src/ds4/flash_bridge.c -o $@

build: $(FLASH_BRIDGE_OBJS)
	mkdir -p build
	LDFLAGS="$(FLASH_BRIDGE_LDFLAGS)" $(UYA) build $(SRC) -o $(BIN)

test: $(FLASH_BRIDGE_OBJS)
	$(UYA) test src/binary_test.uya
	$(UYA) test src/gguf_test.uya
	$(UYA) test src/tokenizer_test.uya
	$(UYA) test src/tensor_test.uya
	$(UYA) test src/kernels_test.uya
	$(UYA) test src/model_test.uya
	$(UYA) test src/sampler_test.uya
	$(UYA) test src/optimization_test.uya
	LDFLAGS="$(FLASH_BRIDGE_LDFLAGS)" $(UYA) test src/runtime_test.uya

help: build
	$(BIN) --help

flash-q2-audit: build
	test -n "$(DS4_FLASH_Q2_GGUF)"
	$(BIN) audit "$(DS4_FLASH_Q2_GGUF)"

flash-q2-smoke: build
	test -n "$(DS4_FLASH_Q2_GGUF)"
	$(BIN) audit "$(DS4_FLASH_Q2_GGUF)"
	$(BIN) inspect "$(DS4_FLASH_Q2_GGUF)"
	$(BIN) encode "$(DS4_FLASH_Q2_GGUF)" "hello"
	$(BIN) format-chat "$(DS4_FLASH_Q2_GGUF)" "hello"
	DS4_UYA_MAX_NEW=1 DS4_UYA_CTX=512 $(BIN) generate "$(DS4_FLASH_Q2_GGUF)" "hello"
	printf 'hello\n/quit\n' | DS4_UYA_MAX_NEW=1 DS4_UYA_CTX=512 $(BIN) chat "$(DS4_FLASH_Q2_GGUF)"

flash-q2-perf: build
	test -n "$(DS4_FLASH_Q2_GGUF)"
	DS4_UYA_MAX_NEW=4 DS4_UYA_CTX=512 $(BIN) generate "$(DS4_FLASH_Q2_GGUF)" "hello"

clean:
	rm -rf build .uyacache
