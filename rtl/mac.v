// ECE 303 Lab 3 -- Single processing element (PE) for 3x3 systolic MAC array.
// One PE: registers its input and weight (these registers form the systolic
// pipeline -> chaining them across PEs produces the R / RR delayed copies),
// and accumulates IN*W into a signed accumulator when accumulate_enable is high.
//
// Reset: asynchronous active-low (rstb). Spec mandates active-low and "all
// internal flip-flops reset to 0"; sync-vs-async is not stated, async chosen.
// TODO(verify): confirm async vs sync reset against lab handout if required.
`timescale 1ns/10ps
module mac #(
    parameter DATA_W = 8,   // input / weight bit width (signed)
    parameter ACC_W  = 20   // accumulator / OUT bit width (signed)
)(
    input  wire                     clk,
    input  wire                     rstb,              // active-LOW reset (async)
    input  wire                     accumulate_enable, // global freeze gate
    input  wire signed [DATA_W-1:0] in_in,             // input from left (or row src)
    input  wire signed [DATA_W-1:0] w_in,              // weight from top (or col src)
    output wire signed [DATA_W-1:0] in_out,            // registered input -> next PE (R/RR)
    output wire signed [DATA_W-1:0] w_out,             // registered weight -> next PE (R/RR)
    output wire signed [ACC_W-1:0]  OUT                // accumulated result = acc
);

    // Pipeline registers: these ARE the delay elements that create IN->INR->INRR
    // and W->WR->WRR when PEs are chained in the array.
    reg signed [DATA_W-1:0] in_reg;
    reg signed [DATA_W-1:0] w_reg;
    reg signed [ACC_W-1:0]  acc;

    // signed product of two DATA_W operands is 2*DATA_W wide.
    wire signed [2*DATA_W-1:0] product = in_in * w_in;

    always @(posedge clk or negedge rstb) begin
        if (!rstb) begin
            in_reg <= {DATA_W{1'b0}};
            w_reg  <= {DATA_W{1'b0}};
            acc    <= {ACC_W{1'b0}};
        end else begin
            // forward this cycle's operands to the neighbour PE (1-cycle delay)
            in_reg <= in_in;
            w_reg  <= w_in;
            // accumulate only while the global freeze gate permits it
            if (accumulate_enable)
                acc <= acc + $signed(product);
        end
    end

    assign in_out = in_reg;
    assign w_out  = w_reg;
    assign OUT    = acc;

endmodule
