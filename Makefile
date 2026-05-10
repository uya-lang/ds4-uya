UYA ?= /home/winger/uya/uya/bin/uya
SRC := src/main.uya
BIN := build/ds4-uya

.PHONY: build test help clean flash-q2-audit flash-q2-smoke

build:
	mkdir -p build
	$(UYA) build $(SRC) -o $(BIN)

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
	$(BIN) generate "$(DS4_FLASH_Q2_GGUF)" "hello"

clean:
	rm -rf build .uyacache
