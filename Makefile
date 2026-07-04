# sml-serve build (MLton-only impure edge + a small pure, dual-compiler suite)
#
#   make            build the demo and the integration-test binaries (MLton)
#   make smoke      build + run the loopback integration test (MLton)
#   make test       alias for smoke
#   make test-poly  build + run the PURE vendored-sml-json suite under Poly/ML
#   make test-pure  build + run that same PURE suite under MLton
#   make all-tests  run smoke + test-pure + test-poly, and confirm the pure
#                   suite's output is byte-identical across both compilers
#   make example    build + run the self-contained loopback demo
#   make serve      build the demo binary (run it as: bin/serve-mlton serve PORT)
#   make clean      remove build artifacts
#
# The socket adapter itself opens sockets and drives a live network via MLton's
# Socket/INetSock structures, so the loopback INTEGRATION suite stays quarantined
# as MLton-only. The vendored sml-json integer path, however, is pure: the
# boundary suite in test/pure/ is a deterministic string->string computation
# with no I/O, so it builds and runs identically under MLton and Poly/ML and its
# output is byte-identical across both -- the same guarantee the rest of the
# sjqtentacles stack provides. (Poly/ML has no native .mlb support; tools/polybuild
# expands the flat .mlb in dependency order, `use`s each source, and exports main.)

MLTON      ?= mlton
BIN        := bin
SERVEDIR   := lib/github.com/sjqtentacles/sml-serve
TEST_MLB   := test/sources.mlb
PURE_MLB   := test/pure/sources.mlb
EX_MLB     := examples/serve.mlb

# Every vendored .sml/.sig under lib, plus this repo's own sources, are inputs.
LIB_SRCS   := $(shell find lib -name '*.sml' -o -name '*.sig' -o -name '*.mlb')
TEST_SRCS  := $(LIB_SRCS) $(wildcard test/*.sml) $(TEST_MLB)
PURE_SRCS  := $(LIB_SRCS) test/harness.sml test/json_boundary.sml \
              $(wildcard test/pure/*.sml) $(PURE_MLB)
EX_SRCS    := $(LIB_SRCS) $(wildcard examples/*.sml) $(EX_MLB)

.PHONY: all smoke test test-pure test-poly all-tests example serve clean

all: $(BIN)/test-mlton $(BIN)/serve-mlton

$(BIN)/test-mlton: $(TEST_SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

$(BIN)/serve-mlton: $(EX_SRCS) | $(BIN)
	$(MLTON) -output $@ $(EX_MLB)

# Pure vendored-sml-json integer-boundary suite, one binary per compiler.
$(BIN)/test-pure-mlton: $(PURE_SRCS) | $(BIN)
	$(MLTON) -output $@ $(PURE_MLB)

$(BIN)/test-poly: $(PURE_SRCS) tools/polybuild | $(BIN)
	sh tools/polybuild -o $@ $(PURE_MLB)

smoke: $(BIN)/test-mlton
	$(BIN)/test-mlton

test: smoke

test-pure: $(BIN)/test-pure-mlton
	$(BIN)/test-pure-mlton

test-poly: $(BIN)/test-poly
	$(BIN)/test-poly

# Run the impure integration suite (MLton) and the pure suite on BOTH compilers,
# then assert the pure suite's output is byte-identical across MLton and Poly/ML.
all-tests: smoke $(BIN)/test-pure-mlton $(BIN)/test-poly
	$(BIN)/test-pure-mlton > $(BIN)/pure-mlton.out
	$(BIN)/test-poly       > $(BIN)/pure-poly.out
	diff $(BIN)/pure-mlton.out $(BIN)/pure-poly.out \
	  && echo "pure suite: byte-identical across MLton and Poly/ML"

example: $(BIN)/serve-mlton
	$(BIN)/serve-mlton

serve: $(BIN)/serve-mlton

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)
