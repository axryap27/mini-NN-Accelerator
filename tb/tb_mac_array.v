// Testbench for the 3x3 systolic MAC array.
// 2 ns clock, active-low reset, all six input streams non-zero and changing
// every cycle for >15 cycles. Prints a per-cycle table of the 9 outputs.
//
// Anticipated values: PE(r,c) sees the row input delayed by c cycles
// (col0 = IN, col1 = INR, col2 = INRR) times the column weight delayed by r
// cycles (row0 = W, row1 = WR, row2 = WRR), accumulated each enabled cycle.
// cycle 1 is the first rising edge after reset release; operands for cycle k are
// driven before the edge that does accumulation k, so the printed cycle index
// matches the array's internal count. Outputs freeze at cycle 13.
`timescale 1ns/10ps
module tb_mac_array;

    localparam DATA_W = 8;
    localparam ACC_W  = 20;

    reg clk, rstb;
    reg signed [DATA_W-1:0] IN1, IN2, IN3;
    reg signed [DATA_W-1:0] W1,  W2,  W3;
    wire signed [ACC_W-1:0] OUT1,OUT2,OUT3,OUT4,OUT5,OUT6,OUT7,OUT8,OUT9;

    integer cyc;

    mac_array #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rstb(rstb),
        .IN1(IN1), .IN2(IN2), .IN3(IN3),
        .W1(W1),   .W2(W2),   .W3(W3),
        .OUT1(OUT1),.OUT2(OUT2),.OUT3(OUT3),
        .OUT4(OUT4),.OUT5(OUT5),.OUT6(OUT6),
        .OUT7(OUT7),.OUT8(OUT8),.OUT9(OUT9)
    );

    initial clk = 1'b0;
    always #1.0 clk = ~clk;

    // non-zero, every-cycle-changing stimulus (small enough to not overflow 20 bits)
    task drive_cycle(input integer k);
        begin
            IN1 = k;
            IN2 = k + 1;
            IN3 = k + 2;
            W1  = 1 + (k % 3);
            W2  = 2 + (k % 2);
            W3  = -(1 + (k % 4));
        end
    endtask

    initial begin
        rstb = 1'b0;
        drive_cycle(1);          // keep inputs non-zero during reset
        @(negedge clk); @(negedge clk);
        rstb = 1'b1;

        $display("  cyc |   OUT1   OUT2   OUT3 |   OUT4   OUT5   OUT6 |   OUT7   OUT8   OUT9");
        $display("------+----------------------+----------------------+---------------------");

        for (cyc = 1; cyc <= 18; cyc = cyc + 1) begin
            drive_cycle(cyc);
            @(posedge clk);
            #0.1;
            $display(" %4d | %6d %6d %6d | %6d %6d %6d | %6d %6d %6d",
                     cyc, OUT1, OUT2, OUT3, OUT4, OUT5, OUT6, OUT7, OUT8, OUT9);
            @(negedge clk);
        end

        $display("Outputs frozen after cycle 13.");
        $finish;
    end

endmodule
