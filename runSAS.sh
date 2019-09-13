#!/bin/bash
#
######################################################################################################################
#                                                                                                                    #
#     Program: runSAS.sh                                                                                             #
#                                                                                                                    #
#        Desc: The script can run and monitor SAS Data Integration Studio jobs.                                      #
#                                                                                                                    #
#     Version: 10.6                                                                                                  #
#                                                                                                                    #
#        Date: 13/09/2019                                                                                            #
#                                                                                                                    #
#      Author: Prajwal Shetty D                                                                                      #
#                                                                                                                    #
#       Usage: The script has many invocation modes:                                                                 #
#                                                                                                                    #
#              [1] Non-Interactive mode (default)--------: ./runSAS.sh                                               #
#              [2] Interactive mode----------------------: ./runSAS.sh -i                                            #
#              [3] Run-a-job mode------------------------: ./runSAS.sh -j    <name or index>                         #
#              [4] Run-upto mode-------------------------: ./runSAS.sh -u    <name or index>                         #
#              [5] Run-from mode-------------------------: ./runSAS.sh -f    <name or index>                         #
#              [6] Run-a-single-job mode-----------------: ./runSAS.sh -o    <name or index>                         #
#              [7] Run-from-to-job mode------------------: ./runSAS.sh -fu   <name or index> <name or index>         #
#              [8] Run-from-to-job-interactive mode------: ./runSAS.sh -fui  <name or index> <name or index>         #
#              [9] Run-from-to-job-interactive-skip mode-: ./runSAS.sh -fuis <name or index> <name or index>         #
#                                                                                                                    #
#              For more details, see https://github.com/PrajwalSD/runSAS/blob/master/README.md                       #
#                                                                                                                    #
#  Dependency: SAS 9.x (Linux) environment with SAS BatchServer (or an equivalent) is required at minimum with bash. #
#              The other minor dependencies are automatically checked by the script during the runtime.              #
#                                                                                                                    #
#      Github: https://github.com/PrajwalSD/runSAS (Grab the latest version automatically: ./runSAS.sh --update)     #
#                                                                                                                    #
######################################################################################################################
#<
#------------------------USER CONFIGURATION: Set the parameters below as per the environment-------------------------#
#
# 1/4: Set SAS 9.x environment related parameters.
#      Ideally, setting just the first two parameters should work but amend the rest if needed as per the environment
#      Always enclose the value with double-quotes (NOT single-quotes)
#
sas_installation_root_directory="/SASInside/SAS/"
sas_app_server_name="SASApp"
sas_lev="Lev1"
sas_default_sh="sasbatch.sh"
sas_app_root_directory="$sas_installation_root_directory/$sas_lev/$sas_app_server_name"
sas_batch_server_root_directory="$sas_app_root_directory/BatchServer"
sas_logs_root_directory="$sas_app_root_directory/BatchServer/Logs"
sas_deployed_jobs_root_directory="$sas_app_root_directory/SASEnvironment/SASCode/Jobs"
#
# 2/4: Provide a list of SAS program(s) or SAS Data Integration Studio deployed job(s).
#      Do not include ".sas" in the name.
#      You can optionally add "--prompt" after the job to halt/pause the run, --skip to skip the job run, and --server to override default app server parameters
#
cat << EOF > .job.list
XXXXX --prompt
YYYYY
EOF
#
# 3/4: Script behaviors, defaults should work just fine but amend as per the environment needs.
#
run_in_debug_mode=N                                                     # Default is N        ---> Set this to Y to turn on debugging mode.
runtime_comparsion_routine=N                                            # Default is Y        ---> Set this N to turn off job runtime checks.
increase_in_runtime_factor=50                                           # Default is 50       ---> This is used in determining the runtime changes between runs (to a last successful run only).
job_error_display_count=1                                               # Default is 1        ---> This will restrict the error log display to the x no. of error(s) in the log.
job_error_display_steps=N                                               # Default is N        ---> This will show more details when a job fails, it can be a page long output.
job_error_display_lines_around_count=1                                  # Default is 1        ---> This will allow you to increase or decrease how much is shown from the log.
job_error_display_lines_around_mode=a                                   # Default is a        ---> These are grep arguements, a=after error, b=before error, c=after & before.
kill_process_on_user_abort=Y                                            # Default is Y        ---> The rogue processes are automatically killed by the script on user abort.
program_type_ext=sas                                                    # Default is sas      ---> Do not change this. 
check_for_error_string="^ERROR"                                         # Default is "^ERROR" ---> Change this to the locale setting.
check_for_step_string="Step:"                                           # Default is "Step:"  ---> Change this to the locale setting.
enable_runsas_run_history=Y                                             # Default is N        ---> Set to Y to capture runSAS run history
abort_on_error=N                                                        # Default is N        ---> Set to Y to abort as soon as runSAS sees an ERROR in the log file (i.e don't wait for the job to complete)
#
# 4/4: Email alerts, set the first parameter to N to turn off this feature.
#      Uses "sendmail" program to send email. 
#      If you don't receive emails from the server, add <logged-in-user>@<server-full-name> (e.g.: sas@sasserver.demo.com) to your email client whitelist.
#
email_alerts=N                                  	                    # Default is N        ---> "Y" to enable all 4 alert types (YYYY is the extended format, <trigger-alert><job-alert><error-alert><completion-alert>)
email_alert_to_address=""                                               # Default is ""       ---> Provide email addresses separated by a semi-colon
email_alert_user_name="runSAS"                                          # Default is "runSAS" ---> This is used as FROM address for the email alerts
#                                                                             
#--------------------------------------DO NOT CHANGE ANYTHING BELOW THIS LINE----------------------------------------#
#>
# FUNCTIONS: User defined functions are kept here, not all are "pure" functions.
#
#------
# Name: display_welcome_ascii_banner()
# Desc: Displays a pretty ascii banner on script launch.
#   In: <NA>
#  Out: <NA>
#------
function display_welcome_ascii_banner(){
# Banner
printf "\n${green}"
cat << "EOF"
+-+-+-+-+-+-+ +-+-+-+-+-+
|r|u|n|S|A|S| |v|1|0|.|6|
+-+-+-+-+-+-+ +-+-+-+-+-+
|P|r|a|j|w|a|l|S|D|
+-+-+-+-+-+-+-+-+-+
EOF
printf "\n${white}"
}
#------
# Name: show_the_script_version_number()
# Desc: Displays the version number (invoked using --version or -v or --v)
#   In: <NA>
#  Out: <NA>
#------
function show_the_script_version_number(){
    # Script version
    runsas_version=10.6
    runsas_in_place_upgrade_compatible_version=10.6
    # Show version numbers
    if [[ ${#@} -ne 0 ]] && ([[ "${@#"--version"}" = "" ]] || [[ "${@#"-v"}" = "" ]] || [[ "${@#"--v"}" = "" ]]); then
        printf "$runsas_version"
        exit 0;
    fi;
}
#------
# Name: show_the_update_compatible_script_version_number()
# Desc: Shows the version number from which you can auto-update (using --update) 
#   In: --update-c
#  Out: <NA>
#------
function show_the_update_compatible_script_version_number(){
    if [[ ${#@} -ne 0 ]] && [[ "${@#"--update-c"}" = "" ]]; then
        printf "$runsas_in_place_upgrade_compatible_version"
        exit 0;
    fi;
}
#------
# Name: print_the_help_menu()
# Desc: Displays the help menu (--help)
#   In: <NA>
#  Out: <NA>
#------
function print_the_help_menu(){
    if [[ ${#@} -ne 0 ]] && [[ "${@#"--help"}" = "" ]]; then
		# Set the script version numbers for the help menu
		show_the_script_version_number
		show_the_update_compatible_script_version_number
		# Print help menu
        printf "${blue}"
        printf "${underline}"
        printf "\nNAME\n"
        printf "${end}${blue}"
        printf "\n       runSAS.sh"
        printf "${underline}"
        printf "\n\nSYNOPSIS\n"
        printf "${end}${blue}"
        printf "\n       runSAS.sh [script-mode] [optional-script-mode-value-1] [optional-script-mode-value-2]"
        printf "${underline}"
        printf "\n\nDESCRIPTION\n"
        printf "${end}${blue}"
        printf "\n       There are various [script-mode] in which you can launch runSAS, see below.\n"
        printf "\n      -i                          The script will halt after running each job, waiting for an ENTER key to continue"
        printf "\n      -j    <job-name>            The script will run a specified job even if it is not in the job list (adhoc mode, run any job using runSAS)"
        printf "\n      -u    <job-name>            The script will run everything (and including) upto the specified job"
        printf "\n      -f    <job-name>            The script will run from (and including) a specified job."
        printf "\n      -o    <job-name>            The script will run a specified job from the job list."
        printf "\n      -fu   <job-name> <job-name> The script will run from one job upto the other job."
        printf "\n      -fui  <job-name> <job-name> The script will run from one job upto the other job, but in an interactive mode (runs the rest in a non-interactive mode)"
        printf "\n      -fuis <job-name> <job-name> The script will run from one job upto the other job, but in an interactive mode (skips the rest)"
        printf "\n     --update                     The script will update itself to the latest version from Github"
        printf "\n     --delay <time-in-seconds>    The script will launch after a specified time delay in seconds"
        printf "\n     --jobs or --show             The script will show a list of job(s) provided by the user in the script (quick preview)"
        printf "\n     --help                       Display this help and exit"
        printf "\n"
        printf "\n       Tip #1: You can use <job-index> instead of a <job-name> e.g.: ./runSAS.sh -fu 1 3 instead of ./runSAS.sh -fu jobA jobC"
        printf "\n       Tip #2: You can add --prompt option against job(s) when you provide a list, this will halt the script during runtime for the user confirmation."
		printf "\n       Tip #3: You can add --skip option against job(s) when you provide a list, this will skip the job in every run."
        printf "\n       Tip #4: You can add --noemail option during the launch to override the email setting during runtime (useful for one time runs etc.)"        
		printf "\n       Tip #5: You can add --server option followed by specific parameters to override the defaults for a job (syntax: <jobname> --server <sas-server-name><sasapp-dir><batch-server-dir><sas-sh><logs-dir><deployed-jobs-dir>)" 
        printf "${underline}"
        printf "\n\nVERSION\n"
        printf "${end}${blue}"
        printf "\n       $runsas_version (auto-update compatible version: $runsas_in_place_upgrade_compatible_version)"
		printf "${underline}"
        printf "\n\nAUTHOR\n"
        printf "${end}${blue}"
        printf "\n       Written by Prajwal Shetty D"
        printf "${underline}"
        printf "\nGITHUB\n"
        printf "${end}${blue}"
        printf "\n       $runsas_github_src_url "
        printf "(To get the latest version of the runSAS you can use the in place upgrade option: ./runSAS.sh --update)\n\n"
        printf "${white}"
        exit 0;
    fi;
}
#------
# Name: validate_parameters_passed_to_script()
# Desc: Validates the allowed modes/values to the script 
#   In: <NA>
#  Out: <NA>
#------
function validate_parameters_passed_to_script(){
    while test $# -gt 0
    do
        case "$1" in
        --help) ;;
     --version) ;;
       --delay) ;;
     --noemail) ;;
      --nomail) ;;
      --update) ;;
    --update-c) ;;
        --jobs) ;;
         --job) ;;
        --show) ;;
        --list) ;;
            -v) ;;
           --v) ;;
            -i) ;;
            -j) ;;
            -o) ;;
            -f) ;;
            -u) ;;
           -fu) ;;
          -fui) ;;
         -fuis) ;;
             *) printf "${red}\n*** ERROR: ./runSAS ${white}${red_bg}$1${white}${red} is invalid, see the --help menu below for available options ***\n${white}"
                print_the_help_menu --help
                exit 0 
                ;;
        esac
        shift
    done
}
#------
# Name: show_first_launch_intro_message()
# Desc: Just displays some useful information for the first time users of the script
#   In: <NA>
#  Out: <NA>
#------
function show_first_launch_intro_message(){
     if [[ ! -f $runsas_first_use_intro_done_file ]]; then
        printf "${blue}Welcome, it looks like a first launch of the runSAS script, let's quickly go through some basics. \n\n${end}" 
        printf "${blue}runSAS essentially requires two things and they are set inside the script (set them if it is not done already): \n\n${end}"
        printf "${blue}    (a) SAS environment parameters and, ${end}\n"
        printf "${blue}    (b) List of SAS deployed jobs ${end}\n\n" 
        printf "${blue}There are many features like email alerts, job reports etc. and various launch modes like run from a specific job, run in interactive mode etc. \n\n${end}"
        printf "${blue}To know more about runSAS see the help menu (i.e. ./runSAS.sh --help) or go to ${underline}$runsas_github_page${end}${blue} for detailed documentation. \n${end}"
        press_enter_key_to_continue
        printf "\n"
        # Do not show the message again
        create_a_new_file $runsas_first_use_intro_done_file  
    fi
}
#------
# Name: show_the_list()
# Desc: Displays the list of jobs/programs in the script (quick preview using --list)
#   In: --jobs or --job or --show or --list
#  Out: <NA>
#------
function show_the_list(){
    if [[ ${#@} -ne 0 ]] && ([[ "${@#"--jobs"}" = "" ]] || [[ "${@#"--list"}" = "" ]] || [[ "${@#"--job"}" = "" ]] || [[ "${@#"--show"}" = "" ]]); then
        print_file_content_with_index .job.list jobs
        printf "\n"
        exit 0;
    fi;
}
#------
# Name: set_colors_codes()
# Desc: Bash color codes, reference: https://misc.flogisoft.com/bash/tip_colors_and_formatting
#   In: <NA>
#  Out: <NA>
#------
function set_colors_codes(){
    # Foreground colors
    black=$'\e[30m'
    red=$'\e[31m'
    green=$'\e[1;32m'
    yellow=$'\e[1;33m'
    blue=$'\e[1;34m'
    magenta=$'\e[1;35m'
    cyan=$'\e[1;36m'
    grey=$'\e[38;5;243m'
    white=$'\e[0m'
    # Color term
    end=$'\e[0m'
    # Background colors
    red_bg=$'\e[41m'
    green_bg=$'\e[42m'
    blue_bg=$'\e[44m'
    yellow_bg=$'\e[43m'
    darkgrey_bg=$'\e[100m'
    # Manipulators
    blink=$'\e[5m'
    bold=$'\e[1m'
    italic=$'\e[3m'
    underline=$'\e[4m'
	
    # Reset text attributes to normal without clearing screen.
    alias reset_colors="tput sgr0" 
}
#------
# Name: display_post_banner_messages()
# Desc: Informational messages, printed post welcome banner
#   In: <NA>
#  Out: <NA>
#------
function display_post_banner_messages(){
    printf "${white}The script has many modes of execution, ./runSAS.sh --help to see more details.${end}\n"
}
#------
# Name: check_dependencies()
# Desc: Checks if the dependencies have been installed and can install the missing dependencies automatically via "yum" 
#   In: program-name or package-name (multiple inputs could be specified)
#  Out: <NA>
#------
function check_dependencies(){
    # Set the package manager
    package_installer=yum
    # Dependency checker
    if [[ "$check_for_dependencies" == "Y" ]]; then
        for prg in "$@"
        do
            # Defaults
            check_dependency_cmd=`which $prg`
            # Check
            printf "${white}"
            if [[ -z "$check_dependency_cmd" ]]; then
                printf "${red}\n*** ERROR: Dependency checks failed, ${white}${red_bg}$prg${white}${red} program is not found, runSAS requires this program to run. ***\n"
                # If the package installer is available try installing the missing dependency
                if [[ ! -z `which $package_installer` ]]; then
                    printf "${green}\nPress Y to auto install $prg (requires $package_installer and sudo access if you're not root): ${white}"
                    read read_install_dependency
                    if [[ "$read_install_dependency" == "Y" ]]; then
                        printf "${white}\nAttempting to install $prg, running ${green}sudo yum install $prg${white}...\n${white}"
                        # Command 
                        sudo $package_installer install $prg
                    else
                        printf "${white}Try installing this using $package_installer, run ${green}sudo $package_installer install $prg${white} or download the $prg package from web (Goooooogle!)"
                    fi
                else
                    printf "${green}\n$package_installer not found, skipping auto install.\n${white}"
                    printf "${white}\nLaunch runSAS after installing the ${green}$prg${white} program manually (Google if your friend!) or ask server administrator."
                fi
                clear_session_and_exit
            fi
        done
    fi
}
#------
# Name: runsas_script_auto_update()
# Desc: Auto updates the runSAS script from Github
#   In: <NA>
#  Out: <NA>
#------
function runsas_script_auto_update(){
# Generate a backup name and folder
runsas_backup_script_name=runSAS.sh.$(date +"%Y%m%d_%H%M%S")

# Create backup folder
create_a_new_directory -p backups

# Create a backup of the existing script
if ! cp runSAS.sh backups/$runsas_backup_script_name; then
     printf "${red}*** ERROR: Backup has failed! ***\n${white}"
     clear_session_and_exit
else
    printf "${green}\nNOTE: The existing runSAS script has been backed up to `pwd`/backups/$runsas_backup_script_name ${white}\n"
fi

# Check if wget exists
check_dependencies wget dos2unix

# Download the latest file from Github
printf "${green}\nNOTE: Downloading the latest version from Github using wget utility...${white}\n\n"
if ! wget -O .runSAS.sh.downloaded $runsas_github_src_url; then
    printf "${red}*** ERROR: Could not download the new version of runSAS from Github using wget, possibly due to server restrictions or internet connection issues or the server has timed-out ***\n${white}"
    clear_session_and_exit
fi
printf "${green}NOTE: Download complete.\n${white}"

# Breather
sleep 0.5

# Fix perms (775 is the default!)
chmod 775 .runSAS.sh.downloaded
dos2unix .runSAS.sh.downloaded

# Show the version numbers 
# Get OLD version from the current file
printf "${green}\nCurrent version: ${white}"
./runSAS.sh --version > .runSAS.sh.ver
cat .runSAS.sh.ver
curr_runsas_ver=$(<.runSAS.sh.ver)
# Get NEW version from the downloaded file
printf "${green}\nNew version: ${white}"
./.runSAS.sh.downloaded --version > .runSAS.sh.downloaded.ver
cat .runSAS.sh.downloaded.ver
new_runsas_ver=$(<.runSAS.sh.downloaded.ver)
# Get COMPATIBLE version from the downloaded file
./.runSAS.sh.downloaded --update-c > .runSAS.sh.downloaded.comp.ver
compatible_runsas_ver=$(<.runSAS.sh.downloaded.comp.ver)

# Delete the temp files
rm -rf .runSAS.sh.ver
rm -rf .runSAS.sh.downloaded.ver

# runSAS version number regex pattern (i.e. nn.nn e.g. 9.0 or 10.12)
runsas_version_number_regex='^[0-9]+([.][0-9]+)?$' 

# Check if the environment already has the latest version, a warning must be shown
if (( $(echo "$curr_runsas_ver >= $new_runsas_ver" | bc -l) )); then
    printf "${red}\n\nWARNING: It looks like you already have the latest version of the script (i.e. $curr_runsas_ver). Do you still want to update?${white}"
fi

# Check if the current version is auto-update compatible? 
if ! [[ $curr_runsas_ver =~ $runsas_version_number_regex ]]; then 
    printf "${red}\n\n*** ERROR: The current version of the script ($curr_runsas_ver${red}) is not compatible with auto-update ***\n${white}"
    printf "${red}*** Download the latest version (and update it) manually from $runsas_github_src_url ***${white}"
    clear_session_and_exit
else
    if (( $(echo "$curr_runsas_ver < $compatible_runsas_ver" | bc -l) )); then
		printf "${red}\n\n*** ERROR: The current version of the script ($curr_runsas_ver${red}) is not compatible with auto-update ***\n${white}"
		printf "${red}*** Download the latest version (and update it) manually from $runsas_github_src_url ***${white}"
		clear_session_and_exit
    fi
fi

# Just to keep the console messages tidy
printf "\n"

# Get a config backup from existing script
cat runSAS.sh | sed -n '/^\#</,/^\#>/{/^\#</!{/^\#>/!p;};}' > .runSAS.config

# Remove everything between the markers in the downloaded file
sed -i '/^\#</,/^\#>/{/^\#</!{/^\#>/!d;};}' .runSAS.sh.downloaded

# Insert the config to the latest script
sed -i '/^\#</r.runSAS.config' .runSAS.sh.downloaded

# Spawn update script
cat > .runSAS_update.sh << EOF
#!/bin/bash
# Colors 
red=$'\e[31m'
green=$'\e[1;32m'
white=$'\e[0m'
# Update runSAS 
if mv .runSAS.sh.downloaded runSAS.sh; then
    sleep 0.5
    chmod 775 runSAS.sh
    printf "${green}\nNOTE: runSAS script has been successfully updated to ${white}"
    ./runSAS.sh --version
    printf "\n"
else
    printf "${red}\n\n*** ERROR: The runSAS script update has failed at the last step! ***${white}\n"
    printf "${red}\n\n*** You can recover the old version of runSAS from the backup created during this process, if needed. ***${white}\n"
fi
EOF

# Continue
press_enter_key_to_continue
   
# Handover the execution to the update script 
exec /bin/bash .runSAS_update.sh

# Exit
exit 0
} 
#------
# Name: check_for_in_place_upgrade_request_from_user()
# Desc: Check if the user is requesting the script update (--update)
#   In: --update
#  Out: <NA>
#------
function check_for_in_place_upgrade_request_from_user(){
    if [[ "$1" == "--update" ]]; then
        printf "${red}The update process will overwrite the runSAS script (user configuration will be preserved), press Y to proceed: ${white}"
        read read_in_place_upgrade_confirmation
        if [[ "$read_in_place_upgrade_confirmation" == "Y" ]]; then
            runsas_script_auto_update
        else
            printf "Cancelled.\n"
            exit 0
        fi
    fi
}
#------
# Name: process_delayed_execution()
# Desc: Check if the user is requesting a delayed execution (--delay)
#   In: --delay
#  Out: <NA>
#------
function process_delayed_execution(){
	# The delay implementation (called by the conditional code block below, requires the time delay in seconds)
	function process_delayed_execution_core(){
		if [[ "$1" == "0" ]]; then
			printf "${red}*** ERROR: You launched the script in --delay mode, a ${white}${red_bg}time delay in seconds${red_bg}${white}${red} is required for this mode ${white}"
			printf "${red}(e.g. ./runSAS.sh --delay 3600 for a delay of one hour) ***${white}"
			clear_session_and_exit
		else
			# Disable carriage return (ENTER key) during the script run
			stty igncr < /dev/tty
			# Parameters
			runsas_delay_time_in_secs=$1 
			runsas_delay_start_timestamp=`date --date="+$runsas_delay_time_in_secs seconds" '+%Y-%m-%d %T'`
			runsas_delay_time_in_secs_length=${#progress_bar_pct_completed_x_scale}
			# Notify 
			printf "${green}A time delay of $runsas_delay_time_in_secs seconds was specified, runSAS launch is deferred to $runsas_delay_start_timestamp, please wait ${white}"
			# Sleep
			for (( j=1; j<=$runsas_delay_time_in_secs; j++ )); do
				progressbar_start_timestamp=`date +%s`
				let delay_time_remaining=$runsas_delay_time_in_secs-$j
				display_progressbar_with_offset $j $runsas_delay_time_in_secs -1
				progressbar_end_timestamp=`date +%s`
				let sleep_delay_corrected_in_secs=1-$((progressbar_end_timestamp-progressbar_start_timestamp))
				sleep $sleep_delay_corrected_in_secs
			done
			display_progressbar_with_offset $runsas_delay_time_in_secs $runsas_delay_time_in_secs 0
			printf "\n\n"
		fi
	}

	# Check if --delay mode is specified as a primary mode
	if [[ "$script_mode" == "--delay" ]]; then
		if [[ "$script_mode_value_1" == "" ]]; then
			printf "${red}*** ERROR: You launched the script in --delay mode, a ${white}${red_bg}time delay in seconds${red_bg}${white}${red} is required for this mode${white}"
			printf "${red}(e.g. ./runSAS.sh --delay 3600 for a delay of one hour) ***${white}"
			clear_session_and_exit
		else
			process_delayed_execution_core $script_mode_value_1
		fi
	else
		# Check if --delay mode is specified in combination with other modes (assumption: --delay will be followed by time delay in seconds) 
		for (( i=1; i<=$runsas_allowable_parameter_count; i++ )); do
			delay_script_mode_value_i="script_mode_value_$i"
			delay_script_mode_value="${!delay_script_mode_value_i}"
			if [[ "$delay_script_mode_value" == "--delay" ]]; then
				# If --delay is found, next one must be the time in seconds 
				let i+=1
				delay_script_mode_value=0
				delay_script_mode_value_i="script_mode_value_$i"
				delay_script_mode_value="${!delay_script_mode_value_i}" 
				process_delayed_execution_core $delay_script_mode_value
			fi
		done
	fi
}
#------
# Name: move_files_to_a_directory()
# Desc: Move files to a specified directory
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
# Desc: Check if the specified directory exists
#   In: directory-name (multiple could be specified)
#  Out: <NA>
#------
function check_if_the_dir_exists(){
    for dir in "$@"
    do
        if [[ ! -d "$dir" ]]; then
            printf "${red}*** ERROR: Directory ${white}${red_bg}$dir${white}${red} was not found in the server, make sure you have correctly set the script parameters as per the environment *** ${white}"
            clear_session_and_exit
        fi
    done
}
#------
# Name: create_a_new_file()
# Desc: This function will create a new file if it doesn't exist, that's all.
#   In: file-name (multiple files can be provided)
#  Out: <NA>
#------
function create_a_new_file(){
    for f in "$@"
    do
        if [[ ! -f $f ]]; then
            touch $f
            chmod 775 $f
        fi
    done
}
#------
# Name: check_if_the_file_exists()
# Desc: Check if the specified file exists
#   In: file-name (multiple could be specified)
#  Out: <NA>
#------
function check_if_the_file_exists(){
    for file in "$@"
    do
        if [ ! -f "$file" ]; then
            printf "\n${red}*** ERROR: File ${black}${red_bg}$file${white}${red} was not found in the server *** ${white}"
            clear_session_and_exit
        fi
    done
}
#------
# Name: create_a_new_directory()
# Desc: Create a specified directory if it doesn't exist
#   In: directory-name (multiple could be specified)
#  Out: <NA>
#------
function create_a_new_directory(){
    mkdir_mode=""
    for dir in "$@"
    do
        if [[ "$dir" == "-p" ]]; then
            mkdir_mode="-p"
        else 
            if [[ ! -d "$dir" ]]; then
                printf "${green}\nNOTE: Creating a directory named $dir...${white}"
                mkdir $mkdir_mode $dir
                # See if the directory creation was successful
                if [[ -d "$dir" ]]; then
                    printf "${green}DONE\n${white}"
                else
                    printf "${red}\n*** ERROR: Directory ${black}${red_bg}$dir${white}${red} cannot be created under the path specified ***${white}"
                    printf "${red}\n*** ERROR: It is likely that one of the parent folder in the directory tree does't exist or the folder permission is restricting the creation of new object under it ***${white}"
                    clear_session_and_exit
                fi
            fi
        fi
    done
}
#------
# Name: print_file_content_with_index()
# Desc: This function prints the file content with a index
#   In: file-name, file-line-content-type
#  Out: <NA>
#------
function print_file_content_with_index(){
    total_lines_in_the_file=`cat $1 | wc -l`
    printf "\n${white}There are $total_lines_in_the_file $2 in the list:${white}\n"
    printf "${white}---${white}\n"
    awk '{printf("%02d) %s\n", NR, $0)}' $1
    printf "${white}---${white}\n"
}
#------
# Name: check_if_logged_in_user_is_root()
# Desc: Check if the user is logged in as root
#   In: <NA>
#  Out: <NA>
#------
function check_if_logged_in_user_is_root(){
    if [[ "$EUID" -eq 0 ]]; then
        printf "${yellow}\nWARNING: Typically you have to launch this script as a SAS installation user such as ${green}sas${yellow} or any user that has SAS batch execution privileges, you are currently logged in as ${red}root. ${white}"
        printf "${yellow}Press ENTER key to ignore this and continue (CTRL+C to abort this session)...${white}"
        read -s < /dev/tty
        printf "\n"
    fi
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
# Desc: Backup a directory to a folder as tar zip with timestamps (filename_YYYYMMDD.tar.gz)
#   In: source-dir, target-dir, target-zip-file-name
#  Out: <NA>
#------
function backup_directory(){
	curr_timestamp=`date +%Y%m%d`
	tar -zcf $2/$3_${curr_timestamp}.tar.gz $1
}
#------
# Name: add_a_newline_char_to_eof()
# Desc: This function will add a new line character to the end of file (only if it doesn't exists)
#   In: file-name
#  Out: <NA>
#------
function add_a_newline_char_to_eof(){
    if [ "$(tail -c1 "$1"; echo x)" != $'\nx' ]; then     
        echo "" >> "$1"; 
    fi
}
#------
# Name: run_in_interactive_mode_check()
# Desc: Interactive mode (-i) will pause the run after each job run (useful for training etc.)
#   In: <NA>
#  Out: <NA>
#------
function run_in_interactive_mode_check(){
    if [[ "$script_mode" == "-i" ]] && [[ "$escape_interactive_mode" != "1" ]]; then
        interactive_mode=1
        printf "${red_bg}${black}Press ENTER key to continue OR type E to escape the interactive mode${white} "
        stty -igncr < /dev/tty
        read run_in_interactive_mode_check_user_input < /dev/tty
        if [[ "$run_in_interactive_mode_check_user_input" == "E" ]] || [[ "$run_in_interactive_mode_check_user_input" == "e" ]]; then
            escape_interactive_mode=1
        fi
    else
        interactive_mode=0
    fi
}
#------
# Name: run_until_a_job_mode_check()
# Desc: Run upto mode (-u) will run all jobs upto the specified job
#   In: <NA>
#  Out: <NA>
#------
function run_until_a_job_mode_check(){
    if [[ "$script_mode" == "-u" ]]; then
        if [[ "$script_mode_value_1" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode (run-upto-a-job) mode, a job name is also required after $script_mode option ***${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value_1" == "$local_sas_job" ]]; then 
				if [[ $index_mode_first_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $job_counter_for_display -eq $index_mode_first_job_number ]]; then
						run_until_mode=1
					fi
				else
					run_until_mode=1
				fi
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
# Desc: Run from a job mode (-f) will run all jobs from a specified job
#   In: <NA>
#  Out: <NA>
#------
function run_from_a_job_mode_check(){
    if [[ "$script_mode" == "-f" ]]; then
        if [[ "$script_mode_value_1" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-a-job) mode, a job name is also required after $script_mode option ***${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value_1" == "$local_sas_job" ]]; then
				if [[ $index_mode_first_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $job_counter_for_display -eq $index_mode_first_job_number ]]; then
						run_from_mode=1
					fi
				else
					run_from_mode=1
				fi
            fi
        fi
    else
        run_from_mode=1 # Just so that this doesn't trigger for other modes
    fi
}
#------
# Name: run_a_single_job_mode_check()
# Desc: Run a single job mode (-o) will run only the specified job
#   In: <NA>
#  Out: <NA>
#------
function run_a_single_job_mode_check(){
    if [[ "$script_mode" == "-o" ]]; then
        if [[ "$script_mode_value_1" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-a-single-job) mode, a job name is also required after $script_mode option ***${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value_1" == "$local_sas_job" ]]; then
				if [[ $index_mode_first_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $job_counter_for_display -eq $index_mode_first_job_number ]]; then
						run_a_job_mode=1
					fi
				else
					run_a_job_mode=1
				fi
            else
                run_a_job_mode=0
            fi
        fi
    else
        run_a_job_mode=1 # Just so that this doesn't trigger for other modes
    fi
}
#------
# Name: run_a_job_mode_check()
# Desc: Run a job mode (-j) will run only the specified job even if it is not specified in the list
#   In: <NA>
#  Out: <NA>
#------
function run_a_job_mode_check(){
    # Set defaults if nothing is specified (i.e. just a job name is specified)
    rjmode_script_mode="$1"
    rjmode_sas_job="$2"
    rjmode_sas_opt="$3"
    rjmode_sas_subopt="$4"
    rjmode_sas_app_root_directory="${5:-$sas_app_root_directory}"
    rjmode_sas_batch_server_root_directory="${6:-$sas_batch_server_root_directory}"
    rjmode_sas_sh="${7:-$sas_default_sh}"
    rjmode_sas_logs_root_directory="${8:-$sas_logs_root_directory}"
    rjmode_sas_deployed_jobs_root_directory="${9:-$sas_deployed_jobs_root_directory}"
      
    if [[ "$rjmode_script_mode" == "-j" ]]; then
        if [[ "$rjmode_sas_job" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $rjmode_script_mode(run-a-job) mode, a job name is also required (without the .sas extension) after $script_mode option ***${white}"
            clear_session_and_exit
        else
            check_if_the_file_exists $rjmode_sas_deployed_jobs_root_directory/$rjmode_sas_job.$program_type_ext
			printf "\n"
			total_no_of_jobs_counter=1
			runSAS $rjmode_sas_job $rjmode_sas_opt $rjmode_sas_subopt $rjmode_sas_app_root_directory $rjmode_sas_batch_server_root_directory $rjmode_sas_sh $rjmode_sas_logs_root_directory $rjmode_sas_deployed_jobs_root_directory
			clear_session_and_exit
        fi
    fi
}
#------
# Name: run_from_to_job_mode_check()
# Desc: Run from a job to a job mode (-fu) will run jobs between the specified jobs (including the specified ones)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_mode_check(){
    if [[ "$script_mode" == "-fu" ]]; then
        if [[ "$script_mode_value_1" == "" ]] || [[ "$script_mode_value_2" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-to-job) mode, two job names (separated by spaces) are also required after $script_mode option ***${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value_1" == "$local_sas_job" ]]; then
				if [[ $index_mode_first_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too 
					if [[ $job_counter_for_display -eq $index_mode_first_job_number ]]; then
						run_from_to_job_mode=1
					fi
				else
					run_from_to_job_mode=1
				fi
            else
                if [[ "$script_mode_value_2" == "$local_sas_job" ]]; then
					if [[ $index_mode_second_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
						if [[ $job_counter_for_display -eq $index_mode_second_job_number ]]; then
							run_from_to_job_mode=2
						fi
					else
						run_from_to_job_mode=2
					fi
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
# Desc: Run from a job to a job mode in interactive mode (-fui) will run jobs between the specified jobs in a interactive mode but will run the rest
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_interactive_mode_check(){
    if [[ "$script_mode" == "-fui" ]]; then
        if [[ "$script_mode_value_1" == "" ]] || [[ "$script_mode_value_2" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-to-job-interactive) mode, two job names (separated by spaces) are also required after $script_mode option ***${white}"
            clear_session_and_exit
        else
            if [[ "$script_mode_value_1" == "$local_sas_job" ]]; then
				if [[ $index_mode_first_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $job_counter_for_display -eq $index_mode_first_job_number ]]; then
						run_from_to_job_interactive_mode=1
					fi
				else
					run_from_to_job_interactive_mode=1
				fi
            else
                if [[ "$script_mode_value_2" == "$local_sas_job" ]]; then
					if [[ $index_mode_second_job_number -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
						if [[ $job_counter_for_display -eq $index_mode_second_job_number ]]; then
							run_from_to_job_interactive_mode=2
						fi
					else
						run_from_to_job_interactive_mode=2
					fi
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
# Desc: Run from a job to a job mode in interactive mode (-fuis) will run jobs between the specified jobs in a interactive mode but will skip the rest
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_interactive_skip_mode_check(){
    if [[ "$script_mode" == "-fuis" ]]; then
        if [[ "$script_mode_value_1" == "" ]] || [[ "$script_mode_value_2" == "" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-to-job-interactive-skip) mode, two job names (separated by spaces) are also required after $script_mode option ***${white}"
            clear_session_and_exit
        else
			# In index mode, match the index too.
            if [[ "$script_mode_value_1" == "$local_sas_job" ]]; then
				if [[ $index_mode_first_job_number -gt 0 ]]; then
					if [[ $job_counter_for_display -eq $index_mode_first_job_number ]]; then
						run_from_to_job_interactive_skip_mode=1
					fi
				else
					run_from_to_job_interactive_skip_mode=1
				fi
            else
				# In index mode, match the index too.
                if [[ "$script_mode_value_2" == "$local_sas_job" ]]; then
					if [[ $index_mode_second_job_number -gt 0 ]]; then
						if [[ $job_counter_for_display -eq $index_mode_second_job_number ]]; then
							run_from_to_job_interactive_skip_mode=2
						fi
					else
						run_from_to_job_interactive_skip_mode=2
					fi
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
# Name: kill_a_pid()
# Desc: Terminate the process using kill command
#   In: pid
#  Out: <NA>
#------
function kill_a_pid(){
    if [[ ! -z `ps -p $1 -o comm=` ]]; then
        kill -9 $1
        printf "${red}\n\nCleaning up the background process (pid $1), please wait...${white}"
        sleep 2
        if [[ -z `ps -p $1 -o comm=` ]]; then
            printf "${green}DONE${white}\n\n${white}"
        else
            printf "${red}\n\n*** ERROR: Attempt to terminate the pid $1 using kill command kill -9 command failed. It is likely due to user permissions (try sudo kill?), see details below. ***\n${white}"
            show_pid_details $1
            printf "\n"
        fi
    else
        printf "${red} (pid is missing anyway, no action taken)${white}\n\n"
    fi
}
#------
# Name: show_pid_details()
# Desc: Show PID details
#   In: pid
#  Out: <NA>
#------
function show_pid_details(){
    if [[ ! -z `ps -p $1 -o comm=` ]]; then
        printf "${yellow}$console_message_line_wrappers\n"
        ps $1 # Show process details
        printf "${yellow}$console_message_line_wrappers\n${white}"
    fi
}
#------
# Name: running_processes_housekeeping()
# Desc: Housekeeping for background process, terminate it if required (based on the kill_process_on_user_abort parameter)
#   In: pid 
#  Out: <NA>
#------
function running_processes_housekeeping(){
    if [[ ! -z ${1} ]]; then
        if [[ ! -z `ps -p $1 -o comm=` ]]; then
            if [[ "$kill_process_on_user_abort" ==  "Y" ]]; then
                stty igncr < /dev/tty
                printf "${yellow}PID details for the active job:\n${white}"
                # PID show & kill
                show_pid_details $1
                kill_a_pid $1               
                stty -igncr < /dev/tty
            else
                echo $1 > $runsas_last_job_pid_file
                printf "${red}WARNING: The last job submitted by runSAS with pid $1 is still running/active in the background, terminate it manually using ${green}kill -9 $1${white}${red} command.\n\n${white}"
            fi
        fi
    fi
}
#------
# Name: check_if_there_are_any_rogue_runsas_processes()
# Desc: Check if there are any rogue runSAS processes, display a warning and abort the script based on the user input
#   In: <NA>
#  Out: <NA>
#------
function check_if_there_are_any_rogue_runsas_processes(){
    # Create an empty file it it doesn't exist already
    create_a_new_file $runsas_last_job_pid_file

    # Get the last known PID launched by runSAS
    runsas_last_job_pid="$(<$runsas_last_job_pid_file)"

    # Check if the PID is still active
    if ! [[ -z `ps -p ${runsas_last_job_pid:-"999"} -o comm=` ]]; then
        printf "${yellow}WARNING: There is a job (pid $runsas_last_job_pid) that is still active/running from the last runSAS session, see the details below.\n\n${white}"
        show_pid_details $runsas_last_job_pid
        printf "${red}\nDo you want to kill this process and continue? (Type Y to kill and N to ingore this warning): ${white}"
        stty igncr < /dev/tty
        read -n1 ignore_process_warning
        if [[ "$ignore_process_warning" == "Y" ]] || [[ "$ignore_process_warning" == "y" ]]; then
            kill_a_pid $runsas_last_job_pid
        else
            printf "\n\n"
        fi
        stty -igncr < /dev/tty
    fi
}
#------
# Name: print_to_console_debug_only()
# Desc: Prints more details to console if the debug mode is turned on (experimental)
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
# Name: send_an_email()
# Desc: This routine will send an email alert to the intended recipient(s)
#   In: email-mode, subject-identifier, subject, to-address (separated by semi-colon), email-body-msg-html-file, 
#       optional-email-attachment-dir, optional-email-attachment, optional-from-address (separated by semi-colon), optional-to-distribution-list (separated by semi-colon)
#  Out: <NA>
#------
function send_an_email(){
# Parameters
email_mode=$1
email_subject_id=$2
email_subject=$3
email_to_address=$4
email_body_message_file=$5
email_optional_attachment_directory=$6
email_optional_attachment=$7
email_optional_from_address=$8
email_optional_to_distribution_list=$9

# Email files root directory (default is set to current directory)
email_html_files_root_directory=.

# HTML files
email_header_file="$email_html_files_root_directory/.runSAS_email_header.html" 
email_body_file="$email_html_files_root_directory/.runSAS_email_body.html"
email_footer_file="$email_html_files_root_directory/.runSAS_email_footer.html"

# Do not change this
email_boundary_string="ZZ_/afg6432dfgkl.94531q"

# Check for the file size limit, if there's an attachment
if [[ "$email_optional_attachment" != "" ]]; then
	this_attachment_size=`du -b "$email_optional_attachment_directory/$email_optional_attachment" | cut -f1`
	if (( $this_attachment_size > $email_attachment_size_limit_in_bytes )); then
		printf "${red}The log is too large to be sent as an email attachment ($this_attachment_size bytes). ${white}"
		email_optional_attachment=;
	fi
fi

# Customize the email content (HTML is default format used here, you could use any!) as per the customer need. 
# The email body (dynamic) will be sandwiched between header and footer
# Header 
cat << EOF > $email_header_file
<html><body>
<font face=Arial size=2>Hi,<br>
<font face=courier size=2><div style="font-size: 13; font-family: 'Courier New', Courier, monospace"><p style="color: #ffffff; background-color: #303030">
EOF
# Body (this is dynamically constructed)
# Footer
cat << EOF > $email_footer_file
</p></div></body>
<p><font face=Arial size=2>Cheers,<br>runSAS</p>
EOF

# Validation
if [[ "$email_to_address" == "" ]]; then
    printf "${red}*** ERROR: Recipient email address was not specified in the parameters sections of the script, review and try again. *** \n${white}"
    clear_session_and_exit
fi

# Compose the email body 
cat $email_header_file       | awk '{print $0}'  > $email_body_file
cat $email_body_message_file | awk '{print $0}' >> $email_body_file
cat $email_footer_file       | awk '{print $0}' >> $email_body_file

# Get the file contents to the variable
email_body=$(<$email_body_file)

# Build "To", "From" and "Subject"
email_from_address_complete="$email_alert_user_name <$USER@`hostname`>"
email_to_address_complete="$email_to_address $email_optional_to_distribution_list" 
email_subject_full_line="$email_subject_id $email_subject"

# Remember the current directory and switch to attachments root directory (is switched back once the routine is complete)
curr_directory=`pwd`
cd $email_optional_attachment_directory

# Build a console message (first part of the message)
email_attachment_msg=
if [[ "$email_mode" != "-s" ]]; then
    printf "${green}An email ${white}"
    email_attachment_msg="with no attachment "
fi

# Email routine
declare -a attachments
attachments=( "$email_optional_attachment" )
{
# Do not change anything beyond this line
printf '%s\n' "FROM: $email_from_address_complete
To: $email_to_address_complete
SUBJECT: $email_subject_full_line
Mime-Version: 1.0
Content-Type: multipart/mixed; BOUNDARY=\"$email_boundary_string\"

--${email_boundary_string}
Content-Type: text/html; charset=\"US-ASCII\"
Content-Transfer-Encoding: 7bit
Content-Disposition: inline

$email_body
"
# Loop over the attachments, guess the type and produce the corresponding part, encoded base64
for attached_file in "${attachments[@]}"; do
[ ! -f "$attached_file" ] && printf "${green}$email_attachment_msg${white}" >&2 && continue
printf '%s\n' "--${email_boundary_string}
Content-Type:text/plain; charset=\"US-ASCII\"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"$attached_file\"
"
base64 "$attached_file"
echo
done
# Print last email_boundary_string with closing --
printf '%s\n' "--${email_boundary_string}--"
} | sendmail -t -oi

# Post email alert
if [[ "$email_mode" != "-s" ]]; then
    printf "${green}was sent to $email_to_address$email_to_distribution_list${white}"
fi
cd $curr_directory

# Clear the temporary files
rm -rf $email_header_file $email_body_file $email_footer_file
}
#------
# Name: add_html_color_tags_for_keywords()
# Desc: This adds color tags for based on the content of the file (used in email)
#   In: file-name
#  Out: <NA>
#------
function add_html_color_tags_for_keywords(){
	sed -e 's/$/<br>/'                                                                      -i  $1
	sed -e "s/ERROR/<font size=\"2\" face=\"courier\"color=\"RED\">ERROR<\/font>/g"         -i  $1
	sed -e "s/MISSING/<font size=\"2\" face=\"courier\"color=\"RED\">MISSING<\/font>/g"     -i  $1
	sed -e "s/LOCK/<font size=\"2\" face=\"courier\"color=\"RED\">LOCK<\/font>/g"           -i  $1
	sed -e "s/ABORT/<font size=\"2\" face=\"courier\"color=\"RED\">ABORT<\/font>/g"         -i  $1
	sed -e "s/WARNING/<font size=\"2\" face=\"courier\"color=\"YELLOW\">WARNING<\/font>/g"  -i  $1
	sed -e "s/NOTE/<font size=\"2\" face=\"courier\"color=\"GREEN\">NOTE<\/font>/g"         -i  $1
	sed -e "s/Log:/<font size=\"2\" face=\"courier\"color=\"RED\">Log:<\/font>/g"         	-i  $1
	sed -e "s/Job:/<font size=\"2\" face=\"courier\"color=\"RED\">Job:<\/font>/g"        	-i  $1
	sed -e "s/Step:/<font size=\"2\" face=\"courier\"color=\"RED\">Step:<\/font>/g"         -i  $1
}
#------
# Name: runsas_triggered_email()
# Desc: Send an email when runSAS is triggered
#   In: <NA>
#  Out: <NA>
#------
function runsas_triggered_email(){
    if [[ "$email_alerts" == "Y" ]] || [[ "${email_alerts:0:1}" == "Y" ]]; then
		# Reset the input parameters 
        echo "runSAS was launched in ${1:-"a full batch"} mode with ${2:-"no parameters."} $3 $4 $5" > $email_body_msg_file
        add_html_color_tags_for_keywords $email_body_msg_file
        send_an_email -v "" "Batch has been triggered" $email_alert_to_address $email_body_msg_file
        printf "\n\n"
    fi
}
#------
# Name: runsas_job_completed_email()
# Desc: Send an email when a single job/program run is complete
#   In: <NA>
#  Out: <NA>
#------
function runsas_job_completed_email(){
    if [[ "$email_alerts" == "Y" ]] || [[ "${email_alerts:1:1}" == "Y" ]]; then
        echo "Job $1 ($4 of $5) completed successfully and took about $2 seconds to complete (took $3 seconds to run previously)." > $email_body_msg_file
        add_html_color_tags_for_keywords $email_body_msg_file
        send_an_email -s "" "$1 has run successfully" $email_alert_to_address $email_body_msg_file
    fi
}
#------
# Name: runsas_error_email()
# Desc: Send an email when runSAS has seen an error
#   In: <NA>
#  Out: <NA>
#------
function runsas_error_email(){
    if [[ "$email_alerts" == "Y" ]] || [[ "${email_alerts:2:1}" == "Y" ]]; then
        printf "\n\n"
        echo "$console_message_line_wrappers" > $email_body_msg_file
        # See if the steps are displayed
        if [[ "$job_error_display_steps" == "Y" ]]; then
            cat $tmp_log_w_steps_file | awk '{print $0}' >> $email_body_msg_file
        else
            cat $tmp_log_file | awk '{print $0}' >> $email_body_msg_file
        fi
        # Send email
        echo "$console_message_line_wrappers" >> $email_body_msg_file
        echo "Job: $(<$job_that_errored_file)" >> $email_body_msg_file
        echo "Log: $local_sas_logs_root_directory/$current_log_name" >> $email_body_msg_file
        add_html_color_tags_for_keywords $email_body_msg_file
        send_an_email -v "" "Job $1 (of $2) has failed!" $email_alert_to_address $email_body_msg_file $local_sas_logs_root_directory $current_log_name 
    fi
}
#------
# Name: runsas_success_email()
# Desc: Send an email when runSAS has completed its run
#   In: <NA>
#  Out: <NA>
#------
function runsas_success_email(){
    if [[ "$email_alerts" == "Y" ]] || [[ "${email_alerts:3:1}" == "Y" ]]; then
        # Send email
        printf "\n\n"
        cat $job_stats_delta_file | sed 's/ /,|,/g' | column -s ',' -t > $email_console_print_file
        sed -e 's/ /\&nbsp\;/g' -i $email_console_print_file
        echo "The batch completed successfully on $end_datetime_of_session_timestamp and took a total of $((end_datetime_of_session-start_datetime_of_session)) seconds to complete. See the run details below.<br>" > $email_body_msg_file
        cat $email_console_print_file | awk '{print $0}' >> $email_body_msg_file
        add_html_color_tags_for_keywords $email_body_msg_file	
        send_an_email -v "" "Batch has completed successfully!" $email_alert_to_address $email_body_msg_file
    fi
}
#------
# Name: store_job_runtime_stats()
# Desc: Capture job runtime stats, single version of history is kept per job
#   In: job-name, total-time-taken-by-job, logname, start-timestamp, end-timestamp
#  Out: <NA>
#------
function store_job_runtime_stats(){
    sed -i "/$1/d" $job_stats_file # Remove the previous entry
    echo "$1 $2 $3 $4 $5" >> $job_stats_file # Add a new entry 
	echo "$1 $2 $3 $4 $5" >> $job_stats_delta_file # Add a new entry to a delta file
}
#------
# Name: get_job_hist_runtime_stats()
# Desc: Check job runtime for the last batch run
#   In: job-name
#  Out: <NA>
#------
function get_job_hist_runtime_stats(){
    hist_job_runtime=`awk -v pat="$1" -F" " '$0~pat { print $2 }' $job_stats_file`
}
#------
# Name: show_job_hist_runtime_stats()
# Desc: Print details about last run (if available)
#   In: job-name
#  Out: <NA>
#------
function show_job_hist_runtime_stats(){
	get_job_hist_runtime_stats $1
	if [[ "$hist_job_runtime" != "" ]]; then
		printf "${white} (took ~$hist_job_runtime secs last time)${white}"
	fi
}
#------
# Name: write_current_job_details_on_screen()
# Desc: Print details about the currently running job on the console
#   In: job-name
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
#   In: job-name
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
#   In: job-name
#  Out: <NA>
#------
function get_the_job_name_in_the_list(){
    job_name_from_the_list_pre=`sed -n "${1}p" .job.list`
    job_name_from_the_list=${job_name_from_the_list_pre%% *}
    if [[ -z $job_name_from_the_list ]]; then
        printf "${red}*** ERROR: Job index is out-of-range, no job found at $1 in the list above. Please review the specified index and launch the script again ***${white}"
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
    running_processes_housekeeping $job_pid
    printf "${green}*** runSAS is exiting now ***${white}\n\n"
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
    printf "${red}"
    IFS='[;' read -p < /dev/tty $'\e[6n' -d R -a pos -rs || echo "*** ERROR: The cursor position routine failed with error: $? ; ${pos[*]} ***"
    cursor_row_pos=${pos[1]}
    cursor_col_pos=${pos[2]}
    printf "${white}"
}
#------
# Name: display_message_fillers_on_console()
# Desc: Fetch cursor position and populate the fillers
#   In: filler-character-upto-column, filler-character, optional-backspace-counts
#  Out: <NA>
#------
function display_message_fillers_on_console(){
    # Get the current cursor position
    get_current_cursor_position

    # Set the parameters
    filler_char_upto_col=$1
    filler_char_to_display=$2
    pre_filler_backspace_char_count=$3
    use_preserved_filler_char_count=$4
    post_filler_backspace_char_count=$5

    # Calculate no of fillers required to reach the specified column
    filler_char_count=$((filler_char_upto_col-cursor_col_pos))

    # See if a backspace is requested (pre filler)
    if [[ "$pre_filler_backspace_char_count" != "0" ]] && [[ "$pre_filler_backspace_char_count" != "" ]]; then
        for (( i=1; i<=$pre_filler_backspace_char_count; i++ )); do
            printf "\b"
        done
    fi

    # Display fillers
    if [[ "$use_preserved_filler_char_count" != "N" ]] && [[ "$use_preserved_filler_char_count" != "" ]]; then
        for (( i=1; i<=$filler_char_count_prev; i++ )); do
            printf "$filler_char_to_display" 
        done   
    else
        for (( i=1; i<=$filler_char_count; i++ )); do
            printf "$filler_char_to_display" 
        done   
    fi

    # See if a backspace is requested (post filler)
    if [[ "$post_filler_backspace_char_count" != "0" ]] && [[ "$post_filler_backspace_char_count" != "" ]]; then
        for (( i=1; i<=$post_filler_backspace_char_count; i++ )); do
            printf "\b"
        done
    fi

    # Preserve the last count
    filler_char_count_prev=$filler_char_count
}
#------
# Name: press_enter_key_to_continue()
# Desc: This function will pause the script and wait for the ENTER key to be pressed
#   In: newline-count (e.g. 2 for 2 newlines)
#  Out: enter_to_continue_user_input
#------
function press_enter_key_to_continue(){
    # Enable carriage return (ENTER key) during the script run
    stty -igncr < /dev/tty
    # Show message
    printf "${green}\nPress ENTER key to continue...${white}"
    read enter_to_continue_user_input
    # See if a newline is requested
    if [[ "$1" != "" ]]; then
        for (( i=1; i<=$1; i++ )); do
            printf "\n"
        done
    fi
    # Disable carriage return (ENTER key) during the script run
    stty -igncr < /dev/tty
}
#------
# Name: check_for_multiple_instances_of_job()
# Desc: This function checks if a job (if specified at launch) is specified more than once in the job list and shows an error to avoid confusion (doesn't error if a index is specified)
#   In: <job-name>
#  Out: <NA>
#------
function check_for_multiple_instances_of_job(){
	joblist_job_count=0 
	while IFS=' ' read -r j o; do
		if [[ "$j" == "$1" ]] && [[ "$o" != "--skip" ]]; then
			let joblist_job_count+=1
		fi
	done < .job.list
	if [[ $joblist_job_count > 1 ]]; then
		printf "\n${red}*** ERROR: Job ${black}${red_bg}$1${end}${red} has been specified more than once in the job list, launch the script again with a job index/number instead (ex.: ./runSAS.sh -f 16) ***${white}"
		clear_session_and_exit
	fi
}
#------
# Name: validate_job_list()
# Desc: This function checks if the specified job's .sas file in server directory
#   In: job-list-filename
#  Out: <NA>
#------
function validate_job_list(){
	job_counter=0
	if [[ "$script_mode" != "-j" ]]; then  # Skip the job list validation in -j(run-a-job) mode
		while IFS=' ' read -r j o so bservdir bsh blogdir bjobdir; do
			let job_counter+=1
            # Set defaults if nothing is specified
            vjmode_sas_deployed_jobs_root_directory="${bjobdir:-$sas_deployed_jobs_root_directory}"
            # If user has specified a different server context, switch it here
            if [[ "$o" == "--server" ]]; then
                if [[ "$so" != "" ]]; then
                    if [[ "$bjobdir" == "" ]]; then 
                        vjmode_sas_deployed_jobs_root_directory=`echo "${vjmode_sas_deployed_jobs_root_directory/$sas_app_server_name/$so}"`
                    fi
                else
                    printf "${yellow}WARNING: $so was specified for $j in the list without the server context name, defaulting to $sas_app_server_name${white}"
                fi
            fi
			if [[ "$o" != "--skip" ]] && [ ! -f "$vjmode_sas_deployed_jobs_root_directory/$j.$program_type_ext" ]; then
				printf "\n${red}*** ERROR: Job #$job_counter ${black}${red_bg}$j${white}${red} has not been deployed or mispelled because $j.$program_type_ext was not found in $vjmode_sas_deployed_jobs_root_directory *** ${white}"
                clear_session_and_exit
			fi
		done < $1
	fi
}
#------
# Name: archive_all_job_logs()
# Desc: This function archives all logs in the directory in preparation for a fresh batch run
#   In: job-list-filename, archive-folder-name
#  Out: <NA>
#------
function archive_all_job_logs(){
    job_counter=0
    ajmode_logs_archive_directory_name="$2"
	if [[ "$script_mode" != "-j" ]]; then  # Skip the archiving process in -j(run-a-job) mode
		while IFS=' ' read -r j o so bservdir bsh blogdir bjobdir; do
			let job_counter+=1
            # Set defaults if nothing is specified 
            ajmode_sas_logs_root_directory="${blogdir:-$sas_logs_root_directory}"
            # If user has specified a different server context, switch it here
            if [[ "$o" == "--server" ]]; then
                if [[ "$so" != "" ]]; then
                    ajmode_sas_logs_root_directory=`echo "${ajmode_sas_logs_root_directory/$sas_app_server_name/$so}"`
                else
                    printf "${yellow}WARNING: $so was specified for $j in the list without the server context name, defaulting to $sas_app_server_name${white}"
                fi
            fi
            # Archive all old logs
            create_a_new_directory "$ajmode_sas_logs_root_directory/$ajmode_logs_archive_directory_name"
            move_files_to_a_directory "$ajmode_sas_logs_root_directory/*.log" "$ajmode_sas_logs_root_directory/$ajmode_logs_archive_directory_name"
		done < $1
	fi
}
#------
# Name: show_server_and_user_details()
# Desc: This function will show details about the server and the user
#   In: file-name (multiple files can be provided)
#  Out: <NA>
#------
function show_server_and_user_details(){
    printf "\n${white}The script was launched (in "${1:-'a default'}" mode) with pid $$ on $HOSTNAME at `date '+%Y-%m-%d %H:%M:%S'` by ${white}"
    printf '%s' ${white}"${SUDO_USER:-$USER}${white}"
    printf "${white} user\n${white}"
}
#------
# Name: display_progressbar_with_offset()
# Desc: Calculates the progress bar parameters (https://en.wikipedia.org/wiki/Block_Elements#Character_table & https://www.rapidtables.com/code/text/unicode-characters.html, alternative: █)
#   In: steps-completed, total-steps, offset (-1 or 0)
#  Out: <NA>
#------
function display_progressbar_with_offset(){
    # Defaults
    progressbar_width=20
    progressbar_sleep_interval_in_secs=0.5
    progressbar_color_unicode_char=" "
    progressbar_grey_unicode_char=" "
    progressbar_default_active_color=$default_progressbar_color

    # Defaults for percentages shown on the console
    progress_bar_pct_symbol_length=1
    progress_bar_100_pct_length=3

    # Passed parameters
    progressbar_steps_completed=$1
	progressbar_total_steps=$2
    progressbar_offset=$3
    progressbar_color=${4:-$progressbar_default_active_color}

    # Calculate the scale
    let progressbar_scale=100/$progressbar_width
    
  	# Reset (>100% scenario!)
	if [[ $progressbar_steps_completed -gt $progressbar_total_steps ]]; then
		progressbar_steps_completed=$progressbar_total_steps
	fi

	# Calculate the percentage completed
    progress_bar_pct_completed=`bc <<< "scale = 0; ($progressbar_steps_completed + $progressbar_offset) * 100 / $progressbar_total_steps / $progressbar_scale"`

    # Reset the console, backspacing operation defined by the length of the progress bar and the percentage string length
    if [[ "$progress_bar_pct_completed_charlength" != "" ]] && [[ $progress_bar_pct_completed_charlength -gt 0 ]]; then
        for (( i=1; i<=$progress_bar_pct_symbol_length; i++ )); do
            printf "\b"
        done
        for (( i=1; i<=$progress_bar_pct_completed_charlength; i++ )); do
            printf "\b"
        done
    fi

    # Calculate percentage variables
    progress_bar_pct_completed_x_scale=`bc <<< "scale = 0; ($progress_bar_pct_completed * $progressbar_scale)"`

    # Reset if the variable goes beyond the boundary values
    if [[ $progress_bar_pct_completed_x_scale -lt 0 ]]; then
        progress_bar_pct_completed_x_scale=0
    fi

    # Get the length of the current percentage
    progress_bar_pct_completed_charlength=${#progress_bar_pct_completed_x_scale}

    # Show the percentage on console, right justified
    printf "${!progressbar_color}${black}$progress_bar_pct_completed_x_scale%%${white}"

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
        printf "${!progressbar_color}"
        printf "%0.s$progressbar_color_unicode_char" $(seq 1 $progress_bar_pct_completed)
    fi

    # Show the remaining "grey" block
    if [[ $progress_bar_pct_remaining -ne 0 ]]; then
        printf "${darkgrey_bg}"
        printf "%0.s$progressbar_grey_unicode_char" $(seq 1 $progress_bar_pct_remaining)
    fi

    # Delay
    printf "${white}"
    sleep $progressbar_sleep_interval_in_secs

    # Reset the console, backspacing operation defined by the length of the progress bar.
    for (( i=1; i<=$progressbar_width; i++ )); do
        printf "\b"
    done

    # Reset the percentage variables on last iteration (i.e. when the offset is 0)
    if [[ $progressbar_offset -eq 0 ]]; then
        progress_bar_pct_completed_charlength=0
        # Remove the percentages from console
        for (( i=1; i<=$progress_bar_pct_symbol_length+$progress_bar_100_pct_length; i++ )); do
            printf "\b"
        done
    fi
}
#------
# Name: runSAS()
# Desc: This function implements the SAS job execution routine, quite an important one
#   In: (1) A SAS deployed job name        (e.g.: 99_Run_Marketing_Jobs)
#       (2) runSAS job option              (e.g.: --server)
#       (3) runSAS job sub-option          (e.g.: SASAppX)
#       (4) SASApp root directory 		   (e.g.: /SASInside/SAS/Lev1/SASApp)
#       (5) SAS BatchServer directory name (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer)
#       (6) SAS BatchServer shell script   (e.g.: sasbatch.sh)
#       (7) SAS BatchServer logs directory (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer/Logs)
#       (8) SAS deployed jobs directory    (e.g.: /SASInside/SAS/Lev1/SASApp/SASEnvironment/SASCode/Jobs)
#  Out: <NA>
#------
function runSAS(){
    # Reset the return codes
    job_rc=0
    script_rc=0

    # Increment the job counter for console display
    let job_counter_for_display+=1

    # Capture job runtime
	start_datetime_of_job_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
    start_datetime_of_job=`date +%s`

    # Set defaults if nothing is specified (i.e. just a job name is specified)
    local_sas_job="$1"
    local_sas_opt="$2"
    local_sas_subopt="$3"
    local_sas_app_root_directory="${4:-$sas_app_root_directory}"
    local_sas_batch_server_root_directory="${5:-$sas_batch_server_root_directory}"
    local_sas_sh="${6:-$sas_default_sh}"
    local_sas_logs_root_directory="${7:-$sas_logs_root_directory}"
    local_sas_deployed_jobs_root_directory="${8:-$sas_deployed_jobs_root_directory}"

    # If user has specified a different server context, switch it here
    if [[ "$local_sas_opt" == "--server" ]]; then
        if [[ "$local_sas_subopt" != "" ]]; then
            if [[ "$4" == "" ]]; then
                local_sas_app_root_directory=`echo "${local_sas_app_root_directory/$sas_app_server_name/$local_sas_subopt}"`
            fi
            if [[ "$5" == "" ]]; then
                local_sas_batch_server_root_directory=`echo "${local_sas_batch_server_root_directory/$sas_app_server_name/$local_sas_subopt}"`
            fi
            if [[ "$7" == "" ]]; then
                local_sas_logs_root_directory=`echo "${local_sas_logs_root_directory/$sas_app_server_name/$local_sas_subopt}"`
            fi
            if [[ "$8" == "" ]]; then
                local_sas_deployed_jobs_root_directory=`echo "${local_sas_deployed_jobs_root_directory/$sas_app_server_name/$local_sas_subopt}"`
            fi
        else
            printf "${yellow}WARNING: $local_sas_opt was specified for $local_sas_job job in the list without the server context name, defaulting to ${white}"
        fi
    fi

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

    # Run upto a job mode: The script will run everything (including) upto the specified job
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

    # Check if the prompt option is set by the user for the job
    if [[ "$local_sas_opt" == "--prompt" ]] || [[ "$local_sas_opt" == "-p" ]]; then
        printf "${red}Do you want to run ${darkgrey_bg}${red}$local_sas_job${end}${red} as part of this run? (Y/N): ${white}"
        stty -igncr < /dev/tty
        read run_job_with_prompt < /dev/tty
        if [[ "$job_counter_for_display" == "1" ]]; then
            printf "\n"
        fi
        if [[ $run_job_with_prompt != Y ]]; then
            write_skipped_job_details_on_screen $1
            continue
        fi
    fi

    # Check if the prompt option is set by the user for the job
    if [[ "$local_sas_opt" == "--skip" ]]; then
		write_skipped_job_details_on_screen $1
		continue
    fi

    # Display current job details on console, jobname is passed to the function
    write_current_job_details_on_screen $1

    # Check if the directory exists (specified by the user as configuration)
    check_if_the_dir_exists $local_sas_app_root_directory $local_sas_batch_server_root_directory $local_sas_logs_root_directory $local_sas_deployed_jobs_root_directory
    check_if_the_file_exists "$local_sas_batch_server_root_directory/$local_sas_sh" "$local_sas_deployed_jobs_root_directory/$local_sas_job.$program_type_ext"


    # Each job is launched as a separate process (i.e each has a PID), the script monitors the log and waits for the process to complete.
    nice -n 20 $local_sas_batch_server_root_directory/$local_sas_sh -log $local_sas_logs_root_directory/${local_sas_job}_#Y.#m.#d_#H.#M.#s.log \
                                                                    -batch \
                                                                    -noterminal \
                                                                    -logparm "rollover=session" \
                                                                    -sysin $local_sas_deployed_jobs_root_directory/$local_sas_job.$program_type_ext &

    # Count the no. of steps in the job
    total_no_of_steps_in_a_job=`grep -o 'Step:' $local_sas_deployed_jobs_root_directory/$local_sas_job.$program_type_ext | wc -l`

    # Get the PID details
    job_pid=$!
    pid_progress_counter=1
    printf "${white}with pid $job_pid${white}"
	
	# Runtime (history)
	show_job_hist_runtime_stats $1
	
	# Get PID
    ps cax | grep -w $job_pid > /dev/null
    printf "${white} ${green}"

    # Sleep between pid fetches
    sleep 0.5

    # Get the current job log filename (absolute path)
    current_log_name=`ls -tr $local_sas_logs_root_directory | tail -1`
	
    # Show current status of the run, poll for the PID and display the progress bar.
    while [ $? -eq 0 ]; do
        # Disable carriage return (ENTER key) during the script run
        stty igncr < /dev/tty

        # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
        no_of_steps_completed_in_log=`grep -o 'Step:'  $local_sas_logs_root_directory/$current_log_name | wc -l`
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job -1 $progressbar_color

        # Get runtime stats of the job
		get_job_hist_runtime_stats $local_sas_job
        hist_job_runtime_for_current_job="${hist_job_runtime:-0}"

        # Optional feature, check if the runtime is exceeding the given factor
        if [[ "$runtime_comparsion_routine" == "Y" ]] && [[ "$hist_job_runtime_for_current_job" -gt "0" ]]; then
            # Multiply the factor and see if the runtime is exceeding the runtime
            let hist_job_runtime_for_current_job_x_factor=$hist_job_runtime_for_current_job*$increase_in_runtime_factor
            current_end_datetime_of_job=`date +%s`
            let current_runtime_of_job=$current_end_datetime_of_job-$start_datetime_of_job
            # If the runtime is higher by the given factor show the warning to the user
            if [[ "$current_runtime_of_job" -gt "$hist_job_runtime_for_current_job_x_factor" ]]; then
                if [[ "$long_running_job_msg_shown" == "0" ]]; then
                    printf "${red}\nNOTE: The job is taking a bit more time than usual (previously it took $hist_job_runtime secs, it is $current_runtime_of_job secs already), Press ENTER key to continue or CTRL+C to abort this run.${white}"
                    printf "${red}\nNOTE: You can remove these warnings by setting the INCREASE_IN_RUNTIME_FACTOR parameter in the script to a high value such as 999${white}"
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
        
        # Check if there are any errors in the logs (as it updates, in real-time)
        grep -m${job_error_display_count} "$check_for_error_string" $local_sas_logs_root_directory/$current_log_name > $tmp_log_file

        # Return code check
        if [ -s $tmp_log_file ]; then
            script_rc=9
        fi

        # Check return code, abort if there's an error in the job run
        if [ $script_rc -gt 4 ]; then
            progressbar_color=red_bg
            # Refresh the progress bar
    		display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job -1 $progressbar_color
            # Optionally, abort the job run on seeing an error
            if [[ "$abort_on_error" == "Y" ]]; then
				kill $job_pid
				wait $job_pid 2>/dev/null
                break
            fi
        else
            # Reset it to the default
            progressbar_color=$default_progressbar_color
        fi
		
		# Get the PID again for the next iteration
        ps cax | grep -w $job_pid > /dev/null
    done

    # Again, suppress unwanted lines in the log (typical SAS errors!)
    remove_a_line_from_file "ERROR: Errors printed on pages" "$local_sas_logs_root_directory/$current_log_name"

    # Check if there are any errors in the logs
    let job_error_display_count_for_egrep=job_error_display_count+1
    egrep -m${job_error_display_count_for_egrep} -E --color "* $check_for_step_string|$check_for_error_string" -$job_error_display_lines_around_mode$job_error_display_lines_around_count $local_sas_logs_root_directory/$current_log_name > $tmp_log_w_steps_file

    # Job return code check (process rc)
    job_rc=$?

    # ERROR: Check return code, abort if there's an error in the job run
    if [ $script_rc -gt 4 ] || [ $job_rc -gt 4 ]; then
        # Find the last job that ran on getting an error (there can be many jobs within a job in the world of SAS)
        sed -n '1,/^ERROR:/ p' $local_sas_logs_root_directory/$current_log_name | sed 's/Job:             Sngl Column//g' | grep "Job:" | tail -1 > $job_that_errored_file

        # Format the job name for display
        sed -i 's/  \+/ /g' $job_that_errored_file
        sed -i 's/^[1-9][0-9]* \* Job: //g' $job_that_errored_file
        sed -i 's/[A0-Z9]*\.[A0-Z9]* \*//g' $job_that_errored_file

        # Display fillers (tabulated console output)
        display_message_fillers_on_console $filler_col_end_pos $filler_char 0 N 1
		
		# Capture job runtime
		end_datetime_of_job_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
        end_datetime_of_job=`date +%s`

        # Print error(s)
        printf "\b${white}${red}(FAILED rc=$job_rc-$script_rc, it took "
        printf "%04d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs. Failed on $end_datetime_of_job_timestamp)${white}\n"

        # Wrappers
        printf "${red}$console_message_line_wrappers${white}\n"

        # Depending on user setting show the log details
        if [[ "$job_error_display_steps" == "Y" ]]; then
            printf "%s" "$(<$tmp_log_w_steps_file)"
        else
            printf "%s" "$(<$tmp_log_file)"
        fi

        # Line separator
        printf "\n${red}$console_message_line_wrappers${white}\n"

        # Print last job
        printf "${red}Job: ${red}"
        printf "%s" "$(<$job_that_errored_file)"

        # Print the log filename
        printf "\n${white}${white}"
        printf "${red}Log: ${red}$local_sas_logs_root_directory/$current_log_name${white}\n" 

        # Line separator
        printf "${red}$console_message_line_wrappers${white}"
		
		# Send an error email
        runsas_error_email $job_counter_for_display $total_no_of_jobs_counter

        # Clear the session
        clear_session_and_exit
    else
        # SUCCESS: Complete the progress bar with offset 0 (fill the last bit after the step is complete)
        # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
        no_of_steps_completed_in_log=`grep -o 'Step:' $local_sas_logs_root_directory/$current_log_name | wc -l`
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job 0

        # Capture job runtime
		end_datetime_of_job_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
        end_datetime_of_job=`date +%s`

        # Store the stats for the next time
        store_job_runtime_stats $local_sas_job $((end_datetime_of_job-start_datetime_of_job)) $current_log_name $start_datetime_of_job_timestamp $end_datetime_of_job_timestamp

        # Display fillers (tabulated console output)
        display_message_fillers_on_console $filler_col_end_pos $filler_char 1

        # Success (DONE) message
        printf "\b${white}${green}(DONE rc=$job_rc-$script_rc, it took "
        printf "%04d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs. Completed on $end_datetime_of_job_timestamp)${white}\n"

        # Send an email (silently)
        runsas_job_completed_email $local_sas_job $((end_datetime_of_job-start_datetime_of_job)) $hist_job_runtime_for_current_job $job_counter_for_display $total_no_of_jobs_counter
    fi

    # Force to run in interactive mode if in run-from-to-job-interactive (-fui) mode
    if [[ "$run_from_to_job_interactive_mode" -ge "1" ]]; then
        script_mode="-i"
        run_in_interactive_mode_check
        script_mode="-fui"
    fi

    # Force to run in interactive mode if in run-from-to-job-interactive (-fuis) mode
    if [[ "$run_from_to_job_interactive_skip_mode" -eq "1" ]] || [[ "$run_from_to_job_interactive_skip_mode" -eq "2" ]]; then
        script_mode="-i"
        run_in_interactive_mode_check
        script_mode="-fuis"
    fi

    # Interactive mode: Allow the script to pause and wait for the user to press a key to continue (useful during training)
    run_in_interactive_mode_check
}
#--------------------------------------------------END OF FUNCTIONS--------------------------------------------------#

# BEGIN: The script execution begins from here.

# Github URL
runsas_github_page=http://github.com/PrajwalSD/runSAS
runsas_github_src_url=$runsas_github_page/raw/master/runSAS.sh

# Bash color codes for the console
set_colors_codes

# System parameters
runsas_allowable_parameter_count=8
debug_console_print_color=white
filler_col_end_pos=114
filler_char=.
console_message_line_wrappers=-----
specify_job_number_length_limit=3
check_for_dependencies=Y
runsas_tmp_directory=.tmp
job_counter_for_display=0
long_running_job_msg_shown=0
total_no_of_jobs_counter=`cat .job.list | wc -l`
index_mode_first_job_number=-1
index_mode_second_job_number=-1
email_attachment_size_limit_in_bytes=8000000
default_progressbar_color="green_bg"

# Timestamps
start_datetime_of_session_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
start_datetime_of_session=`date +%s`
job_stats_timestamp=`date '+%Y%m%d_%H%M%S'`

# Initialization
create_a_new_directory -p $runsas_tmp_directory

# Files
job_stats_file=$runsas_tmp_directory/.job.stats
tmp_log_file=$runsas_tmp_directory/.tmp.log
tmp_log_w_steps_file=$runsas_tmp_directory/.tmp_s.log
job_that_errored_file=$runsas_tmp_directory/.errored_job.log
email_body_msg_file=$runsas_tmp_directory/.email_body_msg.html
email_console_print_file=$runsas_tmp_directory/.email_console_print.html
job_stats_delta_file=$runsas_tmp_directory/.job_delta.stats.$job_stats_timestamp
runsas_last_job_pid_file=$runsas_tmp_directory/.runsas_last_job.pid
runsas_first_use_intro_done_file=$runsas_tmp_directory/.runsas_intro.done

# Parameters passed to this script at the time of invocation (modes etc.), set the default to 0
script_mode="$1"
script_mode_value_1="$2"
script_mode_value_2="$3"
script_mode_value_3="$4"
script_mode_value_4="$5"
script_mode_value_5="$6"
script_mode_value_6="$7"
script_mode_value_7="$8"

# Idiomatic parameter handling is done here
validate_parameters_passed_to_script $1

# Show the list, if the user wants to quickly preview before launching the script (--show or --jobs or --list)
show_the_list $1

# Check if the user wants to update the script (--update)
check_for_in_place_upgrade_request_from_user $1

# Help menu (if invoked via ./runSAS.sh --help)
print_the_help_menu $1

# Version menu (if invoked via ./runSAS.sh --version or ./runSAS.sh -v or ./runSAS.sh --v)
show_the_script_version_number $1

# Compatible version number
show_the_update_compatible_script_version_number $1

# Welcome banner
display_welcome_ascii_banner

# Dependency checks on each launch
check_dependencies ksh bc grep egrep awk sed sleep ps kill nice touch printf

# Show intro message (only shown once)
show_first_launch_intro_message

# User messages (info)
display_post_banner_messages

# Housekeeping
create_a_new_file $job_stats_file
archive_all_job_logs .job.list archives

# Print session details on console
show_server_and_user_details $1

# Check for CTRL+C and clear the session
trap clear_session_and_exit INT

# Show a warning if logged in user is root (typically "sas" must be the user for running a jobs)
check_if_logged_in_user_is_root

# Check if the user has specified a --nomail or --noemail option anywhere to override the email setting.
if [[ ${#@} -ne 0 ]]; then
    for e in "$@"
    do
        if [[ "$e" == "--noemail" ]] || [[ "$e" == "--nomail" ]]; then 
			email_alerts=NNNN
		fi
    done
fi

# Check if the user wants to run a job in adhoc mode (i.e. the job is not specified in the list)
run_a_job_mode_check

# Print job(s) list on console
print_file_content_with_index .job.list jobs

# Validate the jobs in list
validate_job_list .job.list

# Check if the user has specified a job number (/index) instead of a job name (pick the relevant job from the list) in different modes
if [[ ${#@} -ne 0 ]] && [[ "$script_mode" != "" ]] && [[ "$script_mode" != "-i" ]] && [[ "$script_mode" != "--delay" ]] && [[ "$script_mode" != "--nomail" ]] && [[ "$script_mode" != "--noemail" ]] && [[ "$script_mode" != "--update" ]]; then
	# Cycle through different states of job number variable (-1 > 0 > N), when a index is used it will be set to the index number else 0
    if [[ "$script_mode_value_1" != "" ]]; then 
		index_mode_first_job_number=0
		if [[ ${#script_mode_value_1} -lt $specify_job_number_length_limit ]]; then
			printf "\n"
			get_the_job_name_in_the_list $script_mode_value_1
			index_mode_first_job_number=$script_mode_value_1
			script_mode_value_1=$job_name_from_the_list
		else
			check_for_multiple_instances_of_job $script_mode_value_1
		fi
    fi
    if [[ "$script_mode_value_2" != "" ]]; then 
		index_mode_second_job_number=0
		if [[ ${#script_mode_value_2} -lt $specify_job_number_length_limit ]]; then
			get_the_job_name_in_the_list $script_mode_value_2
			index_mode_second_job_number=$script_mode_value_2
			script_mode_value_2=$job_name_from_the_list		
		else
			check_for_multiple_instances_of_job $script_mode_value_2
		fi
    fi
fi

# Debug mode
print_to_console_debug_only "runSAS session variables"

# Get the consent from the user to trigger the batch 
press_enter_key_to_continue 1

# Check for rogue process(es), the last known pid is checked here
check_if_there_are_any_rogue_runsas_processes

# Hide the cursor
setterm -cursor off

# Reset the prompt variable
run_job_with_prompt=N

# Check if user has specified a delayed execution
process_delayed_execution 

# Send a launch email
runsas_triggered_email $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3 $script_mode_value_4

# Run the jobs from the list one at a time (here's where everything is brought together!)
while IFS=' ' read -r job opt subopt sappdir bservdir bsh blogdir bjobdir; do
    runSAS $job $opt $subopt $sappdir $bservdir $bsh $blogdir $bjobdir
done < .job.list

# Capture session runtimes
end_datetime_of_session_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
end_datetime_of_session=`date +%s`

# Print a final message on console
printf "\n${green}The run completed on $end_datetime_of_session_timestamp and took a total of $((end_datetime_of_session-start_datetime_of_session)) seconds to complete.${white}"

# Send a success email
runsas_success_email

# Clear the run history 
if [[ "$enable_runsas_run_history" != "Y" ]]; then 
    rm -rf $job_stats_delta_file
fi

# Tidy up
rm -rf $tmp_log_file $job_that_errored_file

# END: Clear the session, reset the console
clear_session_and_exit
