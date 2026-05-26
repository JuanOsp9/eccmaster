

# TCL-script for OneSpin (Siemens EDA)


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


###############
# Load Design #
# Use the SystemVerilog standard SV2012

read_verilog -golden -version sv2012 [subst {
    $design_path/16B/memory_wrapper_16_b1.sv
    $design_path/16B/SRAM.v
    $design_path/16B/bch_dec_decoder.sv
    $design_path/16B/bch_dec_encoder.sv

}]


####################
# Elaborate Design #
set_elaborate_option -golden -top memory_wrapper
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
#set_cut_signals {memory_wrapper.u_sram.din0 memory_wrapper.ecc_enc.data}

#cut_signals {memory_wrapper.u_sram.din0 memory_wrapper.ecc_enc.data}



read_sva -version sv2012 [subst {
    $property_path/16B/memory_wrapper_fv_16_1b.sv
}]


