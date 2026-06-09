#==============================================================================
# syn/genus_run.tcl
#
# Cadence Genus synthesis script for the ECE303 Lab 3 MAC array.
#   Top module : mac_array
#   Library    : Nangate Open Cell 45nm
#
# Usage (from the lab3 root directory, on the course server):
#   1) Source the Cadence environment BEFORE launching genus:
#        source /vol/ece303/genus_tutorial/cadence.env
#   2) Launch genus and source this script:
#        genus -batch -file syn/genus_run.tcl
#      or interactively:
#        genus> source syn/genus_run.tcl
#
# This script is fully sourceable and reproducible. All output products are
# written under syn/ (reports) and syn/netlist/ (gate netlist + SDC) which the
# Innovus backend flow (backend/innovus_run.tcl) consumes.
#==============================================================================

#------------------------------------------------------------------------------
# Step 0 : Environment note
#------------------------------------------------------------------------------
# The Cadence environment MUST be sourced in your shell before genus starts:
#   source /vol/ece303/genus_tutorial/cadence.env   ;# TODO(verify) server path
# It is listed here for documentation only; it is a shell command, not TCL.

#------------------------------------------------------------------------------
# Step 1 : Point the tool at the standard-cell technology library (.lib)
#------------------------------------------------------------------------------
# Nangate 45nm Open Cell Library, typical corner (confirmed path on server).
set_db library /vol/ece303/genus_tutorial/NangateOpenCellLibrary_typical.lib

#------------------------------------------------------------------------------
# Step 2 : Read RTL and elaborate the top module
#------------------------------------------------------------------------------
# Read the leaf MAC and the array that instantiates it, then elaborate the
# top-level design 'mac_array'.
read_hdl { rtl/mac.v rtl/mac_array.v }
elaborate mac_array

#------------------------------------------------------------------------------
# Step 3 : Apply timing constraints
#------------------------------------------------------------------------------
read_sdc sdc/constraints.sdc

#------------------------------------------------------------------------------
# Step 4 : Synthesize (generic -> technology map -> optimize)
#------------------------------------------------------------------------------
syn_generic
syn_map
syn_opt

#------------------------------------------------------------------------------
# Step 5 : Reports
#------------------------------------------------------------------------------
report_area   > syn/area.rpt
report_timing > syn/timing.rpt

#------------------------------------------------------------------------------
# Step 6 : Write out products for the backend (Innovus) flow
#------------------------------------------------------------------------------
write_hdl > syn/netlist/mac_array_syn.v
write_sdc > syn/netlist/mac_array_syn.sdc

puts "INFO: Genus synthesis of mac_array complete."
puts "INFO: Netlist : syn/netlist/mac_array_syn.v"
puts "INFO: SDC     : syn/netlist/mac_array_syn.sdc"
