// ECE 303 Lab 3 -- Top module: 3x3 systolic MAC array (9 PEs).
//
// DATAFLOW:
//   Inputs flow LEFT->RIGHT along each row; each PE delays the input 1 cycle
//   via its in_reg, producing IN->INR->INRR. Row0 uses IN1, Row1 IN2, Row2 IN3.
//   Weights flow TOP->BOTTOM along each column; each PE delays the weight 1
//   cycle via its w_reg, producing W->WR->WRR. Col0 uses W1, Col1 W2, Col2 W3.
//   PE(r,c) therefore multiplies (row-input delayed by c) * (col-weight delayed by r).
//
// OUT MAP: OUT1..OUT3 = row0 (cols 0,1,2); OUT4..OUT6 = row1; OUT7..OUT9 = row2.
//
// FREEZE LOGIC (spec item c): "At the clock cycle of 13, the MAC output will not
//   change any more. The OUT value will remain constant until reset."
//   Implementation = a single GLOBAL cycle counter from reset. We accumulate while
//   (cycle_count < FREEZE_CYCLE). The counter starts at 0 the cycle after reset
//   release and increments each clock. With FREEZE_CYCLE=13 the accumulate_enable
//   is asserted during counts 0..12 (i.e. 13 accumulation cycles); on the count
//   that reaches 13 accumulate_enable goes low, so OUT holds constant AT cycle 13
//   and thereafter -- the literal reading of the spec. GLOBAL (single counter,
//   one cycle number 13 for the whole array), NOT per-PE staggered.
//   BOUNDARY (confirmed): accumulate on counter values 0..12 = 13 accumulations;
//   OUT is final after the 13th accumulation and holds at counter==13. The
//   counter SATURATES at FREEZE_CYCLE (never wraps), so acc has no further write
//   path and OUT stays constant until rstb. CNT_W=5 covers counts 0..31.
//   TODO(verify): confirm against the handout that 13 accumulations (not 12) is
//   the intended final-value definition; spec gives no explicit < vs <=.
`timescale 1ns/10ps
module mac_array #(
    parameter DATA_W       = 8,
    parameter ACC_W        = 20,
    parameter ROWS         = 3,
    parameter COLS         = 3,
    parameter FREEZE_CYCLE = 13
)(
    input  wire                    clk,
    input  wire                    rstb,            // active-LOW reset
    input  wire signed [DATA_W-1:0] IN1, IN2, IN3,  // one input stream per ROW
    input  wire signed [DATA_W-1:0] W1,  W2,  W3,   // one weight stream per COLUMN
    output wire signed [ACC_W-1:0]  OUT1, OUT2, OUT3, // row0
    output wire signed [ACC_W-1:0]  OUT4, OUT5, OUT6, // row1
    output wire signed [ACC_W-1:0]  OUT7, OUT8, OUT9  // row2
);

    // ---------------------------------------------------------------
    // Global freeze counter (single counter for the whole array).
    // ---------------------------------------------------------------
    // Width large enough to hold FREEZE_CYCLE.
    localparam CNT_W = 5; // >= ceil(log2(FREEZE_CYCLE+1)); 5 bits covers up to 31
    reg [CNT_W-1:0] cycle_count;
    wire accumulate_enable = (cycle_count < FREEZE_CYCLE);

    always @(posedge clk or negedge rstb) begin
        if (!rstb)
            cycle_count <= {CNT_W{1'b0}};
        else if (cycle_count < FREEZE_CYCLE)
            cycle_count <= cycle_count + 1'b1; // saturate at FREEZE_CYCLE, then hold
    end

    // ---------------------------------------------------------------
    // Inter-PE wires. in_h[r][c] = input entering PE(r,c) from the left.
    // w_v[r][c] = weight entering PE(r,c) from the top.
    // out_w[r][c] = accumulator output of PE(r,c).
    // ---------------------------------------------------------------
    wire signed [DATA_W-1:0] in_h  [0:ROWS-1][0:COLS];   // [.][0]=row input, [.][c]=INR/INRR
    wire signed [DATA_W-1:0] w_v   [0:ROWS][0:COLS-1];   // [0][.]=col weight, [r][.]=WR/WRR
    wire signed [DATA_W-1:0] in_fwd[0:ROWS-1][0:COLS-1]; // registered input out of each PE
    wire signed [DATA_W-1:0] w_fwd [0:ROWS-1][0:COLS-1]; // registered weight out of each PE
    wire signed [ACC_W-1:0]  out_w [0:ROWS-1][0:COLS-1];

    // Row inputs feed the leftmost column.
    assign in_h[0][0] = IN1;
    assign in_h[1][0] = IN2;
    assign in_h[2][0] = IN3;
    // Column weights feed the top row.
    assign w_v[0][0] = W1;
    assign w_v[0][1] = W2;
    assign w_v[0][2] = W3;

    // ---------------------------------------------------------------
    // Instantiate the 3x3 grid. The registered outputs of each PE become
    // the (delayed) inputs to the neighbour to its right / below.
    // ---------------------------------------------------------------
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
                // Forward delayed input to the PE on the right (next column).
                assign in_h[r][c+1] = in_fwd[r][c];
                // Forward delayed weight to the PE below (next row).
                assign w_v[r+1][c]  = w_fwd[r][c];
            end
        end
    endgenerate

    // ---------------------------------------------------------------
    // Output mapping: OUT1..3 row0, OUT4..6 row1, OUT7..9 row2.
    // ---------------------------------------------------------------
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
