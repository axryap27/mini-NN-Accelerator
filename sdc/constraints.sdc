# Timing constraints for the 3x3 MAC array. 0.5 GHz -> 2 ns period.
# clk and rstb get no input delay.

create_clock -name clk -period 2.0 [get_ports clk]

foreach p {IN1 IN2 IN3 W1 W2 W3} {
    set_input_delay -max  0.5 -clock clk [get_ports $p]
    set_input_delay -min -0.2 -clock clk [get_ports $p]
}

foreach p {OUT1 OUT2 OUT3 OUT4 OUT5 OUT6 OUT7 OUT8 OUT9} {
    set_output_delay -max  0.5 -clock clk [get_ports $p]
    set_output_delay -min -0.2 -clock clk [get_ports $p]
}
