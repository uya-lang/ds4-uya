UYA ?= /home/winger/uya/uya/bin/uya
CC ?= cc
SRC := src/main.uya
BIN := build/ds4-uya
RELEASE_CFLAGS ?= -std=c99 -O2 -g -fno-builtin

.PHONY: build build-release test help clean flash-q2-audit flash-q2-smoke flash-q2-perf

build:
	mkdir -p build
	$(UYA) build $(SRC) -o $(BIN)

build-release:
	mkdir -p build
	$(UYA) build $(SRC) -o build/ds4-uya.c --c99
	$(CC) $(RELEASE_CFLAGS) build/ds4-uya.c -o $(BIN) -lm

test:
	$(UYA) test src/binary_test.uya
	$(UYA) test src/gguf_test.uya
	$(UYA) test src/tokenizer_test.uya
	$(UYA) test src/tensor_test.uya
	$(UYA) test src/kernels_test.uya
	$(UYA) test src/model_test.uya
	$(UYA) test src/sampler_test.uya
	$(UYA) test src/optimization_test.uya
	$(UYA) test src/runtime_test.uya

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
	rc=0; $(BIN) generate "$(DS4_FLASH_Q2_GGUF)" "hello" || rc=$$?; test "$$rc" -eq 9
	rc=0; printf '/quit\n' | $(BIN) chat "$(DS4_FLASH_Q2_GGUF)" || rc=$$?; test "$$rc" -eq 9

flash-q2-perf: build
	test -n "$(DS4_FLASH_Q2_GGUF)"
	@echo "flash-q2-perf needs pure Uya Flash layer forward; currently unsupported."
	@exit 1

clean:
	rm -rf build .uyacache
