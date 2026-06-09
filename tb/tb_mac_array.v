// ECE 303 Lab 3 -- Behavioral testbench for the 3x3 systolic MAC array.
//
// Clock: 0.5 GHz -> period 2.0 ns. Reset active-low: held 0, then released.
// All 6 input streams (IN1..IN3, W1..W3) are non-zero, signed, and CHANGE EVERY
// CYCLE for >= 15 continuous cycles, per the lab deliverable.
//
// ====================== CYCLE ALIGNMENT (review fix) ======================
// The DUT's GLOBAL freeze counter increments on the FIRST posedge after rstb
// release and on every posedge thereafter. To make the printed cycle index
// equal the DUT's accumulation count, we must:
//   (1) release rstb on the negedge IMMEDIATELY before the first driven posedge,
//       so NO un-counted "hidden" posedge slips between reset release and cyc=1;
//   (2) drive cyc=k's operands BEFORE the posedge that performs accumulation #k.
// Then printed cyc==1 is exactly the posedge where cycle_count goes 0->1 (the
// FIRST accumulation), and the last OUT change occurs at printed cyc=13, with
// rows 13..18 identical (frozen). This eliminates the off-by-one and ensures
// the stimulus stream the hand-calc uses is the exact stream the DUT accumulates.
//
// ============================ HAND-CALC METHOD ============================
// For PE at (row r, col c):
//   * the INPUT seen by the PE = the row input delayed by c cycles
//       col0 -> IN(t), col1 -> IN(t-1) (INR), col2 -> IN(t-2) (INRR)
//   * the WEIGHT seen by the PE = the column weight delayed by r cycles
//       row0 -> W(t), row1 -> W(t-1) (WR), row2 -> W(t-2) (WRR)
// Each enabled cycle the PE does:  acc <= acc + (delayed_IN * delayed_W).
// OUT(t) is the accumulator AFTER the posedge, so OUT updates one cycle after
// the operands are presented. Accumulation is GLOBALLY gated: it runs while the
// from-reset cycle counter < FREEZE_CYCLE(13); OUT freezes at/after cycle 13.
//
// Define cycle 1 = the FIRST rising edge after reset release, which is also the
// posedge that consumes the cyc=1 operands (because of the alignment above).
// Operands not yet driven (negative time index) are 0; before cyc=1 the array
// holds reset values, so delayed operands for cyc=1 col>0 / row>0 are 0.
// =========================================================================
`timescale 1ns/10ps
module tb_mac_array;

    localparam DATA_W = 8;
    localparam ACC_W  = 20;

    reg clk, rstb;
    reg signed [DATA_W-1:0] IN1, IN2, IN3;
    reg signed [DATA_W-1:0] W1,  W2,  W3;
    wire signed [ACC_W-1:0] OUT1,OUT2,OUT3,OUT4,OUT5,OUT6,OUT7,OUT8,OUT9;

    integer cyc;

    // DUT
    mac_array #(.DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rstb(rstb),
        .IN1(IN1), .IN2(IN2), .IN3(IN3),
        .W1(W1),   .W2(W2),   .W3(W3),
        .OUT1(OUT1),.OUT2(OUT2),.OUT3(OUT3),
        .OUT4(OUT4),.OUT5(OUT5),.OUT6(OUT6),
        .OUT7(OUT7),.OUT8(OUT8),.OUT9(OUT9)
    );

    // 2.0 ns clock (0.5 GHz)
    initial clk = 1'b0;
    always #1.0 clk = ~clk;

    // Per-cycle stimulus: simple, non-zero, every-cycle-changing signed values.
    // IN1 = k, IN2 = k+1, IN3 = k+2, with k>=1 always (so never zero on a driven
    // cycle). Weights also change every cycle and stay non-zero; W3 is signed
    // negative. Magnitudes are small so the 20-bit accumulator never overflows.
    task drive_cycle(input integer k);
        begin
            IN1 = k;             // 1,2,3,...
            IN2 = k + 1;         // 2,3,4,...
            IN3 = k + 2;         // 3,4,5,...
            W1  = 1 + (k % 3);   // changes every cycle, non-zero, small
            W2  = 2 + (k % 2);   // changes, non-zero
            W3  = -(1 + (k % 4));// signed (negative), non-zero, changing
        end
    endtask

    initial begin
        // ---- reset ----
        rstb = 1'b0;
        // Seed with a NON-ZERO stimulus during reset so no zero input stream is
        // ever presented (deliverable: inputs cannot be zero). Math is unaffected
        // because rstb=0 holds all FFs at 0; these values are overwritten by
        // drive_cycle(1) before the first counted posedge.
        drive_cycle(1);
        // Hold reset across a couple of edges, then RELEASE on the negedge that
        // sits immediately before the first driven posedge (no hidden posedge).
        @(negedge clk); @(negedge clk);
        rstb = 1'b1;

        // header
        $display("  cyc |   OUT1   OUT2   OUT3 |   OUT4   OUT5   OUT6 |   OUT7   OUT8   OUT9");
        $display("------+----------------------+----------------------+---------------------");

        // Drive >=15 cycles. Operands for cyc=k are applied BEFORE the posedge
        // that performs accumulation #k, so printed cyc == DUT cycle_count.
        // No @(negedge) precedes the first drive_cycle: rstb was just released on
        // a negedge, so the next posedge is accumulation #1 == printed cyc=1.
        for (cyc = 1; cyc <= 18; cyc = cyc + 1) begin
            drive_cycle(cyc);
            @(posedge clk);
            #0.1; // let NBAs settle for display
            $display(" %4d | %6d %6d %6d | %6d %6d %6d | %6d %6d %6d",
                     cyc, OUT1, OUT2, OUT3, OUT4, OUT5, OUT6, OUT7, OUT8, OUT9);
            @(negedge clk); // move to the negedge so next operands are set up cleanly
        end

        $display("Final OUT values are frozen (should not change after cycle 13).");
        $finish;
    end

endmodule
