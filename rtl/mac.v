// Single MAC processing element for the 3x3 systolic array.
// Registers its input and weight (these regs form the systolic pipeline that
// creates the R/RR delayed copies when PEs are chained), and accumulates
// in_in*w_in when accumulate_enable is high. Async active-low reset.
`timescale 1ns/10ps
module mac #(
    parameter DATA_W = 8,
    parameter ACC_W  = 20
)(
    input  wire                     clk,
    input  wire                     rstb,
    input  wire                     accumulate_enable,
    input  wire signed [DATA_W-1:0] in_in,
    input  wire signed [DATA_W-1:0] w_in,
    output wire signed [DATA_W-1:0] in_out,   // registered input -> right neighbor
    output wire signed [DATA_W-1:0] w_out,    // registered weight -> bottom neighbor
    output wire signed [ACC_W-1:0]  OUT
);

    reg signed [DATA_W-1:0] in_reg;
    reg signed [DATA_W-1:0] w_reg;
    reg signed [ACC_W-1:0]  acc;

    wire signed [2*DATA_W-1:0] product = in_in * w_in;

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            in_reg <= 0;
            w_reg  <= 0;
            acc    <= 0;
        end else begin
            in_reg <= in_in;
            w_reg  <= w_in;
            if (accumulate_enable)
                acc <= acc + product;
        end
    end

    assign in_out = in_reg;
    assign w_out  = w_reg;
    assign OUT    = acc;

endmodule
