NAME = GBCREMOTE
BUILD_DIR = build
RGBDS_DIR ?=
PYTHON ?= .venv/bin/python

RGBASM = $(RGBDS_DIR)rgbasm
RGBLINK = $(RGBDS_DIR)rgblink
RGBFIX = $(RGBDS_DIR)rgbfix

CARTRIDGE_TYPE_MBC5_RAM_BATTERY = 0x1b
SRAM_SIZE_CODE ?= 0x04

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
ifdef CPU_SPEED
ASFLAGS += -D SELECTED_CPU_SPEED=$(CPU_SPEED)
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
test: $(TEST_ROM) $(ROM)
	$(PYTHON) tests/run_tests.py $(TEST_ROM) $(TEST_SYMBOLS)
	$(PYTHON) tests/run_flow_tests.py $(ROM) $(ROM_SYMBOLS)

.PHONY: coverage
coverage: $(TEST_ROM) $(ROM)
	mkdir -p $(COVERAGE_DIR)
	$(PYTHON) tests/run_tests.py $(TEST_ROM) $(TEST_SYMBOLS) --map $(TEST_MAP) --coverage-output $(COVERAGE_DIR)/unit.json
	$(PYTHON) tests/run_flow_tests.py $(ROM) $(ROM_SYMBOLS) --map $(ROM_MAP) --coverage-output $(COVERAGE_DIR)/flow.json
	$(PYTHON) tests/coverage_report.py $(ROM_MAP) $(COVERAGE_DIR)/unit.json $(COVERAGE_DIR)/flow.json docs

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
