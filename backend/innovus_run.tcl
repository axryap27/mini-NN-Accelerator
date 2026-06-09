#==============================================================================
# backend/innovus_run.tcl
#
# Cadence Innovus place-and-route script for the ECE303 Lab 3 MAC array.
#   Top module : mac_array
#   Library    : Nangate Open Cell 45nm
#
# Adapted from the May 2026 course Innovus tutorial (originally written for
# float16_multiplier). All names changed to mac_array.
#
# Usage (on the course server, from the lab3 root directory):
#   1) Source the Cadence environment BEFORE launching innovus:
#        source /vol/ece303/genus_tutorial/cadence.env
#   2) Launch innovus and source this script:
#        innovus> source backend/innovus_run.tcl
#
# IMPORTANT POWER-GRID NOTE:
#   The power rings use Metal4 (left/right) and metal5 (top/bottom), and the
#   detail-route top routing layer is 6. These match the verified course
#   tutorial EXACTLY -- do NOT substitute metal6.
#
# PREREQUISITES:
#   - Gate netlist from synthesis (syn/netlist/mac_array_syn.v) must have
#       inout VDD, VSS;
#     added to the module header + port list before import.
#   - Synthesized SDC (syn/netlist/mac_array_syn.sdc) referenced by the MMMC
#     .view file.
#==============================================================================

#------------------------------------------------------------------------------
# Step 0 : Environment note
#------------------------------------------------------------------------------
# Source the Cadence environment in your shell BEFORE launching innovus:
#   source /vol/ece303/genus_tutorial/cadence.env   ;# TODO(verify) server path
# (Shell command, documented here for reproducibility; not TCL.)

#==============================================================================
# Step 1 : Design Import
#==============================================================================
# Load the gate-level netlist, the Nangate LEF, the MMMC .view file (which
# references the synthesized SDC), and declare the power/ground nets.
#
# The netlist module header must already contain: inout VDD, VSS;
#
# TODO(verify): confirm LEF and .view paths on the course server.
set init_verilog        syn/netlist/mac_array_syn.v
set init_top_cell       mac_array
set init_lef_file       /vol/ece303/genus_tutorial/NangateOpenCellLibrary.lef
set init_mmmc_file      backend/mac_array.view
set init_pwr_net        VDD
set init_gnd_net        VSS
init_design

#==============================================================================
# Step 2 : Floorplan
#==============================================================================
setDesignMode -process 45
fit
setDrawView fplan
getIoFlowFlag

# Aspect ratio 1.0, core utilization 0.63, core-to-IO spacing 2 on all sides.
floorPlan -r 1.0 0.63 2 2 2 2
uiSetTool select
getIoFlowFlag

#==============================================================================
# Step 3 : Global net connections (power intent)
#==============================================================================
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VDD -type tiehi
globalNetConnect VSS -type tielo

#==============================================================================
# Step 4 : Pin placement
#==============================================================================
# NOTE: Pin locations are edited interactively in the GUI per the lab spec:
#   IN1-3  -> LEFT edge
#   W1-3   -> TOP edge
#   OUT1-9 -> BOTTOM edge
# Tutorial example placed pins on metal3, spread from center, spacing ~0.56 /
# 0.42, Use = SIGNAL. Perform this step in the GUI, then continue.

# Save floorplan checkpoint.
saveDesign mac_array_fl.enc

#==============================================================================
# Step 5 : Power -- rings, stripes, special route
#==============================================================================
# EXACT tutorial strings. Rings: top/bottom = metal5, left/right = metal4.
# Do NOT substitute metal6.
addRing -nets {VSS VDD} -type core_rings -follow io -layer {top metal5 bottom metal5 left metal4 right metal4} -width {top 1 bottom 1 left 1 right 1} -spacing {top 1 bottom 1 left 1 right 1} -offset {top 0 bottom 0 left 0 right 0} -center 0 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None

addStripe -block_ring_top_layer_limit metal5 -max_same_layer_jog_length 1.6 -padcore_ring_bottom_layer_limit metal3 -set_to_set_distance 5 -stacked_via_top_layer metal10 -padcore_ring_top_layer_limit metal5 -spacing 1 -xleft_offset 1 -merge_stripes_value 0.095 -layer metal4 -block_ring_bottom_layer_limit metal3 -width 1 -nets {VSS VDD} -stacked_via_bottom_layer metal1

sroute -connect {blockPin padPin padRing corePin floatingStripe} -layerChangeRange {1 10} -blockPinTarget {nearestRingStripe nearestTarget} -padPinPortConnect {allPort oneGeom} -checkAlignedSecondaryPin 1 -blockPin useLef -allowJogging 1 -crossoverViaBottomLayer 1 -allowLayerChange 1 -targetViaTopLayer 10 -crossoverViaTopLayer 10 -targetViaBottomLayer 1 -nets {VDD VSS}

saveDesign mac_array_power.enc

#==============================================================================
# Step 6 : Placement
#==============================================================================
setEndCapMode -reset
setEndCapMode -boundary_tap false
setPlaceMode -reset
setPlaceMode -congEffort auto -timingDriven 1 -modulePlan 1 -clkGateAware 1 -powerDriven 0 -ignoreScan 1 -reorderScan 1 -ignoreSpare 0 -placeIOPins 0 -moduleAwareSpare 0 -preserveRouting 0 -rmAffectedRouting 0 -checkRoute 0 -swapEEQ 0
setPlaceMode -fp false
placeDesign
timeDesign -preCTS -numPaths 200
optDesign -preCTS -numPaths 200
saveDesign mac_array_pl.enc

#==============================================================================
# Step 7 : Clock Tree Synthesis (CCOpt)
#==============================================================================
set_ccopt_property update_io_latency false
set_ccopt_property post_conditioning_enable_routing_eco 1
set_ccopt_property cts_def_lock_clock_sinks_after_routing true
setOptMode -unfixClkInstForOpt false
create_ccopt_clock_tree_spec -file clk_gen.ccopt
ccopt_design
timeDesign -postCTS -numPaths 200
timeDesign -postCTS -hold -numPaths 200
optDesign -postCTS -numPaths 200
optDesign -postCTS -hold -numPaths 200
timeDesign -postCTS -hold -numPaths 200
timeDesign -postCTS -numPaths 200
saveDesign mac_array_clk.enc

#==============================================================================
# Step 8 : Filler insertion + Routing
#==============================================================================
getFillerMode -quiet
addFillerGap 0.6
addFiller -cell FILLCELL_X1 FILLCELL_X2 FILLCELL_X4 FILLCELL_X8 -prefix FILLER -markFixed
saveDesign mac_array_powerroute_clk_filler.enc

# Timing analysis mode for routing.
setAnalysisMode -cppr none -clockGatingCheck true -timeBorrowing true -useOutputPinCap true -sequentialConstProp false -timingSelfLoopsNoSkew false -enableMultipleDriveNet true -clkSrcPath true -warn true -usefulSkew false -analysisType onChipVariation -log true

# NanoRoute setup. Top routing layer = 6 (EXACT tutorial value -- not metal6).
setNanoRouteMode -quiet -drouteFixAntenna false
setNanoRouteMode -quiet -routeTopRoutingLayer default
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration default
setNanoRouteMode -quiet -routeWithTimingDriven false
setNanoRouteMode -quiet -routeWithSiDriven false
setNanoRouteMode -quiet -routeTopRoutingLayer 6
routeDesign -globalDetail

# Post-route optimization: remove fillers, optimize, re-add fillers, fix DRC.
deleteFiller -prefix FILLER
optDesign -postRoute
optDesign -postRoute -hold
setFillerMode -add_fillers_with_drc true
addFiller -cell FILLCELL_X1 FILLCELL_X2 FILLCELL_X4 FILLCELL_X8 -prefix FILLER -markFixed
verify_drc
ecoRoute
verify_drc

#==============================================================================
# Step 9 : Post-route timing
#==============================================================================
timeDesign -postRoute -pathReports -drvReports -slackReports -numPaths 400 -prefix mac_array_postRoute -outDir timingReports
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 400 -prefix mac_array_postRoute -outDir timingReports
saveDesign mac_array_final_layout.enc

#==============================================================================
# Step 10 : Netlist + SDF export
#==============================================================================
saveNetlist -phys -includePowerGround mac_array_phy.v -excludeLeafCell
saveNetlist mac_array_nophy.v -excludeLeafCell
write_sdf mac_array.sdf

#==============================================================================
# Step 11 : Signoff verification
#==============================================================================
verify_drc -report mac_array.drc.rpt -limit 1000
verifyConnectivity -type all -error 1000 -warning 50
verifyProcessAntenna -reportfile mac_array.antenna.rpt -error 1000

#==============================================================================
# Step 12 : Reports
#==============================================================================
report_area
report_timing -late    ;# setup analysis
report_timing -early   ;# hold analysis

# NOTE: Power analysis is performed in the GUI (Power Analysis):
#   Input Activity = 0.2, Dominant Frequency = 500 MHz.

puts "INFO: Innovus backend flow for mac_array complete."
puts "INFO: Final layout : mac_array_final_layout.enc"
