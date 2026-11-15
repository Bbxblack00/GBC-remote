NAME = GBCREMOTE
SRAM_KB ?= 128
DEBUG ?= 0
SRAM_VARIANTS = 8 32 64 128
BUILD_SUFFIX = $(if $(filter 1,$(DEBUG)),/debug)$(if $(filter-out 128,$(SRAM_KB)),/sram-$(SRAM_KB)kb)
BUILD_DIR ?= build$(BUILD_SUFFIX)
RGBDS_DIR ?=
PYTHON ?= .venv/bin/python

RGBASM = $(RGBDS_DIR)rgbasm
RGBLINK = $(RGBDS_DIR)rgblink
RGBFIX = $(RGBDS_DIR)rgbfix

CARTRIDGE_TYPE_MBC5_RAM_BATTERY = 0x1b
SRAM_SIZE_CODE = $(if $(filter 8,$(SRAM_KB)),0x02,$(if $(filter 32,$(SRAM_KB)),0x03,$(if $(filter 64,$(SRAM_KB)),0x05,$(if $(filter 128,$(SRAM_KB)),0x04,$(error SRAM_KB must be 8, 32, 64 or 128)))))
SRAM_BANK_LIMIT = $(shell expr $(SRAM_KB) / 8)

APPLICATION_SOURCES = $(shell find src -name '*.asm')
LIBRARY_SOURCES = $(filter-out src/boot/%,$(APPLICATION_SOURCES))
TEST_SOURCES = $(shell find tests -name '*.asm')
INCLUDES = $(wildcard inc/*.inc tests/inc/*.inc)

APPLICATION_OBJECTS = $(addprefix $(BUILD_DIR)/,$(APPLICATION_SOURCES:.asm=.o))
TEST_OBJECTS = $(addprefix $(BUILD_DIR)/,$(LIBRARY_SOURCES:.asm=.o) $(TEST_SOURCES:.asm=.o))

ROM = $(BUILD_DIR)/gbc-remote.gbc
ROM_SYMBOLS = $(BUILD_DIR)/gbc-remote.sym
ROM_MAP = $(BUILD_DIR)/gbc-remote.map
TEST_ROM = $(BUILD_DIR)/gbc-remote-tests.gbc
TEST_SYMBOLS = $(BUILD_DIR)/gbc-remote-tests.sym
TEST_MAP = $(BUILD_DIR)/gbc-remote-tests.map
COVERAGE_DIR = $(BUILD_DIR)/coverage

ASFLAGS = -I inc/ -I tests/inc/ -Weverything
ASFLAGS += -D SRAM_BANK_LIMIT=$(SRAM_BANK_LIMIT)
ifdef CPU_SPEED
ASFLAGS += -D SELECTED_CPU_SPEED=$(CPU_SPEED)
endif
ifeq ($(DEBUG),1)
ASFLAGS += -D DEBUG_BUILD=1
endif
FIXFLAGS = -v -p 0 -C -m $(CARTRIDGE_TYPE_MBC5_RAM_BATTERY) -r $(SRAM_SIZE_CODE) -t $(NAME)

$(ROM): $(APPLICATION_OBJECTS)
	$(RGBLINK) -n $(ROM_SYMBOLS) -m $(ROM_MAP) -o $@ $^
	$(RGBFIX) $(FIXFLAGS) $@

$(TEST_ROM): $(TEST_OBJECTS)
	$(RGBLINK) -n $(TEST_SYMBOLS) -m $(TEST_MAP) -o $@ $^
	$(RGBFIX) $(FIXFLAGS) $@

$(BUILD_DIR)/%.o: %.asm $(INCLUDES)
	mkdir -p $(dir $@)
	$(RGBASM) $(ASFLAGS) -o $@ $<

.PHONY: test
test: $(TEST_ROM) $(ROM) test-sizes test-debug
	$(PYTHON) tests/run_tests.py $(TEST_ROM) $(TEST_SYMBOLS)
	$(PYTHON) tests/run_flow_tests.py $(ROM) $(ROM_SYMBOLS)
	$(PYTHON) tests/run_tool_tests.py

.PHONY: test-debug
test-debug:
	$(MAKE) --no-print-directory DEBUG=1 SRAM_KB=128 BUILD_DIR=build/debug RGBDS_DIR=$(RGBDS_DIR) build-variant
	$(PYTHON) tests/run_flow_tests.py build/debug/gbc-remote.gbc build/debug/gbc-remote.sym --debug

.PHONY: test-sizes
test-sizes:
	for kb in $(SRAM_VARIANTS); do \
		directory=build; \
		if [ $$kb -ne 128 ]; then directory=build/sram-$${kb}kb; fi; \
		$(MAKE) --no-print-directory SRAM_KB=$$kb BUILD_DIR=$$directory RGBDS_DIR=$(RGBDS_DIR) build-variant || exit 1; \
	done
	$(PYTHON) tests/run_size_tests.py build $(SRAM_VARIANTS)

.PHONY: build-variant
build-variant: $(ROM)

.PHONY: coverage
coverage: $(TEST_ROM) $(ROM)
	$(MAKE) --no-print-directory DEBUG=1 SRAM_KB=128 BUILD_DIR=build/debug RGBDS_DIR=$(RGBDS_DIR) build-variant
	mkdir -p $(COVERAGE_DIR)
	$(PYTHON) tests/run_tests.py $(TEST_ROM) $(TEST_SYMBOLS) --map $(TEST_MAP) --coverage-output $(COVERAGE_DIR)/unit.json
	$(PYTHON) tests/run_flow_tests.py $(ROM) $(ROM_SYMBOLS) --map $(ROM_MAP) --coverage-output $(COVERAGE_DIR)/flow.json
	$(PYTHON) tests/run_flow_tests.py build/debug/gbc-remote.gbc build/debug/gbc-remote.sym --map build/debug/gbc-remote.map --debug --coverage-output $(COVERAGE_DIR)/debug.json
	$(PYTHON) tests/coverage_report.py build/debug/gbc-remote.map $(COVERAGE_DIR)/unit.json $(COVERAGE_DIR)/flow.json $(COVERAGE_DIR)/debug.json docs $(COVERAGE_DIR)/summary.json

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
