# ECE 303 Lab 3 -- timing constraints for 3x3 systolic MAC array
# Clock 0.5 GHz -> 2.0 ns period. clk and rstb get NO input delay.

create_clock -name clk -period 2.0 [get_ports clk]

# All data/weight inputs (exclude clk, rstb): max 0.5 ns, min -0.2 ns.
set in_ports [list IN1 IN2 IN3 W1 W2 W3]
foreach p $in_ports {
    set_input_delay -max  0.5 -clock clk [get_ports $p]
    set_input_delay -min -0.2 -clock clk [get_ports $p]
}

# All outputs: max 0.5 ns, min -0.2 ns (negative min adds hold margin).
set out_ports [list OUT1 OUT2 OUT3 OUT4 OUT5 OUT6 OUT7 OUT8 OUT9]
foreach p $out_ports {
    set_output_delay -max  0.5 -clock clk [get_ports $p]
    set_output_delay -min -0.2 -clock clk [get_ports $p]
}

# clk and rstb intentionally have NO set_input_delay applied.
