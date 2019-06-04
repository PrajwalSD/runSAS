#!/bin/bash

######################################################################################################################
#                                                                                                                    #
#     Program: runSAS.sh                                                                                             #
#                                                                                                                    #
#        Desc: This script can run (and monitor) single (or batch) of SAS program(s)/Data Integration (DI) job(s).   #
#              The list of programs/jobs are provided as an input.                                                   #
#              Useful for SAS 9.x environments where a third-party job scheduler is not installed.                   #
#                                                                                                                    #
#     Version: 8.1                                                                                                   #
#                                                                                                                    #
#        Date: 04/06/2019                                                                                            #
#                                                                                                                    #
#      Author: Prajwal Shetty D                                                                                      #
#                                                                                                                    #
#       Usage: The script has many invocation/execution modes:                                                       #
#                                                                                                                    #
#              [1] Non-Interactive mode------------------: ./runSAS.sh                                               #
#              [2] Interactive mode----------------------: ./runSAS.sh -i                                            #
#              [3] Run-upto mode-------------------------: ./runSAS.sh -u    <name or index>                         #
#              [4] Run-from mode-------------------------: ./runSAS.sh -f    <name or index>                         #
#              [5] Run-a-job mode------------------------: ./runSAS.sh -o    <name or index>                         #
#              [6] Run-from-to-job mode------------------: ./runSAS.sh -fu   <name or index> <name or index>         #
#              [7] Run-from-to-job-interactive mode------: ./runSAS.sh -fui  <name or index> <name or index>         #
#              [8] Run-from-to-job-interactive-skip mode-: ./runSAS.sh -fuis <name or index> <name or index>         #
#                                                                                                                    #
#              For more details: https://github.com/PrajwalSD/runSAS/blob/master/README.md                           #
#                                                                                                                    #
#  Dependency: SAS 9.x environment (Linux) with SAS BatchServer is required at minimum for the script to work or     #
#              any equivalent (i.e. sas.sh, sasbatch.sh etc.) would work.                                            #
#              The other dependencies are automatically checked by the script during the runtime.                    #
#                                                                                                                    #
#      Github: https://github.com/PrajwalSD/runSAS (Grab the latest version: ./runSAS.sh --update)                   #
#                                                                                                                    #
######################################################################################################################
#<
#------------------------USER CONFIGURATION: Set the parameters below as per the environment-------------------------#
#
# 1/4: Set the SAS 9.x environment parameter
#      Setting the first parameter should work but amend the rest as per the environment
#
sas_app_root_directory="/SASInside/SAS/Lev1/SASApp"
sas_batch_server_root_directory="${sas_app_root_directory}/BatchServer"
sas_logs_root_directory="${sas_app_root_directory}/BatchServer/Logs"
sas_deployed_jobs_root_directory="${sas_app_root_directory}/SASEnvironment/SASCode/Jobs"
sas_batch_sh="sasbatch.sh"
sas_sh="sas.sh"
#
# 2/4: Provide a list of SAS program(s) or SAS Data Integration Studio job(s), do not include ".sas" in the file name
#      You can add --prompt next to the job name to halt the script and allow the user to optionally skip a job during the runtime
#
cat << EOF > .job.list
XXXXX --prompt
YYYYY
EOF
#
# 3/4: Change default behaviors, defaults have been set by the developer, change them as per the needs
#
run_in_debug_mode=N                    # Default is N        ---> Set this to Y to turn on debugging mode
runtime_comparsion_routine=Y           # Default is Y        ---> Set this N to turn off job runtime checks
increase_in_runtime_factor=50          # Default is 50       ---> This is used in determining the runtime changes between runs (to a last successful run only)
job_error_display_count=1              # Default is 1        ---> This will restrict the error log display to the x no. of error(s) in the log
job_error_display_steps=N              # Default is Y        ---> This will show more details when a job fails, it can be a page long output
job_error_display_lines_around_count=1 # Default is 1        ---> This will allow you to increase or decrease how much is shown from the log
job_error_display_lines_around_mode=a  # Default is a        ---> These are grep arguements, a=after error, b=before error, c=after & before
kill_process_on_user_abort=Y           # Default is Y        ---> The rogue processes are automatically killed by the script on user abort.
program_type_ext=sas                   # Default is sas      ---> Do not change this. 
check_for_error_string="^ERROR"        # Default is "^ERROR" ---> Change this to the locale setting
check_for_step_string="Step:"          # Default is "Step:"  ---> Change this to the locale setting
#
# 4/4: Do not change this unless asked by the developer
#
runsas_github_url=http://github.com/PrajwalSD/runSAS/raw/master/runSAS.sh
#
#--------------------------------------DO NOT CHANGE ANYTHING BELOW THIS LINE----------------------------------------#
#>
# FUNCTIONS: User defined functions are defined here.
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
|r|u|n|S|A|S| |v|8|.|1|
+-+-+-+-+-+-+ +-+-+-+-+
|P|r|a|j|w|a|l|S|D|
+-+-+-+-+-+-+-+-+-+
EOF
printf "\n${white}"
}
#------
# Name: show_the_script_version_number()
# Desc: Displays version number (--version or -v or --v)
#   In: <NA>
#  Out: <NA>
#------
function show_the_script_version_number(){
    if [[ ${#@} -ne 0 ]] && ([[ "${@#"--version"}" = "" ]] || [[ "${@#"-v"}" = "" ]] || [[ "${@#"--v"}" = "" ]]); then
        printf "${blue}runSAS 8.1\n${white}"
        exit 0;
    fi;
}
#------
# Name: print_the_help_menu()
# Desc: Displays help menu (--help)
#   In: <NA>
#  Out: <NA>
#------
function print_the_help_menu(){
    if [[ ${#@} -ne 0 ]] && [[ "${@#"--help"}" = "" ]]; then
        printf "${blue}"
        printf "${underline}"
        printf "\nNAME\n"
        printf "${end}${blue}"
        printf "\n       runSAS.sh                  This script can run (and monitor) single (or batch) of SAS program(s)/Data Integration (DI) job(s)."
        printf "${underline}"
        printf "\n\nSYNOPSIS\n"
        printf "${end}${blue}"
        printf "\n       runSAS.sh [script-mode] [optional-script-mode-value-1] [optional-script-mode-value-2]"
        printf "${underline}"
        printf "\n\nDESCRIPTION\n"
        printf "${end}${blue}"
        printf "\n      There are various [script-mode] in which you can launch runSAS, see below.\n"
        printf "\n      -i                          The script will halt after running each job, waiting for an ENTER key to continue"
        printf "\n      -u    <job-name>            The script will run everything (and including) upto the specified job.t"
        printf "\n      -f    <job-name>            The script will run from (and including) a specified job."
        printf "\n      -o    <job-name>            The script will run a specified job."
        printf "\n      -fu   <job-name> <job-name> The script will run from one job upto the other job."
        printf "\n      -fui  <job-name> <job-name> The script will run from one job upto the other job, but in an interactive mode (runs the rest in a non-interactive mode)"
        printf "\n      -fuis <job-name> <job-name> The script will run from one job upto the other job, but in an interactive mode (skips the rest)"
        printf "\n     --update                     The script will update itself to the latest version from Github"
        printf "\n     --jobs or --show             The script will show a list of job(s) provided by the user in the script (quick preview)"
        printf "\n     --help                       Display this help and exit"
        printf "\n"
        printf "\n       Tip #1: You can use <job-index> instead of a <job-name> (e.g.: ./runSAS.sh -fu 1 3 instead of ./runSAS.sh -fu jobA jobC).   "
        printf "\n       Tip #2: You can add --prompt option against job(s) when you provide a list, this will halt the script during runtime for the user confirmation."
        printf "${underline}"
        printf "\n\nAUTHOR\n"
        printf "${end}${blue}"
        printf "\n       Written by Prajwal Shetty D"
        printf "${underline}"
        printf "\n\nBUGS\n"
        printf "${end}${blue}"
        printf "\n       Report bug(s) to prajwalsd@github\n"
        printf "${underline}"
        printf "\nGITHUB\n"
        printf "${end}${blue}"
        printf "\n       Repo: https://github.com/PrajwalSD/runSAS\n"
        printf "\n       To get the latest version of runSAS you can use the auto-update option: ./runSAS.sh --update \n\n"
        printf "${white}"
        exit 0;
    fi;
}
#------
# Name: validate_parameters_passed_to_script()
# Desc: This function validates the script parameters 
#   In: <NA>
#  Out: <NA>
#------
function validate_parameters_passed_to_script(){
    while test $# -gt 0
    do
        case "$1" in
        --help) ;;
     --version) ;;
      --update) ;;
        --jobs) ;;
         --job) ;;
        --show) ;;
        --list) ;;
            -v) ;;
           --v) ;;
            -i) ;;
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
# Name: show_the_list()
# Desc: Displays the list of jobs/programs in the script (quick preview)
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
# Desc: Set different bash color codes, reference: https://misc.flogisoft.com/bash/tip_colors_and_formatting
#   In: <NA>
#  Out: <NA>
#------
function set_colors_codes(){
    black=$'\e[30m'
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
    printf "${white}The script has many modes of execution, ./runSAS.sh --help to see more details.${white}\n"
}
#------
# Name: check_dependencies()
# Desc: Check if the dependencies have been installed (auto install is supported only via yum for now).
#   In: program-name or package-name (multiple inputs could be specified)
#  Out: <NA>
#------
function check_dependencies(){
    if [[ "$check_for_dependencies" == "Y" ]]; then
        for prg in "$@"
        do
            # Defaults
            package_installer=yum
            check_dependency_cmd=`which $prg`
            # Check
            printf "${white}"
            if [[ -z "$check_dependency_cmd" ]]; then
                printf "${red}\n*** ERROR: Dependency checks failed, ${white}${red_bg}$prg${white}${red} program is not found, runSAS requires this program to run. *** \n"
                # If the package installer is available try installing the missing dependency
                if [[ ! -z `which $package_installer` ]]; then
                    printf "${green}\nPress Y to auto install $prg (requires $package_installer and sudo access if you're not root): ${white}"
                    read read_install_dependency
                    if [[ "$read_install_dependency" == "Y" ]]; then
                        printf "${white}\nAttempting to install $prg, running ${green}sudo yum install $prg${white}...\n${white}"
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
# Desc: Auto updates the runSAS script from Github version
#   In: <NA>
#  Out: <NA>
#------
function runsas_script_auto_update(){

# Generate a backup name and folder
runsas_backup_script_name=runSAS.sh.$(date +"%Y%m%d_%H%M%S")

# Create backup folder
create_a_directory backups

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
if ! wget -O .runSAS.sh.downloaded $runsas_github_url; then
    printf "${red}*** ERROR: Could not download the new version of runSAS from Github using wget, possibly due to server restrictions or internet connection issues or the server has timed-out ***\n${white}"
    clear_session_and_exit
fi
printf "${green}NOTE: Download complete.\n${white}"
sleep 0.5

# Fix perms (775 is the default!)
chmod 775 .runSAS.sh.downloaded
dos2unix .runSAS.sh.downloaded

# Show the version numbers 
printf "${green}\nCurrent version: ${white}"
./runSAS.sh --version > .runSAS.sh.ver
cat .runSAS.sh.ver
rm -rf .runSAS.sh.ver
printf "${green}New version: ${white}"
./.runSAS.sh.downloaded --version > .runSAS.sh.downloaded.ver
cat .runSAS.sh.downloaded.ver
rm -rf .runSAS.sh.downloaded.ver

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

press_enter_key_to_continue
   
# Handover the execution
exec /bin/bash .runSAS_update.sh

# Exit
exit 0
} 
#------
# Name: check_for_update_request_from_user()
# Desc: Check if the user is requesting an update
#   In: --update
#  Out: <NA>
#------
function check_for_update_request_from_user(){
    if [[ "$1" == "--update" ]]; then
        printf "${red}Press Y to confirm: ${white}"
        read read_auto_update_confirmation
        if [[ "$read_auto_update_confirmation" == "Y" ]]; then
            runsas_script_auto_update
        else
            printf "Cancelled.\n"
            exit 0
        fi
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
# Name: create_a_directory()
# Desc: Create a directory if it doesn't exist
#   In: directory-name (multiple could be specified)
#  Out: <NA>
#------
function create_a_directory(){
    for dir in "$@"
    do
        if [[ ! -d "$dir" ]]; then
            printf "${green}NOTE: Creating a directory named $dir in `pwd`...${white}"
            mkdir -p $dir
            printf "${green}DONE\n${white}"
        fi
    done
}
#------
# Name: check_if_logged_in_user_is_root()
# Desc: User login check
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
# Name: run_in_interactive_mode_check()
# Desc:  Interactive mode (-i)
#   In: <NA>
#  Out: <NA>
#------
function run_in_interactive_mode_check(){
    if [[ "$script_mode" == "-i" ]] && [[ "$escape_interactive_mode" != "1" ]]; then
        interactive_mode=1
        printf "${red_bg}Press ENTER key to continue OR type E to escape the interactive mode${white} "
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
# Desc: Run upto mode (-u)
#   In: <NA>
#  Out: <NA>
#------
function run_until_a_job_mode_check(){
    if [[ "$script_mode" == "-u" ]]; then
        if [[ "$script_mode_value" == "0" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode (run-upto-a-job) mode, a job name is also required after $script_mode option ***${white}"
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
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-a-job) mode, a job name is also required after $script_mode option ***${white}"
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
            printf "${red}*** ERROR: You launched the script in $script_mode(run-a-single-job) mode, a job name is also required after $script_mode option ***${white}"
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
# Desc: Run from a job to a job mode (-fu)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_mode_check(){
    if [[ "$script_mode" == "-fu" ]]; then
        if [[ "$script_mode_value" == "0" ]] || [[ "$script_mode_value_other" == "0" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-to-job) mode, two job names (separated by spaces) are also required after $script_mode option ***${white}"
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
# Desc: Run from a job to a job mode in interactive mode (-fui)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_interactive_mode_check(){
    if [[ "$script_mode" == "-fui" ]]; then
        if [[ "$script_mode_value" == "0" ]] || [[ "$script_mode_value_other" == "0" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-to-job-interactive) mode, two job names (separated by spaces) are also required after $script_mode option ***${white}"
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
# Desc: Run from a job to a job mode in interactive mode (-fuis)
#   In: <NA>
#  Out: <NA>
#------
function run_from_to_job_interactive_skip_mode_check(){
    if [[ "$script_mode" == "-fuis" ]]; then
        if [[ "$script_mode_value" == "0" ]] || [[ "$script_mode_value_other" == "0" ]]; then
            printf "${red}*** ERROR: You launched the script in $script_mode(run-from-to-job-interactive-skip) mode, two job names (separated by spaces) are also required after $script_mode option ***${white}"
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
                stty igncr < /dev/tty
                printf "${yellow}---\n"
                ps $1 # Show process details
                printf "${yellow}---\n${white}"
                kill -9 $1
                printf "${green}\nCleaning up, please wait...${white}"
                sleep 2
                if [[ -z `ps -p $1 -o comm=` ]]; then
                    printf "${green}\n\nThe last job process launched by runSAS with pid $1 has been terminated successfully!\n\n${white}"
                else
                    printf "${red}\n\n*** ERROR: Attempt to kill the last job process launched by runSAS with pid $1 did not go very well. It is likely to be the permission issue (sudo?) or the process has terminated already *** \n\n${white}"
                fi
                stty -igncr < /dev/tty
            else
                printf "${yellow}\nWARNING: The last process launched by runSAS with pid $1 is still running in the background, terminate it manually using ${green}kill -9 $1${white} command.\n\n${white}"
            fi
        fi
    fi
}
#------
# Name: check_if_there_are_any_rogue_runsas_processes()
# Desc: Check if there are any rogue processes, display a warning and abort the script based on the user input
#   In: <NA>
#  Out: <NA>
#------
function check_if_there_are_any_rogue_runsas_processes(){
    process_srch_str=`echo "$sas_logs_root_directory" | sed "s/^.\(.*\)/[\/]\1/"`
    if [ `ps -ef | grep $process_srch_str | wc -l` -gt 0 ]; then
        printf "${yellow}\nWARNING: There is a server process that has not completed/terminated, proceeding without terminating these processes may cause issues in current run.\n${white}"
        printf "${yellow}---\n${green}"
        ps -ef | grep $process_srch_str
        printf "${yellow}---\n\n${white}"
        printf "${yellow}Do you want to ignore this and continue...? (Press N or CTRL+C to abort this session) ${white}"
        read ignore_process_warning
        if [[ "$ignore_process_warning" == "N" ]]; then
            printf "${red}runSAS session has been terminated by the user.${white}"
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
    terminate_running_processes $job_pid
    printf "${green}runSAS is exiting now, session has been cleared.${white}\n\n"
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
# Name: press_enter_key_to_continue()
# Desc: This function will pause the script and wait for the ENTER key to be pressed
#   In: <ENTER-KEY>
#  Out: enter_to_continue_user_input
#------
function press_enter_key_to_continue(){
    printf "\n"
    printf "${green}Press the ENTER key to continue or CTRL+C to abort the session...${white}"
    read enter_to_continue_user_input
}
#------
# Name: print_job_list()
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
# Name: create_a_new_file()
# Desc: This function will create a new file, that's all.
#   In: <file-name> (multiple files can be provided)
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
# Name: show_server_and_user_details()
# Desc: This function will show details about the server and the user
#   In: <file-name> (multiple files can be provided)
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
#   In: steps-completed, total-steps, offset
#  Out: <NA>
#------
function display_progressbar_with_offset(){
    # Defaults
    progressbar_width=20
    progressbar_green_unicode_char=" "
    progressbar_grey_unicode_char=" "
    progressbar_sleep_interval_in_secs=0.5

    # Defaults for percentages shown on the console
    progress_bar_pct_symbol_length=1
    progress_bar_100_pct_length=3

    # Passed parameters
    progressbar_steps_completed=$1
	progressbar_total_steps=$2
    progressbar_offset=$3

    # Calculate the scale
    let progressbar_scale=100/$progressbar_width

	# Calculate the perecentage completed
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

    # Show the percentage on console, right justfied
    printf "${green_bg}${black}$progress_bar_pct_completed_x_scale%%${white}"

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
        printf "${green_bg}"
        printf "%0.s$progressbar_green_unicode_char" $(seq 1 $progress_bar_pct_completed)
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
#   In: (1) A SAS deployed job name        (e.g: 99_Run_Marketing_Jobs)
#       (2) SAS BatchServer directory name (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer)
#       (3) SAS BatchServer shell script   (e.g.: sasbatch.sh)
#       (4) SAS BatchServer logs directory (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer/Logs)
#       (5) SAS deployed jobs directory    (e.g.: /SASInside/SAS/Lev1/SASApp/SASEnvironment/SASCode/Jobs)
#  Out: <NA>
#------
function runSAS(){
    # Reset the return codes
    job_rc=0
    script_rc=0

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
    if [[ "$opt" == "--prompt" ]] || [[ "$opt" == "-p" ]]; then
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

    # Display current job details on console, jobname is passed to the function
    write_current_job_details_on_screen $1

    # Each job is launched as a separate process (i.e each has a PID), the script monitors the log and waits for the process to complete.
    nice -n 20 $local_sas_batch_server_root_directory/$local_sas_batch_sh -log $local_sas_logs_root_directory/${local_sas_job}_#Y.#m.#d_#H.#M.#s.log \
                                                                          -batch \
                                                                          -noterminal \
                                                                          -logparm "rollover=session" \
                                                                          -sysin $local_sas_deployed_jobs_root_directory/$local_sas_job.$program_type_ext &

    # Count the no. of steps in the job
    total_no_of_steps_in_a_job=`grep -o 'Step:'  $local_sas_deployed_jobs_root_directory/$local_sas_job.$program_type_ext | wc -l`

    # Get the PID details
    job_pid=$!
    pid_progress_counter=1
    printf "${white}with pid $job_pid${white}"
    ps cax | grep $job_pid > /dev/null
    printf "${white} ${green}"

    # Sleep before pid fetch
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

        # Get the PID again for the next iteration
        ps cax | grep $job_pid > /dev/null
    done

    # Suppress unwanted lines in the log (typical SAS errors!)
    remove_a_line_from_file "ERROR: Errors printed on pages" "$sas_logs_root_directory/$current_log_name"

    # Check if there are any errors in the logs
    let job_error_display_count_for_egrep=job_error_display_count+1
    grep -m${job_error_display_count} "$check_for_error_string" $sas_logs_root_directory/$current_log_name > $tmp_log_file
    egrep -m${job_error_display_count_for_egrep} -E --color "* $check_for_step_string|$check_for_error_string" -$job_error_display_lines_around_mode$job_error_display_lines_around_count $sas_logs_root_directory/$current_log_name > $tmp_log_w_steps_file

    # Return code check
    job_rc=$?
    script_rc=$job_rc
    if [ -s $tmp_log_file ]; then
        script_rc=900
    fi

    # Check return code, abort if there's an error
    if [ $script_rc -gt 4 ]; then
        # Find the last job that ran on getting an error (there can be many jobs within a job in the world of SAS)
        sed -n '1,/^ERROR:/ p' $sas_logs_root_directory/$current_log_name | sed 's/Job:             Sngl Column//g' | grep "Job:" | tail -1 > $job_that_errored_file

        # Format the job name for display
        sed -i 's/  \+/ /g' $job_that_errored_file
        sed -i 's/^[1-9][0-9]* \* Job: //g' $job_that_errored_file
        sed -i 's/[A0-Z9]*\.[A0-Z9]* \*//g' $job_that_errored_file

        # Print error(s)
        printf "${white}${red} *** ERROR: Job has failed with rc=$job_rc-$script_rc, details below. Failed on `date '+%Y-%m-%d %H:%M:%S'` ***${white}\n"
        printf "${red}$log_block_wrapper${white}\n"

        # Depending on user setting show the log details
        if [[ "$job_error_display_steps" == "Y" ]]; then
            printf "%s" "$(<$tmp_log_w_steps_file)"
        else
            printf "%s" "$(<$tmp_log_file)"
        fi

        # Line separator
        printf "\n${red}$log_block_wrapper${white}\n"

        # Print last job
        printf "${red}Job: ${red}"
        printf "%s" "$(<$job_that_errored_file)"

        # Print the log filename
        printf "\n${white}${white}"
        printf "${red}Log: ${red}$sas_logs_root_directory/$current_log_name${white}\n"

        # Line separator
        printf "${red}$log_block_wrapper${white}"

        # Clear the session
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
        for (( k=1; k<=$buff_to_fix_col; k++ )); do
            printf "$filler_char"
        done

        # Success (DONE) message
        printf "\b${white}${green}(DONE rc=$job_rc-$script_rc, it took "
        printf "%03d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs. Completed on `date '+%Y-%m-%d %H:%M:%S'`)${white}\n"
    fi

    # Forece to run in interactive mode if in run-from-to-job-interactive (-fui) mode
    if [[ "$run_from_to_job_interactive_mode" -ge "1" ]]; then
        script_mode="-i"
        run_in_interactive_mode_check
        script_mode="-fui"
    fi

    # Forece to run in interactive mode if in run-from-to-job-interactive (-fuis) mode
    if [[ "$run_from_to_job_interactive_skip_mode" -eq "1" ]] || [[ "$run_from_to_job_interactive_skip_mode" -eq "2" ]]; then
        script_mode="-i"
        run_in_interactive_mode_check
        script_mode="-fuis"
    fi

    # Interactive mode: Allow the script to pause and wait for the user to press a key to continue (useful during training)
    run_in_interactive_mode_check
}
#--------------------------------------------------END OF FUNCTIONS--------------------------------------------------#
#
# BEGIN: The script execution begins from here...
#

# Bash color codes for the console
set_colors_codes

# System parameters
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

# Capture session runtimes
start_datetime_of_session=`date +%s`

# Idiomatic parameter handling
validate_parameters_passed_to_script $1

# Show the list if the user wants to quickly preview before launching the script (--show or --jobs or --list)
show_the_list $1

# Check if the user wants to update the script (--update)
check_for_update_request_from_user $1

# Help menu (if invoked via ./runSAS.sh --help)
print_the_help_menu $1

# Version menu (if invoked via ./runSAS.sh --version or ./runSAS.sh -v or ./runSAS.sh --v)
show_the_script_version_number $1

# Welcome banner
display_welcome_ascii_banner

# Dependency checks on each launch
check_dependencies ksh bc grep egrep awk sed sleep ps kill nice touch printf

# Check if the directory and file exists (specified by the user as configuration)
check_if_the_dir_exists $sas_app_root_directory $sas_batch_server_root_directory $sas_logs_root_directory $sas_deployed_jobs_root_directory

# Information for the user
display_post_banner_messages

# Housekeeping
create_a_new_file $job_stats_file
move_files_to_a_directory $sas_logs_root_directory/*.log $sas_logs_root_directory/archives

# Print session details on console
show_server_and_user_details $1

# Print job(s) list on console
print_file_content_with_index .job.list jobs

# Check for CTRL+C and clear the session
trap clear_session_and_exit INT

# Show a warning if logged in user is root (typically "sas" must be the user for running a jobs)
check_if_logged_in_user_is_root

# Check if there are rogue processes from last run, show the warning.
check_if_there_are_any_rogue_runsas_processes

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

# Get the consent from the user to trigger the batch
press_enter_key_to_continue
printf "\n"

# Hide the cursor
setterm -cursor off

# Reset the prompt variable
run_job_with_prompt=N

# Run the jobs from the list one at a time
while IFS=' ' read -r job opt; do
    runSAS $job
done < .job.list

# Capture session runtimes
end_datetime_of_session=`date +%s`

# Tidying up
rm -rf $tmp_log_file $job_that_errored_file

# Print a final message on console
printf "\n${green}The run completed on `date '+%Y-%m-%d %H:%M:%S'` and took a total of $((end_datetime_of_session-start_datetime_of_session)) seconds to complete.${white}"

# END: Clear the session, reset the console
clear_session_and_exit
