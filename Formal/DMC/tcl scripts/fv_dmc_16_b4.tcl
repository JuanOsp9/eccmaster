

# TCL-script for OneSpin (Siemens EDA)

################################################################################
# Configuration

# Tell the tool to use database (and create one unless it exists)
# When 1: Tool will     create &     load the database
# When 0: Tool will not create & not load the database
set use_setup_database 0

# Select what actions the tool should automatically perform
# Check:   When true  it          performs proofs for all properties of the default task
#          When false it does not perform  proofs for all properties of the default task
set auto_check 0
# Witness: When true  it          computes witnesses for all properties of the default task
#          When false it does not compute  witnesses for all properties of the default task
set auto_witness 0

# Tell the tool to exit after the execution of the tcl-script finishes
# When 1: Tool will exit
# When 0: Tool will remain in interactive mode
set exit_after_execution 0

################################################################################
# Script - No change required below this line

# Change working directory to the directory of the script
# Eliminate every symbolic link
set script_path [file dirname [file dirname [file normalize [info script]/___]]]
set design_path $script_path/rtl
set property_path $script_path/Properties
cd $script_path


# Start logging
start_message_log -force ./prove.log


# Re-run setup in case this script was already executed
#re_setup
set_mode setup
delete_design -both
remove_server -all

set_session_option -naming_style sv


# Load Setup Database
set setup_database_name setup.onespin
if {$use_setup_database && [file isdirectory $setup_database_name]} {
    load_database -force $setup_database_name
} else {

###############
# Load Design #
# Use the SystemVerilog standard SV2012

read_verilog -golden -version sv2012 [subst {
    $design_path/dmc_sram_wrapper_16Bit_B4.sv
    $design_path/SRAM.v
    $design_path/dmc_locator_corrector_64bit.sv
    $design_path/dmc_codec_64bit.sv

}]


####################
# Elaborate Design #
set_elaborate_option -golden -top memory_wrapper_16_B4
elaborate     -golden 

##################
# Compile Design #
set_compile_option   -golden -clock { {clk} }
set_compile_option   -golden -undriven_value input
compile              -golden


###############
# Final Setup #
set_clock_spec -period 2 clk

#set_reset_sequence -golden { { rst=0 } }




##########################
# Configure Verification #
set_mode mv

# 2. Cut the signal sram_din
# This prevents the RTL encoder from driving this net
#set_cut_signals {memory_wrapper_16bit_B1.u_sram.din0 memory_wrapper_16bit_B1.encoder_inst.D}

#cut_signals {memory_wrapper_16bit_B1.u_sram.din0 memory_wrapper_16bit_B1.encoder_inst.D}

# Save Setup Database
if {$use_setup_database} {
    save_database -force $setup_database_name
}

}

read_sva -version sv2012 [subst {
    $property_path/fv_dmc_memory_wrapper_16_B4.sv
}]


####################
# Check properties #
if {[string equal [info hostname] elara]} {
    add_server -max_processes 1 mab.lubis-eda.com
}
if {[string equal [info hostname] elara]} {
    add_server -max_processes 1 atlas.lubis-eda.com
}

# Configure default task
# Server configuration
if {[string equal [info hostname] elara]} {
    set_check_option -local_processes 1
    set_check_option -network_processes 2
    set_check_option -parallel network
}
if {[string equal [info hostname] mab.lubis-eda.com]} {
    set_check_option -local_processes 1
}
if {[string equal [info hostname] atlas.lubis-eda.com]} {
    set_check_option -local_processes 1
}

if {$auto_check && $auto_witness} {
    check -force -all [get_assertions] -orchestrator questa
} elseif {$auto_check} {
    check -force [get_assertions] -orchestrator questa
} elseif {$auto_witness} {
    check -force -pass [get_assertions] -orchestrator questa
}

if {$exit_after_execution} {
    exit -force
}
