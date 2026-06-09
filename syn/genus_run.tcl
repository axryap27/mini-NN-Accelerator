# Genus synthesis for mac_array (Nangate 45nm).
# Source the Cadence env first:  source /vol/ece303/genus_tutorial/cadence.env
# Run with:  genus -batch -files syn/genus_run.tcl

set_db library /vol/ece303/genus_tutorial/NangateOpenCellLibrary_typical.lib

read_hdl { rtl/mac.v rtl/mac_array.v }
elaborate mac_array
read_sdc sdc/constraints.sdc

syn_generic
syn_map
syn_opt

report_area   > syn/area.rpt
report_timing > syn/timing.rpt

write_hdl > syn/netlist/mac_array_syn.v
write_sdc > syn/netlist/mac_array_syn.sdc
