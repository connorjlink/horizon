GHDL	  ?= ghdl
STD	   ?= 08
WORK	  ?= work

ANALYZE   := $(GHDL) -a --work=$(WORK) --std=$(STD)
RUN	   := $(GHDL) --elab-run --std=$(STD)

# GHDL's library index file for VHDL-2008
WORK_CF   := work-obj08.cf

SOURCE := \
	./source/types.vhd \
	./source/not_1.vhd ./source/not_N.vhd ./source/and_2.vhd ./source/or_2.vhd ./source/xor_2.vhd \
	./source/multiplexer_2to1.vhd ./source/multiplexer_2to1_N.vhd ./source/multiplexer_32to1.vhd \
	./source/register_1.vhd ./source/register_N.vhd \
	./source/decoder_5to32.vhd \
	./source/adder_1.vhd \
	./source/adder_N.vhd \
	./source/addersubtractor_N.vhd \
	./source/barrel_shifter.vhd \
	./source/instruction_decoder.vhd \
	./source/instruction_pointer.vhd \
	./source/register_file.vhd \
	./source/memory.vhd \
	./source/extender_NtoM.vhd \
	./source/arithmetic_logic_unit.vhd \
	./source/control_unit.vhd \
	./source/branch_unit.vhd

.PHONY: setup verify tests \
	test_barrel_shifter test_adder_1 test_adder_N test_addersubtractor_N test_arithmetic_logic_unit test_branch_unit test_not_N test_decoder_5to32 test_instruction_decoder test_register_1 test_register_N test_memory test_extender

# suppress "Entering/Leaving directory"
# MAKEFLAGS += --no-print-directory

setup: $(WORK_CF)

# Re-analyze the whole design if any source changes
$(WORK_CF): $(SOURCE)
	$(ANALYZE) $(SOURCE)

tests: test_barrel_shifter test_adder_1 test_adder_N test_addersubtractor_N test_arithmetic_logic_unit test_branch_unit test_not_N test_decoder_5to32 test_instruction_decoder test_register_1 test_register_N test_memory test_extender

verify: setup tests

test_barrel_shifter: setup ./test/tb_barrel_shifter.vhd
	$(ANALYZE) ./test/tb_barrel_shifter.vhd
	$(RUN) tb_barrel_shifter

test_adder_1: setup ./test/tb_adder_1.vhd
	$(ANALYZE) ./test/tb_adder_1.vhd
	$(RUN) tb_adder_1

test_adder_N: setup ./test/tb_adder_N.vhd
	$(ANALYZE) ./test/tb_adder_N.vhd
	$(RUN) tb_adder_N

test_addersubtractor_N: setup ./test/tb_addersubtractor_N.vhd
	$(ANALYZE) ./test/tb_addersubtractor_N.vhd
	$(RUN) tb_addersubtractor_N

test_arithmetic_logic_unit: setup ./test/tb_arithmetic_logic_unit.vhd
	$(ANALYZE) ./test/tb_arithmetic_logic_unit.vhd
	$(RUN) tb_arithmetic_logic_unit

test_branch_unit: setup ./test/tb_branch_unit.vhd
	$(ANALYZE) ./test/tb_branch_unit.vhd
	$(RUN) tb_branch_unit

test_not_N: setup ./test/tb_not_N.vhd
	$(ANALYZE) ./test/tb_not_N.vhd
	$(RUN) tb_not_N

test_decoder_5to32: setup ./test/tb_decoder_5to32.vhd
	$(ANALYZE) ./test/tb_decoder_5to32.vhd
	$(RUN) tb_decoder_5to32

test_instruction_decoder: setup ./test/tb_instruction_decoder.vhd
	$(ANALYZE) ./test/tb_instruction_decoder.vhd
	$(RUN) tb_instruction_decoder

test_register_1: setup ./test/tb_register_1.vhd
	$(ANALYZE) ./test/tb_register_1.vhd
	$(RUN) tb_register_1

test_register_N: setup ./test/tb_register_N.vhd
	$(ANALYZE) ./test/tb_register_N.vhd
	$(RUN) tb_register_N

test_memory: setup ./test/tb_memory.vhd
	$(ANALYZE) ./test/tb_memory.vhd
	$(RUN) tb_memory

test_extender: setup ./test/tb_extender_NtoM.vhd
	$(ANALYZE) ./test/tb_extender_NtoM.vhd
	$(RUN) tb_extender_NtoM