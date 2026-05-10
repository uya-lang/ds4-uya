UYA ?= /home/winger/uya/uya/bin/uya
SRC := src/main.uya
BIN := build/ds4-uya

.PHONY: build test help clean

build:
	mkdir -p build
	$(UYA) build $(SRC) -o $(BIN)

test:
	$(UYA) test src/binary_test.uya
	$(UYA) test src/gguf_test.uya
	$(UYA) test src/tokenizer_test.uya
	$(UYA) test src/tensor_test.uya

help: build
	$(BIN) --help

clean:
	rm -rf build .uyacache
