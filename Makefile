AS      ?= as
LD      ?= ld
ASFLAGS := --64 -I src
OBJDIR  := build
SRCS    := $(wildcard src/*.s)
OBJS    := $(patsubst src/%.s,$(OBJDIR)/%.o,$(SRCS))

.PHONY: all clean test bench

all: tsc-asm

$(OBJDIR)/%.o: src/%.s src/defs.inc | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

tsc-asm: $(OBJS)
	$(LD) -o $@ $(OBJS)

$(OBJDIR):
	mkdir -p $@

test: tsc-asm
	./tests/run.sh

bench: tsc-asm
	./tests/bench.sh

clean:
	rm -rf $(OBJDIR) tsc-asm tests/cases/*.js tests/.bench.js tests/.bench.ts
