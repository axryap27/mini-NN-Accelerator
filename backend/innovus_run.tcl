# Innovus place-and-route for mac_array (Nangate 45nm).
# Source the Cadence env first:  source /vol/ece303/genus_tutorial/cadence.env
# RUN THIS SCRIPT FROM INSIDE backend/  (cd backend; innovus; source innovus_run.tcl)
# so that all outputs (.enc, netlists, .sdf, reports, timingReports/) land in backend/.
# Input paths below are therefore relative to backend/ (../syn/... for frontend files).
#
# Before importing, add  inout VDD, VSS;  to the module header and port list in
# ../syn/netlist/mac_array_syn.v (done), and make sure backend/mac_array.view points
# at the synthesized SDC (../syn/netlist/mac_array_syn.sdc).

# --- design import ---
set init_verilog        ../syn/netlist/mac_array_syn.v
set init_top_cell       mac_array
set init_lef_file       /vol/ece303/genus_tutorial/NangateOpenCellLibrary.lef
set init_mmmc_file      mac_array.view
set init_pwr_net        VDD
set init_gnd_net        VSS
init_design

# --- floorplan ---
setDesignMode -process 45
fit
setDrawView fplan
getIoFlowFlag
floorPlan -r 1.0 0.63 2 2 2 2
uiSetTool select
getIoFlowFlag

# --- power/ground net connections ---
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VDD -type tiehi
globalNetConnect VSS -type tielo

# Edit pin locations in the GUI here: IN1-3 on the left, W1-3 on top,
# OUT1-9 on the bottom (metal3, spread from center, Use SIGNAL).
saveDesign mac_array_fl.enc

# --- power rings / stripes / sroute ---
# CAVEAT (tutorial update): the power stripe in the previous tutorial version sat at
# Metal4, which is low -- power should normally be on a higher metal. The new version
# moves it to Metal6 to avoid blocking main signal routing. Four commands change:
# addRing, addStripe, sroute (below) and the routing-stage
# "setNanoRouteMode -quiet -routeTopRoutingLayer 5" (this script currently uses 6).
# The older Metal4 version below STILL WORKS for Lab3; the Metal6 version just gives a
# cleaner design. We keep Metal4 here because the exact Metal6 command strings are not
# in our tutorial copy -- do not retype them from memory. Swap them in only from the
# current tutorial doc's exact lines if you want the cleaner design.
addRing -nets {VSS VDD} -type core_rings -follow io -layer {top metal5 bottom metal5 left metal4 right metal4} -width {top 1 bottom 1 left 1 right 1} -spacing {top 1 bottom 1 left 1 right 1} -offset {top 0 bottom 0 left 0 right 0} -center 0 -extend_corner {} -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None

addStripe -block_ring_top_layer_limit metal5 -max_same_layer_jog_length 1.6 -padcore_ring_bottom_layer_limit metal3 -set_to_set_distance 5 -stacked_via_top_layer metal10 -padcore_ring_top_layer_limit metal5 -spacing 1 -xleft_offset 1 -merge_stripes_value 0.095 -layer metal4 -block_ring_bottom_layer_limit metal3 -width 1 -nets {VSS VDD} -stacked_via_bottom_layer metal1

sroute -connect {blockPin padPin padRing corePin floatingStripe} -layerChangeRange {1 10} -blockPinTarget {nearestRingStripe nearestTarget} -padPinPortConnect {allPort oneGeom} -checkAlignedSecondaryPin 1 -blockPin useLef -allowJogging 1 -crossoverViaBottomLayer 1 -allowLayerChange 1 -targetViaTopLayer 10 -crossoverViaTopLayer 10 -targetViaBottomLayer 1 -nets {VDD VSS}

saveDesign mac_array_power.enc

# --- placement ---
setEndCapMode -reset
setEndCapMode -boundary_tap false
setPlaceMode -reset
setPlaceMode -congEffort auto -timingDriven 1 -modulePlan 1 -clkGateAware 1 -powerDriven 0 -ignoreScan 1 -reorderScan 1 -ignoreSpare 0 -placeIOPins 0 -moduleAwareSpare 0 -preserveRouting 0 -rmAffectedRouting 0 -checkRoute 0 -swapEEQ 0
setPlaceMode -fp false
placeDesign
timeDesign -preCTS -numPaths 200
optDesign -preCTS -numPaths 200
saveDesign mac_array_pl.enc

# --- clock tree synthesis ---
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

# --- fillers + routing ---
getFillerMode -quiet
addFillerGap 0.6
addFiller -cell FILLCELL_X1 FILLCELL_X2 FILLCELL_X4 FILLCELL_X8 -prefix FILLER -markFixed
saveDesign mac_array_powerroute_clk_filler.enc

setAnalysisMode -cppr none -clockGatingCheck true -timeBorrowing true -useOutputPinCap true -sequentialConstProp false -timingSelfLoopsNoSkew false -enableMultipleDriveNet true -clkSrcPath true -warn true -usefulSkew false -analysisType onChipVariation -log true

setNanoRouteMode -quiet -drouteFixAntenna false
setNanoRouteMode -quiet -routeTopRoutingLayer default
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration default
setNanoRouteMode -quiet -routeWithTimingDriven false
setNanoRouteMode -quiet -routeWithSiDriven false
setNanoRouteMode -quiet -routeTopRoutingLayer 6
routeDesign -globalDetail

deleteFiller -prefix FILLER
optDesign -postRoute
optDesign -postRoute -hold
setFillerMode -add_fillers_with_drc true
addFiller -cell FILLCELL_X1 FILLCELL_X2 FILLCELL_X4 FILLCELL_X8 -prefix FILLER -markFixed
verify_drc
ecoRoute
verify_drc

# --- post-route timing ---
timeDesign -postRoute -pathReports -drvReports -slackReports -numPaths 400 -prefix mac_array_postRoute -outDir timingReports
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 400 -prefix mac_array_postRoute -outDir timingReports
saveDesign mac_array_final_layout.enc

# --- netlist + sdf export ---
saveNetlist -phys -includePowerGround mac_array_phy.v -excludeLeafCell
saveNetlist mac_array_nophy.v -excludeLeafCell
write_sdf mac_array.sdf

# --- signoff checks ---
verify_drc -report mac_array.drc.rpt -limit 1000
verifyConnectivity -type all -error 1000 -warning 50
verifyProcessAntenna -reportfile mac_array.antenna.rpt -error 1000

# --- reports ---
report_area
report_timing -late
report_timing -early

# Power analysis is run in the GUI: Input Activity 0.2, Dominant Frequency 500 MHz.
