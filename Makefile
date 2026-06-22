# sml-serve build (MLton-only, impure edge)
#
#   make            build the demo and the integration-test binaries (MLton)
#   make smoke      build + run the loopback integration test
#   make test       alias for smoke
#   make example    build + run the self-contained loopback demo
#   make serve      build the demo binary (run it as: bin/serve-mlton serve PORT)
#   make clean      remove build artifacts
#
# There are deliberately NO poly / test-poly targets: this adapter opens
# sockets and drives a live network via MLton's Socket/INetSock structures, so
# it is quarantined from the dual-compiler, byte-identical purity guarantee
# that the rest of the sjqtentacles stack provides.

MLTON      ?= mlton
BIN        := bin
SERVEDIR   := lib/github.com/sjqtentacles/sml-serve
TEST_MLB   := test/sources.mlb
EX_MLB     := examples/serve.mlb

# Every vendored .sml/.sig under lib, plus this repo's own sources, are inputs.
LIB_SRCS   := $(shell find lib -name '*.sml' -o -name '*.sig' -o -name '*.mlb')
TEST_SRCS  := $(LIB_SRCS) $(wildcard test/*.sml) $(TEST_MLB)
EX_SRCS    := $(LIB_SRCS) $(wildcard examples/*.sml) $(EX_MLB)

.PHONY: all smoke test example serve clean

all: $(BIN)/test-mlton $(BIN)/serve-mlton

$(BIN)/test-mlton: $(TEST_SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

$(BIN)/serve-mlton: $(EX_SRCS) | $(BIN)
	$(MLTON) -output $@ $(EX_MLB)

smoke: $(BIN)/test-mlton
	$(BIN)/test-mlton

test: smoke

example: $(BIN)/serve-mlton
	$(BIN)/serve-mlton

serve: $(BIN)/serve-mlton

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)
