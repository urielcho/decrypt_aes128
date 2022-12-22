source $::env(TIMING_ROOT)/env/common.tcl
source $::env(TIMING_ROOT)/env/caravel_spef_mapping-mpw7.tcl

if { [file exists $::env(CUP_ROOT)/env/spef-mapping.tcl] } {
    source $::env(CUP_ROOT)/env/spef-mapping.tcl
} else {
    puts "WARNING no user project spef mapping file found"
}

source $::env(TIMING_ROOT)/env/$::env(LIB_CORNER).tcl

set libs [split [regexp -all -inline {\S+} $libs]]
set verilogs [split [regexp -all -inline {\S+} $verilogs]]


foreach liberty $libs {
}

foreach liberty $libs {
    run_puts "read_liberty $liberty"
}

foreach verilog $verilogs {
    run_puts "read_verilog $verilog"
}

run_puts "link_design caravel"

if { $::env(SPEF_OVERWRITE) ne "" } {
    puts "overwriting spef from "
    puts "$spef to"
    puts "$::env(SPEF_OVERWRITE)"
    eval set spef $::env(SPEF_OVERWRITE)
}

set missing_spefs 0
set missing_spefs_list ""
run_puts "read_spef $spef"
foreach key [array names spef_mapping] {
    set spef_file $spef_mapping($key)
    if { [file exists $spef_file] } {
        run_puts "read_spef -path $key $spef_mapping($key)"
    } else {
        set missing_spefs 1
        set missing_spefs_list "$missing_spefs_list $key"
        puts "$spef_file not found"
        if { $::env(ALLOW_MISSING_SPEF) } {
            puts "WARNING ALLOW_MISSING_SPEF set to 1. continuing"
        } else {
            exit 1
        }
    }
}

set sdc $::env(CARAVEL_ROOT)/signoff/caravel/caravel.sdc
run_puts "read_sdc -echo $sdc"

set logs_path "$::env(PROJECT_ROOT)/signoff/caravel/openlane-signoff/timing/$::env(RCX_CORNER)/$::env(LIB_CORNER)"
file mkdir [file dirname $logs_path]


run_puts_logs "report_check_types \\
    -max_delay \\
    -min_delay \\
    -max_slew \\
    -max_capacitance \\
    -clock_gating_setup \\
    -clock_gating_hold \\
    -format end \\
    -violators" \
    "${logs_path}-summary.rpt"


set max_delay_result "met"
set min_delay_result "met"
set max_slew_result "met"
set max_cap_result "met"
set missing_spefs_result "incomplete"

set report ${logs_path}-summary.rpt

set max_cap_value "[exec bash -c "grep 'max cap' $report -A 4 | tail -n1 | awk -F '  *' '{print \$4}'"]"
set worst_hold "[exec bash -c "grep 'min_delay\/hold' $report -A 10 | grep VIOLATED | head -n1 | awk -F '  *' '{print \$5}'"]"
set worst_setup "[exec bash -c "grep 'max_delay\/setup' $report -A 10 | grep VIOLATED | head -n1 | awk -F '  *' '{print \$5}'"]"
set max_slew_value "[exec bash -c "grep 'max slew' $report -A 4 | tail -n1 | awk -F '  *' '{print \$4}'"]"

set table_format "%7s| %15s |%15s |%15s |%15s |%15s"
set header [format "$table_format" "corner" "max cap" "max slew" "min delay" "max delay" "spefs"]
if {![catch {exec grep -q {max cap} $report} err]} {
    set max_cap_result "vio($max_cap_value)"
}

if {![catch {exec grep -q {max slew} $report} err]} {
    set max_slew_result "vio($max_slew_value)"
}

if {![catch {exec grep -q {min_delay\/hold} $report} err]} {
    set min_delay_result "vio($worst_hold)"
}

if {![catch {exec grep -q {max_delay\/setup} $report} err]} {
    set max_delay_result "vio($worst_setup)"
}

if { !$missing_spefs } {
    set missing_spefs_result "complete"
}

set summary [format "$table_format" "$::env(LIB_CORNER)-$::env(RCX_CORNER)"\
    "$max_cap_result" \
    "$max_slew_result" \
    "$min_delay_result"\
    "$max_delay_result"\
    "$missing_spefs_result"]

exec echo "$header" >> "${logs_path}-summary.rpt"
exec echo "$summary" >> "${logs_path}-summary.rpt"


run_puts_logs "report_checks \\
    -path_delay min \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -group_count 10000 \\
    -slack_max 10 \\
    -digits 4 \\
    -endpoint_count 10 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-min.rpt"

run_puts_logs "report_checks \\
    -path_delay max \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -group_count 10000 \\
    -slack_max 10 \\
    -digits 4 \\
    -endpoint_count 10 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-max.rpt"

run_puts_logs "report_checks \\
    -path_delay min \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -path_group hk_serial_clk \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-hk_serial_clk-min.rpt"


run_puts_logs "report_checks \\
    -path_delay max \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -path_group hk_serial_clk \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-hk_serial_clk-max.rpt"

run_puts_logs "report_checks \\
    -path_delay max \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -path_group hkspi_clk \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-hkspi_clk-max.rpt"

run_puts_logs "report_checks \\
    -path_delay min \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -path_group hkspi_clk \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-hkspi_clk-min.rpt"

run_puts_logs "report_checks \\
    -path_delay min \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -path_group clk \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-clk-min.rpt"
        
run_puts_logs "report_checks \\
    -path_delay max \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -path_group clk \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-clk-max.rpt"

run_puts_logs "report_checks \\
    -path_delay min \\
    -through [get_cells soc] \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-soc-min.rpt"

run_puts_logs "report_checks \\
    -path_delay max \\
    -through [get_cells soc] \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -group_count 1000 \\
    -slack_max 10 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-soc-max.rpt"

run_puts_logs "report_checks \\
    -path_delay min \\
    -through [get_cells mprj] \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -group_count 1000 \\
    -slack_max 40 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-mprj-min.rpt"

run_puts_logs "report_checks \\
    -path_delay max \\
    -through [get_cells mprj] \\
    -format full_clock_expanded \\
    -fields {slew cap input_pins nets fanout} \\
    -no_line_splits \\
    -group_count 1000 \\
    -slack_max 40 \\
    -digits 4 \\
    -unique_paths_to_endpoint \\
    "\
    "${logs_path}-mprj-max.rpt"

run_puts "report_parasitic_annotation -report_unannotated > ${logs_path}-unannotated.log"
if { $missing_spefs } {
    puts "there are missing spefs. check the log for ALLOW_MISSING_SPEF"
    puts "the following macros don't have spefs"
    foreach spef $missing_spefs_list {
        puts "$spef"
    }
}
report_parasitic_annotation 


puts "you may want to edit sdc: $sdc to change i/o constraints"
puts "check $logs_path"
