setup:
	ghdl -a --work=work --std=08 ./source/types.vhd
	ghdl -a --work=work --std=08 ./source/not_1.vhd ./source/not_N.vhd ./source/and_2.vhd ./source/or_2.vhd ./source/xor_2.vhd
	ghdl -a --work=work --std=08 ./source/multiplexer_2to1.vhd ./source/multiplexer_2to1_N.vhd ./source/multiplexer_32to1.vhd
	ghdl -a --work=work --std=08 ./source/register_1.vhd ./source/register_N.vhd
	ghdl -a --work=work --std=08 ./source/decoder_5to32.vhd
	ghdl -a --work=work --std=08 ./source/adder_1.vhd
	ghdl -a --work=work --std=08 ./source/adder_N.vhd
	ghdl -a --work=work --std=08 ./source/addersubtractor_N.vhd
	ghdl -a --work=work --std=08 ./source/barrel_shifter.vhd
	ghdl -a --work=work --std=08 ./source/instruction_decoder.vhd
	ghdl -a --work=work --std=08 ./source/instruction_pointer.vhd
	ghdl -a --work=work --std=08 ./source/register_file.vhd
	ghdl -a --work=work --std=08 ./source/memory.vhd
	ghdl -a --work=work --std=08 ./source/extender_NtoM.vhd
	ghdl -a --work=work --std=08 ./source/arithmetic_logic_unit.vhd
	ghdl -a --work=work --std=08 ./source/control_unit.vhd
	ghdl -a --work=work --std=08 ./source/branch_unit.vhd

test_barrel_shifter:
	ghdl -a --work=work --std=08 ./source/barrel_shifter.vhd ./test/tb_barrel_shifter.vhd
	ghdl --elab-run --std=08 tb_barrel_shifter

test_adder_1:
	ghdl -a --work=work --std=08 ./source/adder_1.vhd ./test/tb_adder_1.vhd
	ghdl --elab-run --std=08 tb_adder_1

test_adder_N:
	ghdl -a --work=work --std=08 ./source/adder_N.vhd ./test/tb_adder_N.vhd
	ghdl --elab-run --std=08 tb_adder_N

verify:
	nmake setup
	nmake test_barrel_shifter
	nmake test_adder_1
	nmake test_adder_N