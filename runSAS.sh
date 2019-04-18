#!/bin/bash

######################################################################################################################
#                                                                                                                    #
#     Program: runSAS.sh                                                                                             #
#                                                                                                                    #
#        Desc: This script can run a batch of (and monitor) SAS programs or SAS Data Integration (DI) jobs.          #
#            : The list of programs/jobs are provided as an input.                                                   #
#            : It is useful for SAS 9.x environments where a third-party job scheduler is not installed .            #
#                                                                                                                    #
#     Version: 6.1                                                                                                   #
#                                                                                                                    #
#        Date: 10/04/2019                                                                                            #
#                                                                                                                    #
#      Author: Prajwal Shetty D (all copyrights reserved)                                                            #
#                                                                                                                    #
#       Usage: The script has many invocation/execution modes:                                                       #
#                                                                                                                    #
#          [1] Non-Interactive mode------------------: ./runSAS.sh                                                   #
#          [2] Interactive mode----------------------: ./runSAS.sh -i                                                #
#          [3] Run-until mode------------------------: ./runSAS.sh -u  <name or index>                               #
#          [4] Run-from mode-------------------------: ./runSAS.sh -f  <name or index>                               #
#          [5] Run-a-job mode------------------------: ./runSAS.sh -o  <name or index>                               #
#          [6] Run-from-to-job mode------------------: ./runSAS.sh -t  <name or index> <name or index>               #
#          [7] Run-from-to-job-interactive mode------: ./runSAS.sh -s  <name or index> <name or index>               #
#          [8] Run-from-to-job-interactive-skip mode-: ./runSAS.sh -ss <name or index> <name or index>               #
#                                                                                                                    #
#  Dependency: SAS 9.x environment (Linux) with SAS BatchServer with XCMD is required for the script to work or      #
#              any equivalent (i.e. sas.sh, sasbatch.sh etc.) would work. The other dependencies are automatically   #
#              by the script during the runtime.                                                                     #
#                                                                                                                    #
######################################################################################################################

#------------------------USER CONFIGURATION: Set the parameters below as per the environment-------------------------#
#
# 1/3: Set the SAS 9.x environment parameters, setting the first parameter should work but amend as needed.
#
sas_app_root_directory="/SASInside/SAS/Lev1/SASApp"
sas_batch_server_root_directory="${sas_app_root_directory}/BatchServer"
sas_logs_root_directory="${sas_app_root_directory}/BatchServer/Logs"
sas_deployed_jobs_root_directory="${sas_app_root_directory}/SASEnvironment/SASCode/Jobs"
sas_batch_sh="sasbatch.sh"
#
# 2/3: Provide a list of SAS program(s) or SAS Data Integration Studio job(s), do not include ".sas" in the file name
#
cat <<EOF > .job.list
XXXXXXXXXXXXXXXXXXXXX
YYYYYYYYYYYYYYYYYYYYY
EOF
#
# 3/3: Change default behaviors, defaults have been set by the developer, change them as per the needs
#
run_in_debug_mode=N                     # Default is N, Y to turn on debugging mode
runtime_comparsion_routine=Y            # Default is Y, set this N to turn off job runtime checks
increase_in_runtime_factor=15           # Default is 15, this parameter is used in determining the runtime changes (to last successful run)
job_error_display_count=1               # Default is 1, this parameter will restrict the error log display to the x no. of error(s) in the log
job_error_display_steps=N               # Default is N, this parameter will show more details when a job fails, it can be a page long output
job_error_display_lines_around_count=1  # Default is 1, this parameter will allow you to increase or decrease how much is shown from the log
job_error_display_lines_around_mode=a   # Default is 'a', a=after error, b=before error, c=after & before (see grep modes)
kill_process_on_user_abort=Y            # Default is Y, the rogue processes are automatically killed by the script on user abort.
program_type_ext=sas                    # Default is sas
#
#--------------------------------------DO NOT CHANGE ANYTHING BELOW THIS LINE----------------------------------------#

#
# FUNCTIONS: User defined functions library
#
#------
# Name: display_welcome_ascii_banner()
# Desc: Displays a pretty ascii banner on script launch.
#   In: <NA>
#  Out: <NA>
#------
function display_welcome_ascii_banner(){
printf "\n${green}"
cat << "EOF"
+-+-+-+-+-+-+ +-+-+-+-+
|r|u|n|S|A|S| |v|6|.|1|
+-+-+-+-+-+-+ +-+-+-+-+
|P|r|a|j|w|a|l|S|D|
+-+-+-+-+-+-+-+-+-+
|S|A|S|
+-+-+-+
EOF
printf "\n${white}"
}
#------
# Name: set_colors_codes()
# Desc: Set different bash color codes, reference: https://misc.flogisoft.com/bash/tip_colors_and_formatting
#   In: <NA>
#  Out: <NA>
#------
function set_colors_codes(){
    red=$'\e[31m'
    green=$'\e[1;32m'
    yellow=$'\e[1;33m'
    blue=$'\e[1;34m'
    magenta=$'\e[1;35m'
    cyan=$'\e[1;36m'
    grey=$'\e[38;5;243m'
    white=$'\e[0m'
    end=$'\e[0m'
    red_bg=$'\e[41m'
    green_bg=$'\e[42m'
    blue_bg=$'\e[44m'
    yellow_bg=$'\e[43m'
    darkgrey_bg=$'\e[100m'
    blink=$'\e[5m'
    bold=$'\e[1m'
    italic=$'\e[3m'
    underline=$'\e[4m'
}
#------
# Name: display_post_banner_messages()
# Desc: Informational messages, printed post welcome banner
#   In: <NA>
#  Out: <NA>
#------
function display_post_banner_messages(){
    printf "${green}The script has many modes of execution, type ./runSAS.sh --help to see more details.${white}\n"
}
#------
# Name: check_dependencies()
# Desc: Check if the dependencies have been installed (auto install is supported only via yum for now)
#   In: program-name or package-name
#  Out: <NA>
#------
function check_dependencies(){
    package_installer=yum
    printf "${white}"
    check_dependency=`which $1`
    if [[ -z "$check_dependency" ]]; then
        printf "${red}\nERROR: Dependency checks failed, ${white}${red_bg}$1 program/pkg is not found${white}${red}, runSAS requires this package/program.\n"
        printf "${green}\nPress Y to install $1 (requires yum and sudo access) or press N to manually install this program/package: ${white}"
        read read_install_dependency
        if [[ "$read_install_dependency" == "Y" ]]; then
            printf "${white}Ok, attempting to install $1, running ${green}sudo yum install $1${white}...\n${white}"
            sudo $package_installer install $1
        else
            printf "${white}You can manually install this using yum, run ${green}sudo yum install $1${white} or download the $1 package from web (Goooooogle!)"
        fi
        clear_session_and_exit
    fi
}
#------
# Name: move_files_to_a_directory()
# Desc: Move files to a directory
#   In: filename, directory-name
#  Out: <NA>
#------
function move_files_to_a_directory(){
    if [ `ls -1 $1 2>/dev/null | wc -l` -gt 0 ]; then
      mv -f $1 $2
    fi
}
#------
# Name: check_if_the_dir_exists()
# Desc: Check if the directory exists
#   In: mode, directory-name
#  Out: <NA>
#------
function check_if_the_dir_exists(){
    if [[ ! -d "$2" ]]; then
        printf "${red}ERROR: Directory ${white}${red_bg}$2${white}${red} was not found in the server, make sure you have correctly set the script parameters as per the environment.${white}"
        clear_session_and_exit
    fi
}
#------
# Name: check_if_logged_in_user_is_root()
# Desc: User login check
#   In: <NA>
#  Out: <NA>
#------
function check_if_logged_in_user_is_root(){
    if [[ "$EUID" -eq 0 ]]; then
        printf "${yellow}\nWARNING: Typically you have to launch this script as a installation user such as ${green}sas${yellow} or any user that has batch execution privileges, you are currently logged in as ${red}root. ${white}"
        printf "${yellow}Press ENTER key to ignore this warning and continue...${white}"
        read -s < /dev/tty
        printf "\n"
    fi
}
#------
# Name: run_in_interactive_mode_check()
# Desc:  Interactive mode (-i)
#   In: <NA>
#  Out: <NA>
#------
function run_in_interactive_mode_check(){
    if [[ "$script_mode" == "-i" ]]; then
        interactive_mode=1
        printf "${red_bg}Press ENTER key to continue...${white}"
        stty -igncr < /dev/tty
        read -s < /dev/tty
        printf "\n"
    else
        interactive_mode=0
    fi
}
#------
# Name: run_until_a_job_mode_check()
# Desc: Run until mode (-u)
#   In: <NA>
#  Out: <NA>
#------
function run_until_a_job_mode_check(){
    if [[ "$script_mode" == "-u" ]]; then
        if [[ "$script_mode_value" == "0" ]]; then
            printf "${red}ERROR: You launched the script in -u (run-until-a-job) mode, a job name is also required after -u option.${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value" == "$local_sas_job" ]]; then
                run_until_mode=1
            else
                if  [[ $run_until_mode -ge 1 ]]; then
                    run_until_mode=2
                else
                    run_until_mode=0
                fi
            fi
        fi
    else
        run_until_mode=1 # Just so that this doesn't trigger for other modes
    fi
}
#------
# Name: run_from_a_job_mode_check()
# Desc: Run from a job mode (-f)
#   In: <NA>
#  Out: <NA>
#------
function run_from_a_job_mode_check(){
    if [[ "$script_mode" == "-f" ]]; then
        if [[ "$script_mode_value" == "0" ]]; then
            printf "${red}ERROR: You launched the script in -f(run-from-a-job) mode, a job name is also required after -f option.${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value" == "$local_sas_job" ]]; then
                run_from_mode=1
            fi
        fi
    else
        run_from_mode=1 # Just so that this doesn't trigger for other modes
    fi
}
#------
# Name: run_a_single_job_mode_check()
# Desc: Run a single job mode (-o)
#   In: <NA>
#  Out: <NA>
#------
function run_a_single_job_mode_check(){
    if [[ "$script_mode" == "-o" ]]; then
        if [[ "$script_mode_value" == "0" ]]; then
            printf "${red}ERROR: You launched the script in -o(run-a-single-job) mode, a job name is also required after -o option.${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value" == "$local_sas_job" ]]; then
                run_a_job_mode=1
            else
                run_a_job_mode=0
            fi
        fi
    else
        run_a_job_mode=1 # Just so that this doesn't trigger for other modes
    fi
}
#------
# Name: run_from_to_job_mode_check()
# Desc: Run from a job to a job mode (-t)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_mode_check(){
    if [[ "$script_mode" == "-t" ]]; then
        if [[ "$script_mode_value" == "0" ]] || [[ "$script_mode_value_other" == "0" ]]; then
            printf "${red}ERROR: You launched the script in -t(run-from-to-job) mode, two job names (separated by spaces) are also required after -t option.${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value" == "$local_sas_job" ]]; then
                run_from_to_job_mode=1
            else
                if [[ "$script_mode_value_other" == "$local_sas_job" ]]; then
                    run_from_to_job_mode=2
                else
                    if  [[ $run_from_to_job_mode -eq 1 ]]; then
                        run_from_to_job_mode=1
                    else
                        if [[ $run_from_to_job_mode -eq 2 ]]; then
                            run_from_to_job_mode=0
                        fi
                    fi
                fi
            fi
        fi
    else
        run_from_to_job_mode=1
    fi
}
#------
# Name: run_from_to_job_interactive_mode_check()
# Desc: Run from a job to a job mode in interactive mode (-s)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_interactive_mode_check(){
    if [[ "$script_mode" == "-s" ]]; then
        if [[ "$script_mode_value" == "0" ]] || [[ "$script_mode_value_other" == "0" ]]; then
            printf "${red}ERROR: You launched the script in -s(run-from-to-job-interactive) mode, two job names (separated by spaces) are also required after -s option.${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value" == "$local_sas_job" ]]; then
                run_from_to_job_interactive_mode=1
            else
                if [[ "$script_mode_value_other" == "$local_sas_job" ]]; then
                    run_from_to_job_interactive_mode=2
                else
                    if  [[ $run_from_to_job_interactive_mode -eq 1 ]]; then
                        run_from_to_job_interactive_mode=1
                    else
                        if [[ $run_from_to_job_interactive_mode -eq 2 ]]; then
                            run_from_to_job_interactive_mode=0
                        fi
                    fi
                fi
            fi
        fi
    else
        run_from_to_job_interactive_mode=-1
    fi
}
#------
# Name: run_from_to_job_interactive_skip_mode_check()
# Desc: Run from a job to a job mode in interactive mode (-ss)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_interactive_skip_mode_check(){
    if [[ "$script_mode" == "-ss" ]]; then
        if [[ "$script_mode_value" == "0" ]] || [[ "$script_mode_value_other" == "0" ]]; then
            printf "${red}ERROR: You launched the script in -ss(run-from-to-job-interactive-skip) mode, two job names (separated by spaces) are also required after -ss option.${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value" == "$local_sas_job" ]]; then
                run_from_to_job_interactive_skip_mode=1
            else
                if [[ "$script_mode_value_other" == "$local_sas_job" ]]; then
                    run_from_to_job_interactive_skip_mode=2
                else
                    if  [[ $run_from_to_job_interactive_skip_mode -eq 1 ]]; then
                        run_from_to_job_interactive_skip_mode=1
                    else
                        if [[ $run_from_to_job_interactive_skip_mode -eq 2 ]]; then
                            run_from_to_job_interactive_skip_mode=0
                        fi
                    fi
                fi
            fi
        fi
    else
        run_from_to_job_interactive_skip_mode=3
    fi
}
#------
# Name: terminate_running_processes()
# Desc: Terminate the proces
#   In: pid
#  Out: <NA>
#------
function terminate_running_processes(){
    if [[ ! -z ${1} ]]; then
        if [[ ! -z `ps -p $1 -o comm=` ]]; then
            if [[ "$kill_process_on_user_abort" ==  "Y" ]]; then
                printf "${yellow}---\n"
                ps $1 # Show process details
                printf "${yellow}---\n${white}"
                kill -9 $1
                sleep 2
                if [[ -z `ps -p $1 -o comm=` ]]; then
                    printf "${green}The last job process with $1 has been terminated successfully!\n\n${white}"
                else
                    printf "${red}ERROR: Attempt to kill the last job process with pid $1 did not go very well. It is likely to be the permission issue (sudo?) or the process has terminated already.\n\n${white}"
                fi
            else
                printf "${yellow}WARNING: The last process $1 is still running in the background, terminate it manually using ${green}kill -9 $1${white} command.\n\n${white}"
            fi
        fi
    fi
}
#------
# Name: check_if_there_are_any_running_jobs()
# Desc: Check if there are any rogue processes, display a warning and abort the script based on the user input
#   In: <NA>
#  Out: <NA>
#------
function check_if_there_are_any_running_jobs(){
    process_srch_str=`echo "$sas_logs_root_directory" | sed "s/^.\(.*\)/[\/]\1/"`
    if [ `ps -ef | grep $process_srch_str | wc -l` -gt 0 ]; then
        printf "${yellow}\nWARNING: There is a server process that has not completed/terminated, proceeding without terminating these processes may cause issues in current run.\n${white}"
        printf "${yellow}---\n${green}"
        ps -ef | grep $process_srch_str
        printf "${yellow}---\n\n${white}"
        printf "${yellow}Do you want to ignore this and continue...? (Press N to abort) ${white}"
        read ignore_process_warning
        if [[ "$ignore_process_warning" == "N" ]]; then
            printf "${red}Terminated by the user.${white}"
            clear_session_and_exit
        fi
    fi
}
#------
# Name: print_to_console_debug_only()
# Desc: Prints more details to console if the debug mode is turned on
#   In: <NA>
#  Out: <NA>
#------
function print_to_console_debug_only(){
    if [[ "$run_in_debug_mode" == "Y" ]]; then
        printf "${!debug_console_print_color}DEBUG - $1: $2\n${white}"
        session_variables_array=`compgen -v`
        printf "${!debug_console_print_color}-----------------------------${white}\n"
        for session_variable_name in $session_variables_array; do
            printf "${!debug_console_print_color}${green}$session_variable_name${white} is set to ${green}${!session_variable_name}\n${white}"
        done
        printf "${!debug_console_print_color}-----------------------------\n\n${white}"
    fi
    printf "${white}"
}
#------
# Name: display_progressbar_with_offset()
# Desc: Calculates the progress bar parameters (https://en.wikipedia.org/wiki/Block_Elements#Character_table & https://www.rapidtables.com/code/text/unicode-characters.html, alternative: █)
#   In: steps-completed, total-steps, offset
#  Out: <NA>
#------
function display_progressbar_with_offset(){
    # Defaults
    progressbar_width=20
    progressbar_green_unicode_char=▬
    progressbar_grey_unicode_char=▬
    progressbar_sleep_interval_in_secs=0.5

    # Passed parameters
    progressbar_steps_completed=$1
	progressbar_total_steps=$2
    progressbar_offset=$3

    # Calculate the scale
    let progressbar_scale=100/$progressbar_width

	# Calculate the perecentage completed
    progress_bar_pct_completed=`bc <<< "scale = 0; ($progressbar_steps_completed + $progressbar_offset) * 100 / $progressbar_total_steps / $progressbar_scale"`

    # Reset if the variable goes beyond the boundary values
    if [[ $progress_bar_pct_completed -lt 0 ]]; then
        progress_bar_pct_completed=0
    fi

    progress_bar_pct_remaining=`bc <<< "scale = 0; $progressbar_width-$progress_bar_pct_completed"`

    # Reset if the variable goes beyond the boundary values
    if [[ "$progress_bar_pct_remaining" == "" ]] || [[ $progress_bar_pct_remaining -lt 0 ]]; then
        progress_bar_pct_remaining=$progressbar_width
    fi

    # Show the completed "green" block
    if [[ $progress_bar_pct_completed -ne 0 ]]; then
        printf "${green}"
        printf "%0.s$progressbar_green_unicode_char" $(seq 1 $progress_bar_pct_completed)
    fi

    # Show the remaining "grey" block
    if [[ $progress_bar_pct_remaining -ne 0 ]]; then
        printf "${grey}"
        printf "%0.s$progressbar_grey_unicode_char" $(seq 1 $progress_bar_pct_remaining)
    fi

    # Delay
    printf "${white}"
    sleep $progressbar_sleep_interval_in_secs

    # Reset the console, backspacing operation defined by the length of the progress bar.
    for (( i=1; i <= $progressbar_width; i++ )); do
        printf "\b"
    done
}
#------
# Name: store_job_runtime_stats()
# Desc: Capture job runtime stats, single version of history is kept per job
#   In: jobname, total-time-taken-by-job, logname
#  Out: <NA>
#------
function store_job_runtime_stats(){
    sed -i "/$1/d" $job_stats_file # Remove the previous entry
    echo "$1 $2 $3 `date '+%Y-%m-%d %H:%M:%S'`" >> $job_stats_file # Add a new entry
}
#------
# Name: get_job_hist_runtime_stats()
# Desc: Check job runtimes for the last batch run
#   In: jobname
#  Out: <NA>
#------
function get_job_hist_runtime_stats(){
    hist_job_runtime=`awk -v pat="$1" -F" " '$0~pat { print $2 }' $job_stats_file`
}
#------
# Name: write_current_job_details_on_screen()
# Desc: Print details about the currently running job on the console
#   In: jobname
#  Out: <NA>
#------
function write_current_job_details_on_screen(){
    printf "${white}Job ${white}"
    printf "%02d" $job_counter_for_display
    printf "${white} of $total_no_of_jobs_counter${white}: ${darkgrey_bg}$1${white} is running ${white}"
}
#------
# Name: write_skipped_job_details_on_screen()
# Desc: Show the skipped job details
#   In: jobname
#  Out: <NA>
#------
function write_skipped_job_details_on_screen(){
    printf "${grey}Job ${grey}"
    printf "%02d" $job_counter_for_display
    printf "${grey} of $total_no_of_jobs_counter: $1 has been skipped.\n${white}"
}
#------
# Name: get_the_job_name_in_the_list()
# Desc: Get the jobname when user inputs a number/index (from the list)
#   In: jobname
#  Out: <NA>
#------
function get_the_job_name_in_the_list(){
    job_name_from_the_list=`sed -n "${1}p" .job.list`
    if [[ -z $job_name_from_the_list ]]; then
        printf "${red}ERROR: Job index overflow, no job found in the job list at $1. Please review the specified job number/index is correct and within the provided list.${white}"
        clear_session_and_exit
    else
        printf "${white}Job ${darkgrey_bg}$job_name_from_the_list${white} has been selected from the job list at $1.${white}\n"
    fi
}
#------
# Name: clear_session_and_exit()
# Desc: Resets the terminal
#   In: <NA>
#  Out: <NA>
#------
function clear_session_and_exit(){
    printf "${white}\n\n${white}"
    stty -igncr < /dev/tty
    setterm -cursor on
    if [[ $interactive_mode == 1 ]]; then
        reset
    fi
    terminate_running_processes $job_pid
    printf "${green}runSAS is existing now, session has been cleared.${white}\n\n"
    exit 1
}
#------
# Name: get_current_cursor_position()
# Desc: Get the current cursor position, reference: https://stackoverflow.com/questions/2575037/how-to-get-the-cursor-position-in-bash
#   In: <NA>
#  Out: cursor_row_pos, cursor_col_pos
#------
function get_current_cursor_position() {
    local pos
    IFS='[;' read -p < /dev/tty $'\e[6n' -d R -a pos -rs || echo "cursor position routine failed with error: $? ; ${pos[*]}"
    cursor_row_pos=${pos[1]}
    cursor_col_pos=${pos[2]}
}
#------
# Name: remove_a_line_from_file()
# Desc: Remove a line from a file
#   In: string, filename
#  Out: <NA>
#------
function remove_a_line_from_file(){
	sed -e "s/$1//" -i $2
}
#------
# Name: backup_directory()
# Desc: Backup a directory to a folder as tar zip with timestamp (filename_YYYYMMDD.tar.gz)
#   In: source-dir, target-dir, target-zip-file-name
#  Out: <NA>
#------
function backup_directory(){
	curr_timestamp=`date +%Y%m%d`
	tar -zcf $2/$3_${curr_timestamp}.tar.gz $1
}
#------
# Name: runSAS()
# Desc: This function implements the SAS job execution routine, quite an important one
#   In: (1) A SAS deployed job name (e.g: 99_Execute_Scoring_Component_Graph)
#       (2) SAS BatchServer directory name (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer)
#       (3) SAS BatchServer shell script (e.g.: sasbatch.sh)
#       (4) SAS BatchServer logs directory (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer/logs)
#       (5) SAS deployed jobs directory  (e.g.: /SASInside/SAS/Lev1/SASApp/SASEnvironment/SASCode/Jobs)
#  Out: <NA>
#------
function runSAS(){
    # Reset the return code
    job_rc=0

    # Increment the job counter for console display
    let job_counter_for_display+=1

    # Capture job runtimes
    start_datetime_of_job=`date +%s`

    # Set defaults if nothing is specified (i.e. just a job name is specified)
    local_sas_job="$1"
    local_sas_batch_server_root_directory="${2:-$sas_batch_server_root_directory}"
    local_sas_batch_sh="${3:-$sas_batch_sh}"
    local_sas_logs_root_directory="${4:-$sas_logs_root_directory}"
    local_sas_deployed_jobs_root_directory="${5:-$sas_deployed_jobs_root_directory}"

    # Run all the jobs post specified job (including that specified job)
    run_from_a_job_mode_check
    if [[ "$run_from_mode" -ne "1" ]]; then
        write_skipped_job_details_on_screen $1
        continue
    fi

    # Run a single job
    run_a_single_job_mode_check
    if [[ "$run_a_job_mode" -ne "1" ]]; then
        write_skipped_job_details_on_screen $1
        continue
    fi

    # Run until a job mode: The script will run everything (including) until the specified job
    run_until_a_job_mode_check
    if [[ "$run_until_mode" -gt "1" ]]; then
        write_skipped_job_details_on_screen $1
        continue
    fi

    # Run from a job to another job (including the specified jobs)
    run_from_to_job_mode_check
    if [[ "$run_from_to_job_mode" -lt "1" ]]; then
        write_skipped_job_details_on_screen $1
        continue
    fi

    # Run from a job to another job in interactive (including the specified jobs)
    run_from_to_job_interactive_mode_check

    # Run from a job to another job (including the specified jobs)
    run_from_to_job_interactive_skip_mode_check
    if [[ "$run_from_to_job_interactive_skip_mode" -lt "1" ]]; then
        write_skipped_job_details_on_screen $1
        continue
    fi

    # Display current job details on console, jobname is passed to the function
    write_current_job_details_on_screen $1

    # Each job is launched as a separate process (i.e each has a PID), the script monitors the log and waits for the process to complete.
    nice -n 20 $local_sas_batch_server_root_directory/$local_sas_batch_sh -log $local_sas_logs_root_directory/${local_sas_job}_#Y.#m.#d_#H.#M.#s.log \
                                                                          -batch \
                                                                          -noterminal \
                                                                          -logparm "rollover=session" \
                                                                          -sysin $local_sas_deployed_jobs_root_directory/$local_sas_job.$program_type_ext &

    # Count the no. of steps in the job
    total_no_of_steps_in_a_job=`grep -o 'Step:'  $local_sas_deployed_jobs_root_directory/$local_sas_job.sas | wc -l`

    # Get the PID details
    job_pid=$!
    pid_progress_counter=1
    printf "${white}with pid $job_pid${white}"
    ps cax | grep $job_pid > /dev/null
    printf "${white} ${green}"

    # Random sleep for pid fetch
    sleep 0.5

    # Get the current job log filename (absolute path)
    current_log_name=`ls -tr $sas_logs_root_directory | tail -1`

    # Show current status of the run, poll for the PID and display the progress bar.
    while [ $? -eq 0 ]; do
        # Disable carriage return (ENTER key) during the script run
        stty igncr < /dev/tty

        # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
        no_of_steps_completed_in_log=`grep -o 'Step:'  $sas_logs_root_directory/$current_log_name | wc -l`
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job -1

        # Get runtime stats of the job
        if [[ "$runtime_comparsion_routine" == "Y" ]]; then
            get_job_hist_runtime_stats $local_sas_job
        else
            hist_job_runtime=0
        fi
        hist_job_runtime_for_current_job="${hist_job_runtime:-0}"

        # Check if the runtime is exceeding the given factor
        if [[ "$hist_job_runtime_for_current_job" -gt "0" ]]; then
            # Multiply the factor and see if the runtime is exceeding the runtime
            let hist_job_runtime_for_current_job_x_factor=$hist_job_runtime_for_current_job*$increase_in_runtime_factor
            current_end_datetime_of_job=`date +%s`
            let current_runtime_of_job=$current_end_datetime_of_job-$start_datetime_of_job
            # If the runtimes are higher by the given factor show the warning
            if [[ "$current_runtime_of_job" -gt "$hist_job_runtime_for_current_job_x_factor" ]]; then
                if [[ "$long_running_job_msg_shown" == "0" ]]; then
                    printf "${red}\nNOTE: The job is taking a bit more time than usual (previously it took $hist_job_runtime secs, it is $current_runtime_of_job secs already), Press ENTER key to continue or CTRL+C to abort this run.${white}"
                    printf "${red}\nNOTE: You can remove these warnings by setting the increase_in_runtime_factor parameter to a high value such as 999${white}"
                    stty -igncr < /dev/tty
                    read -s < /dev/tty
                    stty igncr < /dev/tty
                    long_running_job_msg_shown=1
                    printf "${white}\n${white}"
                    # Resume the run by displaying the last job run (note that the job wasn't terminated when the warning was shown)
                    write_current_job_details_on_screen $1
                fi
            fi
        fi

        # Get the PID again for the next iteration
        ps cax | grep $job_pid > /dev/null
    done

    # Suppress unwanted lines in the log
    remove_a_line_from_file "ERROR: Errors printed on pages" "$sas_logs_root_directory/$current_log_name"

    # Check if there are any errors in the logs
    let job_error_display_count_for_egrep=job_error_display_count+1
    grep -m${job_error_display_count} "$check_for_error_string" $sas_logs_root_directory/$current_log_name > $tmp_log_file
    egrep -m${job_error_display_count_for_egrep} -E --color "* $check_for_step_string|$check_for_error_string" -$job_error_display_lines_around_mode$job_error_display_lines_around_count $sas_logs_root_directory/$current_log_name > $tmp_log_w_steps_file

    if [ -s $tmp_log_file ]; then
        job_rc=900
    else
        job_rc=$?
    fi

    # Check return code, abort if there's an error
    if [ $job_rc -gt 4 ]; then
        # Find the last job that ran on getting an error (there can be many jobs within a job in the world of SAS)
        sed -n '1,/^ERROR:/ p' $sas_logs_root_directory/$current_log_name | sed 's/Job:             Sngl Column//g' | grep "Job:" | tail -1 > $job_that_errored_file

        # Format the job name for display
        sed -i 's/  \+/ /g' $job_that_errored_file
        sed -i 's/^[1-9][0-9]* \* Job: //g' $job_that_errored_file
        sed -i 's/[A0-Z9]*\.[A0-Z9]* \*//g' $job_that_errored_file

        # Print error(s)
        printf "\b${white}$print_msg_separator${red}(ERROR rc=$job_rc, see the errors below)${white}\n"
        printf "${red}$log_block_wrapper${white}\n"

        # Depending on user setting show the log details
        if [[ "$job_error_display_steps" == "Y" ]]; then
            printf "%s" "$(<$tmp_log_w_steps_file)"
        else
            printf "%s" "$(<$tmp_log_file)"
        fi

        printf "\n${red}$log_block_wrapper${white}\n"

        # Print last job
        printf "${red}Job: ${red}"
        printf "%s" "$(<$job_that_errored_file)"

        # Print the log filename
        printf "\n${white}${white}"
        printf "${red}Log: ${red}$sas_logs_root_directory/$current_log_name${white}\n"
        printf "${red}$log_block_wrapper${white}"
        clear_session_and_exit
    else
        # Complete the progress bar with offset 0 (fill the last bit after the step is complete)
        # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
        no_of_steps_completed_in_log=`grep -o 'Step:'  $sas_logs_root_directory/$current_log_name | wc -l`
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job 0

        # Capture job runtimes
        end_datetime_of_job=`date +%s`

        # Store the stats for the next time
        store_job_runtime_stats $local_sas_job $((end_datetime_of_job-start_datetime_of_job)) $current_log_name

        # Fetch cursor position and populate the fillers
        get_current_cursor_position
        buff_to_fix_col=$((filler_col_begin_pos-cursor_col_pos))
        printf "\b"
        for (( k=1; k <= $buff_to_fix_col; k++ )); do
            printf "$filler_char"
        done

        # Success message
        printf "\b${white}${green}(DONE rc=$job_rc, it took "
        printf "%03d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs. Completed on `date '+%Y-%m-%d %H:%M:%S'`)${white}\n"
    fi

    # Forece to run in interactive mode if in run-from-to-job-interactive (-s) mode
    if [[ "$run_from_to_job_interactive_mode" -ge "1" ]]; then
        script_mode="-i"
        run_in_interactive_mode_check
        script_mode="-s"
    fi

    # Forece to run in interactive mode if in run-from-to-job-interactive (-s) mode
    if [[ "$run_from_to_job_interactive_skip_mode" -eq "1" ]] || [[ "$run_from_to_job_interactive_skip_mode" -eq "2" ]]; then
        script_mode="-i"
        run_in_interactive_mode_check
        script_mode="-ss"
    fi

    # Interactive mode: Allow the script to pause and wait for the user to press a key to continue (useful during training)
    run_in_interactive_mode_check
}

#
# BEGIN: The script execution begins from here
#

# Bash color codes for the console
set_colors_codes

# System parameters
print_msg_separator=.......
check_for_error_string="^ERROR"
check_for_step_string="Step:"
debug_console_print_color=white
filler_col_begin_pos=100
filler_char=.
log_block_wrapper=-----
specify_job_number_length_limit=3
check_for_dependencies=Y

# Files
job_stats_file=.job.stats
tmp_log_file=.tmp.log
tmp_log_w_steps_file=.tmp_s.log
job_that_errored_file=.errored_job.log

# Initialization
job_counter_for_display=0
long_running_job_msg_shown=0
total_no_of_jobs_counter=`cat .job.list | wc -l`

# Parameters passed to this script at the time of invocation (modes etc.), set the default to 0
script_mode="${1:-0}"
script_mode_value="${2:-0}"
script_mode_value_other="${3:-0}"

# Capture runtimes
start_datetime_of_session=`date +%s`

# Help menu (invoked via ./runSAS.sh --help)
if [[ ${#@} -ne 0 ]] && [[ "${@#"--help"}" = "" ]]; then
    printf "${blue}"
    printf "${underline}"
    printf "\nNAME"
    printf "${end}${blue}"
    printf "\n       runSAS.sh                 The script will run (and monitor) SAS Data Integration (DI) job(s) in a specified order"
    printf "${underline}"
    printf "\nSYNOPSIS"
    printf "${end}${blue}"
    printf "\n       runSAS.sh [script-mode] [script-mode-value]"
    printf "${underline}"
    printf "\nDESCRIPTION"
    printf "${end}${blue}"
    printf "\n       -i                        The script will halt after running each job, waiting for an ENTER key to continue"
    printf "\n       -u  <job-name>            The script will run everything (and including) until the specified job.t"
    printf "\n       -f  <job-name>            The script will run from (and including) a specified job."
    printf "\n       -o  <job-name>            The script will run a specified job."
    printf "\n       -t  <job-name> <job-name> The script will run from one job to the other job."
    printf "\n       -s  <job-name> <job-name> The script will run from one job to the other job, but in an interactive mode (runs the rest in a non-interactive mode)"
    printf "\n       -ss <job-name> <job-name> The script will run from one job to the other job, but in an interactive mode (skips the rest in a non-interactive mode)"
    printf "\n       --help                    Display this help and exit"
    printf "\n"
    printf "\nTip:   You can use <job-number> instead of <job-name> in the above modes (e.g.: ./runSAS.sh -f 1 3)"
    printf "${underline}"
    printf "\nAUTHOR"
    printf "${end}${blue}"
    printf "\n       Written by Prajwal Shetty D"
    printf "${underline}"
    printf "\nBUGS"
    printf "${end}${blue}"
    printf "\n       Report bug(s) to neoprajwal@sas.com\n\n"
    printf "${white}"
    exit 0;
fi;

# Welcome banner
display_welcome_ascii_banner

# Dependency checks
if [[ "$check_for_dependencies" == "Y" ]]; then
    check_dependencies ksh
    check_dependencies bc
    check_dependencies grep
    check_dependencies egrep
    check_dependencies awk
    check_dependencies sed
    check_dependencies sleep
    check_dependencies ps
    check_dependencies kill
    check_dependencies nice
fi

# Check if the directory and file exists (specified by the user as configuration)
check_if_the_dir_exists -d $sas_app_root_directory
check_if_the_dir_exists -d $sas_batch_server_root_directory
check_if_the_dir_exists -d $sas_logs_root_directory
check_if_the_dir_exists -d $sas_deployed_jobs_root_directory

# Information for the user
display_post_banner_messages

# Housekeeping
if [[ ! -f $job_stats_file ]]; then
  touch $job_stats_file
fi
move_files_to_a_directory $sas_logs_root_directory/*.log $sas_logs_root_directory/archives

# Print session details on console
printf "\n${white}The script was launched (in a "${1:-'non-interactive'}" mode) with pid ${green}$$${white} on ${green}$HOSTNAME${white} at `date '+%Y-%m-%d %H:%M:%S'` by ${white}"
printf '%s' ${green}"${SUDO_USER:-$USER}${white}"
printf "${white} user\n${white}"

# Print job(s) list on console
printf "\n${white}There are $total_no_of_jobs_counter jobs in the list:${white}\n"
printf "${white}---${white}\n"
awk '{printf("%02d) %s\n", NR, $0)}' .job.list
printf "${white}---${white}\n"

# Check for CTRL+C and clear the session
trap clear_session_and_exit INT

# Show a warning if logged in user is root (typically "sas" must be the user for running a jobs)
check_if_logged_in_user_is_root

# Check if there are rogue processes from last run, show the warning.
check_if_there_are_any_running_jobs

# Check if the user has specified a job number instead of a name (pick the relevant from the list) in any of the modes
if [[ ${#@} -ne 0 ]] && [[ "$script_mode" != "0" ]]; then
    if [[ "$script_mode_value" != "0" ]] && [[ ${#script_mode_value} -lt $specify_job_number_length_limit ]]; then
        printf "\n"
        get_the_job_name_in_the_list $script_mode_value
        script_mode_value=$job_name_from_the_list
    fi
    if [[ "$script_mode_value_other" != "0" ]] && [[ ${#script_mode_value_other} -lt $specify_job_number_length_limit ]]; then
        get_the_job_name_in_the_list $script_mode_value_other
        script_mode_value_other=$job_name_from_the_list
    fi
fi

# Debug mode
print_to_console_debug_only "runSAS session variables"

# Hide the cursor
setterm -cursor off

# Run the jobs from the list one at a time
while read job; do
    runSAS $job
done < .job.list

# Capture session runtimes
end_datetime_of_session=`date +%s`

# Tidying up
rm -rf $tmp_log_file $job_that_errored_file

# Print a final message on console
printf "\n${green}The batch run completed on `date '+%Y-%m-%d %H:%M:%S'` and took a total of $((end_datetime_of_session-start_datetime_of_session)) secs to complete.${white}"

# END: Clear the session, reset the console
clear_session_and_exit
