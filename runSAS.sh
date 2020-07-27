#!/bin/bash
#
######################################################################################################################
#                                                                                                                    #
#     Program: runSAS.sh                                                                                             #
#                                                                                                                    #
#        Desc: A simple SAS Data Integration Studio job flow execution script                                        #
#                                                                                                                    #
#     Version: 40.8                                                                                                  #
#                                                                                                                    #
#        Date: 27/07/2020                                                                                            #
#                                                                                                                    #
#      Author: Prajwal Shetty D                                                                                      #
#                                                                                                                    #
#       Usage: ./runSAS.sh --help                                                                                    #
#                                                                                                                    #
#        Docs: https://github.com/PrajwalSD/runSAS/blob/master/README.md                                             #
#                                                                                                                    #
#  Dependency: SAS 9.x (Linux) bash environment with SAS BatchServer (or an equivalent), other minor dependencies    #
#              are automatically checked by the script during the runtime.                                           #
#                                                                                                                    #
#      Github: https://github.com/PrajwalSD/runSAS (Grab the latest version automatically: ./runSAS.sh --update)     #
#                                                                                                                    #
######################################################################################################################
#<
#------------------------USER CONFIGURATION: Set the parameters below as per the environment-------------------------#
#
# 1/4: Set SAS 9.x environment related parameters.
#      Ideally, setting just the first four parameters should work but amend the rest if needed as per the environment
#      Always enclose the value with double-quotes (NOT single-quotes, everything is case-sensitive)
#
SAS_HOME_DIRECTORY="/SASInside/SASHome"
SAS_INSTALLATION_ROOT_DIRECTORY="/SASInside/SAS"
SAS_APP_SERVER_NAME="SASApp"
SAS_LEV="Lev1"
SAS_DEFAULT_SH="sasbatch.sh"
SAS_APP_ROOT_DIRECTORY="$SAS_INSTALLATION_ROOT_DIRECTORY/$SAS_LEV/$SAS_APP_SERVER_NAME"
SAS_BATCH_SERVER_ROOT_DIRECTORY="$SAS_APP_ROOT_DIRECTORY/BatchServer"
SAS_LOGS_ROOT_DIRECTORY="$SAS_APP_ROOT_DIRECTORY/BatchServer/Logs"
SAS_DEPLOYED_JOBS_ROOT_DIRECTORY="$SAS_APP_ROOT_DIRECTORY/SASEnvironment/SASCode/Jobs"
#
# 2/4: Provide a list of flow and jobs to execute in the format given below (no whitespaces), optional fields must be appended to the mandatory inputs in a single line
# 
#      MANDATORY: flow-id | flow-nm | job-id | job-nm | dependent-job-id (delimted by comma or a range) | dependency-type (AND/OR) | job-rc-max | job-run-flag 
#       OPTIONAL: options (--prompt/--server) |sub-options | sasapp-dir | batchserver-dir | sas-sh | log-dir | job-dir |
#
cat << EOF > .job.list
1|Flow_A|1|Job_1|1|AND|4|Y|
1|Flow_A|2|Job_2|2|AND|0|Y|
1|Flow_A|3|Job_3|3|AND|4|Y|
2|Flow_B|4|Job_4|1-2,3|AND|4|Y|
2|Flow_B|5|Job_5|5|AND|4|Y|
3|Flow_C|6|Job_6|6|AND|4|Y|
4|Flow_D|7|Job_7|7|AND|4|Y|
4|Flow_D|8|Job_8|8|AND|4|Y|
4|Flow_D|9|Job_9|9|AND|4|Y|
5|Flow_E|10|Job_10|10|AND|4|Y|
5|Flow_E|11|Job_11|11|AND|4|Y|
5|Flow_E|12|Job_12|12|AND|4|Y|
EOF
#
# 3/4: Email alerts, set the first parameter to N to turn off this feature.
#      Uses "sendmail" program to send email (installs it if not found in the server)
#      If you don't receive emails from the server, add <logged-in-user>@<server-full-name> (e.g.: sas@sasserver.demo.com) to your email client whitelist.
#
ENABLE_EMAIL_ALERTS=N                                  	                # Default is N                    ---> "Y" to enable all 4 alert types (YYYY is the extended format, <trigger-alert><job-alert><error-alert><completion-alert>)
EMAIL_ALERT_TO_ADDRESS=""                                               # Default is ""                   ---> Provide email addresses separated by a semi-colon
EMAIL_ALERT_USER_NAME="runSAS"                                          # Default is "runSAS"             ---> This is used as FROM address for the email alerts                          
#
# 4/4: Script behaviors, defaults should work just fine but amend as per the environment needs.
#
ENABLE_DEBUG_MODE=N                                                     # Default is N                    ---> Enables the debug mode, specifiy Y/N
RUNTIME_COMPARISON_FACTOR=30                                            # Default is 30                   ---> This is the factor used by job run times comparison module to display a % difference, specify a positive number
KILL_PROCESS_ON_USER_ABORT=Y                                            # Default is Y                    ---> The rogue processes are automatically killed by the script on user abort.
ERROR_CHECK_SEARCH_STRING="^ERROR"                                      # Default is "^ERROR"             ---> This is what is grepped in the log
STEP_CHECK_SEARCH_STRING="Step:"                                        # Default is "Step:"              ---> This is searched for the step in the log
SASTRACE_SEARCH_STRING="^options sastrace"                              # Default is "^options sastrace"  ---> This is used for searching the sastrace option in SAS log
ENABLE_RUNSAS_RUN_HISTORY=Y                                             # Default is Y                    ---> Enables runSAS script history, specify Y/N
ABORT_ON_ERROR=N                                                        # Default is N                    ---> Set to Y to abort as soon as runSAS sees an ERROR in the log file (i.e don't wait for the job to complete)
ENABLE_SASTRACE_IN_JOB_CHECK=Y                                          # Default is Y                    ---> Set to N to turn off the warnings on sastrace
ENABLE_RUNSAS_DEPENDENCY_CHECK=Y                                        # Default is Y                    ---> Set to N to turn off the script dependency checks 
BATCH_HISTORY_PERSISTENCE=ALL                                           # Default is ALL                  ---> Specify a postive number to control the number of batches preserved by runSAS  (e.g. 50 will preserve last 50 runs)
CONCURRENT_JOBS_LIMIT=ALL                                               # Default is ALL                  ---> Specify the available job slots as a number (e.g. 2), "ALL" will use the CPU count instead (nproc --all) and "MAX" will spawn all jobs
CONCURRENT_JOBS_LIMIT_MULTIPLIER=1                                      # Default is 1                    ---> Specify a positive number to increase the available job slots (e.g. 1x, 2x, 3x...), will be used a multiplier to the above parameter
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
printf "\n${green}"
cat << EOF
             _____ _____ _____ 
 ___ _ _ ___|   __|  _  |   __|
|  _| | |   |__   |     |__   |
|_| |___|_|_|_____|__|__|_____| v$RUNSAS_CURRENT_VERSION

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
	# Current version & compatible version for update
	RUNSAS_CURRENT_VERSION=40.8
	RUNSAS_IN_PLACE_UPDATE_COMPATIBLE_VERSION=40.0

    # Show version numbers
    if [[ ${#@} -ne 0 ]] && ([[ "${@#"--version"}" = "" ]] || [[ "${@#"-v"}" = "" ]] || [[ "${@#"--v"}" = "" ]]); then
        printf "$RUNSAS_CURRENT_VERSION"
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
        printf "$RUNSAS_IN_PLACE_UPDATE_COMPATIBLE_VERSION"
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
        printf "\n       runSAS.sh [script-mode] [optional-script-mode-value-1] [optional-script-mode-value-2] ..."
        printf "${underline}"
        printf "\n\nDESCRIPTION\n"
        printf "${end}${blue}"
        printf "\n       There are various [script-mode] in runSAS:\n"
        printf "\n        -i    --byflow (optional)         runSAS will run the batch jobs in sequential mode, waiting for an ENTER key to continue after each mode. If you specify --byflow, the batch will pause after each flow"
        printf "\n        -j    <job-name>                  runSAS will run a specified job even if it is not in the job list (adhoc mode, run any job using runSAS)"
        printf "\n        -u    <job-id>                    runSAS will run everything (and including) upto the specified job"
        printf "\n        -f    <job-id>                    runSAS will run from (and including) a specified job."
        printf "\n        -o    <job-id>                    runSAS will run a specified job from the job list."
        printf "\n        -s    <job-id> <job-id>           runSAS will skip these jobs from running"
        printf "\n        -fu   <job-id> <job-id>           runSAS will run from one job upto the other job."
        printf "\n        -fui  <job-id> <job-id>           runSAS will run from one job upto the other job, but in an interactive mode (runs the rest in a non-interactive mode)"
        printf "\n        -fuis <job-id> <job-id>           runSAS will run from one job upto the other job, but in an interactive mode (skips the rest)"
        printf "\n       --update                           runSAS will update itself to the latest version from Github (internet required), if you want to force an update on version mismatch use --force"
        printf "\n       --delay <time-in-seconds>          runSAS will launch after a specified time delay in seconds"
        printf "\n       --list                             runSAS will show a list of job(s) provided by the user in the script (quick preview)"
        printf "\n       --log or --last                    runSAS will show the last script run details"
        printf "\n       --reset                            runSAS will remove temporary files. To only reset the batch id append --batchid to the --reset option (i.e. ./runSAS.sh --reset --batchid)"
        printf "\n       --parms                            runSAS will show the user & script parameters"
        printf "\n       --redeploy <jobs-file>             runSAS will redeploy the jobs specified in the <jobs-file>, job filters (name or index) can be added after <jobs-file> or you can specify filters after the launch too."
        printf "\n       --joblist  <jobs-file>             runSAS will override the embedded jobs with the jobs specified in <jobs-file>. Suffix this option with filters (e.g.: ./runSAS.sh -fu 1 2 --joblist jobs.txt)"
        printf "\n       --resume   <batchid>               runSAS can resume a failed batch using this option, state of the batch will automatically be restored (e.g. ./runSAS.sh --resume <batchid>"
        printf "\n       --batch                            runSAS can be launched in batch mode (i.e. non-interactive mode) for easy scheduling, just append --batch to the launch command (e.g. ./runSAS.sh -fu 2 3 --batch)"
        printf "\n       --help                             Display this help and exit"
        printf "\n"
        printf "\n       Tip #1: You can add --prompt option against job(s) when you provide a list, this will halt the script during runtime for the user confirmation."
        printf "\n       Tip #2: You can add --noemail option during the launch to override the email setting during runtime (useful for one time runs etc.)"        
		printf "\n       Tip #3: You can append --server option followed by server parameters (syntax: ... --server <sas-server-name><sasapp-dir><batch-server-dir><sas-sh><logs-dir><deployed-jobs-dir>)" 
        printf "\n       Tip #4: You can add --email <email-address> option during the launch to override the email address setting during runtime (must be added at the end of all arguments)"        
        printf "\n       Tip #5: You can add --message option during the launch for an additional user message for the batch (useful for tagging the batch runs)"        
        printf "\n       Tip #6: You can add --nocolors option during the launch to remove color highlighting in --batch mode"        
        printf "\n       Tip #7: To schedule runSAS in Crontab just use the --batch mode with other options e.g.: nohup ./runSAS.sh -fu 1 20 --batch --nocolors &"        
        printf "${underline}"
        printf "\n\nVERSION\n"
        printf "${end}${blue}"
        printf "\n       $RUNSAS_CURRENT_VERSION (auto-update compatible version: $RUNSAS_IN_PLACE_UPDATE_COMPATIBLE_VERSION)"
		printf "${underline}"
        printf "\n\nAUTHOR\n"
        printf "${end}${blue}"
        printf "\n       Written by Prajwal Shetty D (GPL v3 license)"
        printf "${underline}"
        printf "\nGITHUB\n"
        printf "${end}${blue}"
        printf "\n       $RUNSAS_GITHUB_PAGE "
        printf "(To get the latest version of the runSAS you can use the in-place upgrade option: ./runSAS.sh --update)\n\n"
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
    --redeploy) ;;
       --reset) ;;
       --parms) ;;
       --batch) ;;
    --nocolors) ;;
      --resume) ;;
  --parameters) ;;
    --update-c) ;;
        --list) ;;
     --joblist) ;;
     --message) ;;
       --email) ;;
         --log) ;;
        --last) ;;
      --byflow) ;;
            -v) ;;
           --v) ;;
            -i) ;;
            -s) ;;
            -j) ;;
            -o) ;;
            -f) ;;
            -u) ;;
           -fu) ;;
          -fui) ;;
         -fuis) ;;
             *) printf "${red}\n*** ERROR: ./runSAS.sh ${white}${red_bg}$1${white}${red} is invalid, see --help menu below for available options ***\n${white}"
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
     if [[ ! -f $RUNSAS_FIRST_USER_INTRO_DONE_FILE ]]; then
        printf "${blue}Welcome, this is a first launch of runSAS script post installation (or update), so let's quickly check few things. \n\n${end}" 
        printf "${blue}runSAS essentially requires two things and they are set inside the script (set them if it is not done already): \n\n${end}"
        printf "${blue}    (a) SAS environment parameters and, ${end}\n"
        printf "${blue}    (b) List of SAS deployed jobs ${end}\n\n" 
        printf "${blue}There are many features like email alerts, job reports etc. and various launch modes like run from a specific job, run in interactive mode etc. \n\n${end}"
        printf "${blue}To know more about various options available in runSAS, see the help menu (i.e. ./runSAS.sh --help) or better yet go to ${underline}$RUNSAS_GITHUB_PAGE${end}${blue} for detailed documentation. \n${end}"
        press_enter_key_to_continue 1

        # Show
		printf "${blue}\nBelow is the current configuration, review before you continue.\n${end}"
		show_runsas_parameters --parms
		printf "\n"
		press_enter_key_to_continue 1
        printf "\n"

        # Do not show the message again
        create_a_file_if_not_exists $RUNSAS_FIRST_USER_INTRO_DONE_FILE  
    fi
}
#------
# Name: show_the_list()
# Desc: Displays the list of jobs/programs in the script (quick preview using --list)
#   In: --list
#  Out: <NA>
#------
function show_the_list(){
    if [[ ${#@} -ne 0 ]] && [[ "${@#"--list"}" = "" ]]; then
        publish_to_messagebar "${yellow}Formatting the job list, please wait...${white}"
        print_file_content_with_index $JOB_LIST_FILE jobs --prompt --server
        printf "\n"
        exit 0;
    fi;
}
#------
# Name: override_terminal_message_line_wrappers()
# Desc: Overrides the default decorators for the batch mode
#   In: <NA>
#  Out: <NA>
#------
function override_terminal_message_line_wrappers(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]] || [[ -z $RUNSAS_INVOKED_IN_BATCH_MODE ]]; then
        TERMINAL_MESSAGE_LINE_WRAPPERS=-----
    else
        TERMINAL_MESSAGE_LINE_WRAPPERS=*****
    fi
}
#------
# Name: set_colors_codes()
# Desc: Bash color codes, reference: https://misc.flogisoft.com/bash/tip_colors_and_formatting
#   In: <NA>
#  Out: <NA>
#------
function set_colors_codes(){
    if [[ $RUNSAS_INVOKED_IN_NOCOLOR_MODE -le -1 ]]; then
        # Foreground colors
        black=$'\e[30m'
        red=$'\e[31m'
        green=$'\e[1;32m'
        yellow=$'\e[1;33m'
        blue=$'\e[1;34m'
        light_blue=$'\e[94m'
        magenta=$'\e[1;35m'
        cyan=$'\e[1;36m'
        grey=$'\e[38;5;243m'
        white=$'\e[0m'
        light_yellow=$'\e[38;5;101m' 
        orange=$'\e[38;5;215m'

        # Color term
        end=$'\e[0m'

        # Background colors
        red_bg=$'\e[41m'
        green_bg=$'\e[42m'
        blue_bg=$'\e[44m'
        yellow_bg=$'\e[43m'
        darkgrey_bg=$'\e[100m'
        orange_bg=$'\e[48;5;215m'
        white_bg=$'\e[107m'

        # Manipulators
        blink=$'\e[5m'
        bold=$'\e[1m'
        italic=$'\e[3m'
        underline=$'\e[4m'

        # Reset text attributes to normal without clearing screen.
        alias reset_colors="tput sgr0" 

        # Checkmark (green)
        green_check_mark="\033[0;32m\xE2\x9C\x94\033[0m"
    else
        # Foreground colors
        black=""
        red=""
        green=""
        yellow=""
        blue=""
        light_blue=""
        magenta=""
        cyan=""
        grey=""
        white=""
        light_yellow=""
        orange=""

        # Color term
        end=""

        # Background colors
        red_bg=""
        green_bg=""
        blue_bg=""
        yellow_bg=""
        darkgrey_bg=""
        orange_bg=""
        white_bg=""

        # Manipulators
        blink=""
        bold=""
        italic=""
        underline=""

        # Reset text attributes to normal without clearing screen.
        alias reset_colors=""

        # Checkmark (green)
        green_check_mark="*"
    fi
}
#------
# Name: display_post_banner_messages()
# Desc: Informational messages, printed post welcome banner
#   In: <NA>
#  Out: <NA>
#------
function display_post_banner_messages(){
    printf "${white}The script has many options, ./runSAS.sh --help to see more details.${end}\n"
}
#------
# Name: check_runsas_linux_program_dependencies()
# Desc: Checks if the dependencies have been installed and can install the missing dependencies automatically via "yum" 
#   In: program-name or package-name (multiple inputs could be specified)
#  Out: <NA>
#------
function check_runsas_linux_program_dependencies(){
    # Dependency checker
    if [[ "$ENABLE_RUNSAS_DEPENDENCY_CHECK" == "Y" ]]; then
        for prg in "$@"
        do
            # Defaults
            check_dependency_cmd=`which $prg`

            # Check
            printf "${white}"
            if [[ -z "$check_dependency_cmd" ]]; then
                printf "${red}\n*** ERROR: Dependency checks failed, ${white}${red_bg}$prg${white}${red} program is not found, runSAS requires this program to run. ***\n"

                # If the package installer is available try installing the missing dependency
                if [[ ! -z `which $SERVER_PACKAGE_INSTALLER_PROGRAM` ]]; then
                    printf "${green}\nPress Y to auto install $prg (requires $SERVER_PACKAGE_INSTALLER_PROGRAM and sudo access if you're not root): ${white}"
                    read read_install_dependency
                    if [[ "$read_install_dependency" == "Y" ]]; then
                        printf "${white}\nAttempting to install $prg, running ${green}sudo yum install $prg${white}...\n${white}"
                        
                        # Command 
                        sudo $SERVER_PACKAGE_INSTALLER_PROGRAM install $prg
                    else
                        printf "${white}Try installing this using $SERVER_PACKAGE_INSTALLER_PROGRAM, run ${green}sudo $SERVER_PACKAGE_INSTALLER_PROGRAM install $prg${white} or download the $prg package from web (Goooooogle!)"
                    fi
                else
                    printf "${green}\n$SERVER_PACKAGE_INSTALLER_PROGRAM not found, skipping auto-install.\n${white}"
                    printf "${white}\nLaunch runSAS after installing the ${green}$prg${white} program manually (Google is your friend!) or ask server administrator."
                fi
                clear_session_and_exit
            fi
        done
    fi
}
#------
# Name: archive_runsas_batch_history()
# Desc: Archive the runSAS batch stats and batch history, user specifies 
#   In: no-of-batches-to-be-preserved
#  Out: <NA>
#------
function archive_runsas_batch_history(){
    # Parameters
    no_of_batches_to_be_preserved=$1

    # Archive
    if [[ "$no_of_batches_to_be_preserved" == "ALL" ]] || [[ "$no_of_batches_to_be_preserved" == "" ]]; then
        # There's no need for archiving, everything is preserved for reference
        print2debug "*** Skipping the archival process (ALL is preserved) ***"
    else 
        # Check if the user has specified a valid number 
        if [[ $no_of_batches_to_be_preserved =~ $RUNSAS_REGEX_NUMBER ]]; then
            # Get the last batchid
            get_keyval global_batchid "" "" last_batchid

            # Debug
            print2debug no_of_batches_to_be_preserved "*** Archival strategy has kicked in: " " runs will be preserved ***"
            print2debug last_batchid

            # Only preserve a given number of batches (going backwards...)
            if [[ $last_batchid -gt $no_of_batches_to_be_preserved ]]; then
                publish_to_messagebar "${green}runSAS has initiated archival process ($no_of_batches_to_be_preserved last runs will be preserved)....please wait${white}"
                for ((i=1;i<=$((last_batchid-no_of_batches_to_be_preserved));i++)); do 
                    # Archive
                    delete_a_file $RUNSAS_TMP_DIRECTORY/.batch/$i silent
                done
                publish_to_messagebar "${green}NOTE: runSAS has automatically archived old batches (last $no_of_batches_to_be_preserved runs has been preserved)${white}"
            else
                print2debug ">>> Skipping the archival process as the current batchid is less than the specified max limit..."
            fi
        else
            printf "${red}*** ERROR: BATCH_HISTORY_PERSISTENCE parameter (in the header section inside script) must be a positive integer, ${red_bg}${black}$BATCH_HISTORY_PERSISTENCE${white}${red} is invalid, please fix this and restart.\n${white}"
            clear_session_and_exit
        fi
    fi
}
#------
# Name: runsas_script_auto_update()
# Desc: Auto updates the runSAS script from Github
#   In: optional-github-branch
#  Out: <NA>
#------
function runsas_script_auto_update(){
# Optional branch name
runsas_download_git_branch="${1:-$RUNSAS_GITHUB_SOURCE_CODE_DEFAULT_BRANCH}"

# Generate a backup name and folder
runsas_backup_script_name=runSAS.sh.$(date +"%Y%m%d_%H%M%S")

# Create backup folder
create_a_new_directory -p $RUNSAS_BACKUPS_DIRECTORY

# Create a backup of the existing script
if ! cp runSAS.sh $RUNSAS_BACKUPS_DIRECTORY/$runsas_backup_script_name; then
     printf "${red}*** ERROR: Backup has failed! ***\n${white}"
     clear_session_and_exit
else
    printf "${green}\nNOTE: The existing runSAS script has been backed up to `pwd`/$RUNSAS_BACKUPS_DIRECTORY/$runsas_backup_script_name ${white}\n"
fi

# Check if wget exists
check_runsas_linux_program_dependencies wget dos2unix

# Make sure the file is deleted before the download
delete_a_file .runSAS.sh.downloaded silent

# Switch the branches if the user has asked to (default is usually "master")
RUNSAS_GITHUB_SOURCE_CODE_DEFAULT_BRANCH=$runsas_download_git_branch
RUNSAS_GITHUB_SOURCE_CODE_URL=$RUNSAS_GITHUB_PAGE/raw/$RUNSAS_GITHUB_SOURCE_CODE_DEFAULT_BRANCH/runSAS.sh

# Download the latest file from Github
printf "${green}\nNOTE: Downloading the latest version from Github (branch: $RUNSAS_GITHUB_SOURCE_CODE_DEFAULT_BRANCH) using wget utility...${white}\n\n"
if ! wget -O .runSAS.sh.downloaded $RUNSAS_GITHUB_SOURCE_CODE_URL; then
    printf "\n${red}*** ERROR: Could not download the new version of runSAS from Github using wget, possibly due to server restrictions or internet connection issues or the server has timed-out ***\n${white}"
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

# Extract the existing config
cat runSAS.sh | sed -n '/^\#</,/^\#>/{/^\#</!{/^\#>/!p;};}' > .runSAS.config

# Check if the environment already has the latest version, a warning must be shown
if (( $(echo "$curr_runsas_ver >= $new_runsas_ver" | bc -l) )); then
    printf "${red}\n\nWARNING: It looks like you already have the latest version of the script (i.e. $curr_runsas_ver). Do you still want to update? ${white}"
    press_enter_key_to_continue
fi

# Check if the current version is auto-update compatible? 
if ! [[ $curr_runsas_ver =~ $runsas_version_number_regex ]]; then 
    printf "${red}\n\n*** ERROR: The current version of the script ($curr_runsas_ver${red}) is not compatible with auto-update ***\n${white}"
    printf "${red}*** Download the latest version (and update it) manually from $RUNSAS_GITHUB_SOURCE_CODE_URL ***${white}"
    clear_session_and_exit
else
    if (( $(echo "$curr_runsas_ver < $compatible_runsas_ver" | bc -l) )); then
        if [[ "$script_mode_value_1" == "--force" ]]; then
            printf "${red}\n\nWARNING: Attempting a force update (you specified --force), this will reset the current configuration, do you want to continue? ${white}"
            press_enter_key_to_continue
            # Reset, so that user is shown a welcome message
            delete_a_file $RUNSAS_FIRST_USER_INTRO_DONE_FILE silent
            # Force overwrite the config (old config is kept anyway)
            cat .runSAS.sh.downloaded | sed -n '/^\#</,/^\#>/{/^\#</!{/^\#>/!p;};}' > .runSAS.config
            printf "${red}The configuration section was reset, please make sure you configure it again (a backup was kept in ${red_bg}${black}.runSAS.config${end}${red} file).\n${white}"
        else
            printf "${red}\n\n*** ERROR: The current version of the script ($curr_runsas_ver${red}) is not compatible with auto-update due to configuration section changes in the latest release ***\n${white}"
            printf "${red}*** Download the latest version (and update it) manually from $RUNSAS_GITHUB_SOURCE_CODE_URL or use --force option to force update the script (may reset the config, take a backup) ***${white}"
            clear_session_and_exit
        fi
    fi
fi

# Just to keep the terminal messages tidy
printf "\n"

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
    printf "\n${green}NOTE: runSAS script has been successfully updated to ${white}"
    ./runSAS.sh --version
    printf "\n\n"
else
    printf "${red}\n\n*** ERROR: The runSAS script update has failed at the last step! ***${white}\n"
    printf "${red}\n\n*** You can recover the old version of runSAS from the backup created during this process, if needed. ***${white}\n\n"
fi
EOF
   
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
        runsas_script_auto_update $2
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
			disable_enter_key keyboard
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
				display_progressbar_with_offset $j $runsas_delay_time_in_secs -1 ""
				progressbar_end_timestamp=`date +%s`
				let sleep_delay_corrected_in_secs=1-$((progressbar_end_timestamp-progressbar_start_timestamp))
				sleep $sleep_delay_corrected_in_secs
			done
			display_progressbar_with_offset $runsas_delay_time_in_secs $runsas_delay_time_in_secs 0 ""
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
		for (( i=1; i<=$RUNSAS_MAX_PARAMETERS_COUNT; i++ )); do
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
# Name: copy_files_to_a_directory()
# Desc: Copy files to a specified directory
#   In: filename, directory-name
#  Out: <NA>
#------
function copy_files_to_a_directory(){
    if [ `ls -1 $1 2>/dev/null | wc -l` -gt 0 ]; then
        cp $1 $2
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
# Name: create_a_file_if_not_exists()
# Desc: This function will create a new file if it doesn't exist, that's all.
#   In: file-name (multiple files can be provided)
#  Out: <NA>
#------
function create_a_file_if_not_exists(){
    for fil in "$@"
    do
        if [[ ! -f $fil ]]; then
            touch $fil
            print2debug fil "*** Creating a new file [" "] ***" 
            # Check if the file was created successfully
            if [[ ! -f $fil ]]; then
                printf "${red}*** ERROR: ${white}${red_bg}$fil${white}${red} could not be created, check the permissions *** ${white}\n"
                clear_session_and_exit
            else
                chmod 775 $fil
            fi
        fi
    done
}
#------
# Name: check_if_the_file_exists()
# Desc: Check if the specified file exists
#   In: file-name (multiple could be specified), <noexit>, additional-message
#  Out: <NA>
#------
function check_if_the_file_exists(){
	noexit=0
	for p in "$@"
    do
        if [[ "$p" == "noexit" ]]; then
            noexit=1
        fi
    done
    for file in "$@"
    do
        if [ ! -f "$file" ] && [ ! "$file" == "noexit" ] ; then
            printf "\n${red}*** ERROR: File ${black}${red_bg}$file${white}${red} was not found in the server *** ${white}"
			if [[ $noexit -eq 0 ]]; then
				clear_session_and_exit
			fi
        fi
        if [ "$file" == "noexit" ] ; then
            break
        fi
    done
}
#------
# Name: split_job_list_file_by_flowid()
# Desc: split the job list file by flow id
#   In: job-list-file-name
#  Out: <NA>
#------
function split_job_list_file_by_flowid(){
    # Input parameters
    split_in_file=$1

    # Create a temporary directory
    create_a_new_directory -p --silent $RUNSAS_SPLIT_FLOWS_DIRECTORY

    # Clear the directory
    rm -rf $RUNSAS_SPLIT_FLOWS_DIRECTORY/*.flow

    # Split 
    awk -F\| '{print>".tmp/.flows/"$1"-"$2".flow"}' $split_in_file # TODO: Hardcoded paths must be replaced with -v in awk

    # Count the number of files in the directory (in ascending order)
    flow_file_counter=0
    for flow_file in `ls $RUNSAS_SPLIT_FLOWS_DIRECTORY/*.* | sort -V`; do
        let flow_file_counter+=1
    done
    put_keyval total_flows_in_current_batch $flow_file_counter
}
#------
# Name: delete_a_file()
# Desc: Removes/deletes file(s) 
#   In: file-name (wild-card "*" supported, multiple files not supported), post-delete-message (optional, specify "silent" for no message post deletion), delete-options(optional), post-delete-message-color(optional)
#  Out: <NA>
#------
function delete_a_file(){
    # Parameters
    delete_filename=$1
    delete_message="${2:-...(DONE)}"
    delete_options="${3:--rf}"
    delete_message_color="${4:-green}"

    # Check if the file exists before attempting to delete it.
    if ls $delete_filename 1> /dev/null 2>&1; then
        rm $delete_options $delete_filename
        # Check if the file exists post delete
        if ls $delete_filename 1> /dev/null 2>&1; then
            printf "${red}\n*** ERRROR: Delete request did not complete successfully, $delete_filename was not removed (permissions issue?) ***\n${white}"
            clear_session_and_exit
        else
            if [[ ! "$delete_message" == "silent" ]]; then 
                printf "${!delete_message_color}${delete_message}${white}"
            fi
        fi
    else
        if [[ ! "$delete_message" == "silent" ]]; then 
            printf "${grey}...(file does not exist, no action taken)${white}"
        fi
    fi        
}
#------
# Name: create_a_new_directory()
# Desc: Create a specified directory if it doesn't exist
#   In: directory-name (multiple could be specified), --silent (optional)
#  Out: <NA>
#------
function create_a_new_directory(){
    # Check if the user has specified "--silent" option
    for dir in "$@"
    do
        if [[ "$dir" == "--silent" ]]; then
            silent_mode=1
        fi
    done

    # Create directories (no messages are shown if "--silent" is specified)
    mkdir_mode=""
    for dir in "$@"
    do
        if [[ "$dir" == "-p" ]]; then
            mkdir_mode="-p"
        else 
            if [[ ! "$dir" == "--silent" ]]; then
                if [[ ! -d "$dir" ]]; then
                    if [[ $silent_mode -ne 1 ]]; then
                        printf "${green}\nNOTE: Creating a directory named $dir...${white}"
                    fi
                    mkdir $mkdir_mode $dir
                    # See if the directory creation was successful
                    if [[ -d "$dir" ]]; then
                        if [[ $silent_mode -ne 1 ]]; then
                            printf "${green}DONE\n${white}"
                        fi
                    else
                        printf "${red}\n*** ERROR: Directory ${black}${red_bg}$dir${white}${red} cannot be created under the path specified ***${white}"
                        printf "${red}\n*** ERROR: It is likely that one of the parent folder in the directory tree does't exist or the folder permission is restricting the creation of new object under it ***${white}"
                        clear_session_and_exit
                    fi
                fi
            fi
        fi
    done
}
#------
# Name: print_file_to_terminal()
# Desc: This function prints the file content as is to the terminal
#   In: file-name
#  Out: <NA>
#------
function print_file_to_terminal(){
    cat $1 | awk '{print $0}' 
}
#------
# Name: print_file_content_with_index()
# Desc: This function prints the file content with a index
#   In: file-name, file-line-content-type, highlight-keywords (optional)
#  Out: <NA>
#------
function print_file_content_with_index(){
    # Create an array of parameters passed
    printfile_parameters_array_element_count=$#
    printfile_parameters_array=("$@")

    # If the count > 2, then highlight is requested so create a temporary file
    if [[ $printfile_parameters_array_element_count -gt 2 ]]; then 
        printfile=$RUNSAS_TMP_PRINT_FILE
        cp $1 $printfile
    else
        printfile=$1
    fi

    # Get total line count
    total_lines_in_the_file=`cat $printfile | wc -l`

    # Default message 
    printf "\n${white}There are $total_lines_in_the_file $2 in the list:${white}\n"

    # Wrappers
    printf "${white}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n" 

    # Show the list (highlight keywords, ignore the first two parameters)
    for (( p=2; p<$printfile_parameters_array_element_count; p++ )); do
        if [[ ! "${printfile_parameters_array[p]}" == "" ]]; then
            # Highlight keywords
            add_bash_color_tags_for_keywords $printfile ${printfile_parameters_array[p]} ${light_yellow} ${white} 
        fi
    done

    # Print the file
    awk '{printf("%02d) %s\n", NR, $0)}' $printfile

    # Wrappers
    printf "${white}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n"
}
#------
# Name: check_if_logged_in_user_is_root()
# Desc: Check if the user is logged in as root
#   In: <NA>
#  Out: <NA>
#------
function check_if_logged_in_user_is_root(){
    if [[ "$EUID" -eq 0 ]]; then
        printf "${yellow}\nWARNING: Typically you have to launch this script using a SAS batch user such as ${green}sas${yellow} or any user that has SAS batch execution privileges, you are currently logged in as ${red}root. ${white}"
        press_enter_key_to_continue 0 1 yellow
    fi
}
#------
# Name: remove_a_string_pattern_from_file()
# Desc: Remove a string pattern from file 
#   In: string, filename
#  Out: <NA>
#------
function remove_a_string_pattern_from_file(){
	sed -e "s/$1//" -i $2
}
#------
# Name: remove_a_line_from_file()
# Desc: Remove a line from a file
#   In: string, filename
#  Out: <NA>
#------
function remove_a_line_from_file(){
    # Input parameters
    rm_pat=$1
    rm_file=$2

    # Match and remove the line (in line edit)
    if [[ ! "$rm_pat" == "" ]]; then
        sed -i "/$rm_pat/d" $rm_file
    fi
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
# Name: run_a_job_mode_check()
# Desc: Run a job mode (-j) will run only the specified job even if it is not specified in the list
#   In: <NA>
#  Out: <NA>
#------
function run_a_job_mode_check(){
    # Parameters
    rjmode_script_mode="$1"
    rjmode_sas_job="$2"
    rjmode_sas_opt="$3"
    rjmode_sas_subopt="$4"
    rjmode_sas_app_root_directory="${5:-$SAS_APP_ROOT_DIRECTORY}"
    rjmode_sas_batch_server_root_directory="${6:-$SAS_BATCH_SERVER_ROOT_DIRECTORY}"
    rjmode_sas_sh="${7:-$SAS_DEFAULT_SH}"
    rjmode_sas_logs_root_directory="${8:-$SAS_LOGS_ROOT_DIRECTORY}"
    rjmode_sas_deployed_jobs_root_directory="${9:-$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY}"

    # Show a mesage
    publish_to_messagebar "Getting things ready, please wait..."
    
    if [[ "$rjmode_script_mode" == "-j" ]]; then
        if [[ "$rjmode_sas_job" == "" ]]; then
            printf "${red}\n*** ERROR: You launched the script in $rjmode_script_mode(run-a-job) mode, a job name is also required (without the .sas extension) after $script_mode option, job index/numbers are invalid here. ***${white}"
            clear_session_and_exit
        else
            # Overwrite the global parameter by the length of the current job
            let RUNSAS_RUNNING_MESSAGE_FILLER_END_POS=${#rjmode_sas_job}+23
            TOTAL_NO_OF_JOBS_COUNTER_CMD=1

            # Check if the file exists?
            if [[ ! -f "$rjmode_sas_deployed_jobs_root_directory/$rjmode_sas_job.sas" ]]; then
                printf "${red}*** ERROR: The deploy job file $rjmode_sas_deployed_jobs_root_directory/$rjmode_sas_job.sas was not found, have you deployed this job? Use --server option to override defaults (see --help for more details) ${white}"
                clear_session_and_exit
            fi

            printf "\n"
			
            # Create a batch id for the injection of job run status
            generate_a_new_batchid
            
            # Trigger the batch
            printf "${white}   \n${white}"
            printf "${white}${SINGLE_PARENT_DECORATOR}${green}Flow [1]:${white}\n"

            # Capture flow runtimes
            start_datetime_of_flow_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
            start_datetime_of_flow=`date +%s`

            while [ $RUNSAS_BATCH_COMPLETE_FLAG = 0 ]; do
                runSAS "1" "Flow" "1" ${rjmode_sas_job##/*/} "1" "AND" "4" "Y" "$rjmode_sas_opt" "$rjmode_sas_subopt" "$rjmode_sas_app_root_directory" "$rjmode_sas_batch_server_root_directory" "$rjmode_sas_sh" "$rjmode_sas_logs_root_directory" "$rjmode_sas_deployed_jobs_root_directory"
                check_if_batch_has_stalled
            done
            # Capture flow runtimes
            end_datetime_of_flow_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
            end_datetime_of_flow=`date +%s`
            printf "${green}${SPACE_DECORATOR}${CHILD_DECORATOR}The flow took $((end_datetime_of_flow-start_datetime_of_flow)) seconds to complete.${white}" SPACE_DECORATOR

            # Exit gracefully
            clear_session_and_exit
        fi
    fi
}
#------
# Name: check_for_job_list_override
# Desc: If user has specified a file of jobs for the run, override the embedded job list.
#   In: --joblist
#  Out: <NA>
#------
function check_for_job_list_override(){
    if [[ $RUNSAS_INVOKED_IN_JOBLIST_MODE -gt -1 ]]; then
        publish_to_messagebar "${yellow}Validating the jobs file, please wait...${white}"

        # Check the file
        if [[ "${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_JOBLIST_MODE+1]}" == "" ]]; then
            # Check for the jobs file (mandatory for this mode)
            printf "\n${red}*** ERROR: A file that contains a list of deployed jobs is required as a second arguement for this option (e.g.: ./runSAS.sh --joblist jobs.txt) ***${white}"
            clear_session_and_exit
        else
            check_if_the_file_exists ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_JOBLIST_MODE+1]}
            remove_empty_lines_from_file ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_JOBLIST_MODE+1]}
            add_a_newline_char_to_eof ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_JOBLIST_MODE+1]}
            
            # Replace the file that's used by runSAS
            cp -f ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_JOBLIST_MODE+1]} $JOB_LIST_FILE
            
            # Fix the job list file if the user has not decided to provide flow details
            convert_ranges_in_job_dependencies $JOB_LIST_FILE
            refactor_job_list_file $JOB_LIST_FILE
        fi
    fi
}
#------
# Name: kill_a_pid()
# Desc: Terminate the (parent and child) process using pkill command
#   In: pid
#  Out: <NA>
#------
function kill_a_pid(){
    disable_enter_key keyboard
    if [[ ! -z `ps -p $1 -o comm=` ]]; then
        pkill -TERM -P $1
        printf "${red}\nTerminating the running job (pid $1 and the descendants), please wait...${white}"
        sleep 7
        if [[ -z `ps -p $1 -o comm=` ]] && [[ -z `pgrep -P $1` ]]; then
            printf "${green}(DONE)${white}\n\n${white}"
        else
            # Attempting second time...with force kill command 
            printf "${red}taking a bit more time than usual, hold on...${white}"
			kill -9 `ps -p $1 -o comm=` 2>/dev/null
			kill -9 $1 2>/dev/null
            sleep 10
            if [[ -z `ps -p $1 -o comm=` ]] && [[ -z `pgrep -P $1` ]]; then
                printf "${green}(DONE)${white}\n\n${white}"
            else
                printf "${red}\n\n*** ERROR: Attempt to terminate the job (PID $1 and the descendants) failed. It is likely due to user permissions, review the process/child process details below. ***\n${white}"
                show_pid_details $1
                show_child_pid_details $1
                printf "\n"
            fi
        fi
    else
        printf "${red}\n(PID is missing anyway, no action taken)${white}\n\n"
    fi
    enable_enter_key keyboard
}
#------
# Name: show_pid_details()
# Desc: Show process details
#   In: PID
#  Out: <NA>
#------
function show_pid_details(){
    if [[ ! -z `ps -p $1 -o comm=` ]]; then
        printf "${white}$TERMINAL_MESSAGE_LINE_WRAPPERS\n"
        ps $1 # Show process details
        printf "${white}$TERMINAL_MESSAGE_LINE_WRAPPERS\n${white}"
    fi
}
#------
# Name: show_child_pid_details()
# Desc: Show child/descendant processes
#   In: PID
#  Out: <NA>
#------
function show_child_pid_details(){
    if [[ ! -z `pgrep -P $1` ]]; then
        printf "${white}Child Process(es):\n"
        pgrep -P $1 # Show child process details
        printf "${white}$TERMINAL_MESSAGE_LINE_WRAPPERS\n${white}"
    fi
}
#------
# Name: running_processes_housekeeping()
# Desc: Housekeeping for background process, terminate it if required (based on the KILL_PROCESS_ON_USER_ABORT parameter)
#   In: PID, optional-additional-variable
#  Out: <NA>
#------
function running_processes_housekeeping(){
    if [[ ! -z ${1} ]]; then
        if [[ ! -z `ps -p $1 -o comm=` ]]; then
            if [[ "$KILL_PROCESS_ON_USER_ABORT" ==  "Y" ]]; then
                disable_enter_key
                printf "\n${red}*** Attempting to clean up running $2 processes, please wait... ***\n\n${white}"
                printf "${white}Process (PID) details for the currently running job:\n${white}"
                # Show & kill!
                show_pid_details $1
                show_child_pid_details $1
                kill_a_pid $1               
                enable_enter_key
            else
                echo $1 >> $RUNSAS_LAST_JOB_PID_FILE
                printf "${red}WARNING: The last job submitted by runSAS with PID $1 is still running/active in the background, auto-kill is off, terminate it manually using ${green}pkill -TERM -P $1${white}${red} command.\n${white}"
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
    create_a_file_if_not_exists $RUNSAS_LAST_JOB_PID_FILE

    while IFS='|' read -r j_pid; do
        # One process at a time
        runsas_last_job_pid=$j_pid
        
        # Check if the PID is still active
        if [[ ! "$runsas_last_job_pid" == "" ]]; then
            if ! [[ -z `ps -p ${runsas_last_job_pid} -o comm=` ]]; then
                printf "${yellow}WARNING: There is a job (PID $runsas_last_job_pid) that is still active/running from the last runSAS session, see the details below.\n\n${white}"
                show_pid_details $runsas_last_job_pid
                printf "${red}\nDo you want to kill this process and continue? (Y/N): ${white}"
                disable_enter_key
                read -n1 ignore_process_warning < /dev/tty
                if [[ "$ignore_process_warning" == "Y" ]] || [[ "$ignore_process_warning" == "y" ]]; then
                    kill_a_pid $runsas_last_job_pid
                else
                    printf "\n\n"
                fi
                enable_enter_key
            fi
        fi
    done < $RUNSAS_LAST_JOB_PID_FILE 

    delete_a_file $RUNSAS_LAST_JOB_PID_FILE silent
}
#------
# Name: show_runsas_parameters
# Desc: Shows the runSAS parameters set by the user
#   In: script-mode, exit-signal
#  Out: <NA>
#------
function show_runsas_parameters(){
    if [[ "$1" == "--parms" ]] || [[ "$1" == "--parameters" ]]; then
        printf "\n${red}$TERMINAL_MESSAGE_LINE_WRAPPERS (SAS) $TERMINAL_MESSAGE_LINE_WRAPPERS ${white}"  
        printf "\n${white}SAS_INSTALLATION_ROOT_DIRECTORY: ${green}$SAS_INSTALLATION_ROOT_DIRECTORY ${white}"
        printf "\n${white}SAS_APP_SERVER_NAME: ${green}$SAS_APP_SERVER_NAME ${white}"
        printf "\n${white}SAS_LEV: ${green}$SAS_LEV ${white}"
        printf "\n${white}SAS_DEFAULT_SH: ${green}$SAS_DEFAULT_SH ${white}"
        printf "\n${white}SAS_APP_ROOT_DIRECTORY: ${green}$SAS_APP_ROOT_DIRECTORY ${white}"
        printf "\n${white}SAS_BATCH_SERVER_ROOT_DIRECTORY: ${green}$SAS_BATCH_SERVER_ROOT_DIRECTORY ${white}"
        printf "\n${white}SAS_LOGS_ROOT_DIRECTORY: ${green}$SAS_LOGS_ROOT_DIRECTORY ${white}"
        printf "\n${white}SAS_DEPLOYED_JOBS_ROOT_DIRECTORY: ${green}$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY ${white}"

        printf "\n${red}$TERMINAL_MESSAGE_LINE_WRAPPERS (Script) $TERMINAL_MESSAGE_LINE_WRAPPERS ${white}" 
        printf "\n${white}ENABLE_DEBUG_MODE: ${green}$ENABLE_DEBUG_MODE ${white}"                       
        printf "\n${white}RUNTIME_COMPARISON_FACTOR: ${green}$RUNTIME_COMPARISON_FACTOR ${white}"                                                                        
        printf "\n${white}KILL_PROCESS_ON_USER_ABORT: ${green}$KILL_PROCESS_ON_USER_ABORT ${white}"                                          
        printf "\n${white}ERROR_CHECK_SEARCH_STRING: ${green}$ERROR_CHECK_SEARCH_STRING ${white}"                                      
        printf "\n${white}STEP_CHECK_SEARCH_STRING: ${green}$STEP_CHECK_SEARCH_STRING ${white}"                                   
        printf "\n${white}SASTRACE_SEARCH_STRING: ${green}$SASTRACE_SEARCH_STRING ${white}"                        
        printf "\n${white}ENABLE_RUNSAS_RUN_HISTORY: ${green}$ENABLE_RUNSAS_RUN_HISTORY ${white}"                                          
        printf "\n${white}ABORT_ON_ERROR: ${green}$ABORT_ON_ERROR ${white}"                                                       
        printf "\n${white}ENABLE_SASTRACE_IN_JOB_CHECK: ${green}$ENABLE_SASTRACE_IN_JOB_CHECK ${white}"                                         
        printf "\n${white}ENABLE_RUNSAS_DEPENDENCY_CHECK: ${green}$ENABLE_RUNSAS_DEPENDENCY_CHECK ${white}"   

        printf "\n${red}$TERMINAL_MESSAGE_LINE_WRAPPERS (Email) $TERMINAL_MESSAGE_LINE_WRAPPERS ${white}"
        printf "\n${white}ENABLE_EMAIL_ALERTS: ${green}$ENABLE_EMAIL_ALERTS ${white}"                                  	                
        printf "\n${white}EMAIL_ALERT_TO_ADDRESS: ${green}$EMAIL_ALERT_TO_ADDRESS ${white}"                                              
        printf "\n${white}EMAIL_ALERT_USER_NAME: ${green}$EMAIL_ALERT_USER_NAME ${white}"  

        # Exit
		if [[ "$2" == "X" ]]; then
			clear_session_and_exit   
		fi
    fi 
}                                   
#------
# Name: reset()
# Desc: Clears the temporary files
#   In: script-mode, script-mode-value
#  Out: <NA>
#------
function reset(){
    # Parameters
    reset_mode=$1
    reset_mode_optionals=$2

    # Reset
    if [[ "$reset_mode" == "--reset" ]]; then
        # Check if the user has asked for a batch number reset
        if [[ "$reset_mode_optionals" == "--batchid" ]] || [[ "$reset_mode_optionals" == "--batchnum" ]]; then
            delete_a_file $RUNSAS_TMP_DIRECTORY/.runsas_global_user.parm silent
            printf "${green}\nBatch ID has been reset...${white}"
            clear_session_and_exit
        fi

        # Clear the temporary files
        printf "${red}\nClear temporary files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_tmp_files
        if [[ "$clear_tmp_files" == "Y" ]] || [[ "$clear_tmp_files" == "y" ]]; then    
            delete_a_file $EMAIL_BODY_MSG_FILE silent
            delete_a_file $SASTRACE_CHECK_FILE silent
            delete_a_file $EMAIL_TERMINAL_PRINT_FILE silent
            delete_a_file $RUNSAS_LAST_JOB_PID_FILE silent
            delete_a_file $RUNSAS_FIRST_USER_INTRO_DONE_FILE silent
            printf "${green}...(DONE)${white}"
        fi

        # Clear the session history files
        printf "${red}\nClear runSAS session history? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_session_files
        if [[ "$clear_session_files" == "Y" ]] || [[ "$clear_session_files" == "y" ]]; then    
            delete_a_file $RUNSAS_SESSION_LOG_FILE
        fi

        # Clear the historical run stats
        printf "${red}\nClear historical runtime stats? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_his_files
        if [[ "$clear_his_files" == "Y" ]] || [[ "$clear_his_files" == "y" ]]; then    
            delete_a_file $RUNSAS_RUN_STATS_DIRECTORY silent -rf
            printf "${green}...(DONE)${white}"
        fi

		# Clear redeploy parameters file
        printf "${red}\nClear job redeployment logs? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_depjob_files
        if [[ "$clear_depjob_files" == "Y" ]] || [[ "$clear_depjob_files" == "y" ]]; then    
			delete_a_file $RUNSAS_DEPLOY_JOB_UTIL_LOG silent
        fi

        # Clear global user parameters file
        printf "${red}\nClear stored global user parameters? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_global_user_parms
        if [[ "$clear_global_user_parms" == "Y" ]] || [[ "$clear_global_user_parms" == "y" ]]; then    
            delete_a_file $RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE
            
        fi

        # Clear batch history
        printf "${red}\nClear batch run status preservation files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_batch_run_history
        if [[ "$clear_batch_run_history" == "Y" ]] || [[ "$clear_batch_run_history" == "y" ]]; then    
            delete_a_file $RUNSAS_BATCH_STATE_ROOT_DIRECTORY silent -rf
        fi

        # Clear flow split files
        printf "${red}\nClear flow related temporary files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_flow_temp_split_files
        if [[ "$clear_flow_temp_split_files" == "Y" ]] || [[ "$clear_flow_temp_split_files" == "y" ]]; then    
            delete_a_file $RUNSAS_SPLIT_FLOWS_DIRECTORY silent -rf
        fi

        # Clear debug files
        printf "${red}\nClear debug & trace files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_debug_files
        if [[ "$clear_debug_files" == "Y" ]] || [[ "$clear_debug_files" == "y" ]]; then    
            rm -rf $RUNSAS_TMP_DIRECTORY/.??*.debug silent 
            rm -rf $RUNSAS_TMP_DIRECTORY/.??*.trace silent
        fi

        # Clear print and job backup files
        printf "${red}\nClear misc print and job list backup files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_misc_print_files
        if [[ "$clear_misc_print_files" == "Y" ]] || [[ "$clear_misc_print_files" == "y" ]]; then    
            rm -rf $JOB_LIST_FILE
            rm -rf $RUNSAS_TMP_PRINT_FILE
        fi

        # Clear script backup files
        printf "${red}\nClear runSAS script backup files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_script_backup_files
        if [[ "$clear_misc_print_files" == "Y" ]] || [[ "$clear_misc_print_files" == "y" ]]; then    
            delete_a_file $RUNSAS_BACKUPS_DIRECTORY/*.* silent -rf
        fi

        # Close with a clear session
        clear_session_and_exit
    fi
}
#------
# Name: print_unix_user_session_variables()
# Desc: Prints user session variables using compgen -v command
#   In: file-or-terminal-mode, file-name
#  Out: <NA>
#------
function print_unix_user_session_variables(){
    session_variables_array=`compgen -v`
    for session_variable_name in $session_variables_array; do
        if [[ "$1" == "file" ]]; then
            printf "$session_variable_name: ${!session_variable_name}\n" >> $2
        else
            printf "${white}${green}$session_variable_name${white} is set to ${green}${!session_variable_name}\n${white}" 
        fi
    done
    # Fix the color issue
    sed -i 's/\x1b\[[0-9;]*m//g' $2
}
#------
# Name: print_to_terminal_debug_only()
# Desc: Prints more details to terminal if the debug mode is turned on (experimental)
#   In: <NA>
#  Out: <NA>
#------
function print_to_terminal_debug_only(){
    if [[ "$ENABLE_DEBUG_MODE" == "Y" ]]; then
        printf "${white}DEBUG - $1: $2\n${white}"
        print_unix_user_session_variables 
		printf "${white}\n"
    fi
}
#------
# Name: check_for_noemail_option()
# Desc: This function will check if the user has requested for --noemail or --nomail option (overrides the email flags to NNNN)
#   In: <NA>
#  Out: <NA> 
#------
function check_for_noemail_option(){
    for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); do
        if [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "--noemail" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "--nomail" ]]; then 
            # Override the flags
            ENABLE_EMAIL_ALERTS=NNNN
        fi
    done
}
#------
# Name: check_for_email_option()
# Desc: This function will check if the user has requested for --email option (overrides the email TO address)
#   In: <NA>
#  Out: <NA> 
#------
function check_for_email_option(){
    for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); do
        if [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "--email" ]]; then
            if [[ "${RUNSAS_PARAMETERS_ARRAY[p+1]}" == "" ]]; then
                # Check for the email address(es)
                printf "\n${red}*** ERROR: An email address (or addresses separated by semi-colon with no spaces in between) is required for --email option ***${white}"
                clear_session_and_exit
            else
                # Check if the user has specified it before other arguments 
                if [[ "${RUNSAS_PARAMETERS_ARRAY[p+2]}" == "" ]]; then
                    # Override the flags
                    ENABLE_EMAIL_ALERTS=$EMAIL_FLAGS_DEFAULT_SETTING
                    # Override the email addresses
                    EMAIL_ALERT_TO_ADDRESS=${RUNSAS_PARAMETERS_ARRAY[p+1]}
                else 
                    # Check for the jobs file (mandatory for this mode)
                    printf "\n${red}*** ERROR: --email option must always be specified after all arguements (e.g. ./runSAS.sh -fu jobA jobB --email xyz@abc.com) ***${white}"
                    clear_session_and_exit
                fi
            fi
        fi
    done
}
#------
# Name: check_for_user_messages_option()
# Desc: This function will check if the user has requested for --message option (sends this user message in the subject line)
#   In: <NA>
#  Out: <NA> 
#------
function check_for_user_messages_option(){
    for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); do
        if [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "--message" ]]; then
            # Override the flags
            EMAIL_USER_MESSAGE="(${RUNSAS_PARAMETERS_ARRAY[p+1]})"
        fi
    done
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
	if (( $this_attachment_size > $EMAIL_ATTACHMENT_SIZE_LIMIT_IN_BYTES )); then
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
email_from_address_complete="$EMAIL_ALERT_USER_NAME <$USER@`hostname`>"
email_to_address_complete="$email_to_address $email_optional_to_distribution_list" 
email_subject_full_line="$email_subject_id $email_subject $EMAIL_USER_MESSAGE"

# Remember the current directory and switch to attachments root directory (is switched back once the routine is complete)
curr_directory=`pwd`
cd $email_optional_attachment_directory

# Build a terminal message (first part of the message)
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
# Name: add_bash_color_tags_for_keywords()
# Desc: This adds bash color tags to a keyword in a file (in file replacement)
#   In: file-name, keyword, begin-color-code, end-color-code
#  Out: <NA>
#------
function add_bash_color_tags_for_keywords(){
	sed -e "s/$2/$3$2$4/g" -i $1
}
#------
# Name: runsas_notify_email()
# Desc: Send an email when runSAS is waiting for user input
#   In: <NA>
#  Out: <NA>
#------
function runsas_notify_email(){
    if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:0:1}" == "Y" ]]; then
		# Reset the input parameters 
        echo "The batch has been paused at $1 for user input" > $EMAIL_BODY_MSG_FILE
        add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
        send_an_email -s "" "Batch paused, awaiting user input" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
    fi
}
#------
# Name: runsas_triggered_email()
# Desc: Send an email when runSAS is triggered
#   In: <NA>
#  Out: <NA>
#------
function runsas_triggered_email(){
    if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:0:1}" == "Y" ]]; then
		# Reset the input parameters 
        echo "runSAS was launched in ${1:-"a full batch"} mode with ${2:-"no parameters."} $3 $4 $5 $6 $7 $8" > $EMAIL_BODY_MSG_FILE
        add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
        send_an_email -v "" "Batch has been triggered" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
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
    if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:1:1}" == "Y" ]]; then
        echo "Job $1 ($4 of $5) completed successfully and took about $2 seconds to complete (took $3 seconds to run previously)." > $EMAIL_BODY_MSG_FILE
        add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
        send_an_email -s "" "$1 has run successfully" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
    fi
}
#------
# Name: runsas_error_email()
# Desc: Send an email when runSAS has seen an error
#   In: <NA>
#  Out: <NA>
#------
function runsas_error_email(){
    if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:2:1}" == "Y" ]]; then
        printf "\n\n"
        echo "$TERMINAL_MESSAGE_LINE_WRAPPERS" > $EMAIL_BODY_MSG_FILE
        # See if the steps are displayed
        if [[ "$JOB_ERROR_DISPLAY_STEPS" == "Y" ]]; then
            cat $runsas_error_w_steps_tmp_log_file | awk '{print $0}' >> $EMAIL_BODY_MSG_FILE
        else
            cat $runsas_error_tmp_log_file | awk '{print $0}' >> $EMAIL_BODY_MSG_FILE
        fi
        # Send email
        echo "$TERMINAL_MESSAGE_LINE_WRAPPERS" >> $EMAIL_BODY_MSG_FILE
        echo "Job:)" >> $EMAIL_BODY_MSG_FILE
        echo "Log: $runsas_logs_root_directory/$runsas_job_log" >> $EMAIL_BODY_MSG_FILE
        add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
        send_an_email -v "" "Job $1 (of $2) has failed!" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE $runsas_logs_root_directory $runsas_job_log 
    fi
}
#------
# Name: runsas_success_email()
# Desc: Send an email when runSAS has completed its run
#   In: <NA>
#  Out: <NA>
#------
function runsas_success_email(){
    if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:3:1}" == "Y" ]]; then
        # Send email
        printf "\n\n"
        cat $JOB_STATS_DELTA_FILE | sed 's/ /,|,/g' | column -s ',' -t > $EMAIL_TERMINAL_PRINT_FILE
        sed -e 's/ /\&nbsp\;/g' -i $EMAIL_TERMINAL_PRINT_FILE
        echo "The batch completed successfully on $end_datetime_of_session_timestamp and took a total of $((end_datetime_of_session-start_datetime_of_session)) seconds to complete. See the run details below.<br>" > $EMAIL_BODY_MSG_FILE
        cat $EMAIL_TERMINAL_PRINT_FILE | awk '{print $0}' >> $EMAIL_BODY_MSG_FILE
        add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE	
        send_an_email -v "" "Batch has completed successfully!" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
    fi
}
#------
# Name: evalf()
# Desc: Creates a dynamic variable 
#   In: parameter, key, prefix, value
#  Out: Variable format is "$prefix_$parameter_$key = $value"
#------
function evalf(){
    # Input parameters
    ev_paramater=$1
    ev_key=$2
    ev_parameter_prefix=$3
    ev_parameter_value=$4

    # Create a dynamic variable and assign the value
    eval "$ev_paramater=${ev_parameter_prefix}_${ev_key}"
    eval "${!ev_paramater}=$ev_parameter_value"
}
#------
# Name: set_concurrency_parameters()
# Desc: Set the job slots based on the CPU count (user can override this)
#   In: <NA>
#  Out: <NA>
#------
function set_concurrency_parameters(){
    # Get CPU count (for hyperthreaded systems, replace "nproc -all" with "grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}'")
    sjs_cpu_count=`nproc --all`

    # Check if the user has specified any overrides?
    if [[ "$CONCURRENT_JOBS_LIMIT" == "" ]] || [[ "$CONCURRENT_JOBS_LIMIT" == "ALL" ]]; then
        sjs_concurrent_job_count_limit=$sjs_cpu_count

        # Amplify!
        if [[ ! $CONCURRENT_JOBS_LIMIT_MULTIPLIER == "" ]] && [[ $CONCURRENT_JOBS_LIMIT_MULTIPLIER =~ $RUNSAS_REGEX_NUMBER ]]; then
            sjs_concurrent_job_count_limit=$((sjs_cpu_count*CONCURRENT_JOBS_LIMIT_MULTIPLIER))
        fi
    elif [[ "$CONCURRENT_JOBS_LIMIT" == "MAX" ]]; then
        sjs_concurrent_job_count_limit=999999999 # Upper limit
    else
        sjs_concurrent_job_count_limit=$CONCURRENT_JOBS_LIMIT
    fi

    # Debug
    print2debug sjs_concurrent_job_count_limit "*** Concurrency has been set to [" "], detected $sjs_cpu_count cores via 'nproc' with CONCURRENT_JOBS_LIMIT=$CONCURRENT_JOBS_LIMIT and CONCURRENT_JOBS_LIMIT_MULTIPLIER=$CONCURRENT_JOBS_LIMIT_MULTIPLIER ***"
}
#------
# Name: store_flow_runtime_stats()
# Desc: Capture flow runtime stats, single version of history is kept per job
#   In: flow-name, total-time-taken-by-flow, change-in-runtime, start-timestamp, end-timestamp
#  Out: <NA>
#------
function store_flow_runtime_stats(){
    # Input parameters
    flowstats_flowname=$1
    flowstats_timetaken_by_flow_in_secs=$2
    flowstats_flow_runtime_change_in_pct=$3
    flowstats_flow_start_timestamp=$4
    flowstats_flow_end_timestamp=$5
    
    # Defaults
    flowstats_flowstats_file=$FLOW_STATS_FILE
    flowstats_flowstats_delta_file=$FLOW_STATS_DELTA_FILE

    # Add the entry
    if [[ $flowstats_timetaken_by_flow_in_secs -gt 0 ]]; then
        # First, remove the existing entry
        sed -i "/\b$flowstats_flowname\b/d" $flowstats_flowstats_file
        # Now add the new entry 
        echo "$flowstats_flowname $flowstats_timetaken_by_flow_in_secs ${flowstats_flow_runtime_change_in_pct}% $flowstats_flow_start_timestamp $flowstats_flow_end_timestamp" >> $flowstats_flowstats_file       # Add a new entry 
        echo "$flowstats_flowname $flowstats_timetaken_by_flow_in_secs ${flowstats_flow_runtime_change_in_pct}% $flowstats_flow_start_timestamp $flowstats_flow_end_timestamp" >> $flowstats_flowstats_delta_file # Add a new entry to a delta file
    fi
}
#------
# Name: get_flow_hist_runtime_stats()
# Desc: Check flow runtime for the last batch run
#   In: flow-name
#  Out: $hist_flow_runtime
#------
function get_flow_hist_runtime_stats(){
    # Input parameters
    getflowstats_flow_name=$1

    # Defaults
    getflowstats_flowstats_file=$FLOW_STATS_FILE
    getflowstats_flowstats_delta_file=$FLOW_STATS_DELTA_FILE

    # Get the flow stats
    hist_flow_runtime=`awk -v pat="$getflowstats_flow_name " -F" " '$0~pat { print $2 }' $getflowstats_flowstats_file | head -1`
}
#------
# Name: store_job_runtime_stats()
# Desc: Capture job runtime stats, single version of history is kept per job
#   In: flow-name, job-name, total-time-taken-by-job, change-in-runtime, logname, start-timestamp, end-timestamp
#  Out: <NA>
#------
function store_job_runtime_stats(){
    # Input parameters
    jobstats_flowname=$1
    jobstats_jobname=$2
    jobstats_timetaken_by_job_in_secs=$3
    jobstats_job_runtime_change_in_pct=$4
    jobstats_job_logname=$5
    jobstats_job_start_timestamp=$6
    jobstats_job_end_timestamp=$7
    
    # Defaults
    jobstats_jobstats_file=$JOB_STATS_FILE
    jobstats_jobstats_delta_file=$JOB_STATS_DELTA_FILE

    # Remove the previous entry
    sed -i "/\b$jobstats_jobname\b/d" $jobstats_jobstats_file

    # Add new entry 
    echo "$jobstats_flowname $jobstats_jobname $jobstats_timetaken_by_job_in_secs ${jobstats_job_runtime_change_in_pct}% $jobstats_job_logname $jobstats_job_start_timestamp $jobstats_job_end_timestamp" >> $jobstats_jobstats_file       # Add a new entry 
	echo "$jobstats_flowname $jobstats_jobname $jobstats_timetaken_by_job_in_secs ${jobstats_job_runtime_change_in_pct}% $jobstats_job_logname $jobstats_job_start_timestamp $jobstats_job_end_timestamp" >> $jobstats_jobstats_delta_file # Add a new entry to a delta file
}
#------
# Name: get_job_hist_runtime_stats()
# Desc: Check job runtime for the last batch run
#   In: job-name
#  Out: $hist_job_runtime
#------
function get_job_hist_runtime_stats(){
     # Input parameters
    getjobstats_flow_name=$1

    # Defaults
    getjobstats_flowstats_file=$JOB_STATS_FILE
    getjobstats_flowstats_delta_file=$JOB_STATS_DELTA_FILE

    # Get the job stats
    hist_job_runtime=`awk -v pat="$getjobstats_flow_name " -F" " '$0~pat { print $3 }' $getjobstats_flowstats_file | head -1`
}
#------
# Name: show_job_hist_runtime_stats()
# Desc: Print details about last run (if available)
#   In: job-name
#  Out: <NA>
#------
function show_job_hist_runtime_stats(){
    # Input parameters
    sj_job=$1
    
    # Get the runtime for job
	get_job_hist_runtime_stats $sj_job

	if [[ "$hist_job_runtime" != "" ]]; then
        display_fillers $((RUNSAS_RUNNING_MESSAGE_FILLER_END_POS+11)) $RUNSAS_FILLER_CHARACTER 0 N 2 $runsas_job_status_color
		printf "${!runsas_job_status_color}(takes ~"
        printf "%05d" $hist_job_runtime
        printf " secs)${white}"
	fi
}
#------
# Name: show_flow_hist_runtime_stats()
# Desc: Print details about last run (if available)
#   In: flow-name
#  Out: <NA>
#------
function show_flow_hist_runtime_stats(){
    # Input parameters
    sj_flow=$1
    
    # Get the runtime for flow
	get_flow_hist_runtime_stats $sj_flow

	if [[ "$hist_flow_runtime" != "" ]]; then
		printf "${green}(takes ~"
        printf "%05d" $hist_flow_runtime
        printf " secs)${white}"
	fi
}
#------
# Name: show_time_remaining_stats()
# Desc: Print details about time remaining (if history runtime stats is available)
#   In: job-name
#  Out: <NA>
#------
function show_time_remaining_stats(){
    # Input parameters
    st_job=$1

    # "Empty" variable (used to clear the screen during refresh of terminal messages)
    st_empty_var="                            "

    # Get runtime stats from previous runs
	get_job_hist_runtime_stats $st_job

    # Calculate remaining time stats
	if [[ "$hist_job_runtime" != "" ]]; then
		# Record timestamp
		st_curr_timestamp=`date +%s`
		
		# Calculate the time remaining in secs.
		if [ ! -z "$st_last_shown_timestamp" ]; then
            let st_diff_in_seconds=$st_curr_timestamp-$st_last_shown_timestamp
            if [[ $st_diff_in_seconds -lt 0 ]]; then
                st_diff_in_seconds=0
            fi
            assign_and_preserve st_time_remaining_in_secs $st_time_remaining_in_secs-$st_diff_in_seconds
		else
            assign_and_preserve st_time_remaining_in_secs $hist_job_runtime
            let st_diff_in_seconds=0
		fi

		# Show the stats
        if [[ $st_time_remaining_in_secs -ge 0 ]]; then
            st_msg=" ~$st_time_remaining_in_secs secs remaining...$st_empty_var" 
        else
		    st_msg=" additional $((st_time_remaining_in_secs*-1)) secs elapsed......$st_empty_var" 
		fi
		
		# Record the message last shown timestamp
        assign_and_preserve st_last_shown_timestamp $st_curr_timestamp
	else
		# Record timestamp
		st_time_since_run_msg_curr_timestamp=`date +%s`
		
		# Calculate the time elapsed in secs.
		if [ ! -z "$st_time_since_run_msg_last_shown_timestamp" ]; then
            let st_diff_in_seconds=$st_time_since_run_msg_curr_timestamp-$st_time_since_run_msg_last_shown_timestamp
            if [[ $st_diff_in_seconds -lt 0 ]]; then
                st_diff_in_seconds=0
            fi
            assign_and_preserve st_time_since_run_in_secs $st_time_since_run_in_secs+$st_diff_in_seconds
		else
            assign_and_preserve st_time_since_run_in_secs 0
            let st_diff_in_seconds=0
		fi

		# Show the stats
        if [[ $st_time_since_run_in_secs -ge 0 ]]; then
            st_msg=" ~$st_time_since_run_in_secs secs elapsed...$st_empty_var" 
		fi
		
		# Record the message last shown timestamp
        assign_and_preserve st_time_since_run_msg_last_shown_timestamp $st_time_since_run_msg_curr_timestamp 
	fi
}
#------
# Name: show_last_run_summary()
# Desc: Print summary about last run (if available)
#   In: script-launch-mode
#  Out: <NA>
#------
function show_last_run_summary(){
    if [[ "$1" == "--log" ]] || [[ "$1" == "--last" ]]; then
        if [ ! -f "$RUNSAS_SESSION_LOG_FILE" ]; then
            printf "${red}\n*** ERROR: History file is empty (possibly due to reset?) ***${white}"
            clear_session_and_exit
        else
            print_file_to_terminal $RUNSAS_SESSION_LOG_FILE
            clear_session_and_exit
        fi
    fi
}
#------
# Name: print2log()
# Desc: Keeps a track of what's done in the session for debugging etc.
#   In: msg
#  Out: <NA>
#------
function print2log(){
    create_a_file_if_not_exists $RUNSAS_SESSION_LOG_FILE
    printf "\n$1" >> $RUNSAS_SESSION_LOG_FILE
}
#------
# Name: write_job_details_on_terminal()
# Desc: Print details about the currently running job on the terminal
#   In: job-name, color (optional)
#  Out: <NA>
#------
function write_job_details_on_terminal(){
    # Input parameters
    wjd_job=$1
    wjd_additional_message=$2
    wjd_additional_message_color="${3:-grey}"
    wjd_begin_color="${4:-white}"
    wjd_job_color="${5:-darkgrey_bg}"
    wjd_end_color="${6:-white}"

    # Show job stuff
    if [[ "$repeat_job_terminal_messages" == "Y" ]]; then
        if [[ $flow_file_flow_id -ge $total_flows_in_current_batch ]]; then
            printf "${!wjd_begin_color}${SPACE_DECORATOR}${CHILD_DECORATOR}Job #"
            printf "%03d" $runsas_jobid
        else
           printf "${!wjd_begin_color}${NO_BRANCH_DECORATOR}${CHILD_DECORATOR}Job #" 
           printf "%03d" $runsas_jobid
        fi

        # Additional info
        printf ": ${!wjd_job_color}$wjd_job${!wjd_end_color} "

        # Additional message
        if [[ ! "$wjd_additional_message" == "" ]]; then
            display_fillers $RUNSAS_DISPLAY_FILLER_COL_END_POS $RUNSAS_FILLER_CHARACTER 1 N 2 $wjd_additional_message_color
            printf "${!wjd_additional_message_color}$wjd_additional_message\n${!wjd_end_color}"
        fi
    fi
}
#------
# Name: print2debug()
# Desc: Debug code
#   In: variable, description, prefix, postfix, debug-file (optional)
#  Out: <NA>
#------
function print2debug(){
    # Input parameters
    debug_var="${1:-DEBUG}"
    debug_prefix="$2"
    debug_postfix="$3"
    debug_file="${4:-$RUNSAS_DEBUG_FILE}"

    # Print to the file
    printf "\n$debug_prefix${debug_var}=${!debug_var}$debug_postfix" >> $debug_file
}
#------
# Name: add_more_info_to_log_in_batch_mode()
# Desc: This function adds additional information to the log for easier debugging.
#   In: <NA>
#  Out: <NA>
#------
function add_more_info_to_log_in_batch_mode(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -gt -1 ]]; then

        # Batch related information
        show_runsas_parameters --parms

        # Launch parms
        printf "\n\nBatch launch parameters: ./runSAS.sh ${RUNSAS_PARAMETERS_ARRAY[@]}\n"

        # Debug
        printf "\n\n${green}NOTE: runSAS debug and trace logs (usually 'hidden') can be accessed under `pwd`/ and more temporary files under `pwd`/.tmp ${white}\n"
    fi
}
#------
# Name: batch_mode_pre_process()
# Desc: The function runs few pre - batch mode stuff
#   In: <NA>
#  Out: <NA>
#------
function batch_mode_pre_process(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        publish_to_messagebar ""
        # clear
    fi
}
#------
# Name: get_running_jobs_count()
# Desc: Get the list of jobs currently running...
#   In: job-list-file-name, delimiter
#  Out: $running_jobs_current_count
#------
function get_running_jobs_count(){
    # Input parameters
    getname_file=${1:-$JOB_LIST_FILE} 
    getname_delimeter="${2:-|}" # Pipe is the default
        
    # Get the count
    running_jobs_current_count=0
    while IFS="$getname_delimeter" read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do
        get_keyval_from_batch_state runsas_jobrc runsas_jobrc_i $jid
        if [[ $runsas_jobrc_i -eq $RC_JOB_TRIGGERED ]]; then
            let running_jobs_current_count+=1
        fi
	done < $getname_file
}
#------
# Name: get_name_from_list()
# Desc: Get the name when user inputs a number/index (from the list)
#   In: id, file, column, delimeter, silent
#  Out: <NA>
#------
function get_name_from_list(){
    # Input parameters
    getname_id=$1
    getname_file=$2
    getname_column=${3:-4} # 4th column is the default 
    getname_delimeter="${4:-|}" # Pipe is the default
    getname_silent=$5
        
    # Get the job name from the file for a given index
    # job_name_from_the_list=`sed -n "${getname_id}p" $getname_file | awk -v getname_column=$getname_column -F "$getname_delimeter" '{print $getname_column}'`
    getname_job_counter=0
    job_name_from_the_list=""
    flow_name_from_the_list=""
    while IFS="$getname_delimeter" read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do
		if [[ "$jid" == "${getname_id}" ]]; then
			job_name_from_the_list=$j
            flow_name_from_the_list=$f
            break
		fi
        let getname_job_counter+=1
	done < $getname_file

    # Check if the name has been picked correctly by the above command
    if [[ -z $job_name_from_the_list ]] || [[ "$job_name_from_the_list" == ""  ]]; then
        printf "${red}*** ERROR: No job was found with jobid $1 in the list above. Please review the specified index and launch the script again ***${white}"
        clear_session_and_exit
    else
        if [[ "$getname_silent" == "" ]]; then
            printf "${green}Job ${darkgrey_bg}${job_name_from_the_list}${end}${green} from flow ${darkgrey_bg}$flow_name_from_the_list${end}${green} has been selected from the job list at line ${darkgrey_bg}#$getname_job_counter${end}${green} with jobid ${darkgrey_bg}${getname_id}${end}${green}${white}\n"
        fi
    fi
}
#------
# Name: show_cursor()
# Desc: Shows the cursor
#   In: <NA>
#  Out: <NA>
#------
function show_cursor(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        setterm -cursor on
    fi
}
#------
# Name: hide_cursor()
# Desc: Hides the cursor
#   In: <NA>
#  Out: <NA>
#------
function hide_cursor(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        setterm -cursor off
    fi
}
#------
# Name: clear_session_and_exit()
# Desc: Resets the terminal
#   In: email-short-message, email-long-message
#  Out: <NA>
#------
function clear_session_and_exit(){
    # Input parameters
    clear_session_and_exit_email_short_message=$1
    clear_session_and_exit_email_long_message=${2:-$clear_session_and_exit_email_short_message}

    # Disable the keyboard
    disable_enter_key
    disable_keyboard_inputs

    # Print two newlines
    printf "${white}\n\n${white}"

    # Check if an email is requested
    if [[ "$clear_session_and_exit_email_short_message" != "" ]]; then
        if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:0:1}" == "Y" ]]; then
            echo "$clear_session_and_exit_email_long_message" > $EMAIL_BODY_MSG_FILE
            add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
            send_an_email -v "" "clear_session_and_exit_email_short_message" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
            print2debug clear_session_and_exit_email_short_message "*** Email was sent [" "]"
        fi
    fi

    publish_to_messagebar "${green}*** runSAS is exiting now ***${white}"
    print2debug global_batchid "*** runSAS is exiting now for batchid:" " (${clear_session_and_exit_email_short_message:-"no error messages"})***"

    # Save debug logs for future reference
    copy_files_to_a_directory "$RUNSAS_DEBUG_FILE" "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid"
    copy_files_to_a_directory "$RUNSAS_TMP_DEBUG_FILE" "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid"
    copy_files_to_a_directory "$RUNSAS_SESSION_LOG_FILE" "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid"

    # Kill all running processes (one at a time, including child processes)
    while IFS='|' read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do
        get_keyval_from_batch_state runsas_job_pid runsas_job_pid $jid $global_batchid
        if [[ ! -z "$runsas_job_pid" && "$runsas_job_pid" != "" && $runsas_job_pid -gt 0 ]]; then
            running_processes_housekeeping $runsas_job_pid $j
        fi
    done < $JOB_LIST_FILE 
    
    # Goodbye!
    publish_to_messagebar "${green_bg}${black}*** runSAS is exiting now ***${white}"
    sleep 0.3
    publish_to_messagebar "${white} ${white}"

    # Show cursor
    show_cursor

    # Reset the scrollable area 
    tput csr 0 $tput_lines

    # Reset if the interactive mode is on
    if [[ $runsas_mode_interactiveflag == 1 ]]; then
        reset
    fi

    # Enable enter key and keyboard inputs
    enable_enter_key
    enable_enter_key keyboard

    # Goodbye!
    exit 1
}
#------
# Name: move_cursor()
# Desc: Moves the cursor to a specific point on terminal using ANSI/VT100 cursor control sequences
#   In: row-position, col-position, row-offset, col-offset
#  Out: <NA>
#------
function move_cursor(){
    # Input parameters
	target_row_pos=$1
	target_col_pos=$2
    target_row_offset=${3:-1}
    target_col_offset=${4:-1}

	# Go to the specified row (make sure no invalid position is requested)
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        if [[ "$target_row_pos" != "" ]] && [[ "$target_col_pos" != "" ]] && [[ ! -z "$target_row_pos" ]] && [[ ! -z "$target_col_pos" ]]; then
            if [[ $target_row_offset -le $target_row_pos ]] && [[ $target_col_offset -le $target_col_pos ]]; then
                tput cup $((target_row_pos-target_row_offset)) $((target_col_pos-target_col_offset))
            fi
        fi
    fi
}
#------
# Name: get_current_terminal_cursor_position()
# Desc: Get the current cursor position, reference: https://stackoverflow.com/questions/2575037/how-to-get-the-cursor-position-in-bash
#   In: col-pos-output-variable-name (optional), row-pos-output-variable-name (optional)
#  Out: current_cursor_row_pos, current_cursor_col_pos
#------
function get_current_terminal_cursor_position() {
    # Input parameters
    row_pos_output_var="${1:-current_cursor_row_pos}"
    col_pos_output_var="${1:-current_cursor_col_pos}"

    # Get cursor position
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        local pos
        printf "${red}"
        IFS='[;' read -p < /dev/tty $'\e[6n' -d R -a pos -rs || echo "*** ERROR: The cursor position fetch function failed with an error: $? ; ${pos[*]} ***"
        # Assign to the output variables
        eval "$row_pos_output_var=${pos[1]}"
        eval "$col_pos_output_var=${pos[2]}"
        printf "${white}"
    fi
}
#------
# Name: get_remaining_lines_on_terminal()
# Desc: Get the rows/lines remaining on screen
#   In: <NA>
#  Out: runsas_remaining_lines_in_screen
#------
function get_remaining_lines_on_terminal(){
    # Output 
    runsas_remaining_lines_in_screen=999999 # Default!

    # Calculate
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        # Get current terminal positions
        get_current_terminal_cursor_position # returns $row_pos_output_var
        current_terminal_height=`tput lines`

        # Remaining lines in the screen
        if [[ "$row_pos_output_var" != "" ]] && [[ $row_pos_output_var -le $current_terminal_height ]]; then
            runsas_remaining_lines_in_screen=$((current_terminal_height-row_pos_output_var))
        fi
    fi

    # Debug
    print2debug runsas_remaining_lines_in_screen ">>> Remaining lines on the screen: " " <<<"   
}
#------
# Name: get_remaining_cols_on_terminal()
# Desc: Get the cols remaining on screen
#   In: <NA>
#  Out: runsas_remaining_cols_in_screen
#------
function get_remaining_cols_on_terminal(){
    runsas_remaining_cols_in_screen=1

    # Get the current terminal cursor position
    get_current_terminal_cursor_position
    current_available_cols=`tput cols`            
    runsas_remaining_cols_in_screen=$((current_available_cols-$col_pos_output_var))
}
#------
# Name: clear_the_rest_of_the_line()
# Desc: Clear the rest of the line
#   In: <NA>
#  Out: <NA>
#------
function clear_the_rest_of_the_line(){
    # Get the remaining columns on the current line
    get_remaining_cols_on_terminal

    # Clear the columns with blanks
    printf "%${runsas_remaining_cols_in_screen}s" " "
}
#------
# Name: refresh_term_screen_size()
# Desc: This function captures the current size of the terminal 
#   In: <NA>
#  Out: term_total_no_of_rows, term_total_no_of_cols
#------
function refresh_term_screen_size(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        # Capture the rows and column positions
        term_total_no_of_rows=`tput lines`
        term_total_no_of_cols=`tput cols`

        # Capture the terminal row/col info when it's invoked the fisrt time
        get_keyval original_term_total_no_of_rows
        get_keyval original_term_total_no_of_cols
        if [[ -z "$original_term_total_no_of_rows" ]] || [[ -z "$original_term_total_no_of_cols" ]]; then
            # Store the original row/col positions
            assign_and_preserve original_term_total_no_of_rows $term_total_no_of_rows
            assign_and_preserve original_term_total_no_of_cols $term_total_no_of_cols
        fi

        # Store the terminal total number of rows (exclude the message bar)
        let term_total_no_of_rows=$term_total_no_of_rows-$TERM_BOTTOM_LINES_EXCLUDE_COUNT+1

        # Store the currernt terminal positions 
        assign_and_preserve current_term_total_no_of_rows $term_total_no_of_rows
        assign_and_preserve current_term_total_no_of_cols $term_total_no_of_cols
    fi
}
#------
# Name: check_terminal_size()
# Desc: This function checks the current terminal size and prompts the user to resize the screen if needed (and finally saves the current terminal size)
#   In: required-rows, required-cols
#  Out: <NA>
#------
function check_terminal_size(){
    # Input parameters
    required_terminal_rows=${1:-$RUNSAS_REQUIRED_TERMINAL_ROWS}
    required_terminal_cols=${2:-$RUNSAS_REQUIRED_TERMINAL_COLS}

    # Flag
    term_req_resizing=0

    # Current terminal width
    current_term_width=`tput cols`
    current_term_height=`tput lines`

    # Hide the cursor
    hide_cursor  

    # Check (skip on batch mode)
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        while [[ $current_term_width -lt $required_terminal_cols ]] || [[ $current_term_height -lt $required_terminal_rows ]]; do
            # Flag to indicate the terminal required resizing
            term_req_resizing=1

            # Hide the cursor
            hide_cursor        

            # Message
            printf "${red}*** ERROR: Terminal window too small to fit the flows, requires at least $required_terminal_cols cols x $required_terminal_rows rows terminal ***${white}"
            printf "${red} Current terminal: $current_term_width cols x $current_term_height rows). *** ${white}\n"
            printf "${red_bg}${black}Try to close side panes and zoom out by pressing CTRL key and scroll down/up using your mouse scroll wheel, runSAS will auto-detect the right settings and resume.${white}"
            
            # Refresh
            current_term_width=`tput cols`
            current_term_height=`tput lines`

            # Clear
            clear
        done 

        # Confirm the dimensions
        if [[ $term_req_resizing -eq 1 ]]; then
            printf "${green}Good work, it's now $current_term_width cols x $current_term_height rows${white}\n"
            press_enter_key_to_continue
            clear
        fi
    fi
}
#------
# Name: restore_terminal_screen_cursor_positions()
# Desc: This function restores the cursor positions based on the terminal size, job number etc.
#   In: <NA>
#  Out: <NA>
#------
function restore_terminal_screen_cursor_positions(){
        # Capture the terminal size
        refresh_term_screen_size

        # Get the stored cursor positions (if there's any)
        get_keyval_from_batch_state runsas_job_cursor_row_pos 
        get_keyval_from_batch_state runsas_job_cursor_col_pos 

        # Get current cursor positions
        get_current_terminal_cursor_position

        # Print to debug file
        print2debug current_cursor_row_pos "--- Cursor positions (before offset) " " ---"
        print2debug runsas_job_cursor_row_pos

        # If the current row position is equal (or greater than) to the max no of rows on the terminal, the terminal will scroll so make the cursor position relative than absolute
        if [[ $current_cursor_row_pos -ne $(tput lines) ]]; then # If the cursor returned from message bar then do not apply offset.
            if [[ $current_cursor_row_pos -ge $term_total_no_of_rows ]] && [[ $term_row_offset -le $((TOTAL_NO_OF_JOBS_COUNTER_CMD+1)) ]]; then
                let term_row_offset+=1
            fi
        fi

        # Print to debug file
        print2debug term_total_no_of_rows
        print2debug term_row_offset

        # Get the row position from the first job
        get_keyval_from_batch_state runsas_job_cursor_row_pos first_runsas_job_cursor_row_pos 1

        # Apply offset
        if [[ -z "$runsas_job_cursor_row_pos" ]] || [[ -z "$runsas_job_cursor_col_pos" ]]; then
            assign_and_preserve runsas_job_cursor_row_pos $current_cursor_row_pos
            assign_and_preserve runsas_job_cursor_col_pos $current_cursor_col_pos
        else
            # Apply offset only when there's a need to
            if [[ $term_row_offset -gt 0 ]]; then
                if [[ -z "$row_offset_applied_already" ]] || [[ "$row_offset_applied_already" == "" ]] || [[ $row_offset_applied_already -eq 0 ]]; then
                    let job_row_offset=$((term_row_offset-runsas_jobid))
                    if [[ $runsas_jobid -eq 1 ]]; then
                        assign_and_preserve runsas_job_cursor_row_pos $((runsas_job_cursor_row_pos-job_row_offset))
                    else
                        assign_and_preserve runsas_job_cursor_row_pos $((first_runsas_job_cursor_row_pos+runsas_jobid-1))
                    fi
                    assign_and_preserve row_offset_applied_already 1
                fi
            else
                assign_and_preserve runsas_job_cursor_row_pos $runsas_job_cursor_row_pos
                assign_and_preserve row_offset_applied_already 0
            fi
        fi

        # Print to debug file
        print2debug job_row_offset ">> Job offset "
        print2debug runsas_job_cursor_row_pos
        print2debug runsas_job_cursor_col_pos

        # Finally place the cursor
        move_cursor $runsas_job_cursor_row_pos $runsas_job_cursor_col_pos
}
#------
# Name: display_fillers()
# Desc: Fetch cursor position and populate the fillers
#   In: filler-character-upto-column, filler-character, optional-backspace-counts
#  Out: <NA>
#------
function display_fillers(){
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        # Get the current cursor position
        get_current_terminal_cursor_position

        # Set the parameters
        filler_char_upto_col=$1
        filler_char_to_display=$2
        pre_filler_backspace_char_count=$3
        use_preserved_filler_char_count=$4
        post_filler_backspace_char_count=$5
        filler_char_color=$6

        # Calculate no of fillers required to reach the specified column
        filler_char_count=$((filler_char_upto_col-current_cursor_col_pos))

        # See if a backspace is requested (pre filler)
        if [[ "$pre_filler_backspace_char_count" != "0" ]] && [[ "$pre_filler_backspace_char_count" != "" ]]; then
            for (( i=1; i<=$pre_filler_backspace_char_count; i++ )); do
                printf "\b"
            done
        fi

        # Display fillers
        if [[ "$use_preserved_filler_char_count" != "N" ]] && [[ "$use_preserved_filler_char_count" != "" ]]; then
            for (( i=1; i<=$filler_char_count_prev; i++ )); do
                printf "${!filler_char_color}$filler_char_to_display${white}" 
            done   
        else
            for (( i=1; i<=$filler_char_count; i++ )); do
                printf "${!filler_char_color}$filler_char_to_display${white}"         
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
    else
        printf "${!filler_char_color}...${white}"
    fi
}
#------
# Name: disable_keyboard_inputs()
# Desc: This function will disable user inputs via keyboard
#   In: <NA>
#  Out: <NA>
#------
function disable_keyboard_inputs(){
    # Disable user inputs via keyboard
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        stty -echo < /dev/tty
    fi
}
#------
# Name: enable_keyboard_inputs()
# Desc: This function will enable user inputs via keyboard
#   In: <NA>
#  Out: <NA>
#------
function enable_keyboard_inputs(){
    # Enable user inputs via keyboard
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        stty echo < /dev/tty
    fi
}
#------
# Name: disable_enter_key()
# Desc: This function will disable carriage return (ENTER key)
#   In: <NA>
#  Out: <NA>
#------
function disable_enter_key(){
    # Disable carriage return (ENTER key) during the script run
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        stty igncr < /dev/tty
        # Disable keyboard inputs too if user has asked for it
        if [[ ! "$1" == "" ]]; then
            disable_keyboard_inputs
        fi
    fi
}
#------
# Name: enable_enter_key()
# Desc: This function will enable carriage return (ENTER key)
#   In: <NA>
#  Out: <NA>
#------
function enable_enter_key(){
    # Enable carriage return (ENTER key) during the script run
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        stty -igncr < /dev/tty
        # Enable keyboard inputs too if user has asked for it
        if [[ ! "$1" == "" ]]; then
            enable_keyboard_inputs
        fi
    fi
}
#------
# Name: press_enter_key_to_continue()
# Desc: This function will pause the script and wait for the ENTER key to be pressed
#   In: before-newline-count, after-newline-count, color (default is green)
#  Out: <NA>
#------
function press_enter_key_to_continue(){
	# Input parameters
    ekey_newlines_before=$1
    ekey_newlines_after=$2
	ekey_color=${3:-"green"}

    # Skip in batch mode
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        # Enable carriage return (ENTER key) during the script run
        enable_enter_key
        
        # Newlines (before)
        if [[ "$ekey_newlines_before" != "" ]] && [[ "$ekey_newlines_before" != "0" ]]; then
            for (( i=1; i<=$ekey_newlines_before; i++ )); do
                printf "\n"
            done
        fi
        
        # Show message
        printf "${!ekey_color}Press ENTER key to continue...${white}"
        read enter_to_continue_user_input
        
        # Newlines (after)
        if [[ "$ekey_newlines_after" != "" ]] && [[ "$ekey_newlines_after" != "0" ]]; then
            for (( i=1; i<=$ekey_newlines_after; i++ )); do
                printf "\n"
            done
        fi
        
        # Disable carriage return (ENTER key) during the script run
        enable_enter_key
    fi
}
#------
# Name: check_for_multiple_instances_of_job()
# Desc: This function checks if a job (if specified at launch) is specified more than once in the job list and shows an error to avoid confusion (doesn't error if a index is specified)
#   In: <job-name>
#  Out: <NA>
#------
function check_for_multiple_instances_of_job(){
	joblist_job_count=0 
	while IFS='|' read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do
		if [[ "$j" == "$1" ]]; then
			let joblist_job_count+=1
		fi
	done < $JOB_LIST_FILE
	if [[ $joblist_job_count > 1 ]]; then
		printf "\n${red}*** ERROR: Job ${black}${red_bg}$1${end}${red} has been specified more than once in the job list, launch the script again with a job index/number instead (ex.: ./runSAS.sh -f 16) ***${white}"
		clear_session_and_exit
	fi
}
#------
# Name: scan_sas_programs_for_debug_options()
# Desc: This function warns the user that SAS debug options are set
#   In: <sas-file-name>
#  Out: <NA>
#------
function scan_sas_programs_for_debug_options(){
	 # Check if there are any debug options in the sas file
	grep -i "$SASTRACE_SEARCH_STRING" $1 > $SASTRACE_CHECK_FILE
	# Show a warning to the user
	if [ -s $SASTRACE_CHECK_FILE ]; then
		printf "\n${yellow}WARNING: SAS global options sastrace is detected in $1 deployed code file (usually harmless but can degrade job runtime performance)\n\n"
	fi
}
#------
# Name: update_job_mode_flags()
# Desc: Creates different flags for jobs used by various modes
#   In: <NA>
#  Out: <NA>
#------
function update_job_mode_flags(){
    # No parameter modes or no job modes are specified
    if [[ $RUNSAS_INVOKED_IN_NON_RUNSAS_MODE -gt -1 ]] || [[ "$runsas_job_filter_mode" = "" ]]; then
        # Set runflag=1 for all
        assign_and_preserve runsas_mode_runflag 1
    fi
    if [[ $RUNSAS_INVOKED_IN_INTERACTIVE_MODE -gt -1 ]]; then
        # Set interactiveflag=1 and runflag=1 for all
        assign_and_preserve runsas_mode_interactiveflag 1
        assign_and_preserve runsas_mode_runflag 1

        # Check for --byflow override
        in_byflow_mode=0
        if [[ $RUNSAS_INVOKED_IN_BYFLOW_MODE -gt -1 ]]; then
            in_byflow_mode=1
            print2debug in_byflow_mode "*** NOTE: --byflow override specified for the interactive mode, the batch will run in flow wise sequential mode " " ***"
        fi
    fi 

    # One parameter modes
    if [[ $RUNSAS_INVOKED_IN_JOB_MODE -gt -1 ]]; then
        # Skip the tags, as it's a adhoc mode
        sleep 0.1
    fi 
    if [[ $RUNSAS_INVOKED_IN_ONLY_MODE -gt -1 ]]; then
        # runflag=1 for just that job 
        if [[ $runsas_jobid -eq ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_ONLY_MODE+1]} ]]; then
            assign_and_preserve runsas_mode_runflag 1
        fi
    fi 
    if [[ $RUNSAS_INVOKED_IN_UNTIL_MODE -gt -1 ]]; then
        # runflag=1 for all jobs until the marker (including the marker) 
        if [[ $runsas_jobid -le ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_UNTIL_MODE+1]} ]]; then
            assign_and_preserve runsas_mode_runflag 1
        fi
    fi 
    if [[ $RUNSAS_INVOKED_IN_FROM_MODE -gt -1 ]]; then
        # runflag=1 for all jobs from the marker (including the marker) 
        if [[ $runsas_jobid -ge ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_MODE+1]} ]]; then 
            assign_and_preserve runsas_mode_runflag 1
        fi
    fi 

    # Two parameter modes 
    if [[ $RUNSAS_INVOKED_IN_FROM_UNTIL_MODE -gt -1 ]]; then
        # runflag=1 for jobs between the markers (including the markers)
        if [[ $runsas_jobid -ge ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_UNTIL_MODE+1]} ]] && [[ $runsas_jobid -le ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_UNTIL_MODE+2]} ]]; then
            assign_and_preserve runsas_mode_runflag 1
        fi
    fi 
    if [[ $RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE -gt -1 ]]; then
        # runflag=1 for all jobs and interactiveflag=1 for jobs between the markers (including the markers) 
        assign_and_preserve runsas_mode_runflag 1
        if [[ $runsas_jobid -ge ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE+1]} ]] && [[ $runsas_jobid -le ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE+2]} ]]; then
            assign_and_preserve runsas_mode_interactiveflag 1
        fi
    fi 
    if [[ $RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE -gt -1 ]]; then
        # runflag=1 & interactiveflag=1 for all jobs between the markers (including the markers)
        if [[ $runsas_jobid -ge ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE+1]} ]] && [[ $runsas_jobid -le ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE+2]} ]]; then
            assign_and_preserve runsas_mode_interactiveflag 1
            assign_and_preserve runsas_mode_runflag 1
        fi
    fi 
    if [[ $RUNSAS_INVOKED_IN_SKIP_MODE -gt -1 ]]; then
        # runflag=1 for all jobs other than jobs between the markers (including the markers)
        assign_and_preserve runsas_mode_runflag 1
        if [[ $runsas_jobid -ge ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_SKIP_MODE+1]} ]] && [[ $runsas_jobid -le ${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_SKIP_MODE+2]} ]]; then
            assign_and_preserve runsas_mode_runflag 0
        fi
    fi 
}
#------
# Name: set_script_mode_flags()
# Desc: This function will set the script mode flags
#   In: <NA>
#  Out: <NA>
#------
function set_script_mode_flags(){
    # Validate the script modes and it's parameters
    for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); 
    do    
        # Firstly, set the mode flags with values equal to the position of the argument
        case ${RUNSAS_PARAMETERS_ARRAY[p]} in
            -i)
                RUNSAS_INVOKED_IN_INTERACTIVE_MODE=$p
                ;;
            -v)
                RUNSAS_INVOKED_IN_VERSION_MODE=$p
                ;;
            -f)
                RUNSAS_INVOKED_IN_FROM_MODE=$p
                ;;
            -u)
                RUNSAS_INVOKED_IN_UNTIL_MODE=$p
                ;;
            -o)
                RUNSAS_INVOKED_IN_ONLY_MODE=$p
                ;;
            -j)
                RUNSAS_INVOKED_IN_JOB_MODE=$p
                ;;
            -fu)
                RUNSAS_INVOKED_IN_FROM_UNTIL_MODE=$p
                ;;
            -fui)
                RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE=$p
                ;;
            -fuis)
                RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE=$p
                ;;
            -s)
                RUNSAS_INVOKED_IN_SKIP_MODE=$p
                ;;
            --noemail)
                RUNSAS_INVOKED_IN_NOEMAIL_MODE=$p
                ;;
            --nomail)
                RUNSAS_INVOKED_IN_NOEMAIL_MODE=$p
                ;;
            --update)
                RUNSAS_INVOKED_IN_UPDATE_MODE=$p
                ;;
            --help)
                RUNSAS_INVOKED_IN_HELP_MODE=$p
                ;;
            --version)
                RUNSAS_INVOKED_IN_VERSION_MODE=$p
                ;;
            -parms)
                RUNSAS_INVOKED_IN_PARAMETERS_MODE=$p
                ;;
            -parameters)
                RUNSAS_INVOKED_IN_PARAMETERS_MODE=$p
                ;;
            --log)
                RUNSAS_INVOKED_IN_LOG_MODE=$p
                ;;
            --last)
                RUNSAS_INVOKED_IN_LOG_MODE=$p
                ;;
            --update-c)
                RUNSAS_INVOKED_IN_UPDATE_COMPATIBILITY_CHECK_MODE=$p
                ;;
            --list)
                RUNSAS_INVOKED_IN_LIST_MODE=$p
                ;;
            --byflow)
                RUNSAS_INVOKED_IN_BYFLOW_MODE=$p
                ;;
            --resume)
                RUNSAS_INVOKED_IN_RESUME_MODE=$p
                ;;
            --delay)
                RUNSAS_INVOKED_IN_DELAY_MODE=$p
                ;;
            --batch)
                RUNSAS_INVOKED_IN_BATCH_MODE=$p
                ;;
            --nocolors)
                RUNSAS_INVOKED_IN_NOCOLOR_MODE=$p
                ;;
            --message)
                RUNSAS_INVOKED_IN_MESSAGE_MODE=$p
                ;;
            --email)
                RUNSAS_INVOKED_IN_EMAIL_MODE=$p
                ;;
            --joblist)
                RUNSAS_INVOKED_IN_JOBLIST_MODE=$p
                ;;
            --redeploy)
                RUNSAS_INVOKED_IN_REDEPLOY_MODE=$p
                ;;
            *)
                DUMMY=1
                ;;
        esac

        # Set the no mode flag
        if [[ \
                RUNSAS_INVOKED_IN_INTERACTIVE_MODE -eq -1  && \
                RUNSAS_INVOKED_IN_VERSION_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_FROM_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_UNTIL_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_ONLY_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_JOB_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_FROM_UNTIL_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_SKIP_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_NOEMAIL_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_UPDATE_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_HELP_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_VERSION_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_PARAMETERS_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_LOG_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_UPDATE_COMPATIBILITY_CHECK_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_LIST_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_BYFLOW_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_RESUME_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_DELAY_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_BATCH_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_NOCOLOR_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_MESSAGE_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_EMAIL_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_JOBLIST_MODE -eq -1 && \
                RUNSAS_INVOKED_IN_REDEPLOY_MODE -eq -1 \
            ]]; then 
            RUNSAS_INVOKED_IN_NON_RUNSAS_MODE=1
        else
            RUNSAS_INVOKED_IN_NON_RUNSAS_MODE=-1
        fi

        # Invalid in batch mode
        if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -gt -1 ]]; then
            if [[ \
                    $RUNSAS_INVOKED_IN_INTERACTIVE_MODE -gt -1 || \
                    $RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE -gt -1 || \
                    $RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE -gt -1 || \
                    $RUNSAS_INVOKED_IN_UPDATE_MODE -gt -1 || \
                    $RUNSAS_INVOKED_IN_REDEPLOY_MODE -gt -1 || \
                    $RUNSAS_INVOKED_IN_DELAY_MODE -gt -1 \
            ]]; then
                printf "\n${red}*** ERROR: Few options (-i, -fui, fuis, --delay, --update, --redeploy) cannot be combined with --batch mode ***${white}"
                clear_session_and_exit
            fi
        fi
    done

    # Print flags to debug
    print2debug "*** Validation of modes" " ***"
    print2debug RUNSAS_INVOKED_IN_INTERACTIVE_MODE 
    print2debug RUNSAS_INVOKED_IN_VERSION_MODE
    print2debug RUNSAS_INVOKED_IN_FROM_MODE
    print2debug RUNSAS_INVOKED_IN_UNTIL_MODE
    print2debug RUNSAS_INVOKED_IN_ONLY_MODE
    print2debug RUNSAS_INVOKED_IN_JOB_MODE
    print2debug RUNSAS_INVOKED_IN_FROM_UNTIL_MODE
    print2debug RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE
    print2debug RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE
    print2debug RUNSAS_INVOKED_IN_SKIP_MODE
    print2debug RUNSAS_INVOKED_IN_NOEMAIL_MODE
    print2debug RUNSAS_INVOKED_IN_UPDATE_MODE
    print2debug RUNSAS_INVOKED_IN_HELP_MODE
    print2debug RUNSAS_INVOKED_IN_VERSION_MODE
    print2debug RUNSAS_INVOKED_IN_PARAMETERS_MODE
    print2debug RUNSAS_INVOKED_IN_LOG_MODE
    print2debug RUNSAS_INVOKED_IN_UPDATE_COMPATIBILITY_CHECK_MODE
    print2debug RUNSAS_INVOKED_IN_LIST_MODE
    print2debug RUNSAS_INVOKED_IN_BYFLOW_MODE
    print2debug RUNSAS_INVOKED_IN_RESUME_MODE
    print2debug RUNSAS_INVOKED_IN_DELAY_MODE
    print2debug RUNSAS_INVOKED_IN_BATCH_MODE
    print2debug RUNSAS_INVOKED_IN_NOCOLOR_MODE
    print2debug RUNSAS_INVOKED_IN_MESSAGE_MODE
    print2debug RUNSAS_INVOKED_IN_EMAIL_MODE
    print2debug RUNSAS_INVOKED_IN_JOBLIST_MODE
    print2debug RUNSAS_INVOKED_IN_REDEPLOY_MODE
    print2debug RUNSAS_INVOKED_IN_NON_RUNSAS_MODE
}
#------
# Name: validate_script_modes()
# Desc: This function validates input parameters to runSAS script
#   In: <NA>
#  Out: <NA>
#------
function validate_script_modes(){
    # Print to debug file
    print2debug SHORTFORM_MODE_NO_PARMS[@] "--- Mode validation parameters --- [" "]---" 
    print2debug SHORTFORM_MODE_SINGLE_PARM[@] 
    print2debug SHORTFORM_MODE_DOUBLE_PARMS[@] 
    print2debug LONGFORM_MODE_NO_PARMS[@] 
    print2debug LONGFORM_MODE_SINGLE_PARM[@] 
    print2debug LONGFORM_MODE_MULTI_PARMS[@] 

    # Refresh the counter
    TOTAL_NO_OF_JOBS_COUNTER_CMD=`cat .job.list | wc -l`

    # Set the flag (before validation)
    runsas_job_filter_mode=""

    # Print a message
    publish_to_messagebar "${yellow}Checking script modes, please wait...${white}"

    # Validate the script modes and it's parameters
    for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); 
    do    
        # Shortform - single parameter mode
        if [[ "${SHORTFORM_MODE_SINGLE_PARM[@]}" =~ " ${RUNSAS_PARAMETERS_ARRAY[p]} " ]]  && [[ ! "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-j" ]]; then 
            # Index to values for the modes(p is the mode) 
            let p1=p+1
            let p2=p+2
            let p3=p+3
            
            # Validations:
            # Job index/number must be specified (no names anymore)
            if [[ ! ${RUNSAS_PARAMETERS_ARRAY[p1]} =~ $RUNSAS_REGEX_NUMBER ]]; then
                printf "\n${red}*** ERROR: A valid job index/number is required for ${RUNSAS_PARAMETERS_ARRAY[p]} option, job names are not allowed anymore ***${white}"
                clear_session_and_exit
            fi

            # Show job name for the index
            get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[p1]} $JOB_LIST_FILE 4

            # Set the flag
            runsas_job_filter_mode="SF-SINGLE"
        fi

        # Shortform - double parameter mode
        if [[ "${SHORTFORM_MODE_DOUBLE_PARMS[@]}" =~ " ${RUNSAS_PARAMETERS_ARRAY[p]} " ]]; then 
            # Index to values for the modes(p is the mode) 
            let p1=p+1
            let p2=p+2
            let p3=p+3

            if [[ ! ${RUNSAS_PARAMETERS_ARRAY[p1]} =~ $RUNSAS_REGEX_NUMBER ]] || [[ ! ${RUNSAS_PARAMETERS_ARRAY[p2]} =~ $RUNSAS_REGEX_NUMBER ]]; then
                printf "\n${red}*** ERROR: Two valid job indexes/numbers (i.e. from job and to job) are required for ${RUNSAS_PARAMETERS_ARRAY[p]} option (jobnames are not allowed anymore in latest versions of runSAS) ***${white}"
                clear_session_and_exit
            fi
            # Check if any second parameter is specified
            if [[ "${RUNSAS_PARAMETERS_ARRAY[p2]}" == "" ]]; then 
                printf "\n${red}*** ERROR: A valid second parameter (i.e. \"to\" job name) was not provided for ${RUNSAS_PARAMETERS_ARRAY[p]} option (received \"${RUNSAS_PARAMETERS_ARRAY[p2]}\" instead) *** ${white}"
                clear_session_and_exit
            fi

            # Show job name for the index
            get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[p1]} $JOB_LIST_FILE 4
            get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[p2]} $JOB_LIST_FILE 4

            # Set the flag
            runsas_job_filter_mode="SF-DOUBLE"
        fi
    done

    # Print parameters to debug
    print2debug RUNSAS_PARAMETERS_ARRAY[@] "---Script parameters [" "]---"

    # Print a message
    publish_to_messagebar ""
    
    # Filter mode to debug 
    print2debug runsas_job_filter_mode
    
}
#------
# Name: messagebar_controlseq()
# Desc: This function is called by publish_to_messagebar() 
#   In: <NA>
#  Out: <NA>
#------
function messagebar_controlseq() {
    # Save cursor position
    tput sc

    # Add a new line
    # tput il 1

    # Change scroll region to exclude the last lines
    tput csr 0 $(($(tput lines) - TERM_BOTTOM_LINES_EXCLUDE_COUNT))

    # Move cursor to bottom line
    tput cup $(tput lines) 0

    # Clear to the end of the line
    tput el

    # Echo the content on that row
    cat "${BOTTOM_LINE_CONTENT_FILE}"

    # Get the value from user via user prompt
    if [[ "$1" == "Y" ]]; then
        # Enable keyboard and user inputs
        enable_enter_key
        enable_keyboard_inputs
    
        # Show the prompt
        read ${2} < /dev/tty

        # Print two lines after the last job
        get_keyval_from_batch_state runsas_job_cursor_row_pos first_job_cursor_row_pos 1 $stallcheck_batchid
        move_cursor $runsas_job_cursor_row_pos
    else
        # Restore cursor position
        tput rc
    fi
}
#------
# Name: publish_to_messagebar()
# Desc: This function creates a message bar feature and will update the message
#   In: message, prompt-required (optional), prompt-variable (optional)
#  Out: prompt-variable (assigned if the prompt is used)
#  Ref: https://stackoverflow.com/questions/51175911/line-created-with-tput-gets-removed-on-scroll
#------
function publish_to_messagebar() {
    # Input parameters
    pubmsg_message=$1
    pubmsg_prompt_required=$2
    pubmsg_prompt_var_name=$3
    pubmsg_prompt_opt=$4

    # Get current cursor position
    get_current_terminal_cursor_position

    # Skip the batch mode
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        # Publish to the message bar
        local bottomLinePromptSeq='\[$(messagebar_controlseq)\]'

        # To the bottom lines
        if [[ "$PS1" != *$bottomLinePromptSeq* ]]
        then
            PS1="$bottomLinePromptSeq$PS1"
        fi
        if [ -z "$BOTTOM_LINE_CONTENT_FILE" ]
        then
            export BOTTOM_LINE_CONTENT_FILE="$(mktemp --tmpdir messagebar.$$.XXX)"
        fi

        # Print the message to the file
        echo -ne "$pubmsg_message" > "$BOTTOM_LINE_CONTENT_FILE"
        
        # Read the file, refresh the message bar
        messagebar_controlseq $pubmsg_prompt_required $pubmsg_prompt_var_name $pubmsg_prompt_opt

        # Restore the cursor back to the content
        move_cursor $row_pos_output_var $col_pos_output_var    
        
        # echo -ne "" > "$BOTTOM_LINE_CONTENT_FILE"
        # messagebar_controlseq $pubmsg_prompt_required $pubmsg_prompt_var_name $pubmsg_prompt_opt
    fi
}
#------
# Name: check_if_batch_has_stalled()
# Desc: This function checks if the batch has stalled (or failed!)
#   In: job-list-file, batchid (optional)
#  Out: <NA>
#------
function check_if_batch_has_stalled(){
    # Input parameters
    stallcheck_file=${1:-$JOB_LIST_FILE}
    stallcheck_batchid=${2:-$global_batchid}

    # Other parameters
    batch_is_stalled=0 
    cyclic_dependency_detected=0
    count_of_dep_jobs_currently_running=0
    count_of_jobs_currently_running=0

    # Reset the flag if the batch is complete
    if [[ $RUNSAS_BATCH_COMPLETE_FLAG -eq 1 ]]; then
        batch_is_stalled=0
    fi

    # Loop through all jobs
    while IFS='|' read -r flowid flow jobid job jobdep logicop jobrc runflag opt subopt sappdir bservdir bsh blogdir bjobdir; do
        # Get the current job return codes and run flags
        get_keyval_from_batch_state runsas_mode_runflag runsas_mode_runflag $jobid $stallcheck_batchid
        get_keyval_from_batch_state runsas_jobrc runsas_jobrc $jobid $stallcheck_batchid

        # Debug
        print2debug jobid "\n*** Stall check for [" "] ***"

        # Check if the batch is stalled
        if [[ $runsas_mode_runflag -eq 1 ]] && [[ "$runflag" == "Y" ]]; then
            # (1) Status: PENDING but one of the dependent(s) has failed!
            if [[ $runsas_jobrc -eq $RC_JOB_PENDING ]]; then                
                IFS=','
                jobdep_array=( $jobdep )
                jobdep_array_elem_count=${#jobdep_array[@]}
                IFS=$SERVER_IFS

                # Debug
                # print2debug jobid "${CHILD_DECORATOR}PENDING job check for [" "]" 

                # Loop through dependencies of the current job
                for (( i=0; i<${jobdep_array_elem_count}; i++ ));
                do                 
                    jobdep_i="${jobdep_array[i]}"
                    get_keyval_from_batch_state runsas_jobrc jobdep_i_jobrc $jobdep_i
                    get_keyval_from_batch_state runsas_max_jobrc jobdep_i_max_jobrc $jobdep_i

                    if [[ $jobid -ne $jobdep_i ]]; then 
                        # Has any of the dependent job failed? (do not prompt too early - purpose of $error_message_shown_on_job_fail)
                        if [[ $jobdep_i_jobrc -gt $jobdep_i_max_jobrc ]]; then
                            if [[ "$error_message_shown_on_job_fail" == "Y" ]]; then
                                let batch_is_stalled+=1
                                update_batch_state error_message_shown_on_job_fail "N" $jobid $global_batchid # Reset for retries
                            fi
                        fi

                        # Are all dependent jobs still in pending state?
                        if [[ $jobdep_i_jobrc -eq $RC_JOB_PENDING ]]; then
                            if [[ $runsas_flow_loop_iterator -gt 5 ]] && [[ $count_of_dep_jobs_currently_running -le 0 ]]; then # avoids premature termination, every job in the flow must have had one chance to start!
                                cyclic_dependency_detected=1
                            fi
                        fi

                        # Is any dependent job still running?
                        if [[ $jobdep_i_jobrc -eq $RC_JOB_TRIGGERED ]]; then 
                            cyclic_dependency_detected=0 
                            let count_of_dep_jobs_currently_running+=1
                            runsas_flow_loop_iterator=1 # Reset this! 
                        fi

                        # Print to debug
                        # print2debug jobdep_i "${SPACE_DECORATOR}${CHILD_DECORATOR}Stall check dependent job [" "] stalled=$batch_is_stalled | jobdep_i_jobrc=$jobdep_i_jobrc | jobdep_i_max_jobrc=$jobdep_i_max_jobrc | error_message_shown_on_job_fail=$error_message_shown_on_job_fail | cyclic_dependency_detected=$cyclic_dependency_detected | count_of_dep_jobs_currently_running=$count_of_dep_jobs_currently_running | count_of_jobs_currently_running=$count_of_jobs_currently_running"
                    fi
                done
            fi

            # (2) Status: FAILED, a job in the flow has failed!
            if [[ $runsas_jobrc -gt $jobrc ]]; then
                if [[ "$error_message_shown_on_job_fail" == "Y" ]]; then
                    let batch_is_stalled+=1
                    update_batch_state error_message_shown_on_job_fail "N" $jobid $global_batchid # Reset for retries
                fi
                # print2debug jobid "${CHILD_DECORATOR}FAILED job check for [" "]" 
                # print2debug jobdep_i "${SPACE_DECORATOR}${CHILD_DECORATOR}Stall check dependent job [" "] stalled=$batch_is_stalled | jobdep_i_jobrc=$jobdep_i_jobrc | jobdep_i_max_jobrc=$jobdep_i_max_jobrc | error_message_shown_on_job_fail=$error_message_shown_on_job_fail | cyclic_dependency_detected=$cyclic_dependency_detected | count_of_dep_jobs_currently_running=$count_of_dep_jobs_currently_running | count_of_jobs_currently_running=$count_of_jobs_currently_running"
            fi

            # (3) Status: RUNNING, at least one job is still running...
            if [[ $runsas_jobrc -eq $RC_JOB_TRIGGERED ]] || [[ $count_of_jobs_currently_running -ge 1 ]]; then
                cyclic_dependency_detected=0
                batch_is_stalled=0
                let count_of_jobs_currently_running+=1
                # print2debug jobid "${CHILD_DECORATOR}RUNNING job check for [" "]" 
                # print2debug jobdep_i "${SPACE_DECORATOR}${CHILD_DECORATOR}Stall check dependent job [" "] stalled=$batch_is_stalled | jobdep_i_jobrc=$jobdep_i_jobrc | jobdep_i_max_jobrc=$jobdep_i_max_jobrc | error_message_shown_on_job_fail=$error_message_shown_on_job_fail | cyclic_dependency_detected=$cyclic_dependency_detected | count_of_dep_jobs_currently_running=$count_of_dep_jobs_currently_running | count_of_jobs_currently_running=$count_of_jobs_currently_running"
            fi
        else
            if [[ "$runsas_mode_runflag" != "" ]]; then
                batch_is_stalled=0
            fi
        fi

        # Increment the iteration
        let check_iter+=1

        # Debug
        # print2debug jobid "Stall check after full iter=&check_iter. for job [" "] stalled=$batch_is_stalled | rc=$runsas_jobrc | runflag=$runflag | runsas_mode_runflag=$runsas_mode_runflag | runflag=$runflag | error_message_shown_on_job_fail=$error_message_shown_on_job_fail | cyclic_dependency_detected=$cyclic_dependency_detected | count_of_dep_jobs_currently_running=$count_of_dep_jobs_currently_running | count_of_jobs_currently_running=$count_of_jobs_currently_running"
    done < $stallcheck_file

    # Stall check
    print2debug jobid "Stall check after full iter=&check_iter. for job [" "] stalled=$batch_is_stalled | rc=$runsas_jobrc | runflag=$runflag | runsas_mode_runflag=$runsas_mode_runflag | runflag=$runflag | error_message_shown_on_job_fail=$error_message_shown_on_job_fail | cyclic_dependency_detected=$cyclic_dependency_detected | count_of_dep_jobs_currently_running=$count_of_dep_jobs_currently_running | count_of_jobs_currently_running=$count_of_jobs_currently_running"

    # Check if there's a cyclic dependency
    if [[ $cyclic_dependency_detected -eq 1 ]]; then
        batch_is_stalled=1
    fi

    # Print to debug file
    print2debug batch_is_stalled "*** Stall check final state [" "] and cyclic_dependency_detected=$cyclic_dependency_detected ***" 

    # Ask the user on way forward
    if [[ $batch_is_stalled -ge 1 ]]; then
        # If in batch mode, just exit the flow and write a message to the log with instructions to restart
        if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -gt -1 ]]; then
            # Print the message on stall
            if [[ $cyclic_dependency_detected -eq 1 ]]; then
                printf "\n${red_bg}${black}*** ERROR: Cyclic dependency detected, review the job dependencies! ***${white}\n"
                print2debug runsas_jobid "*** ERROR: Cyclic dependency detected while running job [" "] with it's dependency [$runsas_jobdep] batch terminated! ****"
            else
                printf "\n${red}*** The batch has failed (or stalled), after reviewing the errors above try to resume the flow. See --help for batch restart options ***${white}\n"
            fi

            # Gracefully exit!
            clear_session_and_exit "The batch has failed (or stalled)" "The batch has failed (or stalled), review the runSAS log and job logs (once the fix has been applied to the job, you can resume the batch by using --resume feature"
        fi
    
        # Enable the keyboard & cursor
        enable_enter_key keyboard
        show_cursor

        # Reset
        stalled_msg_input=""
        
        while [[ ! "$stalled_msg_input" == "R" ]] && [[ ! "$stalled_msg_input" == "C" ]]; do
            # Terminate on cyclic dependency
            if [[ $cyclic_dependency_detected -eq 1 ]]; then
                printf "\n\n${SPACE_DECORATOR}${red_bg}${black}*** ERROR: Cyclic dependency detected, review the job dependencies! ***${white}"
                print2debug runsas_jobid "*** ERROR: Cyclic dependency detected while running job [" "] with it's dependency [$runsas_jobdep] batch terminated! ****"
                clear_session_and_exit "The batch has failed (or stalled)" "ERROR: Cyclic dependency detected, review the job dependencies!"
            fi

            # Show message and ask the user for input.
            stall_user_msg="ERROR: The batch has failed/stalled, resume the batch by typing 'R' to retry failed jobs or type 'C' to mark failed jobs complete & continue:"

            # Send an email
			if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:0:1}" == "Y" ]]; then
				echo "The batch is waiting for user input (to recover from failure)" > $EMAIL_BODY_MSG_FILE
				add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
				send_an_email -v "" "User input required to recover the failed batch" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
            fi

            # Ask the user for options
            publish_to_messagebar "${blink}${red_bg}${black}$stall_user_msg${white} " Y stalled_msg_input
        done

        # Disable user inputs
        hide_cursor
        disable_keyboard_inputs     

        # Show acknoweldgement
        if [[ "$stalled_msg_input" == "R" ]]; then
            publish_to_messagebar "${green}*** Retrying failed job(s), resuming batch in $RUNSAS_FAIL_RECOVER_SLEEP_IN_SECS secs (Press CTRL+C to change your mind)... ***${white}"
            sleep $RUNSAS_FAIL_RECOVER_SLEEP_IN_SECS
            publish_to_messagebar "${white}"
        elif [[ "$stalled_msg_input" == "C" ]]; then
            publish_to_messagebar "${green}*** Skipping failed job(s), resuming batch in $RUNSAS_FAIL_RECOVER_SLEEP_IN_SECS secs (Press CTRL+C to change your mind)... ***${white}"
            sleep $RUNSAS_FAIL_RECOVER_SLEEP_IN_SECS
            publish_to_messagebar "${white}"
        fi
        
        # Disable user inputs
        hide_cursor
        disable_keyboard_inputs      

        # Process the user inputs (R or C)
        if [[ "$stalled_msg_input" == "R" ]]; then
            # Retry
            while IFS='|' read -r flowid flow jobid job jobdep logicop jobrc runflag opt subopt sappdir bservdir bsh blogdir bjobdir; do
                # Get keyval
                get_keyval_from_batch_state runsas_jobrc runsas_jobrc $jobid $stallcheck_batchid

                # Reset the job rc for the failed jobs
                if [[ $runsas_jobrc -gt $jobrc ]]; then
                   update_batch_state runsas_job_pid 0 $jobid $stallcheck_batchid
                   update_batch_state runsas_jobrc $RC_JOB_PENDING $jobid $stallcheck_batchid
                   update_batch_state runsas_mode_runflag 0 $jobid $stallcheck_batchid
                   batch_is_stalled=0
                fi
            done < $stallcheck_file
        elif [[ "$stalled_msg_input" == "C" ]]; then
            # Continue 
            while IFS='|' read -r flowid flow jobid job jobdep logicop jobrc runflag opt subopt sappdir bservdir bsh blogdir bjobdir; do
                # Get keyval
                get_keyval_from_batch_state runsas_jobrc runsas_jobrc $jobid $stallcheck_batchid

                # Reset the job rc for the failed jobs
                if [[ $runsas_jobrc -gt $jobrc ]]; then
                   update_batch_state runsas_jobrc 0 $jobid $stallcheck_batchid
                   update_batch_state runsas_mode_runflag 0 $jobid $stallcheck_batchid
                   update_batch_state runsas_job_marked_complete_after_failure 1 $jobid $stallcheck_batchid
                   batch_is_stalled=0
                fi
            done < $stallcheck_file
        fi

        # Print to debug file
        print2debug stalled_msg_input "*** Batch has recovered from stall, user input " " ***" 
    fi
}
#------
# Name: refactor_job_list_file()
# Desc: This function ensures the job list has the right columns
#   In: job-list-filename
#  Out: <NA>
#------
function refactor_job_list_file(){
    # Parameters
    in_job_list_file=$1

    # Output
    out_job_list_file=${1}_with_flows

    # Delete old files
    delete_a_file $out_job_list_file silent

    # Check if the file is pipe separated already
    pipe_char_in_file_count=`grep '|' $in_job_list_file | wc -l`

    # Process the job list file (if only job details has been specified create one big flow with all defaults)
    iter=1
    if [[ $pipe_char_in_file_count -eq 0 ]];then
        while IFS=' ' read -r flowid flow jobid job jobdep logicop jobrc runflag opt subopt sappdir bservdir bsh blogdir bjobdir; do
            if [[ "$jobid" == "" ]]; then
                # Show a message to user
                publish_to_messagebar "${green}NOTE: runSAS is automatically constructing a flow for the specified jobs, please wait...${white}"

                # First field i.e. flowid is actually the job name and second is the option
                if [[ $iter -eq 1 ]]; then
                    echo "1|Flow|$iter|$flowid|$iter|AND|4|Y|$flow" >> $out_job_list_file
                else
                    echo "1|Flow|$iter|$flowid|$((iter-1))|AND|4|Y|$flow" >> $out_job_list_file
                fi

                let iter+=1
            fi
        done < $in_job_list_file
        print2debug pipe_char_in_file_count "*** Refactored the job list file as " " *** "
    else
        print2debug pipe_char_in_file_count "*** Refactoring job list routine skipped as " " *** "
    fi

    # Done
    publish_to_messagebar ""

    # Update the original file (keep a backup)
    if [ -f "$out_job_list_file" ]; then
        mv $in_job_list_file $in_job_list_file.backup
        mv $out_job_list_file $in_job_list_file
    fi
}
#------
# Name: capture_flow_n_job_stats()
# Desc: This function creates flow and job arrays
#   In: job-list-file-name
#  Out: <NA>
#------
function capture_flow_n_job_stats(){
    # Input parameters
    flowstats_input_job_list_file=$1

    # Create arrays
    while IFS='|' read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do
        # Generate arrays
        if [[ ! " ${flow_id_array[@]} " =~ " ${fid} " ]]; then
            flow_id_array+=( ${fid} )
        fi
        if [[ ! " ${job_id_array[@]} " =~ " ${jid} " ]]; then
            job_id_array+=( $jid )
        fi
    done < $flowstats_input_job_list_file

    # Debug
    print2debug flow_id_array[@] "--- Flow ID array: [" "]---"
    print2debug job_id_array[@] "--- Job ID array: [" "]---"
}
#------
# Name: validate_job_list()
# Desc: This function checks if the specified job's .sas file in server directory
#   In: job-list-filename
#  Out: <NA>
#------
function validate_job_list(){
    # Input parameters
    vld_job_list_file=$1

    # Other parameters
    vld_temp_flowname_keyval_file=$RUNSAS_TMP_FLOWNAME_VALIDATION_FILE
    vld_temp_flowid_keyval_file=$RUNSAS_TMP_FLOWID_VALIDATION_FILE
    
    # For those enter key hitters :)
    disable_enter_key keyboard
	
	# Set the wait message parameters
	vjmode_show_wait_message="Checking few things in the server, and getting things ready for the batch run, please wait..."  
	
	# Show message
	printf "\n${yellow}$vjmode_show_wait_message${white}"

    # Sleep 
    sleep 0.25
	
	# Reset the job counter for the validation routine
	job_counter=0
    flow_job_counter=0
    validation_error_count=0

    # Error handling function
    function vld_error_post_process(){
        let validation_error_count+=1
        if [[ $validation_error_count -eq 1 ]]; then
            printf "\n"
        fi
    }

    # Collect flow and job stats
	capture_flow_n_job_stats $vld_job_list_file # Generates flow_id_array and job_id_array

    # Proceed to validation
	if [[ $RUNSAS_INVOKED_IN_JOB_MODE -le -1 ]]; then  # Skip the job list validation in -j(run-a-job) mode
		while IFS='|' read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do

            # Counter for the job
			let job_counter+=1
    
            # Calculate the length of the job with longest name for the future use
            j_len_array+=( ${#j} )

            # Flow statistics
            # (1) Get the count of jobs for each flow
            # (2) Get job boundaries for a flow (min and max)
            if [[ $fid -eq 1 ]] && [[ $jid -eq 1 ]]; then
                fid_prev=$fid
                flow_job_counter=0
                if [[ $jid -eq 1 ]]; then
                    put_keyval flow_${fid}_jobid_min $jid # Min
                fi
                put_keyval flow_${fid}_jobid_max $jid # Max
            fi
            if [[ $fid -eq $fid_prev ]]; then
                put_keyval flow_${fid}_jobid_max $jid # Max 
            else
                flow_job_counter=0
                put_keyval flow_${fid}_jobid_min $jid # Min
                put_keyval flow_${fid}_jobid_max $jid # Max
            fi   
            let flow_job_counter+=1
            put_keyval flow_${fid}_job_count $flow_job_counter
            fid_prev=$fid
            
            # Check if same flow has multiple flow ids
            get_keyval $f $vld_temp_flowid_keyval_file
            if [[ -z "${!f}" ]] || [[ "${!f}" = "" ]]; then
                put_keyval $f $fid $vld_temp_flowid_keyval_file # Add an entry
            else 
                # Check if the flowid is re-used
                if [[ ! "${!f}" == "$fid" ]]; then   
                    vld_error_post_process
                    printf "\n${red}*** ERROR: Flow ${black}${red_bg}$f${white}${red} at line #$job_counter in the list seems to have incorrect flowname or flowid (NOTE: Every flow must have a unique flowid) *** ${white}"
                fi  
            fi
    
            # Check if the jobid is unique across the list 
            if [[ " ${current_jid_id_array[@]} " =~ " ${jid} " ]]; then
                vld_error_post_process
                printf "\n${red}*** ERROR: Job ${black}${red_bg}$j${white}${red} at line #$job_counter has the same jobid (i.e. ${jid}) as one other job in the list (NOTE: jobid must be unique across all flows and must be in the ascending order) *** ${white}"
            fi

            # Build arrays as we go
            if [[ ! " ${current_flow_id_array[@]} " =~ " ${fid} " ]]; then
                current_flow_id_array+=( ${fid} )
            fi
            if [[ ! " ${current_jid_id_array[@]} " =~ " ${jid} " ]]; then
                current_jid_id_array+=( $jid )
            fi

            # Validate job dependencies
            if [[ "$jdep" == "" ]]; then
                jdep=$jid
            else
                IFS=','
            fi
            jdep_array=( $jdep )
            jdep_array_elem_count=${#jdep_array[@]}
            for (( i=0; i<${jdep_array_elem_count}; i++ ));
            do                 
                jdep_i="${jdep_array[i]}"

                # Check if the dependent jobids are correct 
                if [[ ! " ${job_id_array[@]} " =~ " ${jdep_i} " ]]; then
                    vld_error_post_process
                    printf "\n${red}*** ERROR: Job ${black}${red_bg}$j${white}${red} at line #$job_counter with jobid $jid has incorrect job dependencies (job $jdep_i not found in the list) *** ${white}"
                fi                
            done

            # Set defaults if nothing is specified
            vjmode_sas_deployed_jobs_root_directory="${bjobdir:-$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY}"

            # If user has specified a different server context, switch it here
            if [[ "$o" == "--server" ]]; then
                if [[ "$so" != "" ]]; then
                    if [[ "$bjobdir" == "" ]]; then 
                        vjmode_sas_deployed_jobs_root_directory=`echo "${vjmode_sas_deployed_jobs_root_directory/$SAS_APP_SERVER_NAME/$so}"`
                    fi
                else
                    printf "${yellow}WARNING: $so was specified for $j in the list without the server context name, defaulting to $SAS_APP_SERVER_NAME${white}"
                fi
            fi

			# Check if the deployed job file exists
			if [ ! -f "$vjmode_sas_deployed_jobs_root_directory/$j.sas" ]; then
                vld_error_post_process
				printf "\n${red}*** ERROR: Job #$job_counter ${black}${red_bg}$j${white}${red} not deployed or misspelled, $j.sas was not found in $vjmode_sas_deployed_jobs_root_directory *** ${white}"
			fi

			# Check if there are any sastrace options enabled in the program file
            if [[ $validation_error_count -eq 0 ]]; then
			    scan_sas_programs_for_debug_options $vjmode_sas_deployed_jobs_root_directory/$j.sas
            fi
		done < $vld_job_list_file
	fi

    # Terminate the script if there are errors
    if [[ $validation_error_count -gt 0 ]]; then
    	printf "\n\n${red}$validation_error_count error(s) found in the job list (see above for details), fix them and restart the script.${white}"
        clear_session_and_exit
    fi

    # Get the length of the longest job name
    j_len_array_max=${j_len_array[0]}
    for n in "${j_len_array[@]}" ; do
        ((n > j_len_array_max)) && j_len_array_max=$n
    done
    print2debug j_len_array_max "NOTE: The length of the longest job name in the list is [" "]"
    print2debug RUNSAS_RUNNING_MESSAGE_FILLER_END_POS "The value (before adjustment) of RUNSAS_RUNNING_MESSAGE_FILLER_END_POS=[" "]"

    # Overwrite the global parameter (23 because it gives ... from the biggest job)
    RUNSAS_RUNNING_MESSAGE_FILLER_END_POS=$((j_len_array_max+23)) 
    print2debug RUNSAS_RUNNING_MESSAGE_FILLER_END_POS "The value (after adjustment, adding 23 to j_len_array_max=$j_len_array_max) of RUNSAS_RUNNING_MESSAGE_FILLER_END_POS=[" "]"

	# Remove the message, reset the cursor
	echo -ne "\r"
	printf "%${#vjmode_show_wait_message}s" " "
	echo -ne "\r"
	
    # Reset
    IFS=$SERVER_IFS

	# Enable carriage return
    enable_enter_key keyboard
}
#------
# Name: assign_and_preserve()
# Desc: Extended bash "let" implementation
#   In: variable-name, value, options (DEBUG or SUB or NUM or STRING)
#  Out: <NA> 
#------
function assign_and_preserve(){
    # Input parameters
    anp_varname=$1
    anp_value=$2
    anp_opt=$3

    # String assignment
    function assign_as_string(){
        anp_vartype="Character"
        eval $anp_varname="$anp_value"
    }

    # Number assignment
    function assign_as_number(){
        anp_vartype="Number"
        eval "let $anp_varname=$anp_value"
    }

    # Substitution assignment
    function assign_after_substitution(){
        anp_vartype="Substitution"
        if [[ $anp_value =~ $RUNSAS_REGEX_NUMBER ]]; then
            anp_vartype="Substitution (routed to Number)"
            assign_as_number
        elif [[ "$anp_value" == "" ]]; then
            anp_vartype="Substitution (routed to String)"
            assign_as_string
        else
            anp_vartype="Substitution"
            eval "$anp_varname=${!anp_value}"
        fi
    }

    # Check if it's number or string assignment
    if [[ "$anp_opt" == *"STRING"* ]]; then
        # String
        assign_as_string
    elif [[ "$anp_opt" == *"SUB"* ]]; then
        # Number (substitution)
        assign_after_substitution
    elif [[ "$anp_opt" == *"NUM"* ]]; then
        # Number
        assign_as_number
    elif [[ $anp_value =~ $RUNSAS_REGEX_STRING ]]; then
        # String
        assign_as_string
    elif [[ "$anp_value" = "" ]]; then
        # String
        assign_as_string
    else 
        # Default: Number
        assign_as_number
    fi

    # Debug
    if [[ "$anp_opt" == *"DEBUG"* ]]; then
        printf "DEBUG: anp_varname=$anp_varname anp_value=$anp_value --> $anp_vartype $anp_varname=${!anp_varname}\n" >> $RUNSAS_DEBUG_FILE
    fi

    # Finally update the state
    if [[ "$runsas_jobid" != "" ]]; then
        update_batch_state $anp_varname ${!anp_varname} $runsas_jobid
    else
        printf "${red} *** ERROR: ASSIGN_AND_PRESERVE() routine received an invalid input *** ${white}"
    fi
}
#------
# Name: generate_a_new_batchid()
# Desc: Preserve the state of the current batch run in a file for rerun/resume of batches on failure/abort
#   In: show-batch-id
#  Out: <NA>
#------
function generate_a_new_batchid(){
    # Input parameters
    show_batchid="${1:-Y}"

    # Determine the last batch run identifier (from global parms)
    get_keyval global_batchid

    # Check if old batch is being resumed
    if [[ $RUNSAS_INVOKED_IN_RESUME_MODE -le -1 ]]; then
        # Create a batch state file (if it's the first time)
        if [ -z "$global_batchid" ] || [ "$global_batchid" == "" ]; then
            bid_new_batchid=1 # first run
        else
            let bid_new_batchid=$global_batchid+1
        fi
    else
        # Set the requested batch id
        requested_resume_batchid=${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_RESUME_MODE+1]}
        if [[ "$requested_resume_batchid" == "" ]]; then
            bid_new_batchid=$global_batchid
        else
            # Wrong batch id inputs
            if [[ ! $requested_resume_batchid =~ $RUNSAS_REGEX_NUMBER ]] || [[ $requested_resume_batchid -le 0 ]] || [[ "$requested_resume_batchid" == "" ]]; then
                printf "${red}*** ERROR: Invalid input for batchid ${red_bg}${black}$requested_resume_batchid${end}${red}, must be a number greater than 0 ***${white}\n"
                clear_session_and_exit "The batch has failed" "ERROR: Invalid input for batchid $requested_resume_batchid, must be a number greater than 0 "
            fi 
            # History is not enough!
            if [[ "$BATCH_HISTORY_PERSISTENCE" != "ALL" ]]; then 
                if [[ $((global_batchid-requested_resume_batchid)) -gt $BATCH_HISTORY_PERSISTENCE ]]; then
                    printf "${red}*** ERROR: The requested batchid ${red_bg}${black}$requested_resume_batchid${end}${red} was not found in the persisted batch history (currently BATCH_HISTORY_PERSISTENCE=$BATCH_HISTORY_PERSISTENCE) ***${white}\n"
                    clear_session_and_exit "The batch has failed" "ERROR: The requested batchid $requested_resume_batchid was not found in the persisted batch history (currently BATCH_HISTORY_PERSISTENCE=$BATCH_HISTORY_PERSISTENCE)"
                fi
            fi          
            # The requested batch id has not been run yet!
            if [[ $requested_resume_batchid -gt $global_batchid ]]; then
                printf "${red}*** ERROR: The requested batchid ${red_bg}${black}$requested_resume_batchid${end}${red} was not found in the batch history (> last batchid=$global_batchid) ***${white}\n"
                clear_session_and_exit "The batch has failed" "ERROR: The requested batchid $requested_resume_batchid was not found in the batch history (> last batchid=$global_batchid)"
            else
                bid_new_batchid=${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_RESUME_MODE+1]}
                put_keyval global_batchid $bid_new_batchid
            fi
        fi
    fi

    # Update the global key-value store 
    put_keyval global_batchid $bid_new_batchid

    # Get the newly created batch id
    get_keyval global_batchid 

    # Create message
    if [[ $RUNSAS_INVOKED_IN_RESUME_MODE -le -1 ]]; then
        batchid_gen_message="Batch ID: $global_batchid "
    else
        batchid_gen_message="Batch ID: $global_batchid (resuming an old batch) "
        print2debug $global_batchid "\n\n------>>>>>>>>>>> Resuming an old batch failed/stalled batch, batchid: [" "] <<<<<<<<<<<------"
    fi

    # Show the current batch id
    if [[ "$show_batchid" == "Y" ]]; then
        printf "${green}${batchid_gen_message}${white}\n"
        publish_to_messagebar "${green_bg}${black}${batchid_gen_message}${white}"
    fi

    # Terminate if the batch id is missing!
    if [[ "$global_batchid" == "" || $global_batchid -lt 0 ]]; then
        printf "${red}*** ERROR: Critical error as batchid was not generated (global_batchid=$global_batchid) ***${white}\n"
        clear_session_and_exit "The batch has failed (batchid value error)"
    fi
}
#------
# Name: update_batch_state()
# Desc: Preserve the state of the current batch run in a file for rerun/resume of batches on failure/abort
#   In: key, value, jobid, batchid, batchstate-root-directory (optional)
#  Out: <NA>
#------
function update_batch_state(){
    # Input parameters
    bs_key=$1
    bs_value=$2
    bs_jobid=$3
    bs_batchid=${4:-$global_batchid}
    bs_batch_root_directory="${5:-$RUNSAS_BATCH_STATE_ROOT_DIRECTORY}"

    # Directories
    bs_current_batchid_directory=$bs_batch_root_directory/$bs_batchid
    bs_current_batchid_job_directory=$bs_batch_root_directory/$bs_batchid/.job

    # Files
    bs_current_batchid_file=$bs_current_batchid_directory/$bs_batchid.batch
    bs_current_batchid_jobid_file=$bs_current_batchid_job_directory/$bs_jobid.job

    # Create required directories to preserve the state of the batch (direcoty)
    # Directory tree:
    #   .batch
    #   ├──<batchid>
    #   │  └───<batchid>.batch (batch specific parameters, accessible by any jobs in the context of the flow)
    #   │      └──job
    #   │         └──<jobid>.job (job specifid key-values)
    #   │         └──<jobid>.job (job specifid key-values)
    #   │         └──<jobid>.job (job specifid key-values)
    #   │         └──...
    #   └──...
    # 
    create_a_new_directory --silent $bs_current_batchid_directory 
    create_a_new_directory --silent $bs_current_batchid_job_directory

    # Check if the batch file exists ("batchid" file serves as a marker for the batch)
    create_a_file_if_not_exists "$bs_current_batchid_file" 
    create_a_file_if_not_exists "$bs_current_batchid_jobid_file" 

    # Add/update the entry
    put_keyval $bs_key $bs_value $bs_current_batchid_jobid_file "="
	
}
#------
# Name: inject_batch_state()
# Desc: Set the batch state from a previous run i.e. add the batch state preservation file to the current run
#   In: batchid, jobid, opt, batchstate-root-directory (optional)
#  Out: <NA>
#------
function inject_batch_state(){
    # Input parameters
    inj_batchid=${1:-$global_batchid}
    inj_jobid=$2
    inj_opt=$3
    inj_batch_root_directory="${4:-$RUNSAS_BATCH_STATE_ROOT_DIRECTORY}"

    # Directories
    inj_current_batchid_directory=$inj_batch_root_directory/$inj_batchid
    inj_current_batchid_job_directory=$inj_batch_root_directory/$inj_batchid/.job

    # Files
    inj_current_batchid_file=$inj_current_batchid_directory/$inj_batchid.batch
    inj_current_batchid_jobid_file=$inj_current_batchid_job_directory/$inj_jobid.job

    # Inject the job state (always in the context of the flow)
    if [ -f $inj_current_batchid_jobid_file ]; then
        . $inj_current_batchid_jobid_file
        print2debug inj_current_batchid_jobid_file "Injecting batch state file: "
        if [[ "$opt" == "message" ]]; then
            printf "${green}NOTE: Job state has been restored successfully! (Batch ID: $inj_batchid Job ID: $inj_jobid) ${white}"
        fi
    fi
}
#------
# Name: get_keyval_from_batch_state()
# Desc: Get a value for a specific key from batch state (for a job within a flow)
#   In: key, variable (optional, default is the key), jobid, batchid, file-type (JOB or BATCH parameter file), batchstate-root-directory (optional)
#  Out: <NA>
#------
function get_keyval_from_batch_state(){
    # Input parameters
    gbs_key=$1
    gbs_var=${2:-$1}
    gbs_jobid=${3:-$runsas_jobid}   
    gbs_batchid=${4:-$global_batchid}
    gbs_file_type="${5:-JOB}"
    gbs_batch_root_directory="${6:-$RUNSAS_BATCH_STATE_ROOT_DIRECTORY}"

    # Directories
    gbs_current_batchid_directory=$gbs_batch_root_directory/$gbs_batchid
    gbs_current_batchid_job_directory=$gbs_batch_root_directory/$gbs_batchid/.job

    # Files
    gbs_current_batchid_file=$gbs_current_batchid_directory/$gbs_batchid.batch
    gbs_current_batchid_jobid_file=$gbs_current_batchid_job_directory/$gbs_jobid.job

    # Choose the file based on the file-type specified by the user
    if [[ "$gbs_file_type" == "BATCH" ]]; then
        gbs_keyval_file_selected=$gbs_current_batchid_file
    else
        gbs_keyval_file_selected=$gbs_current_batchid_jobid_file
    fi

    # Get the value for the key 
    get_keyval $gbs_key $gbs_keyval_file_selected "\=" $gbs_var
}
#------
# Name: put_keyval()
# Desc: Stores a key-value pair in a file
#   In: key, value, file, delimeter
#  Out: <NA>
#------
function put_keyval(){
    # Input parameters
    str_key=$1
    str_val=$2
    str_file="${3:-$RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE}"
    str_delim="${4:-\: }"

    # Create a file if it doesn't exist
    create_a_file_if_not_exists $str_file

    # If the file exists remove the previous entry
	if [ -f "$str_file" ]; then
        sed -i "/\b$str_key\b/d" $str_file
    fi 

	# Add the new entry (or update the entry)
    echo "$str_key$str_delim$str_val" >> $str_file # Add a new entry 

    # Debug
    # print2debug str_key "\n*** Added key: " "(val: $str_val) to $str_file file ***"
    # print2debug str_file "---Printing state file: " "(START)---\n"
    # cat $str_file >> $RUNSAS_DEBUG_FILE
}
#------
# Name: get_keyval()
# Desc: Check job runtime for the last batch run
#   In: key, file, delimeter (optional, default is ": "), variable-name (optional, default is key)
#  Out: <NA>
#------
function get_keyval(){
    # Parameters
    ret_key=$1
    ret_file="${2:-$RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE}"
    ret_delim="${3:-\: }"
    ret_var=${4:-$1}
    ret_debug=${5}

    # Create a file if it doesn't exist
    # create_a_file_if_not_exists $ret_file

    # Debug
    # print2debug ret_key "\n*** Retreiving a key: " " with $ret_delim delimeter from $ret_file file (command: eval $ret_var=`awk -v pat="$ret_key" -F"$ret_delim" '$0~pat { print $2 }' $ret_file 2>/dev/null`) ***"
    # print2debug ret_file "---Printing state file: " "(START)---\n"
    # if [ -f "$ret_file" ]; then
    #     cat $ret_file >> $RUNSAS_DEBUG_FILE
    # fi

    # Set the value found in the file to the key
    if [ -f "$ret_file" ]; then
        eval $ret_var=`awk -v pat="$ret_key" -F"$ret_delim" '$0~pat { print $2 }' $ret_file 2>/dev/null`
    fi   

    # Debug
    if [[ "$ret_debug" == "debug" ]]; then
        printf "${yellow}DEBUG keyval(key=$ret_key): [file=$ret_file | delim=$ret_delim | var=$ret_va ] ${white}\n"
    fi
}
#------
# Name: get_keyval_from_user()
# Desc: Ask user for a new value for a key (if user has specified an answer show it as prepopulated and finally store the updated value for future use)
#   In: key, message, message-color, value-color, file (optional)
#  Out: <NA>
#------
function get_keyval_from_user(){
    # Parameters
    keyval_key=$1
    keyval_message=$2
    keyval_message_color="${3:-green}"
    keyval_val_color="${4:-grey}"
    keyval_file=$4
	
    # First retrieve the value for the key from the global parameters file, if it is available.
    get_keyval $keyval_key
	
    # Prompt 
    read -p "${!keyval_message_color}${keyval_message}${!keyval_val_color}" -i "${!keyval_key}" -e $keyval_key	
	
    # Store the value (updated value)
    put_keyval $keyval_key ${!keyval_key}
}
#------
# Name: redeploy_sas_jobs()
# Desc: This function redeploys SAS jobs if user has requested for it (currently only supports REDEPLOY)
#  Ref: http://support.sas.com/documentation/cdl/en/etlug/68225/HTML/default/viewer.htm#p1jxhqhaz10gj2n1pyr0hbzozv2f.htm)
#   In: mode, jobs-file, job-from, job-to
#  Out: <NA>
#------
function redeploy_sas_jobs(){
    # Parameters
    depjob_mode=$1
    depjob_job_file=$2
	
	# Filters (can be index or can be job name with full path)
	depjob_from_job=$3
	depjob_to_job=${4:-$3}
	
	# Reset
	depjob_in_filter_mode=0

    # Begin
	if [[ "$depjob_mode" == "--redeploy" ]]; then
        # Firstly, check if the job file list exists
        check_if_the_file_exists $depjob_job_file
        
        # If it exists, perform dos2unix and apply newline in the file
        dos2unix $depjob_job_file
        add_a_newline_char_to_eof $depjob_job_file

        # Check for the jobs file (mandatory for this mode)
		if [[ "$depjob_job_file" == "" ]]; then
            # Ensure the job list is provided
			printf "${red}*** ERROR: A file that contains a list of jobs is required as a second arguement for $depjob_mode option (e.g.: ./runSAS.sh --redeploy redeployJobs.list) ***${white}"
			clear_session_and_exit
		else
			# Check for the filters
			if [ ! -z "$depjob_from_job" ]; then
				# Show the list of jobs
				if [[ "$depjob_from_job" == "--list" ]]; then
					print_file_content_with_index $depjob_job_file jobs
					clear_session_and_exit
				fi
				
				# Set the flag 
				depjob_in_filter_mode=1
				
				# Get the job name if it is the index
				if [[ ${#depjob_from_job} -le $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
					printf "\n"
					get_name_from_list $depjob_from_job $depjob_job_file 1
					depjob_from_job_index=$depjob_from_job
					depjob_from_job=${job_name_from_the_list}
                else
                    printf "${red}*** ERROR: The job index/number length limit exceeded for $depjob_from_job (limit is set by the following parameter JOB_NUMBER_DEFAULT_LENGTH_LIMIT=$JOB_NUMBER_DEFAULT_LENGTH_LIMIT) ${white}"
                    clear_session_and_exit
				fi
				if [[ ${#depjob_to_job} -le $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
					get_name_from_list $depjob_to_job $depjob_job_file 1
					depjob_to_job_index=$depjob_to_job
					depjob_to_job=${job_name_from_the_list}
				else
                    printf "${red}*** ERROR: The job index/number length limit exceeded for $depjob_to_job (limit is set by the following parameter JOB_NUMBER_DEFAULT_LENGTH_LIMIT=$JOB_NUMBER_DEFAULT_LENGTH_LIMIT) ${white}"
                    clear_session_and_exit
				fi
			else
                # Print the jobs file
                print_file_content_with_index $depjob_job_file jobs

                # Check if the user wants to redeploy only few jobs
				printf "\n"
				read_depjob_filters_required_parms_array_count=0

                # Ensure the user has specified at most two parameters
				while [[ $read_depjob_filters_required_parms_array_count -ne 2 ]]; do
					# Show message
					depjob_filters_required_message="Press ENTER to redeploy all OR specify a from & to job names filter (e.g. 2 3): "
					printf "${red}$depjob_filters_required_message${white}"
					read -ea read_depjob_filters_required_parms_array < /dev/tty
					
					# Continue if enter key was pressed.
					if [[ "$read_depjob_filters_required_parms_array" == "" ]]; then
						printf "\n${green}No job filters provided, getting ready to redeploy all jobs...\n${white}"
						break
					fi
					
					# Process the parameter array
					read_depjob_filters_required_parms_array_count=${#read_depjob_filters_required_parms_array[@]}
				done
						
				if [[ "${read_depjob_filters_required_parms_array[0]}" == "" ]]; then
					# Deploy all mode is invoked
					depjob_in_filter_mode=0
				else
					# Deploy all mode is invoked
					depjob_in_filter_mode=1

					# Assign from and to jobs, if index is used get the names
					depjob_from_job=${read_depjob_filters_required_parms_array[0]}
					depjob_to_job=${read_depjob_filters_required_parms_array[1]}

					# Get the job name if it is the index
					if [[ ${#depjob_from_job} -le $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
						printf "\n"
						get_name_from_list $depjob_from_job $depjob_job_file 1
						depjob_from_job_index=$depjob_from_job
						depjob_from_job=${job_name_from_the_list}
					else
                        printf "${red}*** ERROR: The job index/number length limit exceeded for $depjob_from_job (limit is set by the following parameter JOB_NUMBER_DEFAULT_LENGTH_LIMIT=$JOB_NUMBER_DEFAULT_LENGTH_LIMIT)${white}"
                        clear_session_and_exit
                    fi
					if [[ ${#depjob_to_job} -le $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
						get_name_from_list $depjob_to_job $depjob_job_file 1
						depjob_to_job_index=$depjob_to_job
						depjob_to_job=${job_name_from_the_list}
					else
                        printf "${red}*** ERROR: The job index/number length limit exceeded for $depjob_to_job (limit is set by the following parameter JOB_NUMBER_DEFAULT_LENGTH_LIMIT=$JOB_NUMBER_DEFAULT_LENGTH_LIMIT)${white}"
                        clear_session_and_exit
                    fi
				fi
			fi
			
			# Create an empty file
			create_a_file_if_not_exists $depjob_job_file
			
			# Newlines
			printf "\n"
						
			# Retrieve SAS Metadata details from last user inputs, if you don't find it ask the user
			if [[ "$depjob_in_filter_mode" -eq "0" ]]; then	
				get_keyval_from_user read_depjob_clear_files "Do you want clear all existing deployed SAS files from the server (Y/N): " red
			else 
				read_depjob_clear_files=N
			fi
            get_keyval_from_user read_depjob_user "SAS Metadata username (e.g.: sas or sasadm@saspw): " 
			get_keyval_from_user read_depjob_password "SAS Metadata password: " 
            get_keyval_from_user read_depjob_appservername "SAS Application server name (e.g.: $SAS_APP_SERVER_NAME): " 
            get_keyval_from_user read_depjob_serverusername "SAS Application/Compute server username (e.g.: ${SUDO_USER:-$USER}): " 
            get_keyval_from_user read_depjob_serverpassword "SAS Application/Compute server password: " 
            get_keyval_from_user read_depjob_level "SAS Level (e.g.: Specify 1 for Lev1, 2 for Lev2 and 3 for Lev3 and so on...): " 

            # Clear deployment directory for a fresh start (based on user input)
            if [[ "$read_depjob_clear_files" == "Y" ]]; then
                printf "${white}\nPlease wait, clearing all the existing deployed .sas files from the server directory $SAS_DEPLOYED_JOBS_ROOT_DIRECTORY...\n\n${white}"
                rm -rf $SAS_DEPLOYED_JOBS_ROOT_DIRECTORY/*.sas
            fi
			
			# Set the parameters (some are set to defaults and the rest is from the user inputs above)
			depjobs_scripts_root_directory=$SAS_HOME_DIRECTORY/SASDataIntegrationStudioServerJARs/4.8
			depjob_host="$HOSTNAME"
			depjob_port=856$read_depjob_level
			depjob_user=$read_depjob_user
			depjob_password=$read_depjob_password
			depjob_deploytype=`echo ${1#"--"} | tr a-z A-Z`
			depjob_sourcedir="$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY"    
			depjob_metarepository=Foundation
			depjob_appservername=$read_depjob_appservername
			depjob_servermachine="$HOSTNAME"
			depjob_serverport=859$read_depjob_level
			depjob_serverusername=$read_depjob_serverusername
			depjob_serverpassword=$read_depjob_serverpassword
			depjob_batchserver="$read_depjob_appservername - SAS DATA Step Batch Server" 
			depjob_log=$RUNSAS_DEPLOY_JOB_UTIL_LOG

			# Check if the utility exists? 
			if [ ! -f "$depjobs_scripts_root_directory/DeployJobs" ]; then
				printf "${red}*** ERROR: ${red_bg}${black}DeployJobs${white}${red} utility is not found on the server, cannot proceed with the $1 for now (try the manual option via SAS DI) *** ${white}"
				clear_session_and_exit
			fi

			# Wait for the user to confirm
			press_enter_key_to_continue 0 0 red

            # Counter
            depjob_to_jobtal_count=`cat $depjob_job_file | wc -l`
            depjob_job_counter=1
            depjob_job_deployed_count=0
            
            # Newlines
            get_keyval depjob_total_runtime

            # Message to user
			printf "\n${green}Redeployment process started at $start_datetime_of_session_timestamp, it may take a while, so grab a cup of coffee or tea.${white}\n\n"

            # Add to audit log
            print2log $TERMINAL_MESSAGE_LINE_WRAPPERS
            print2log "Redeployment start timestamp: $start_datetime_of_session_timestamp"
            print2log "DepJobs SAS 9.x utility directory: $depjobs_scripts_root_directory"
			print2log "Metadata server: $depjob_host"
			print2log "Port: $depjob_port"
			print2log "Metadata user: $read_depjob_user"
			print2log "Metadata password (obfuscated): *******"
			print2log "Deployment type: $depjob_deploytype"
			print2log "Deployment directory: $depjob_sourcedir"
			print2log "Job directory (Metadata): $depjob_metarepository"
			print2log "Application server context: $depjob_appservername"
			print2log "Application server: $depjob_servermachine"
			print2log "Application server port: $depjob_serverport"
			print2log "Application server user: $depjob_serverusername"
			print2log "Application server password (obfuscated): *******"
			print2log "Batch server: $depjob_batchserver" 
			print2log "DepJobs SAS 9.x utility log: $depjob_log"
            print2log "Total number of jobs: $depjob_to_jobtal_count"
            print2log "Deleted existing SAS job files?: $read_depjob_clear_files"

            # Disable enter key
            disable_enter_key keyboard

			# Run the jobs from the list one at a time (here's where everything is brought together!)
			while IFS='|' read -r job; do
				# Check if the current job is between the filters (only in filter mode)
				if [[ "$depjob_in_filter_mode" -eq "1" ]]; then	
					if [[ "${depjob_from_job}" == "${job}" ]]; then
						depjob_from_to_job_mode=1
					else
						if [[ "${depjob_to_job}" == "${job}" ]]; then
							depjob_from_to_job_mode=2
						else
							if  [[ $depjob_from_to_job_mode -eq 1 ]]; then
								depjob_from_to_job_mode=1
							else
								if [[ $depjob_from_to_job_mode -eq 2 ]]; then
									depjob_from_to_job_mode=0
								fi
							fi
							if [[ "${depjob_to_job}" == "${depjob_from_job}" ]]; then
								depjob_from_to_job_mode=0
							fi
						fi
					fi
				else
					depjob_from_to_job_mode=1
				fi
								
				# Make a decision (skip or execute)
				if [[ "$depjob_from_to_job_mode" -lt "1" ]]; then	
                    printf "${green}---${white}\n"
					printf "${grey}Job ${grey}"
					printf "%02d" $depjob_job_counter
                    printf "${grey} of $depjob_to_jobtal_count: $job${white}"
                    display_fillers $((RUNSAS_DISPLAY_FILLER_COL_END_POS+35)) $RUNSAS_FILLER_CHARACTER 0 N 2 grey
                    printf "${grey}(SKIPPED)\n${white}"
                    let depjob_job_counter+=1
					continue
				fi	
                
				# Show the current state of the deployment
				printf "${green}---${white}\n"
                printf "${green}["
                printf "%02d" $depjob_job_counter
                printf "${green} of $depjob_to_jobtal_count]: Redeploying ${darkgrey_bg}${green}${job}${end}${green} now...(ignore the warnings)\n${white}"
                    
				# Make sure the metadata tree path is specified in the job list to use --redeploy feature
				if [[ "${job%/*}" == "" ]]; then
					printf "\n${red}*** ERROR: To use $depjob_mode feature in runSAS, you must specify full metadata path for the jobs in the list (relative to ${red_bg}${black}SAS Folders${end}${red} directory) ***\n${white}"
					clear_session_and_exit
				fi

				# Run "DeployJobs" SAS script/utility (currently this does not accept override parameters, possible candidate for later releases)
				$depjobs_scripts_root_directory/DeployJobs 	-host $depjob_host \
															-port $depjob_port \
															-user $depjob_user \
															-password $depjob_password \
															-deploytype $depjob_deploytype \
															-objects "${job}" \
															-sourcedir $depjob_sourcedir \
															-metarepository $depjob_metarepository \
															-appservername $depjob_appservername \
															-servermachine $depjob_servermachine \
															-serverport $depjob_serverport \
															-serverusername $depjob_serverusername \
															-serverpassword $depjob_serverpassword \
															-batchserver "$depjob_batchserver" \
															-log $depjob_log
															
				# Fix the file name with underscores (SAS DI currently does this by default, just to keep it in-sync with deployed job name referred in .jobs.list file)
				deployed_job_sas_file=$depjob_sourcedir/${job##/*/}.sas

                # Fix the names (add underscores etc.)
                if [[ -f "$deployed_job_sas_file" ]]; then
				    mv "$deployed_job_sas_file" "${deployed_job_sas_file// /_}"
                    let depjob_job_deployed_count+=1
                else
                    printf "${red}ERROR: Something went wrong, above job was not deployed correctly${white}\n"
                fi

                # Add it to audit log
                print2log "Reploying job $depjob_job_counter of $depjob_to_jobtal_count: $job"

                # Increment the job counter
                let depjob_job_counter+=1

			done < $depjob_job_file

            # Check if it was deployed correctly
            # Run the jobs from the list one at a time (here's where everything is brought together!)
            depjob_job_not_deployed_counter=0
            depjob_job_counter=0
			while IFS='|' read -r job; do
				# Check if the current job is between the filters (only in filter mode)
				if [[ "$depjob_in_filter_mode" -eq "1" ]]; then	
					if [[ "${depjob_from_job}" == "${job}" ]]; then
						depjob_from_to_job_mode=1
					else
						if [[ "${depjob_to_job}" == "${job}" ]]; then
							depjob_from_to_job_mode=2
						else
							if  [[ $depjob_from_to_job_mode -eq 1 ]]; then
								depjob_from_to_job_mode=1
							else
								if [[ $depjob_from_to_job_mode -eq 2 ]]; then
									depjob_from_to_job_mode=0
								fi
							fi
							if [[ "${depjob_to_job}" == "${depjob_from_job}" ]]; then
								depjob_from_to_job_mode=0
							fi
						fi
					fi
				else
					depjob_from_to_job_mode=1
				fi
								
				# Make a decision (skip or execute)
				if [[ "$depjob_from_to_job_mode" -lt "1" ]]; then	
                    let depjob_job_counter+=1
					continue
				fi	
															
				# Fix the file name with underscores (SAS DI currently does this by default, just to keep it in-sync with deployed job name referred in .jobs.list file)
				deployed_job_sas_file=$depjob_sourcedir/${job##/*/}.sas
                
                # Increment the job counter
                let depjob_job_counter+=1

                # A way to check if the job was deployed at all?
                if [[ ! -f "${deployed_job_sas_file// /_}" ]]; then
                    let depjob_job_not_deployed_counter+=1
                    
                    # Header 
                    if [[ $depjob_job_not_deployed_counter -eq 1 ]]; then
                        printf "\n"
                        printf "\n${red}--------${white}"
                        printf "\n${red}Summary:${white}"
                        printf "\n${red}--------${white}"
                    fi

                    # Print the errors
                    printf "\n${red}#"
                    printf "%04d" $depjob_job_counter
                    printf ": ${red_bg}${black}$job${end}${red} not deployed (${red_bg}${black}${deployed_job_sas_file// /_}${end}${red} not found!)${white}"
                fi


			done < $depjob_job_file

            # Capture session runtimes
            end_datetime_of_session_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
            end_datetime_of_session=`date +%s`

            # Total runtime
            depjob_total_runtime=$((end_datetime_of_session-start_datetime_of_session))

			# Show messages
            if [[ $depjob_job_not_deployed_counter -gt 0 ]]; then
                # Error
                redeploy_detailed_message="*** The redeployment of jobs failed ($depjob_job_deployed_count jobs passed, $depjob_job_not_deployed_counter failed) on $end_datetime_of_session_timestamp and took a total of $depjob_total_runtime seconds to run. ***"
                redeploy_summary_message="$depjob_job_deployed_count jobs deployed, $depjob_job_not_deployed_counter failed!"
                printf "\n\n${red}${redeploy_detailed_message}${white}"
            else
                # Success
                redeploy_detailed_message="*** The redeployment of jobs completed ($depjob_job_deployed_count of $depjob_job_counter jobs deployed) on $end_datetime_of_session_timestamp and took a total of $depjob_total_runtime seconds to complete. ***"
                redeploy_summary_message="All $depjob_job_deployed_count jobs deployed successfully!"
                printf "\n${green}${redeploy_detailed_message}${white}"
            fi
            
            # Store runtime for future use
            put_keyval depjob_total_runtime $depjob_total_runtime

            # Send an email
			if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:0:1}" == "Y" ]]; then
				echo $redeploy_detailed_message > $EMAIL_BODY_MSG_FILE
				add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
				send_an_email -v "" "$redeploy_summary_message" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
            fi

            # End
            print2log "Redeployment end timestamp: $end_datetime_of_session_timestamp"
            print2log "Total time taken (in seconds): $depjob_total_runtime"

            # Exit 
            enable_enter_key keyboard
			clear_session_and_exit
		fi
	fi
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
# Name: convert_ranges_in_job_dependencies()
# Desc: This function will expand the ranges in the file
#   In: file-name
#  Out: <NA>
#------
function convert_ranges_in_job_dependencies(){
    # Input parameters
    range_check_in_file=$1

    # Expand ranges
    awk '{while(match($0, /[0-9]+-[0-9]+/)) \
            {k=substr($0, RSTART, RLENGTH); \
            split(k,a,"-"); \
            f=a[1]; \
            for(j=a[1]+1; j<=a[2]; j++) f=f","j; \
            sub(k,f)}}1' ${range_check_in_file} > ${range_check_in_file}.rangeexpanded

    # Overwrite the file
    if [[ -f "${range_check_in_file}.rangeexpanded" ]]; then
        mv -f ${range_check_in_file}.rangeexpanded ${range_check_in_file}
    else
        printf "\n${red}*** ERROR: The range expansion routine failed (file: ${range_check_in_file}), report this to the developer ***\n${white}"
        clear_session_and_exit
    fi
}
#------
# Name: remove_empty_lines_from_file()
# Desc: This function removes any unwanted empty lines from the file
#   In: file-name
#  Out: <NA>
#------
function remove_empty_lines_from_file(){
	sed -i '/^$/d' $1
}
#------
# Name: convert_job_index_to_job_names()
# Desc: This function will convert job index to job names 
#   In: <NA>
#  Out: <NA> 
#------
function convert_job_index_to_job_names(){
    for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); do
        # Convert first index to job name for all modes (single and double value modes)
        if [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-j" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-o" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-f" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-u" ]] || \
           [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-fu" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-fui" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-fuis" ]]; then
            # Get value pointers for the modes
            let first_value_p=p+1
            if [[ "${RUNSAS_PARAMETERS_ARRAY[first_value_p]}" != "" ]]; then
                INDEX_MODE_FIRST_JOB_NUMBER=0
                if [[ ${#RUNSAS_PARAMETERS_ARRAY[first_value_p]} -lt $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
                    printf "\n"
                    get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[first_value_p]} $JOB_LIST_FILE 4
                    INDEX_MODE_FIRST_JOB_NUMBER=${RUNSAS_PARAMETERS_ARRAY[first_value_p]}
                    eval "script_mode_value_$first_value_p='${job_name_from_the_list}'";
                else
                    check_for_multiple_instances_of_job ${RUNSAS_PARAMETERS_ARRAY[first_value_p]}
                fi
            fi
        fi
        # Convert second index to job name only for double value modes)
        if [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-fu" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-fui" ]] || [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "-fuis" ]]; then
            let second_value_p=p+2
            if [[ "${RUNSAS_PARAMETERS_ARRAY[second_value_p]}" != "" ]]; then 
                INDEX_MODE_SECOND_JOB_NUMBER=0
                if [[ ${#RUNSAS_PARAMETERS_ARRAY[second_value_p]} -lt $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
                    get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[second_value_p]} $JOB_LIST_FILE 4
                    INDEX_MODE_SECOND_JOB_NUMBER=${RUNSAS_PARAMETERS_ARRAY[second_value_p]}
                    eval "script_mode_value_$second_value_p='${job_name_from_the_list}'";
                else
                    check_for_multiple_instances_of_job ${RUNSAS_PARAMETERS_ARRAY[second_value_p]}
                fi
            fi
        fi
    done
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
		while IFS='|' read -r fid f jid j jdep op jrc runflag o so sappdir bservdir bsh blogdir bjobdir; do
			let job_counter+=1
            # Set defaults if nothing is specified 
            ajmode_sas_logs_root_directory="${blogdir:-$SAS_LOGS_ROOT_DIRECTORY}"
            # If user has specified a different server context, switch it here
            if [[ "$o" == "--server" ]]; then
                if [[ "$so" != "" ]]; then
                    ajmode_sas_logs_root_directory=`echo "${ajmode_sas_logs_root_directory/$SAS_APP_SERVER_NAME/$so}"`
                else
                    printf "${yellow}WARNING: $so was specified for $j in the list without the server context name, defaulting to $SAS_APP_SERVER_NAME${white}"
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
    printf "\n${white}The script was launched (in "${1:-'a default'}" mode with ${2:-"no"} ${3:-"filter"}) with PID $$ in $HOSTNAME on `date '+%Y-%m-%d %H:%M:%S'` by ${white}"
    printf '%s' ${white}"${SUDO_USER:-$USER}${white}"
    printf "${white} user\n${white}"
}
#------
# Name: update_job_status_color_palette()
# Desc: This function will update the color variables based on the current state of the jobs (must be called within runSAS function)
#   In: file-name (multiple files can be provided)
#  Out: <NA> 
#------
function update_job_status_color_palette(){
    if [[ $runsas_jobrc -eq $RC_JOB_PENDING ]]; then
        # Set the colors
        assign_and_preserve runsas_job_status_color orange
        assign_and_preserve runsas_job_status_bg_color grey_bg
        assign_and_preserve runsas_job_status_progressbar_color orange_bg 

        print2log $TERMINAL_MESSAGE_LINE_WRAPPERS
        print2log "Job No.: $JOB_COUNTER_FOR_DISPLAY"
        print2log "Job: $runsas_job"
        print2log "Opt: $runsas_opt"
        print2log "Sub-Opt: $runsas_subopt"
        print2log "App server: $runsas_app_root_directory"
        print2log "Batch server: $runsas_batch_server_root_directory"
        print2log "SAS shell: $runsas_sh"
        print2log "Logs: $runsas_logs_root_directory"
        print2log "Deployed Jobs: $runsas_deployed_jobs_root_directory"
        print2log "Start: $start_datetime_of_job_timestamp"
    fi
    if [[ $runsas_jobrc -eq $RC_JOB_TRIGGERED ]]; then
        assign_and_preserve runsas_job_status_color white
        assign_and_preserve runsas_job_status_bg_color grey_bg
        assign_and_preserve runsas_job_status_progressbar_color green_bg
    fi
    if [[ $runsas_jobrc -gt $runsas_max_jobrc ]]; then
        assign_and_preserve runsas_job_status_color red
        assign_and_preserve runsas_job_status_bg_color red_bg
        assign_and_preserve runsas_job_status_progressbar_color red_bg
    fi
}
#------
# Name: check_if_the_batch_is_complete()
# Desc: This function check if the batch is complete and set the RUNSAS_BATCH_COMPLETE_FLAG=1
#   In: <NA>
#  Out: <NA> 
#------
function check_if_the_batch_is_complete(){
    if [[ $runsas_jobrc -ge 0 ]] && [[ ! $runsas_jobrc -gt $runsas_max_jobrc ]]; then
        # Add to the runSAS array that keeps a track of how many jobs have completed the run
        if [[ ${#runsas_jobs_run_array[@]} -eq 0 ]]; then # Empty array!
            runsas_jobs_run_array+=( "$runsas_flow_job_key" ) 
        else 
            # Check if this job has been already added to the array (no duplicates allowed!)
            runsas_job_has_run_already=0
            for (( r=0; r<${#runsas_jobs_run_array[@]}; r++ )); do
                if [[ "${runsas_jobs_run_array[r]}" == "$runsas_flow_job_key" ]]; then
                    runsas_job_has_run_already=1
                fi
            done

            # Add the entry
            if [[ $runsas_job_has_run_already -ne 1 ]]; then
                runsas_jobs_run_array+=( "$runsas_flow_job_key" )
            fi
        fi
    fi

    # If runSAS has executed all jobs already, set the flag
    if [[ ${#runsas_jobs_run_array[@]} -ge $TOTAL_NO_OF_JOBS_COUNTER_CMD ]]; then
        RUNSAS_BATCH_COMPLETE_FLAG=1
    fi
}
#------
# Name: display_progressbar_with_offset()
# Desc: Calculates the progress bar parameters (https://en.wikipedia.org/wiki/Block_Elements#Character_table & https://www.rapidtables.com/code/text/unicode-characters.html, alternative: Ã¢â€“Ë†)
#   In: steps-completed, total-steps, offset (-1 or 0), optional-message, active-color, bypass-backspacing (use it when the whole row refreshes)
#  Out: <NA>
# Note: Requries get_current_terminal_cursor_position() and move
#------
function display_progressbar_with_offset(){
    # Defaults
    progressbar_default_active_color=$DEFAULT_PROGRESS_BAR_COLOR
    progressbar_width=20
    progressbar_sleep_interval_in_secs=0.25
    progressbar_color_unicode_char=" "
    progressbar_grey_unicode_char=" "
    progress_bar_pct_symbol_length=1
    progress_bar_100_pct_length=3

    # Input parameters
    progressbar_steps_completed=$1
	progressbar_total_steps=$2
    progressbar_offset=$3
	progressbar_post_message=$4
    progressbar_color=${5:-$progressbar_default_active_color}
    progressbar_bypass_backspacing=${6:-0}   

    # Calculate the scale
    let progressbar_scale=100/$progressbar_width

    # Skip the progress bar in batch mode
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then  

        # No steps (empty job scenario needs handling)
        if [[ $progressbar_total_steps -le 0 ]]; then
            progressbar_steps_completed=1
            progressbar_total_steps=1
        fi

        # Reset (>100% scenario!)
        if [[ $progressbar_steps_completed -gt $progressbar_total_steps ]]; then
            progressbar_steps_completed=$progressbar_total_steps
        fi

        # Calculate the percentage completed
        progress_bar_pct_completed=`bc <<< "scale = 0; ($progressbar_steps_completed + $progressbar_offset) * 100 / $progressbar_total_steps / $progressbar_scale"`

        # Reset the progress bar, backspace the previously shown percentage numbers (e.g. 10) and symbol (%)
        if [[ $progressbar_bypass_backspacing -eq 0 ]]; then 
            # Bypass the backspacing operation if the whole row is being refreshed instead of just the progress bar 
            if [[ "$progress_bar_pct_completed_charlength" != "" ]] && [[ $progress_bar_pct_completed_charlength -gt 0 ]]; then
                for (( i=1; i<=$progress_bar_pct_symbol_length; i++ )); do
                    printf "\b"
                done
                for (( i=1; i<=$progress_bar_pct_completed_charlength; i++ )); do
                    printf "\b"
                done
            fi
        fi 

        # Calculate percentage variables
        progress_bar_pct_completed_x_scale=`bc <<< "scale = 0; ($progress_bar_pct_completed * $progressbar_scale)"`

        # Reset if the variable goes beyond the boundary values
        if [[ $progress_bar_pct_completed_x_scale -lt 0 ]]; then
            progress_bar_pct_completed_x_scale=0
        fi

        # Get the length of the current percentage
        progress_bar_pct_completed_charlength=${#progress_bar_pct_completed_x_scale}

        # When "bypass backspacing" is turned on, just backspace at the end of the progress bar update (i.e. when progressbar_offset is 0)  
        if [[ $progressbar_bypass_backspacing -eq 1 ]]; then 
            if [[ $progressbar_offset -eq 0 ]] && [[ "$progress_bar_pct_completed_charlength" != "" ]] && [[ $progress_bar_pct_completed_charlength -gt 0 ]]; then
                for (( i=1; i<=$progress_bar_pct_completed_charlength; i++ )); do
                    printf "\b"
                done
            fi
        fi

        # Show the percentage on console, right justified
        printf "${!progressbar_color}${black}${progress_bar_pct_completed_x_scale}%%${white}"

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
            for (( i=1; i<=$progress_bar_pct_completed; i++ )); do
                printf "$progressbar_color_unicode_char"
            done	
        fi

        # Show the remaining "grey" block
        if [[ $progress_bar_pct_remaining -ne 0 ]]; then
            printf "${darkgrey_bg}"
            for (( i=1; i<=$progress_bar_pct_remaining; i++ )); do
                printf "$progressbar_color_unicode_char"
            done		
        fi
        
        # Reset the message when offset is 0 (to remove the message from last iteration, cleaning up)
        if [[ $progressbar_offset -eq 0 ]]; then
            progressbar_post_message="                                      "
        fi

        # Show the optional message after the progress bar
        if [ ! -z "$progressbar_post_message" ]; then
            printf "${white}$progressbar_post_message${end}"
        fi

        # Delay
        printf "${white}"
        sleep $progressbar_sleep_interval_in_secs

        # Erase the progress bar (reset)
        for (( i=1; i<=$progressbar_width; i++ )); do
            printf "\b"
        done

        # Width of the optional message 
        progressbar_post_message_width=${#progressbar_post_message}
        
        # Erase the optional progress bar message 
        if [ ! -z "$progressbar_post_message" ]; then
            for (( i=1; i<=$progressbar_post_message_width; i++ )); do
                printf "\b"
            done
        fi

        # Erase the percent shown in the progress bar on the last call i.e. reset the percentage variables on last iteration (i.e. when the offset is 0)
        if [[ $progressbar_offset -eq 0 ]]; then
            progress_bar_pct_completed_charlength=0
            # Remove the percentages from console
            for (( i=1; i<=$progress_bar_pct_symbol_length+$progress_bar_100_pct_length; i++ )); do
                printf "\b"
            done
        fi
    fi
}
#------
# Name: runSAS()
# Desc: This function implements the SAS job execution routine, quite an important one
#   In: (01) Flow identifier                (e.g.: 1)
#       (02) Flow name                      (e.g.: MarketingFlow)
#       (03) Job identifier                 (e.g.: 1)
#       (04) SAS deployed job name          (e.g.: 99_Run_Marketing_Jobs)
#       (05) Dependency                     (e.g.: 1,2)
#       (06) Logical operation              (e.g.: AND or OR)
#       (07) Return code (max allowed)      (e.g.: 4)
#       (08) runSAS job option              (e.g.: --server)
#       (09) runSAS job sub-option          (e.g.: SASAppX)
#       (10) SASApp root directory 		    (e.g.: /SASInside/SAS/Lev1/SASApp)
#       (11) SAS BatchServer directory name (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer)
#       (12) SAS BatchServer shell script   (e.g.: sasbatch.sh)
#       (13) SAS BatchServer logs directory (e.g.: /SASInside/SAS/Lev1/SASApp/BatchServer/Logs)
#       (14) SAS deployed jobs directory    (e.g.: /SASInside/SAS/Lev1/SASApp/SASEnvironment/SASCode/Jobs)
#  Out: <NA>
#------
function runSAS(){
    # Input Parameters 
    runsas_flowid="${1}"
    runsas_flow="${2}"    
    runsas_jobid="${3}"
    runsas_job="${4}"
    runsas_jobdep="${5:-$3}"
    runsas_logic_op="${6:-AND}"
    runsas_max_jobrc=${7:-4}
    runsas_runflag="${8:-Y}"
    runsas_opt="${9}"
    runsas_subopt="${10}"
    runsas_app_root_directory="${11:-$SAS_APP_ROOT_DIRECTORY}"
    runsas_batch_server_root_directory="${12:-$SAS_BATCH_SERVER_ROOT_DIRECTORY}"
    runsas_sh="${13:-$SAS_DEFAULT_SH}"
    runsas_logs_root_directory="${14:-$SAS_LOGS_ROOT_DIRECTORY}"
    runsas_deployed_jobs_root_directory="${15:-$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY}"

    # Disable carriage return (ENTER key) to stop user from messing up the layout on terminal
    disable_enter_key keyboard

    # Job dependencies are specifed using "," as delimeter, convert it to an array for easy manipulation later
    function convert_jobdep_into_array(){
        IFS=','
        runsas_jobdep_array=( $runsas_jobdep )
        runsas_jobdep_array_elem_count=${#runsas_jobdep_array[@]}
        IFS=$SERVER_IFS
    }
    convert_jobdep_into_array

    # Do not repeat the message to log in batch mode
    function set_do_not_repeat_message_parameter(){
        if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -gt -1 ]]; then
            assign_and_preserve repeat_job_terminal_messages "N" 
        else
            assign_and_preserve repeat_job_terminal_messages "Y"
        fi
    }

    # Reset these job-specific variables for each iteration (the state is injected subsequently)
    runsas_jobrc=$RC_JOB_PENDING
    runsas_max_jobrc=$runsas_max_jobrc
    runsas_job_cursor_row_pos=""
    runsas_job_cursor_col_pos=""
    runsas_job_pid=0
    st_msg=""
    st_time_since_run_msg_last_shown_timestamp=""
    st_last_shown_timestamp=""
    st_time_since_run_in_secs=""
    runsas_mode_runflag=0
    runsas_mode_interactiveflag=0
    progress_bar_pct_completed_charlength=""
    row_offset_applied_already=0
    first_runsas_job_cursor_row_pos=""
    no_slots_available_flag="N"
    run_job_with_prompt=""
    repeat_job_terminal_messages="Y"
    runsas_job_marked_complete_after_failure=0
    error_message_shown_on_job_fail=""

    # If the user has specified a different server context, switch it here
    if [[ "$runsas_opt" == "--server" ]]; then
        if [[ "$runsas_subopt" != "" ]]; then
            if [[ "$runsas_app_root_directory" == "" ]]; then
                runsas_app_root_directory=`echo "${runsas_app_root_directory/$SAS_APP_SERVER_NAME/$runsas_subopt}"`
            fi
            if [[ "$runsas_batch_server_root_directory" == "" ]]; then
                runsas_batch_server_root_directory=`echo "${runsas_batch_server_root_directory/$SAS_APP_SERVER_NAME/$runsas_subopt}"`
            fi
            if [[ "$runsas_logs_root_directory" == "" ]]; then
                runsas_logs_root_directory=`echo "${runsas_logs_root_directory/$SAS_APP_SERVER_NAME/$runsas_subopt}"`
            fi
            if [[ "$runsas_deployed_jobs_root_directory" == "" ]]; then
                runsas_deployed_jobs_root_directory=`echo "${runsas_deployed_jobs_root_directory/$SAS_APP_SERVER_NAME/$runsas_subopt}"`
            fi
        else
            printf "${yellow}WARNING: $runsas_opt was specified for $runsas_job job in the list without the server context name, defaulting to ${white}"
        fi
    fi

    # Unique flow-job key for dynamic variable names (same job can be specified in other flows or within the same flow)
    runsas_flow_job_key=${runsas_flowid}_${runsas_jobid}

    # Temporary "error" files
    runsas_error_tmp_log_file=$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid/.$runsas_flow_job_key.err
    runsas_error_w_steps_tmp_log_file=$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid/.$runsas_flow_job_key.stepserr
    runsas_job_that_errored_file=$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid/.$runsas_flow_job_key.errjob

    # Intitate the batch state (files are created)
    assign_and_preserve init 0
    
    # Print to debug file
    print2debug runsas_job "\n=======[ Looping " " with runsas_flowid=$runsas_flowid and runsas_jobid=$runsas_jobid ]===== "

    # Inject job state for a batch (all job specific variables for a batch is restored here to support parallel processing of jobs)
    if [[ $RUNSAS_INVOKED_IN_RESUME_MODE -gt -1 ]]; then
        # Set the vars
        resumed_batchid=${RUNSAS_PARAMETERS_ARRAY[$RUNSAS_INVOKED_IN_RESUME_MODE+1]}

        # Inject previous batch state
        inject_batch_state $resumed_batchid $runsas_jobid

        # Resume failed jobs
        if [[ $runsas_jobrc -gt $runsas_max_jobrc ]]; then
            # Update state and inject it back!
            update_batch_state runsas_job_pid 0 $runsas_jobid $resumed_batchid
            update_batch_state runsas_jobrc $RC_JOB_PENDING $runsas_jobid $resumed_batchid
            inject_batch_state $resumed_batchid $runsas_jobid
        fi
    else
        # Inject current batch state
        inject_batch_state $global_batchid $runsas_jobid 
    fi

    # Store the jobrc (max)
    assign_and_preserve runsas_max_jobrc $runsas_max_jobrc

    print2debug runsas_jobid "--- Post Injection (before mode flags) " " ---"
    print2debug runsas_job
    print2debug runsas_flow 
    print2debug runsas_flowid
    print2debug runsas_jobdep
    print2debug runsas_logic_op
    print2debug runsas_max_jobrc
    print2debug runsas_opt
    print2debug runsas_subopt
    print2debug runsas_app_root_directory
    print2debug runsas_batch_server_root_directory
    print2debug runsas_sh
    print2debug runsas_logs_root_directory
    print2debug runsas_deployed_jobs_root_directory
    print2debug runsas_job_pid
    print2debug runsas_jobrc 
    print2debug runsas_runflag
    print2debug runsas_mode_runflag
    print2debug runsas_mode_interactiveflag
    print2debug runsas_job_status_color

    # Increment the job counter for terminal display, jobid is unique across the flows
    JOB_COUNTER_FOR_DISPLAY=$runsas_jobid

    # Update the "run flag" and "interactive flag"
    update_job_mode_flags

    # Interactive mode 
    if [[ $runsas_mode_interactiveflag -eq 1 ]]; then
        # The batch must be run in sequential mode, check if --byflow override has been specified to switch the default behaviour of pausing by job
        if [[ $RUNSAS_INVOKED_IN_BYFLOW_MODE -gt -1 ]] && [[ $escape_interactive_mode -ne 1 ]]; then
            # Nothing much is done here, the actual flow-wise pause is applied later
            publish_to_messagebar "${green}NOTE: The batch will pause after each flow (-i with --byflow was applied)${white}"
            interactive_mode_at_flow_level_applied=1
        else
            # Reset the dependency by job
            if [[ $runsas_jobid -gt 1 ]] && [[ $escape_interactive_mode -ne 1 ]]; then
                runsas_jobdep=$((runsas_jobid-1))
                publish_to_messagebar "${green}NOTE: The batch will pause after each job (-i was applied), dependencies for job $runsas_jobid was adjusted to [$runsas_jobdep]"
                interactive_mode_at_job_level_applied=1
            fi
        fi

        # Reset the job dependency array 
        convert_jobdep_into_array
    fi	

    # Print to debug file
    print2debug runsas_jobid "--- Post interactive mode checks and after flag updates " " ---"
    print2debug runsas_job
    print2debug runsas_flow 
    print2debug runsas_flowid
    print2debug runsas_jobdep

    # Place the cursor (relative to the first job cursor)
    if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        restore_terminal_screen_cursor_positions
    fi

    # Print to debug file 
    print2debug runsas_mode_runflag "--- After flag updates " " ---"
    print2debug runsas_mode_interactiveflag
    print2debug runsas_runflag

    # Process the mode "runflag"
    if [[ $runsas_mode_runflag -ne 1 ]] || [[ "$run_job_with_prompt" == "n" ]]; then
        assign_and_preserve runsas_jobrc $RC_JOB_COMPLETE
        write_job_details_on_terminal $runsas_job ".(SKIPPED)" "grey" "grey"
        print2debug runsas_jobrc "Mode runflag is set to 0... "
        set_do_not_repeat_message_parameter
    fi

    # Skip the jobs marked as do not run in job list (overwrites user modes)
    if [[ ! "$runsas_runflag" == "Y" ]]; then
        print2debug runsas_jobrc "Job list runflag is set to N... "
        assign_and_preserve runsas_jobrc $RC_JOB_COMPLETE
        write_job_details_on_terminal $runsas_job ".(SKIPPED, runflag set to N in job list)" "grey" "grey"
        set_do_not_repeat_message_parameter
    fi

    # Set the "RUNSAS_BATCH_COMPLETE_FLAG" (to exit the master loop) based on how many has completed it's run (any state DONE/FAIL)
    check_if_the_batch_is_complete

    # Print to debug file
    print2debug runsas_jobs_run_array[@] "--- Jobs that have run already: [" "]---"
    print2debug RUNSAS_BATCH_COMPLETE_FLAG
 
    # Skip the finished jobs (failed ones will continue to refresh and skipped a bit later)
    if [[ $runsas_jobrc -gt $RC_JOB_TRIGGERED ]] && [[ $runsas_jobrc -le $runsas_max_jobrc ]]; then
        print2debug runsas_jobrc "Skipping the loop as the job has finished running... "

        # Show the skipped details if the batch is being resumed
        if [[ $RUNSAS_INVOKED_IN_RESUME_MODE -gt -1 ]] && [[ $runsas_jobrc -ge $RC_JOB_COMPLETE ]] && [[ $runsas_jobrc -le $runsas_max_jobrc ]] && [[ $runsas_job_marked_complete_after_failure -ne 1 ]]; then
            write_job_details_on_terminal $runsas_job ".(SKIPPED, Job was already run as part of the previous batch)         " "grey" "grey"
        fi

        # If the job was marked a complete to recover from the stalled/failed batch show the message
        if [[ $runsas_job_marked_complete_after_failure -eq 1 ]]; then
            write_job_details_on_terminal $runsas_job ".(FAIL rc=9, Job was marked as complete by user to recover the batch)" "green" "white"
        fi

        # Skip the loop!
        continue
    fi

    # Refresh color palette 
    update_job_status_color_palette

    # Write the job details on the screen
    write_job_details_on_terminal $runsas_job "" "$runsas_job_status_color" "$runsas_job_status_color"

	# Check if the prompt option is set by the user for the job (over engineered!)
    if [[ "$runsas_opt" == "--prompt" ]] && [[ "$run_job_with_prompt" == "" ]] && [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
		# Disable enter key
		disable_enter_key
		
		# Ask user
        run_or_skip_message=" Do you want to run? (y/n): "		
        run_or_skip_message_orig=$run_or_skip_message		
		printf "${red}$run_or_skip_message${white}"
		
		# Make sure the user has pressed a valid answer (i.e. y/n) with time out (and email notification to user after the time out)
		function read_until_user_provides_right_input(){
			while read -t $EMAIL_WAIT_NOTIF_TIMEOUT_IN_SECS -n1 run_job_with_prompt < /dev/tty; do
				# Reset the terminal
				for (( i=1; i<=${#run_or_skip_message}+$1; i++ )); do
					printf "\b"
				done
				if [[ "$run_job_with_prompt" == "y" ]] || [[ "$run_job_with_prompt" == "Y" ]] || [[ "$run_job_with_prompt" == "n" ]] || [[ "$run_job_with_prompt" == "N" ]]; then
					break;
				else
					run_or_skip_message="$run_or_skip_message" 
				fi
				printf "${red}$run_or_skip_message${white}"
			done;
		}
		
		# First iterations
		read_until_user_provides_right_input 1
		
        # On time outs
        while [[ "$run_job_with_prompt" == "" ]]; do
			# Reset the terminal
			for (( i=1; i<=${#run_or_skip_message}; i++ )); do
				printf "\b"
			done
			# Notify the user once
			if [[ "$user_notified_job" != "$runsas_job" ]]; then 
				runsas_notify_email $runsas_job
				user_notified_job=$runsas_job
			fi
			run_or_skip_message="(notified) $run_or_skip_message_orig" 
			printf "${red}$run_or_skip_message${white}"
            read_until_user_provides_right_input 1
        done;
        
		# Act on the user request
        assign_and_preserve run_job_with_prompt $run_job_with_prompt
        if [[ $run_job_with_prompt != Y ]] && [[ $run_job_with_prompt != y ]]; then
			# Remove the message, reset the cursor
			echo -ne "\r"
			printf "%174s" " "
			echo -ne "\r"
            printf "${white}"
            write_job_details_on_terminal $runsas_job "(SKIPPED)"
            assign_and_preserve run_job_with_prompt "n"
            continue
        fi
    fi

    # Check if the directory exists (specified by the user as configuration)
    check_if_the_dir_exists $runsas_app_root_directory $runsas_batch_server_root_directory $runsas_logs_root_directory $runsas_deployed_jobs_root_directory
    check_if_the_file_exists "$runsas_batch_server_root_directory/$runsas_sh" "$runsas_deployed_jobs_root_directory/$runsas_job.sas"

    # Job launch function (standard template for all calls), each PID is monitored by runSAS
    function trigger_the_job_now(){
        if [[ $runsas_jobrc -eq $RC_JOB_PENDING ]]; then
            # Get the count of running jobs
            get_running_jobs_count $flow_file_name
            print2debug running_jobs_current_count "There are [" "] jobs running currently with sjs_concurrent_job_count_limit=$sjs_concurrent_job_count_limit"

            # Check if the job slots are full!
            if [[ $running_jobs_current_count -lt $sjs_concurrent_job_count_limit ]]; then
                nice -n 20 $runsas_batch_server_root_directory/$runsas_sh   -log $runsas_logs_root_directory/${runsas_job}_#Y.#m.#d_#H.#M.#s.log \
                                                                            -batch \
                                                                            -noterminal \
                                                                            -logparm "rollover=session" \
                                                                            -sysin $runsas_deployed_jobs_root_directory/$runsas_job.sas & > $RUNSAS_SAS_SH_TRACE_FILE
                
                # Get the PID details
                if [[ -z "$runsas_job_pid" ]] || [[ "$runsas_job_pid" == "" ]] || [[ $runsas_job_pid -eq 0 ]]; then
                    assign_and_preserve runsas_job_pid $!
                fi
                
                # Set the triggered return code
                assign_and_preserve runsas_jobrc $RC_JOB_TRIGGERED

                # Save the timestamps
                assign_and_preserve start_datetime_of_job_timestamp "`date '+%d-%m-%Y-%H:%M:%S'`" "STRING"
                assign_and_preserve start_datetime_of_job "`date +%s`" "STRING"

                # Print to debug file
                print2debug runsas_job "Job launched (SUCCESS) >>> "  
                print2debug runsas_job_pid
                print2debug runsas_jobrc
                print2debug runsas_job_status_color
            else
                no_slots_available_flag="Y"
                print2debug sjs_concurrent_job_count_limit "(Skipping the trigger as the slots are full!) "  
                print2debug running_jobs_current_count
            fi
        fi
    }

    # Reset the dependent job run counter
    count_of_dep_jobs_that_has_run=0
    AND_check_passed=0
    OR_check_passed=0

    # No dependency has been specified or specified as self-dependent
    if [[ "$runsas_jobdep" == "" ]] || [[ "$runsas_jobdep" == "$runsas_jobid" ]]; then
            # No dependency, trigger!
            trigger_the_job_now
            # Print to debug file
            print2debug runsas_jobdep "No dependency / self dependency "
    else
        # Dependency check loop begins here
        runsas_jobdep_i_jobrc=$RC_JOB_PENDING # Reset
        runsas_jobdep_i_max_jobrc=4 # Reset
        for (( i=0; i<${runsas_jobdep_array_elem_count}; i++ ));
        do                 
            # Get one dependency at a time, check the RC
            runsas_jobdep_i="${runsas_jobdep_array[i]}"
    
            # Print to debug file
            print2debug i "--- Inside the dependency loop now " " ---"
            print2debug runsas_jobdep_i

            # Get dependent job's return code
            if [[ $runsas_jobdep_i -eq $runsas_jobid ]]; then
                # Self dependency!
                runsas_jobdep_i_jobrc=0 
                runsas_jobdep_i_max_jobrc=0 
                print2debug runsas_jobid "Self dependent [" "] dep: $runsas_jobdep_i"
            else
                # Get the dependent's rc and its rc_max
                get_keyval_from_batch_state runsas_jobrc runsas_jobdep_i_jobrc $runsas_jobdep_i
                get_keyval_from_batch_state runsas_max_jobrc runsas_jobdep_i_max_jobrc $runsas_jobdep_i
                print2debug runsas_jobid "Get dependents [" "] dep: $runsas_jobdep_i | runsas_jobdep_i_jobrc=$runsas_jobdep_i_jobrc | runsas_jobdep_i_jobrc=$runsas_jobdep_i_jobrc"
            fi
        
            # Keep a track of how many jobs have run (and see if they have run with 0 <= RC <= maxRC specified by the user in the job list)
            if [[ $runsas_jobdep_i_jobrc -ge 0 ]] && [[ $runsas_jobdep_i_jobrc -le $runsas_jobdep_i_max_jobrc ]] && [[ "$runsas_jobdep_i_jobrc" != "" ]]; then
                let count_of_dep_jobs_that_has_run=$count_of_dep_jobs_that_has_run+1
            fi

            # Gate criteria (AND/OR)
            #   (1) AND: all of the dependent jobs have run with 0 <= RC <= maxRC
            #   (2)  OR: any one of the job has run with 0 <= RC <= maxRC
            if [[ $count_of_dep_jobs_that_has_run -ge 1 ]]; then 
                OR_check_passed=1
                if [[ $count_of_dep_jobs_that_has_run -ge ${runsas_jobdep_array_elem_count} ]]; then
                    AND_check_passed=1
                else
                    AND_check_passed=0
                fi
            else
                OR_check_passed=0
            fi

            # Print to debug file
            print2debug runsas_jobrc "--- Post dependency checks " " ---" 
            print2debug runsas_job_pid 
            print2debug runsas_jobdep_i_jobrc 
            print2debug runsas_logic_op 
            print2debug runsas_max_jobrc
            print2debug count_of_dep_jobs_that_has_run
            print2debug OR_check_passed 
            print2debug AND_check_passed 

            # Finally, evaluate the dependency:
            # (1) AND: All jobs have completed successfully (or within the limits of specified return code by user) and this is the default if nothing has been specified
            # (2) OR: One of the job has completed
            if [[ $runsas_logic_op == "OR" ]]; then
                if [[ $OR_check_passed -eq 1 ]]; then
                    # Trigger!
                    trigger_the_job_now   
                fi
            else   
                 if [[ $AND_check_passed -eq 1 ]]; then 
                    # Trigger!
                    trigger_the_job_now
                fi             
            fi
        done 
    fi  

    # Count the no. of steps in the job
    total_no_of_steps_in_a_job=`grep -o 'Step:' $runsas_deployed_jobs_root_directory/$runsas_job.sas | wc -l`

    # Print to debug file
    print2debug runsas_job_pid "Outside the dependency loop now "

    # Paint the rest of the message on the terminal
    if [[ "$repeat_job_terminal_messages" == "Y" ]]; then
        if [[ $runsas_job_pid -eq 0 ]]; then
            # Get the list of pending dependent jobs
            depjob_pending_jobs=""
            # Loop through the dependents
            for (( i=0; i<${runsas_jobdep_array_elem_count}; i++ ));
            do                 
                runsas_jobdep_i="${runsas_jobdep_array[i]}"
                get_keyval_from_batch_state runsas_jobrc runsas_jobdep_i_jobrc $runsas_jobdep_i
                get_keyval_from_batch_state runsas_max_jobrc runsas_jobdep_i_max_jobrc $runsas_jobdep_i
                if [[ $runsas_jobdep_i_jobrc -lt $RC_JOB_COMPLETE ]] || [[ $runsas_jobdep_i_jobrc -gt $runsas_jobdep_i_max_jobrc ]]; then
                    depjob_pending_jobs+="$runsas_jobdep_i "
                fi
            done
            # Show rest of the message for the job
            display_fillers $RUNSAS_RUNNING_MESSAGE_FILLER_END_POS $RUNSAS_FILLER_CHARACTER 1 N 2 $runsas_job_status_color 
            if [[ "$no_slots_available_flag" == "Y" ]]; then
                printf "${!runsas_job_status_color}no slots available ${running_jobs_current_count}:${sjs_concurrent_job_count_limit} (`echo $depjob_pending_jobs | tr -s " "`) ${white}" 
                clear_the_rest_of_the_line # No residue chars
            else
                get_remaining_cols_on_terminal 
                show_waiting_deps_message="waiting on dependents (`echo $depjob_pending_jobs | tr -s " "`"
                if [[ ${#show_waiting_deps_message} -le $((runsas_remaining_cols_in_screen-5)) ]]; then
                    printf "${!runsas_job_status_color}${show_waiting_deps_message})${white}"
                else
                    printf "${!runsas_job_status_color}${show_waiting_deps_message:0:$((runsas_remaining_cols_in_screen-5))}...)${white}"
                fi
                clear_the_rest_of_the_line # No residue chars
            fi
        else
            display_fillers $RUNSAS_RUNNING_MESSAGE_FILLER_END_POS $RUNSAS_FILLER_CHARACTER 1 N 2 $runsas_job_status_color 
            printf "${!runsas_job_status_color}PID $runsas_job_pid${white}"
            show_job_hist_runtime_stats $runsas_job
        fi
        
        # "Space" between messages and progressbar
        printf "${white} ${green}"        
    fi

    # Get the current job log filename (absolute path), wait until the log is generated...
    runsas_job_log=""
    if [[ $runsas_jobrc -ge $RC_JOB_TRIGGERED ]]; then
        while [[ ! "$runsas_job_log" =~ "log" ]]; do 
            sleep 0.25 
            runsas_job_log=`ls -tr $runsas_logs_root_directory/${runsas_job}*.log | tail -1`
            runsas_job_log=${runsas_job_log##/*/}
        done
    fi

    # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
    no_of_steps_completed_in_log=`grep -o 'Step:' $runsas_logs_root_directory/$runsas_job_log | wc -l`
    
    # Get runtime stats for the current job
    get_job_hist_runtime_stats $runsas_job
    hist_job_runtime_for_current_job="${hist_job_runtime:-0}"

    # Monitor the PID, see if it has completed...
    if [[ $runsas_job_pid -eq 0 ]]; then
        assign_and_preserve runsas_jobrc $RC_JOB_PENDING
    else
        if ! [[ -z `ps -p $runsas_job_pid -o comm=` ]]; then
            assign_and_preserve runsas_jobrc $RC_JOB_TRIGGERED
        else  
            assign_and_preserve runsas_jobrc $RC_JOB_COMPLETE
        fi    
    fi

    # Check if there are any errors in the logs (as it updates, in real-time) and capture step information using "egrep"
    $RUNSAS_LOG_SEARCH_FUNCTION -m${JOB_ERROR_DISPLAY_COUNT} \
                                -E --color "$ERROR_CHECK_SEARCH_STRING" \
                                -$JOB_ERROR_DISPLAY_LINES_AROUND_MODE$JOB_ERROR_DISPLAY_LINES_AROUND_COUNT \
                                $runsas_logs_root_directory/$runsas_job_log > $runsas_error_tmp_log_file

    egrep   -m$((JOB_ERROR_DISPLAY_COUNT+1)) \
            -E --color "* $STEP_CHECK_SEARCH_STRING|$ERROR_CHECK_SEARCH_STRING" \
            -$JOB_ERROR_DISPLAY_LINES_AROUND_MODE$JOB_ERROR_DISPLAY_LINES_AROUND_COUNT \
             $runsas_logs_root_directory/$runsas_job_log > $runsas_error_w_steps_tmp_log_file

    # Again, suppress unwanted lines in the log (typical SAS errors!)
    remove_a_line_from_file ^$ "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_1" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_2" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_3" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_4" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_5" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_6" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_7" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_8" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_9" "$runsas_error_tmp_log_file"
    remove_a_line_from_file "$SUPPRESS_ERROR_MESSAGE_10" "$runsas_error_tmp_log_file"

    # See if the error file has been generated (generated when there's an error)
    if [ -s $runsas_error_tmp_log_file ]; then
        assign_and_preserve runsas_jobrc 9
    fi

    # Check for abnormal termination of job (process killed by the server etc.), very rare and typically an incomplete log without a PID indicates this issue...
    if [[ $runsas_jobrc -ge $RC_JOB_COMPLETE ]] && [[ $runsas_jobrc -le $runsas_max_jobrc ]] && [[ ! -z `ps -p $runsas_job_pid -o comm=` ]]; then
        # Check the logs
        tail -$RUNSAS_SAS_LOG_TAIL_LINECOUNT $runsas_logs_root_directory/$runsas_job_log | grep "NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414" > $runsas_error_tmp_log_file
        tail -$RUNSAS_SAS_LOG_TAIL_LINECOUNT $runsas_logs_root_directory/$runsas_job_log | grep "NOTE: The SAS System used:" >> $runsas_error_tmp_log_file
        
        # Show the error
        if [ ! -s $runsas_error_tmp_log_file ]; then
            assign_and_preserve runsas_jobrc $RC_JOB_ABNORMAL_TERMINATION
            echo "ERROR: runSAS detected abnormal termination of the job/process by the server, there's no SAS error in the log file." > $runsas_error_tmp_log_file 
        fi
    fi

    # Handle different states
    update_job_status_color_palette  

    # Optionally, abort the job run on seeing an error based on the settings
    if [[ "$ABORT_ON_ERROR" == "Y" ]] && [[ $runsas_jobrc -gt $runsas_max_jobrc ]]; then
        if [[ ! -z `ps -p $runsas_job_pid -o comm=` ]]; then
            kill_a_pid $runsas_job_pid
            wait $runsas_job_pid 2>/dev/null
            break
        fi
    fi

    # Show progress bar
    if [[ $runsas_jobrc -ge $RC_JOB_TRIGGERED ]]; then
        # Show time remaining statistics for the running jobs
        show_time_remaining_stats $runsas_job
        # Display/refresh progress bar
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job -1 "$st_msg" $runsas_job_status_progressbar_color 1
        assign_and_preserve progress_bar_pct_completed_charlength $progress_bar_pct_completed_charlength
    fi 

    # Print to debug file
    print2debug runsas_job_pid "--- Just before final job status checks " " ---" 
    print2debug runsas_jobrc

    # Set the "RUNSAS_BATCH_COMPLETE_FLAG" (to exit the master loop) based on how many has completed it's run (any state DONE/FAIL)
    check_if_the_batch_is_complete

    # Batch mode messages (additional)
    function show_additional_batch_mode_messages(){
        if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -gt -1 ]]; then
            printf "${!runsas_job_status_color}${NO_BRANCH_DECORATOR}${SPACE_DECORATOR}${CHILD_DECORATOR}[Results: Job #$runsas_jobid: $runsas_job]${white}"
        fi
    }

    # ERROR: Check return code, abort if there's an error in the job run
    if [[ $runsas_jobrc -gt $runsas_max_jobrc ]]; then
        # Find the last job that ran on getting an error (there can be many jobs within a job in the world of SAS!)
        sed -n '1,/^ERROR:/ p' $runsas_logs_root_directory/$runsas_job_log | sed 's/Job:             Sngl Column//g' | grep "Job:" | tail -1 > $runsas_job_that_errored_file

        # Format the job name for display
        sed -i 's/  \+/ /g' $runsas_job_that_errored_file
        sed -i 's/^[1-9][0-9]* \* Job: //g' $runsas_job_that_errored_file
        sed -i 's/[A0-Z9]*\.[A0-Z9]* \*//g' $runsas_job_that_errored_file
		
		# Capture job runtime
        assign_and_preserve end_datetime_of_job_timestamp "`date '+%d-%m-%Y-%H:%M:%S'`" "STRING"
        assign_and_preserve end_datetime_of_job "`date +%s`" "STRING"

        # Failure (FAILED) message
        if [[ -z `ps -p $runsas_job_pid -o comm=` ]]; then
            # Show the job name in batch mode
            show_additional_batch_mode_messages

            # Display fillers (tabulated terminal output)
            display_fillers $RUNSAS_DISPLAY_FILLER_COL_END_POS $RUNSAS_FILLER_CHARACTER 0 N 1 "$runsas_job_status_color"
            printf "\b${white}${red}(FAIL rc=$runsas_jobrc, ${start_datetime_of_job_timestamp} to ${end_datetime_of_job_timestamp}, ~"
            printf "%05d" $((end_datetime_of_job-start_datetime_of_job))
            printf " secs)${white} "

            # Set a flag
            update_batch_state error_message_shown_on_job_fail "Y" $runsas_jobid $global_batchid

            # Construt the error message
            job_err_message=$(<$runsas_error_tmp_log_file)
            if [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
                get_remaining_cols_on_terminal
                job_err_message_with_log=$job_err_message" ($runsas_job_log)"
                # Append the error message to the row without disturbing the row hence I substring the error message
                printf "${red}${job_err_message_with_log:0:$((runsas_remaining_cols_in_screen-7))}${white}"
            else
                #Append the full error message to the log
                printf "${red}${job_err_message} ($runsas_logs_root_directory/$runsas_job_log)${white}\n"
            fi
        fi

        # Log
        print2log "Job Status: ${red}*** ERROR ***${white}"

        # Display error messsage 
        if [[ "$JOB_ERROR_DISPLAY" == "Y" ]]; then
            # Wrappers
            printf "${red}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n"

            # Show job steps or just the error message
            if [[ "$JOB_ERROR_DISPLAY_STEPS" == "Y" ]]; then
                printf "%s" "$(<$runsas_error_w_steps_tmp_log_file)"
                print2log "Reason: ${red}\n"
                printf "%s" "$(<$runsas_error_w_steps_tmp_log_file)" >> $RUNSAS_SESSION_LOG_FILE
            else        
                printf "%s" "$(<$runsas_error_tmp_log_file)"
                print2log "Reason: ${red}"
                printf "%s" "$(<$runsas_error_tmp_log_file)" >> $RUNSAS_SESSION_LOG_FILE
            fi

            # Line separator
            printf "\n${red}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n"

            # Print last job
            printf "${red}Job: ${red}"
            printf "%s" "$(<$runsas_job_that_errored_file)"

            # Add failed job/step details to the log
            printf "${white}Job: ${red}" >> $RUNSAS_SESSION_LOG_FILE
            printf "%s" "$(<$runsas_job_that_errored_file)" >> $RUNSAS_SESSION_LOG_FILE  
            
            # Print the log filename
            printf "\n${white}${white}"
            printf "${red}Log: ${red}$runsas_logs_root_directory/$runsas_job_log${white}\n" 
            print2log "${white}Log: ${red}$runsas_logs_root_directory/$runsas_job_log${white}"  

            # Line separator
            printf "${red}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n"
        fi

        # Publish error message to the message bar
        publish_to_messagebar "${red}(Job #$runsas_jobid failed): $(<$runsas_error_tmp_log_file)${white}" 
		
		# Send an error email
        runsas_error_email $JOB_COUNTER_FOR_DISPLAY $TOTAL_NO_OF_JOBS_COUNTER_CMD

        # Log
        print2log "${white}End: $end_datetime_of_job_timestamp${white}"

        # Print to debug file
        print2debug runsas_job_pid "--- Inside ERROR/FAIL " " ---" 
        print2debug runsas_jobrc

    elif [[ $runsas_jobrc -ge 0 ]] && [[ $runsas_jobrc -le $runsas_max_jobrc ]]; then

        # SUCCESS: Complete the progress bar with offset 0 (fill the last bit after the step is complete)
        # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
        no_of_steps_completed_in_log=`grep -o 'Step:' $runsas_logs_root_directory/$runsas_job_log | wc -l`
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job 0 "" "" 1
        assign_and_preserve progress_bar_pct_completed_charlength $progress_bar_pct_completed_charlength
    
        # Capture job runtime
        assign_and_preserve end_datetime_of_job_timestamp "`date '+%d-%m-%Y-%H:%M:%S'`" "STRING"
		assign_and_preserve end_datetime_of_job "`date +%s`" "STRING"

		# Get last runtime stats to calculate the difference.
		get_job_hist_runtime_stats $runsas_job
		if [[ "$hist_job_runtime" != "" ]] && [[ $hist_job_runtime -gt 0 ]]; then
            job_runtime_diff_pct=`bc <<< "scale = 0; (($end_datetime_of_job - $start_datetime_of_job) - $hist_job_runtime) * 100 / $hist_job_runtime"`
		else
			job_runtime_diff_pct=0
		fi
		
		# Construct runtime difference messages, appears only when it crosses a threshold (i.e. reusing RUNTIME_COMPARISON_FACTOR parameter here, default is 50%)
		if [[ $job_runtime_diff_pct -eq 0 ]]; then
			job_runtime_diff_pct_string=""
		elif [[ $job_runtime_diff_pct -gt $RUNTIME_COMPARISON_FACTOR ]]; then
			job_runtime_diff_pct_string=" ${red}⯅${job_runtime_diff_pct}%%${green}"
		elif [[ $job_runtime_diff_pct -lt -$RUNTIME_COMPARISON_FACTOR ]]; then
			job_runtime_diff_pct=`bc <<< "scale = 0; -1 * $job_runtime_diff_pct"`
			job_runtime_diff_pct_string=" ${blue}⯆${job_runtime_diff_pct}%%${green}"
		else
			job_runtime_diff_pct_string=""
		fi

        # Store the stats for the next time
        store_job_runtime_stats $runsas_flow $runsas_job $((end_datetime_of_job-start_datetime_of_job)) $job_runtime_diff_pct $runsas_job_log $start_datetime_of_job_timestamp $end_datetime_of_job_timestamp

        # Show the job name in batch mode
        show_additional_batch_mode_messages

        # Display fillers (tabulated terminal output)
        display_fillers $RUNSAS_DISPLAY_FILLER_COL_END_POS $RUNSAS_FILLER_CHARACTER 1

        # Success (DONE) message
        printf "\b${white}${green}(DONE rc=$runsas_jobrc, ${start_datetime_of_job_timestamp} to ${end_datetime_of_job_timestamp}, ~"
        printf "%05d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs)${job_runtime_diff_pct_string}${white}\n"

        # Log
        print2log "Job Status: ${green}DONE${white}"
        print2log "Log: $runsas_logs_root_directory/$runsas_job_log"
        print2log "End: $end_datetime_of_job_timestamp"
        print2log "Diff: $job_runtime_diff_pct"

        # Print to debug file
        print2debug runsas_job_pid "--- Inside DONE (SUCCESS) " " ---" 
        print2debug runsas_jobrc

        # Send an email (silently)
        runsas_job_completed_email $runsas_job $((end_datetime_of_job-start_datetime_of_job)) $hist_job_runtime_for_current_job $JOB_COUNTER_FOR_DISPLAY $TOTAL_NO_OF_JOBS_COUNTER_CMD

        # Stop in case of interactive mode:
        # Job-wise:
        if [[ $interactive_mode_at_job_level_applied -eq 1 ]]; then 
            if [[ "$escape_interactive_mode" != "1" ]]; then
                enable_enter_key keyboard
                publish_to_messagebar "${red_bg}${blink}${black}Press ENTER key to continue or type E to escape the interactive mode${end}" Y run_in_interactive_mode_check_user_input
                if [[ "$run_in_interactive_mode_check_user_input" == "E" ]] || [[ "$run_in_interactive_mode_check_user_input" == "e" ]]; then
                    escape_interactive_mode=1
                fi
                publish_to_messagebar "" 
            fi
        fi
    else
        # "Still running" section
        if [[ "$repeat_job_terminal_messages" == "Y" ]]; then
            printf "\n"
        fi
        # Print to debug file
        print2debug runsas_job_pid "--- Inside ELSE section (WARNING: empty section) " " ---"
        print2debug runsas_jobrc
    fi

    # Do not repeat the messages in batch mode
    set_do_not_repeat_message_parameter
}
#--------------------------------------------------END OF FUNCTIONS--------------------------------------------------#

# BEGIN: Version menu (if invoked via ./runSAS.sh --version or ./runSAS.sh -v or ./runSAS.sh --v)
show_the_script_version_number $1

# Compatible version number
show_the_update_compatible_script_version_number $1

# Welcome message
publish_to_messagebar "Getting things ready and clearing screen, please wait..."

# The script execution begins from here, with a clear screen command
clear

# Github URL
RUNSAS_GITHUB_PAGE=http://github.com/PrajwalSD/runSAS
RUNSAS_GITHUB_SOURCE_CODE_DEFAULT_BRANCH=master
RUNSAS_GITHUB_SOURCE_CODE_URL=$RUNSAS_GITHUB_PAGE/raw/$RUNSAS_GITHUB_SOURCE_CODE_DEFAULT_BRANCH/runSAS.sh

# Directories
RUNSAS_BACKUPS_DIRECTORY=backups
RUNSAS_TMP_DIRECTORY=.tmp
RUNSAS_RUN_STATS_DIRECTORY=$RUNSAS_TMP_DIRECTORY/.stats
RUNSAS_EMAIL_DIRECTORY=$RUNSAS_TMP_DIRECTORY/.email
RUNSAS_BATCH_STATE_ROOT_DIRECTORY=$RUNSAS_TMP_DIRECTORY/.batch
RUNSAS_SPLIT_FLOWS_DIRECTORY=$RUNSAS_TMP_DIRECTORY/.flows

# System defaults 
RUNSAS_PARAMETERS_COUNT=$#
RUNSAS_PARAMETERS_ARRAY=("$@")
RUNSAS_MAX_PARAMETERS_COUNT=8
TERM_BOTTOM_LINES_EXCLUDE_COUNT=2
RUNSAS_SAS_LOG_TAIL_LINECOUNT=25
DEBUG_MODE_TERMINAL_COLOR=white
RUNSAS_RUNNING_MESSAGE_FILLER_END_POS=83
RUNSAS_DISPLAY_FILLER_COL_END_POS=$((RUNSAS_RUNNING_MESSAGE_FILLER_END_POS+34))
RUNSAS_FILLER_CHARACTER=.
TERMINAL_MESSAGE_LINE_WRAPPERS=-----
JOB_NUMBER_DEFAULT_LENGTH_LIMIT=3
JOB_COUNTER_FOR_DISPLAY=0
LONG_RUNNING_JOB_MSG_SHOWN=0
TOTAL_NO_OF_JOBS_COUNTER_CMD=`cat .job.list | wc -l`
INDEX_MODE_FIRST_JOB_NUMBER=-1
INDEX_MODE_SECOND_JOB_NUMBER=-1
EMAIL_ATTACHMENT_SIZE_LIMIT_IN_BYTES=8000000
DEFAULT_PROGRESS_BAR_COLOR="green_bg"
SERVER_PACKAGE_INSTALLER_PROGRAM=yum
RUNSAS_LOG_SEARCH_FUNCTION=egrep
EMAIL_USER_MESSAGE=""
EMAIL_FLAGS_DEFAULT_SETTING=YNYY
EMAIL_WAIT_NOTIF_TIMEOUT_IN_SECS=120
RUNSAS_JOBLIST_FILE_DEFAULT_DELIMETER="|"
RUNSAS_BATCH_COMPLETE_FLAG=0
SERVER_IFS=$IFS
RUNSAS_FAIL_RECOVER_SLEEP_IN_SECS=2
RUNSAS_SCREEN_LINES_OVERFLOW_BUFFER=5

# Graphical defaults
SINGLE_PARENT_DECORATOR="───"
PARENT_DECORATOR="┎──"
BRANCH_DECORATOR="┠──"
CHILD_DECORATOR="┖──"
NO_BRANCH_DECORATOR="┃  "
SPACE_DECORATOR="   "

# Terminal size requirements for runSAS (change this as required)
RUNSAS_REQUIRED_TERMINAL_ROWS=50  # Default is 65
RUNSAS_REQUIRED_TERMINAL_COLS=165 # Default is 165

# Deprecated user parameters which are now defaults (do not change this)
JOB_ERROR_DISPLAY=N
JOB_ERROR_DISPLAY_COUNT=1
JOB_ERROR_DISPLAY_STEPS=N
JOB_ERROR_DISPLAY_LINES_AROUND_MODE=A
JOB_ERROR_DISPLAY_LINES_AROUND_COUNT=1

# Error supressions
SUPPRESS_ERROR_MESSAGE_1="ERROR: Errors printed on page"
SUPPRESS_ERROR_MESSAGE_2=""
SUPPRESS_ERROR_MESSAGE_3=""
SUPPRESS_ERROR_MESSAGE_4=""
SUPPRESS_ERROR_MESSAGE_5=""
SUPPRESS_ERROR_MESSAGE_6=""
SUPPRESS_ERROR_MESSAGE_7=""
SUPPRESS_ERROR_MESSAGE_8=""
SUPPRESS_ERROR_MESSAGE_9=""
SUPPRESS_ERROR_MESSAGE_10=""

# Return codes (do not change these)
RC_JOB_PENDING=-2
RC_JOB_TRIGGERED=-1
RC_JOB_COMPLETE=0
RC_JOB_COMPLETE_WITH_WARNING=4
RC_JOB_ERROR=9
RC_JOB_ABNORMAL_TERMINATION=99

# Mode type arrays (all values must be wrapped with "spaces" around them)
SHORTFORM_MODE_NO_PARMS=( " -i " " -v " )
SHORTFORM_MODE_SINGLE_PARM=( " -f " " -u " " -o " " -j " )
SHORTFORM_MODE_DOUBLE_PARMS=( " -fu " " -fui " " -fuis " " -s " )
LONGFORM_MODE_NO_PARMS=( " --noemail " " --nomail " " --update " " --help " " --version " " --reset " " --parms " " --parameters " " --update-c " " --list " " --log " " --last " " --byflow " " --batch " "--nocolors" )
LONGFORM_MODE_SINGLE_PARM=( " --delay " " --message " " --email " " --joblist " " --resume " )
LONGFORM_MODE_MULTI_PARMS=(  "--redeploy " )

# Regular expressions
RUNSAS_REGEX_NUMBER='^[0-9]+$'
RUNSAS_REGEX_STRING='[a-zA-Z]'

# Reset mode flags
RUNSAS_INVOKED_IN_INTERACTIVE_MODE=-1
RUNSAS_INVOKED_IN_VERSION_MODE=-1
RUNSAS_INVOKED_IN_FROM_MODE=-1
RUNSAS_INVOKED_IN_UNTIL_MODE=-1
RUNSAS_INVOKED_IN_ONLY_MODE=-1
RUNSAS_INVOKED_IN_JOB_MODE=-1
RUNSAS_INVOKED_IN_FROM_UNTIL_MODE=-1
RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_MODE=-1
RUNSAS_INVOKED_IN_FROM_UNTIL_INTERACTIVE_SKIP_MODE=-1
RUNSAS_INVOKED_IN_SKIP_MODE=-1
RUNSAS_INVOKED_IN_NOEMAIL_MODE=-1
RUNSAS_INVOKED_IN_UPDATE_MODE=-1
RUNSAS_INVOKED_IN_HELP_MODE=-1
RUNSAS_INVOKED_IN_VERSION_MODE=-1
RUNSAS_INVOKED_IN_PARAMETERS_MODE=-1
RUNSAS_INVOKED_IN_LOG_MODE=-1
RUNSAS_INVOKED_IN_UPDATE_COMPATIBILITY_CHECK_MODE=-1
RUNSAS_INVOKED_IN_LIST_MODE=-1
RUNSAS_INVOKED_IN_BYFLOW_MODE=-1
RUNSAS_INVOKED_IN_RESUME_MODE=-1
RUNSAS_INVOKED_IN_DELAY_MODE=-1
RUNSAS_INVOKED_IN_BATCH_MODE=-1
RUNSAS_INVOKED_IN_NOCOLOR_MODE=-1
RUNSAS_INVOKED_IN_MESSAGE_MODE=-1
RUNSAS_INVOKED_IN_EMAIL_MODE=-1
RUNSAS_INVOKED_IN_JOBLIST_MODE=-1
RUNSAS_INVOKED_IN_REDEPLOY_MODE=-1
RUNSAS_INVOKED_IN_NON_RUNSAS_MODE=-1

# Timestamps
start_datetime_of_session_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
start_datetime_of_session=`date +%s`
job_stats_timestamp=`date '+%Y%m%d_%H%M%S'`
flow_stats_timestamp=`date '+%Y%m%d_%H%M%S'`

# Files
JOB_LIST_FILE=.job.list
EMAIL_BODY_MSG_FILE=$RUNSAS_EMAIL_DIRECTORY/.email_body_msg.html
EMAIL_TERMINAL_PRINT_FILE=$RUNSAS_EMAIL_DIRECTORY/.email_terminal_print.html
JOB_STATS_FILE=$RUNSAS_RUN_STATS_DIRECTORY/.job.stats
JOB_STATS_DELTA_FILE=$RUNSAS_RUN_STATS_DIRECTORY/.job_delta.stats.$job_stats_timestamp
FLOW_STATS_FILE=$RUNSAS_RUN_STATS_DIRECTORY/.flow.stats
FLOW_STATS_DELTA_FILE=$RUNSAS_RUN_STATS_DIRECTORY/.flow_delta.stats.$flow_stats_timestamp
RUNSAS_LAST_JOB_PID_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_last_job.pid
RUNSAS_FIRST_USER_INTRO_DONE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_intro.done
SASTRACE_CHECK_FILE=$RUNSAS_TMP_DIRECTORY/.sastrace.check
RUNSAS_SESSION_LOG_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_history.log
RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_global_user.parms
RUNSAS_SAS_SH_TRACE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas.trace
RUNSAS_TERM_CURSOR_POS_KEYVALUE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_global_batch_cursor.parms
RUNSAS_DEBUG_FILE=$RUNSAS_TMP_DIRECTORY/.runsas.debug
RUNSAS_TMP_DEBUG_FILE=$RUNSAS_TMP_DIRECTORY/.tmp.debug
RUNSAS_TMP_FLOWNAME_VALIDATION_FILE=$RUNSAS_TMP_DIRECTORY/.tmp_flowname.vld
RUNSAS_TMP_FLOWID_VALIDATION_FILE=$RUNSAS_TMP_DIRECTORY/.tmp_flowid.vld
RUNSAS_TMP_PRINT_FILE=$RUNSAS_TMP_DIRECTORY/.print.tmp
RUNSAS_DEPLOY_JOB_UTIL_LOG=$RUNSAS_TMP_DIRECTORY/runsas_depjob_util.log

# Set script mode flags 
set_script_mode_flags

# Set decorators
override_terminal_message_line_wrappers

# Bash color codes for the terminal
set_colors_codes

# Create required directories
create_a_new_directory -p --silent $RUNSAS_TMP_DIRECTORY $RUNSAS_RUN_STATS_DIRECTORY $RUNSAS_BATCH_STATE_ROOT_DIRECTORY

# Parameters passed to this script at the time of invocation (modes etc.), set the default to 0
script_mode="$1"
script_mode_value_1="$2"
script_mode_value_2="$3"
script_mode_value_3="$4"
script_mode_value_4="$5"
script_mode_value_5="$6"
script_mode_value_6="$7"
script_mode_value_7="$8"

# Check terminal/screen size and prompt the user to fix it
check_terminal_size

# Delete files (except in resume mode!)
if [[ $RUNSAS_INVOKED_IN_RESUME_MODE -le -1 ]]; then
    delete_a_file $RUNSAS_DEBUG_FILE silent
    delete_a_file $RUNSAS_TMP_DEBUG_FILE silent
    delete_a_file $RUNSAS_TMP_FLOWNAME_VALIDATION_FILE silent
    delete_a_file $RUNSAS_TMP_FLOWID_VALIDATION_FILE silent
    delete_a_file $RUNSAS_TERM_CURSOR_POS_KEYVALUE_FILE silent
fi

# Create files
create_a_file_if_not_exists $RUNSAS_DEBUG_FILE $RUNSAS_TMP_DEBUG_FILE

# Expand the ranges in the file
convert_ranges_in_job_dependencies $JOB_LIST_FILE

# Fix the job list file if the user has not decided to provide flow details
refactor_job_list_file $JOB_LIST_FILE

# Show run summary for the last run on user request
show_last_run_summary $script_mode

# Resets the session on user request (optionally --batchid for batch number reset)
reset $script_mode $script_mode_value_1

# Show parameters on user request
show_runsas_parameters $script_mode X

# Log (session variables)
print2log "================ *** runSAS launched on $start_datetime_of_session_timestamp by ${SUDO_USER:-$USER} *** ================\n"
print_unix_user_session_variables file $RUNSAS_SESSION_LOG_FILE

# Log
print2log $TERMINAL_MESSAGE_LINE_WRAPPERS
print2log "Host: $HOSTNAME"
print2log "PID: $$"
print2log "User: ${SUDO_USER:-$USER}"
print2log "Batch start: $start_datetime_of_session_timestamp"
print2log "Script Mode: $script_mode"
print2log "Script Mode Value 1: $script_mode_value_1"
print2log "Script Mode Value 2: $script_mode_value_2"
print2log "Script Mode Value 3: $script_mode_value_3"
print2log "Script Mode Value 4: $script_mode_value_4"
print2log "Script Mode Value 5: $script_mode_value_5"
print2log "Script Mode Value 6: $script_mode_value_6"
print2log "Script Mode Value 7: $script_mode_value_7"

# Print to debug file
print2debug start_datetime_of_session_timestamp "****** runSAS has been triggered " " ******" 
print2debug HOSTNAME
print2debug script_mode
print2debug script_mode_value_1
print2debug script_mode_value_2
print2debug script_mode_value_3
print2debug script_mode_value_4
print2debug script_mode_value_5
print2debug script_mode_value_6
print2debug script_mode_value_7

# Idiomatic parameter handling is done here
validate_parameters_passed_to_script $1

# Override the jobs list, if specified.
check_for_job_list_override 

# Show the list, if the user wants to quickly preview before launching the script (--list)
show_the_list $1

# Check if the user wants to update the script (--update)
check_for_in_place_upgrade_request_from_user $1 $2

# Help menu (if invoked via ./runSAS.sh --help)
print_the_help_menu $1

# Welcome banner
display_welcome_ascii_banner

# Check for dependencies
check_runsas_linux_program_dependencies ksh bc grep egrep awk sed sleep ps kill nice touch printf tput nproc

# Show intro message (only shown once)
show_first_launch_intro_message

# User messages (info)
display_post_banner_messages

# Housekeeping
create_a_file_if_not_exists $JOB_STATS_FILE
create_a_file_if_not_exists $FLOW_STATS_FILE
archive_all_job_logs $JOB_LIST_FILE archives

# Print session details on terminal
show_server_and_user_details $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3 $script_mode_value_4 $script_mode_value_5 $script_mode_value_6 $script_mode_value_7

# Check for CTRL+C and clear the session
trap clear_session_and_exit INT

# Show a warning if logged in user is root (typically "sas" must be the user for running a jobs)
check_if_logged_in_user_is_root

# Check if the user has specified a --nomail or --noemail option anywhere to override the email setting.
check_for_noemail_option

# Check if the user has specified --email option
check_for_email_option

# Check if the user has specified --message option
check_for_user_messages_option

# Redeploy jobs routine (--redeploy option)
redeploy_sas_jobs $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3

# Set the concurrency (job slots, default is all CPUs)
set_concurrency_parameters

# Check if the user wants to run a job in adhoc mode (i.e. the job is not specified in the list)
run_a_job_mode_check $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3 $script_mode_value_4 $script_mode_value_5 $script_mode_value_6 $script_mode_value_7

# Print job(s) list on terminal
print_file_content_with_index $JOB_LIST_FILE jobs --prompt --server

# Validate the script launch parameters
validate_script_modes

# Validate the jobs in list
validate_job_list $JOB_LIST_FILE

# Debug mode
print_to_terminal_debug_only "runSAS session variables"

# Archive stats and batches
archive_runsas_batch_history $BATCH_HISTORY_PERSISTENCE

# Get the consent from the user to trigger the batch 
press_enter_key_to_continue 0 1

# Creates a new batch id (by incrementing the old one)
generate_a_new_batchid 

# Check for rogue process(es), the last known pid is checked here
check_if_there_are_any_rogue_runsas_processes

# Hide the cursor
hide_cursor

# Reset the prompt variable
run_job_with_prompt=N

# Check if user has specified a delayed execution
process_delayed_execution 

# Send a launch email
runsas_triggered_email $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3 $script_mode_value_4 $script_mode_value_5 $script_mode_value_6 $script_mode_value_7

# Split the file for flows
split_job_list_file_by_flowid $JOB_LIST_FILE

# Show more info in batch mode
add_more_info_to_log_in_batch_mode

# Clear the screen to reclaim the screen space!
batch_mode_pre_process

# Core (this is where it all comes together)
for flow_file_name in `ls $RUNSAS_SPLIT_FLOWS_DIRECTORY/*.* | sort -V`; do
    # Disable keyboard inputs
    disable_keyboard_inputs
    disable_enter_key

    # Get flow name & id
    flow_file_flow_name=`basename $flow_file_name .flow`
    flow_file_flow_id=`echo $flow_file_flow_name | cut -d'-' -f 1`

    # Capture flow runtimes
    start_datetime_of_flow_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
    start_datetime_of_flow=`date +%s`

    # Get some stats on the flow and see if the terminal needs to be cleared
    get_keyval flow_${flow_file_flow_id}_job_count "" "" current_flow_job_count
    
    # Clear the screen if there isn't any space
    get_remaining_lines_on_terminal
    # publish_to_messagebar "DEBUG: flow_file_flow_id=$flow_file_flow_id [$flow_file_flow_name] | lines remaining=$runsas_remaining_lines_in_screen | job count=$current_flow_job_count"
    print2debug flow_file_flow_id "Checking terminal lines count for flow: [" " -- $flow_file_flow_name] > runsas_remaining_lines_in_screen=$runsas_remaining_lines_in_screen current_flow_job_count=$current_flow_job_count" ""
    if [[ $current_flow_job_count -ge $((runsas_remaining_lines_in_screen-$RUNSAS_SCREEN_LINES_OVERFLOW_BUFFER)) ]] && [[ $RUNSAS_INVOKED_IN_BATCH_MODE -le -1 ]]; then
        print2debug "*** Terminal screen cleared for flow_file_flow_id=$flow_file_flow_id [$flow_file_flow_name] ***"
        clear
    fi

    # Ensure the flow can run within the current terminal row x col (add a buffer just in case!)
    check_terminal_size $((current_flow_job_count+7))
        
    # Disable keyboards
    disable_keyboard_inputs
    disable_enter_key

    # Check if interactive mode has been invoked in "--byflow" mode
    if [[ $RUNSAS_INVOKED_IN_INTERACTIVE_MODE -gt -1 ]] && [[ $RUNSAS_INVOKED_IN_BYFLOW_MODE -gt -1 ]] && [[ $flow_file_flow_id -gt 1 ]]; then
        if [[ "$escape_interactive_mode" != "1" ]]; then
            enable_enter_key keyboard
            publish_to_messagebar "${blink}${red_bg}${black}Press ENTER key to continue or type E to escape the interactive mode${end}" Y run_in_interactive_mode_check_user_input
            if [[ "$run_in_interactive_mode_check_user_input" == "E" ]] || [[ "$run_in_interactive_mode_check_user_input" == "e" ]]; then
                escape_interactive_mode=1
            fi
            publish_to_messagebar "" 
        fi
    fi

    # Get flow stats
    get_flow_hist_runtime_stats $flow_file_flow_name
    if [[ ! "$hist_flow_runtime" = "" ]] && [[ $hist_flow_runtime -gt 0 ]]; then
        flow_stats_message="(takes ~$hist_flow_runtime secs)"
    else
        flow_stats_message=""
    fi

    # Flow message
    get_keyval total_flows_in_current_batch
    if [[ $flow_file_flow_id -eq 1 && $total_flows_in_current_batch -eq 1 ]]; then
        printf "${white}   \n${white}"
        printf "${white}${SINGLE_PARENT_DECORATOR}${green}$flow_file_flow_name [$current_flow_job_count]: ${grey}$flow_stats_message${white}\n"
    elif [[ $flow_file_flow_id -eq 1 ]]; then
        printf "${white}   \n${white}"
        printf "${white}${PARENT_DECORATOR}${green}$flow_file_flow_name [$current_flow_job_count]: ${grey}$flow_stats_message${white}\n"
    elif [[ $flow_file_flow_id -ge $total_flows_in_current_batch ]]; then
        printf "${white}${NO_BRANCH_DECORATOR}\n${white}"
        printf "${white}${NO_BRANCH_DECORATOR}\n${white}"
        printf "${white}${CHILD_DECORATOR}${green}$flow_file_flow_name [$current_flow_job_count]: ${grey}$flow_stats_message${white}\n"
    else
        printf "${white}${NO_BRANCH_DECORATOR}\n${white}"
        printf "${white}${NO_BRANCH_DECORATOR}\n${white}"
        printf "${white}${BRANCH_DECORATOR}${green}$flow_file_flow_name [$current_flow_job_count]: ${grey}$flow_stats_message${white}\n" 
    fi 

    # Override the jobs counter command (used in many places...)
    TOTAL_NO_OF_JOBS_COUNTER_CMD=`cat $flow_file_name | wc -l`
    
    # Iterator variables (used for stall checks)
    runsas_flow_loop_iterator=1
    runsas_job_loop_iterator=1

    # Run until the batch is complete, trigger one flow at a time
    while [ $RUNSAS_BATCH_COMPLETE_FLAG = 0 ]; do
        # Launch a single flow at a time
        while IFS='|' read -r flowid flow jobid job jobdep logicop jobrc runflag opt subopt sappdir bservdir bsh blogdir bjobdir; do
            # Core!
            runSAS $flowid $flow $jobid ${job##/*/} $jobdep $logicop $jobrc $runflag $opt $subopt $sappdir $bservdir $bsh $blogdir $bjobdir
            
            # Check if the batch is in a stalled state
            check_if_batch_has_stalled $flow_file_name
            
            # Increment the flow interator
            let runsas_job_loop_iterator+=1
        done < $flow_file_name
        
        # Check if the batch is in a stalled state
        check_if_batch_has_stalled $flow_file_name
        
        # Increment the flow interator
        let runsas_flow_loop_iterator+=1;
    done

    # Post-process "reset" before each outer (flow-wise) loop
    runsas_jobs_run_array=()
    RUNSAS_BATCH_COMPLETE_FLAG=0

    # Capture flow runtimes
    end_datetime_of_flow_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
    end_datetime_of_flow=`date +%s`
    # printf "${NO_BRANCH_DECORATOR}\n${green}${NO_BRANCH_DECORATOR}${CHILD_DECORATOR}The flow took $((end_datetime_of_flow-start_datetime_of_flow)) seconds to complete.\n${white}"

    # Store the flow stats
    store_flow_runtime_stats $flow_file_flow_name $((end_datetime_of_flow-start_datetime_of_flow)) 0 $start_datetime_of_job_timestamp $end_datetime_of_job_timestamp
done

# Capture session runtimes
end_datetime_of_session_timestamp=`date '+%d-%m-%Y-%H:%M:%S'`
end_datetime_of_session=`date +%s`

# Print a final message on terminal
printf "\n\n${green}The batch completed on $end_datetime_of_session_timestamp and took a total of $((end_datetime_of_session-start_datetime_of_session)) seconds to complete.${white}"

# Log
print2log $TERMINAL_MESSAGE_LINE_WRAPPERS
print2log "Batch end: $end_datetime_of_session_timestamp"
print2log "Total batch runtime: $((end_datetime_of_session-start_datetime_of_session)) seconds"

# Print to debug file
print2debug end_datetime_of_session_timestamp "**************** " " took $((end_datetime_of_session-start_datetime_of_session)) seconds ****************" 

# Send a success email
runsas_success_email

# Clear the run history 
if [[ "$ENABLE_RUNSAS_RUN_HISTORY" != "Y" ]]; then 
    delete_a_file $JOB_STATS_DELTA_FILE silent
    delete_a_file $FLOW_STATS_DELTA_FILE silent
fi

# Save debug logs for future reference
copy_files_to_a_directory "$RUNSAS_DEBUG_FILE" "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid"
copy_files_to_a_directory "$RUNSAS_TMP_DEBUG_FILE" "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid"
copy_files_to_a_directory "$RUNSAS_SESSION_LOG_FILE" "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid" 

# Tidy up!
delete_a_file "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid/*.err" silent
delete_a_file "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid/*.stepserr" silent
delete_a_file "$RUNSAS_BATCH_STATE_ROOT_DIRECTORY/$global_batchid/*.errjob" silent

# END: Clear the session, reset the terminal
clear_session_and_exit
