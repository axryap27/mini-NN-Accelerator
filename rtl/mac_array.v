// Top module: 3x3 systolic MAC array (9 PEs).
// Inputs flow left->right along each row (one cycle delay per PE -> IN/INR/INRR),
// weights flow top->bottom along each column (W/WR/WRR). So PE(r,c) multiplies
// the row input delayed by c by the column weight delayed by r.
// OUT1-3 = row0, OUT4-6 = row1, OUT7-9 = row2.
//
// Freeze: spec says the output stops changing at clock cycle 13. A single global
// counter runs from reset; we accumulate while cycle_count < FREEZE_CYCLE, then the
// counter holds and the outputs stay constant until rstb.
`timescale 1ns/10ps
module mac_array #(
    parameter DATA_W       = 8,
    parameter ACC_W        = 20,
    parameter ROWS         = 3,
    parameter COLS         = 3,
    parameter FREEZE_CYCLE = 13
)(
    input  wire                    clk,
    input  wire                    rstb,
    input  wire signed [DATA_W-1:0] IN1, IN2, IN3,
    input  wire signed [DATA_W-1:0] W1,  W2,  W3,
    output wire signed [ACC_W-1:0]  OUT1, OUT2, OUT3,
    output wire signed [ACC_W-1:0]  OUT4, OUT5, OUT6,
    output wire signed [ACC_W-1:0]  OUT7, OUT8, OUT9
);

    // global freeze counter
    localparam CNT_W = 5;
    reg [CNT_W-1:0] cycle_count;
    wire accumulate_enable = (cycle_count < FREEZE_CYCLE);

    always @(posedge clk or negedge rstb) begin
        if (!rstb)
            cycle_count <= 0;
        else if (cycle_count < FREEZE_CYCLE)
            cycle_count <= cycle_count + 1'b1;
    end

    // inter-PE wires: in_h enters a PE from the left, w_v from the top
    wire signed [DATA_W-1:0] in_h  [0:ROWS-1][0:COLS];
    wire signed [DATA_W-1:0] w_v   [0:ROWS][0:COLS-1];
    wire signed [DATA_W-1:0] in_fwd[0:ROWS-1][0:COLS-1];
    wire signed [DATA_W-1:0] w_fwd [0:ROWS-1][0:COLS-1];
    wire signed [ACC_W-1:0]  out_w [0:ROWS-1][0:COLS-1];

    // row inputs feed the left column, column weights feed the top row
    assign in_h[0][0] = IN1;
    assign in_h[1][0] = IN2;
    assign in_h[2][0] = IN3;
    assign w_v[0][0] = W1;
    assign w_v[0][1] = W2;
    assign w_v[0][2] = W3;

    genvar r, c;
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : ROW
            for (c = 0; c < COLS; c = c + 1) begin : COL
                mac #(.DATA_W(DATA_W), .ACC_W(ACC_W)) pe (
                    .clk              (clk),
                    .rstb             (rstb),
                    .accumulate_enable(accumulate_enable),
                    .in_in            (in_h[r][c]),
                    .w_in             (w_v[r][c]),
                    .in_out           (in_fwd[r][c]),
                    .w_out            (w_fwd[r][c]),
                    .OUT              (out_w[r][c])
                );
                assign in_h[r][c+1] = in_fwd[r][c];   // delayed input to the right
                assign w_v[r+1][c]  = w_fwd[r][c];    // delayed weight downward
            end
        end
    endgenerate

    assign OUT1 = out_w[0][0];
    assign OUT2 = out_w[0][1];
    assign OUT3 = out_w[0][2];
    assign OUT4 = out_w[1][0];
    assign OUT5 = out_w[1][1];
    assign OUT6 = out_w[1][2];
    assign OUT7 = out_w[2][0];
    assign OUT8 = out_w[2][1];
    assign OUT9 = out_w[2][2];

endmodule
