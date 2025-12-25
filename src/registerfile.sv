// haze-cpu: registerfile.sv
// (c) 2025 Connor J. Link. All rights reserved.

module registerfile
(
    input  logic        i_Clock,
    input  logic        i_Reset,
    input  logic [4:0]  i_RS1,
    input  logic [4:0]  i_RS2,
    input  logic [4:0]  i_RD,
    input  logic        i_WriteEnable,
    input  logic [31:0] i_D,
    output logic [31:0] o_DS1,
    output logic [31:0] o_DS2
);

    logic [31:0] s_WEx;
    logic [31:0] s_WEm;

    logic [31:0] s_Rx [0:31];

    decoder_5to32 u_Decoder_5to32
    (
        .i_S(i_RD),
        .o_Q(s_WEx)
    );

    always_comb begin
        s_WEm = s_WEx & {32{i_WriteEnable}};
    end

    // registers 1 to 31 (x0 hardwired to zero)
    genvar i;
    generate
        for (i = 1; i < 32; i++) begin : g_Registers
            register_N #(.N(32)) u_Reg
            (
                .i_Clock(i_Clock),
                .i_Reset(i_Reset),
                .i_WriteEnable(s_WEm[i]),
                .i_D(i_D),
                .o_Q(s_Rx[i])
            );
        end
    endgenerate

    // register x0 hardwired to zero
    assign s_Rx[0] = 32'h0000_0000;

    // read port 1
    multiplexer_32to1 u_Mux_RS1
    (
        .i_S(i_RS1),
        .i_D(s_Rx),
        .o_Q(o_DS1)
    );

    // read port 2
    multiplexer_32to1 u_Mux_RS2
    (
        .i_S(i_RS2),
        .i_D(s_Rx),
        .o_Q(o_DS2)
    );

endmodule