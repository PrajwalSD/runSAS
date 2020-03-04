#!/bin/bash
#
######################################################################################################################
#                                                                                                                    #
#     Program: runSAS.sh                                                                                             #
#                                                                                                                    #
#        Desc: SAS job/flow scheduler command line tool                                                              #
#                                                                                                                    #
#     Version: 31.1                                                                                                  #
#                                                                                                                    #
#        Date: 26/02/2020                                                                                            #
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
#              For more details, see https://github.com/PrajwalSD/runSAS/blob/master/README.md or --help menu        #
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
#      Ideally, setting just the first four parameters should work but amend the rest if needed as per the environment.
#      Strictly enclose the parameter value within the double-quotes (everything is case-sensitive)
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
# 2/4: Provide a list of SAS Data Integration Studio deployed job(s) or list of base SAS progam(s)
#      Do not include ".sas" in the name of the deployed job.
#      Tips: Add "--prompt" after the job name to prompt for a user confirmation to run the job
#            Add "--skip" after the job name to skip a job run in every batch run
#            Add "--server" after the job name to override default SAS app server parameters, e.g. SASAppX (see --help menu for more details on this)
#
cat << EOF > .job.list
<flow-id>,<flow-name>,<job-id>,<job-name>,<dependency>,<condition>,<return-code> 
<flow-id>,<flow-name>,<job-id>,<job-name>,<dependency>,<condition>,<return-code>
<flow-id>,<flow-name>,<job-id>,<job-name>,<dependency>,<condition>,<return-code>
EOF
#
# 3/4: Script behaviors, defaults should work just fine but amend as per your needs. 
#
ENABLE_DEBUG_MODE=N                                                     # Default is N                    ---> Enables the debug mode, specifiy Y/N
ENABLE_RUNTIME_COMPARE=N                                                # Default is N                    ---> Compares job run times between batches, specify Y/N
RUNTIME_COMPARE_FACTOR=50                                               # Default is 50                   ---> This is the factor used by job run times checker, specify a positive number
JOB_ERROR_DISPLAY_COUNT=1                                               # Default is 1                    ---> This will restrict the error log display to the x no. of error(s) in the log.
JOB_ERROR_DISPLAY_STEPS=N                                               # Default is N                    ---> This will show more details when a job fails, it can be a page long output.
JOB_ERROR_DISPLAY_LINES_AROUND_MODE=A                                   # Default is A                    ---> These are egrep arguements, A=after error, B=before error.
JOB_ERROR_DISPLAY_LINES_AROUND_COUNT=1                                  # Default is 1                    ---> This will allow you to increase or decrease how much is shown from the log.
KILL_PROCESS_ON_USER_ABORT=Y                                            # Default is Y                    ---> The rogue processes are automatically killed by the script on user abort.
PROGRAM_TYPE_EXTENSION=sas                                              # Default is sas                  ---> Do not change this. 
ERROR_CHECK_SEARCH_STRING="^ERROR"                                      # Default is "^ERROR"             ---> This is what is grepped in the log
STEP_CHECK_SEARCH_STRING="Step:"                                        # Default is "Step:"              ---> This is searched for the step in the log
SASTRACE_SEARCH_STRING="^options sastrace"                              # Default is "^options sastrace"  ---> This is used for searching the sastrace option in SAS log
ENABLE_RUNSAS_RUN_HISTORY=Y                                             # Default is Y                    ---> Enables runSAS script history, specify Y/N
ABORT_ON_ERROR=N                                                        # Default is N                    ---> Set to Y to abort as soon as runSAS sees an ERROR in the log file (i.e don't wait for the job to complete)
ENABLE_SASTRACE_IN_JOB_CHECK=Y                                          # Default is Y                    ---> Set to N to turn off the warnings on sastrace
ENABLE_RUNSAS_DEPENDENCY_CHECK=Y                                        # Default is Y                    ---> Set to N to turn off the script dependency checks 
#
# 4/4: Email alerts, set the first parameter to N to turn off this feature.
#      Uses "sendmail" program to send email (installs it if not found in the server)
#      If you don't receive emails from the server, add <logged-in-user>@<server-full-name> (e.g.: sas@sasserver.demo.com) to your email client whitelist.
#
ENABLE_EMAIL_ALERTS=N                                  	                # Default is N                    ---> "Y" to enable all 4 alert types (YYYY is the extended format, <trigger-alert><job-alert><error-alert><completion-alert>)
EMAIL_ALERT_TO_ADDRESS=""                                               # Default is ""                   ---> Provide email addresses separated by a semi-colon
EMAIL_ALERT_USER_NAME="runSAS"                                          # Default is "runSAS"             ---> This is used as FROM address for the email alerts                          
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
	# Current version
	RUNSAS_CURRENT_VERSION=31.1
    # Compatible version for the in-place upgrade feature (set by the developer, do not change this)                                 
	RUNSAS_IN_PLACE_UPDATE_COMPATIBLE_VERSION=12.2
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
        printf "\n       runSAS.sh [script-mode] [optional-script-mode-value-1] [optional-script-mode-value-2]"
        printf "${underline}"
        printf "\n\nDESCRIPTION\n"
        printf "${end}${blue}"
        printf "\n       There are various [script-mode] in which you can launch runSAS, see below.\n"
        printf "\n      -i                          runSAS will halt after running each job, waiting for an ENTER key to continue"
        printf "\n      -j    <job-name>            runSAS will run a specified job even if it is not in the job list (adhoc mode, run any job using runSAS)"
        printf "\n      -u    <job-name>            runSAS will run everything (and including) upto the specified job"
        printf "\n      -f    <job-name>            runSAS will run from (and including) a specified job."
        printf "\n      -o    <job-name>            runSAS will run a specified job from the job list."
        printf "\n      -fu   <job-name> <job-name> runSAS will run from one job upto the other job."
        printf "\n      -fui  <job-name> <job-name> runSAS will run from one job upto the other job, but in an interactive mode (runs the rest in a non-interactive mode)"
        printf "\n      -fuis <job-name> <job-name> runSAS will run from one job upto the other job, but in an interactive mode (skips the rest)"
        printf "\n     --update                     runSAS will update itself to the latest version from Github, if you want to force an update on version mismatch use --force"
        printf "\n     --delay <time-in-seconds>    runSAS will launch after a specified time delay in seconds"
        printf "\n     --jobs or --show             runSAS will show a list of job(s) provided by the user in the script (quick preview)"
        printf "\n     --log or --last              runSAS will show the last script run details"
        printf "\n     --reset                      runSAS will remove temporary files"
        printf "\n     --parameters or --parms      runSAS will show the user & script parameters"
        printf "\n     --redeploy <jobs-file>       runSAS will redeploy the jobs specified in the <jobs-file>, job filters (name or index) can be added after <jobs-file> or you can specify filters after the launch too."
        printf "\n     --joblist  <jobs-file>       runSAS will override the embedded jobs with the jobs specified in <jobs-file>. Suffix this option with filters (e.g.: ./runSAS.sh -fu 1 2 --joblist jobs.txt)"
        printf "\n     --help                       Display this help and exit"
        printf "\n"
        printf "\n       Tip #1: You can use <job-index> instead of a <job-name> e.g.: ./runSAS.sh -fu 1 3 instead of ./runSAS.sh -fu jobA jobC"
        printf "\n       Tip #2: You can add --prompt option against job(s) when you provide a list, this will halt the script during runtime for the user confirmation."
		printf "\n       Tip #3: You can add --skip option against job(s) when you provide a list, this will skip the job in every run."
        printf "\n       Tip #4: You can add --noemail option during the launch to override the email setting during runtime (useful for one time runs etc.)"        
		printf "\n       Tip #5: You can add --server option followed by server parameters (syntax: <jobname> --server <sas-server-name><sasapp-dir><batch-server-dir><sas-sh><logs-dir><deployed-jobs-dir>)" 
        printf "\n       Tip #6: You can add --email <email-address> option during the launch to override the email address setting during runtime (must be added at the end of all arguments)"        
        printf "\n       Tip #7: You can add --message option during the launch for an additional user message for the batch (useful for tagging the batch runs)"        
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
  --parameters) ;;
    --update-c) ;;
        --jobs) ;;
         --job) ;;
        --show) ;;
        --list) ;;
     --joblist) ;;
     --message) ;;
       --email) ;;
         --log) ;;
        --last) ;;
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
     if [[ ! -f $RUNSAS_FIRST_USER_INTRO_DONE_FILE ]]; then
        printf "${blue}Welcome, this is a first launch of runSAS script post installation (or update), so let's quickly check few things. \n\n${end}" 
        printf "${blue}runSAS essentially requires two things and they are set inside the script (set them if it is not done already): \n\n${end}"
        printf "${blue}    (a) SAS environment parameters and, ${end}\n"
        printf "${blue}    (b) List of SAS deployed jobs ${end}\n\n" 
        printf "${blue}There are many features like email alerts, job reports etc. and various launch modes like run from a specific job, run in interactive mode etc. \n\n${end}"
        printf "${blue}To know more about various options available in runSAS, see the help menu (i.e. ./runSAS.sh --help) or better yet go to ${underline}$RUNSAS_GITHUB_PAGE${end}${blue} for detailed documentation. \n${end}"
        press_enter_key_to_continue 1

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
#   In: --jobs or --job or --show or --list
#  Out: <NA>
#------
function show_the_list(){
    if [[ ${#@} -ne 0 ]] && ([[ "${@#"--jobs"}" = "" ]] || [[ "${@#"--list"}" = "" ]] || [[ "${@#"--job"}" = "" ]] || [[ "${@#"--show"}" = "" ]]); then
        print_file_content_with_index .job.list jobs --prompt --skip --server
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
    light_blue=$'\e[94m'
    magenta=$'\e[1;35m'
    cyan=$'\e[1;36m'
    grey=$'\e[38;5;243m'
    white=$'\e[0m'
    light_yellow=$'\e[38;5;101m' 
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
    # Checkmark (green)
    green_check_mark="\033[0;32m\xE2\x9C\x94\033[0m"
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
# Name: check_dependencies()
# Desc: Checks if the dependencies have been installed and can install the missing dependencies automatically via "yum" 
#   In: program-name or package-name (multiple inputs could be specified)
#  Out: <NA>
#------
function check_dependencies(){
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
# Name: runsas_script_auto_update()
# Desc: Auto updates the runSAS script from Github
#   In: optional-github-branch
#  Out: <NA>
#------
function runsas_script_auto_update(){
# Optional branch name
runsas_download_git_branch="${1:-$RUNSAS_GITHUB_SOURCE_CODE_BRANCH}"

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

# Make sure the file is deleted before the download
delete_a_file .runSAS.sh.downloaded 0

# Switch the branches if the user has asked to (default is usually "master")
RUNSAS_GITHUB_SOURCE_CODE_BRANCH=$runsas_download_git_branch
RUNSAS_GITHUB_SOURCE_CODE_URL=$RUNSAS_GITHUB_PAGE/raw/$RUNSAS_GITHUB_SOURCE_CODE_BRANCH/runSAS.sh

# Download the latest file from Github
printf "${green}\nNOTE: Downloading the latest version from Github (branch: $RUNSAS_GITHUB_SOURCE_CODE_BRANCH) using wget utility...${white}\n\n"
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
            delete_a_file $RUNSAS_TMP_DIRECTORY/.runsas_intro.done 0
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
            printf "\n${red}*** ERROR: ${3:-File} ${black}${red_bg}$file${white}${red} was not found in the server *** ${white}"
			if [[ $noexit -eq 0 ]]; then
				clear_session_and_exit
			fi
        fi
    done
}
#------
# Name: delete_a_file()
# Desc: Removes/deletes file(s) 
#   In: file-name (wild-card "*" supported, multiple files not supported), post-delete-message (optional), delete-options(optional), post-delete-message-color(optional)
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
            if [[ ! "$delete_message" == "0" ]]; then 
                printf "${!delete_message_color}${delete_message}${white}"
            fi
        fi
    else
        if [[ ! "$delete_message" == "0" ]]; then 
            printf "${grey}...(file does not exist, no action taken)${white}"
        fi
    fi        
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
        printfile=.printfile.tmp
        cp $1 $printfile
    else
        printfile=$1
    fi

    # Get total line count
    total_lines_in_the_file=`cat $printfile | wc -l`

    # Default message 
    printf "\n${white}There are $total_lines_in_the_file $2 in the list:${white}\n"

    # Wrappers
    printf "${white}---${white}\n"

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
    sed -i "/$1/d" $2
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
        printf "${red_bg}${black}Press ENTER key to continue OR type E to escape this interactive mode${white} "
        enable_enter_key keyboard
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
            if [[ "$script_mode_value_1" == "$runsas_local_job" ]]; then 
				if [[ $INDEX_MODE_FIRST_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_FIRST_JOB_NUMBER ]]; then
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
            if [[ "$script_mode_value_1" == "$runsas_local_job" ]]; then
				if [[ $INDEX_MODE_FIRST_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_FIRST_JOB_NUMBER ]]; then
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
            if [[ "$script_mode_value_1" == "$runsas_local_job" ]]; then
				if [[ $INDEX_MODE_FIRST_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_FIRST_JOB_NUMBER ]]; then
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
    rjmode_sas_app_root_directory="${5:-$SAS_APP_ROOT_DIRECTORY}"
    rjmode_sas_batch_server_root_directory="${6:-$SAS_BATCH_SERVER_ROOT_DIRECTORY}"
    rjmode_sas_sh="${7:-$SAS_DEFAULT_SH}"
    rjmode_sas_logs_root_directory="${8:-$SAS_LOGS_ROOT_DIRECTORY}"
    rjmode_sas_deployed_jobs_root_directory="${9:-$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY}"
    
    if [[ "$rjmode_script_mode" == "-j" ]]; then
        if [[ "$rjmode_sas_job" == "" ]]; then
            printf "${red}\n*** ERROR: You launched the script in $rjmode_script_mode(run-a-job) mode, a job name is also required (without the .sas extension) after $script_mode option ***${white}"
            clear_session_and_exit
        else
            check_if_the_file_exists $rjmode_sas_deployed_jobs_root_directory/$rjmode_sas_job.$PROGRAM_TYPE_EXTENSION
			printf "\n"
			TOTAL_NO_OF_JOBS_COUNTER_CMD=1
			runSAS ${rjmode_sas_job##/*/} "$rjmode_sas_opt" "$rjmode_sas_subopt" "$rjmode_sas_app_root_directory" "$rjmode_sas_batch_server_root_directory" "$rjmode_sas_sh" "$rjmode_sas_logs_root_directory" "$rjmode_sas_deployed_jobs_root_directory"
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
            if [[ "$script_mode_value_1" == "$runsas_local_job" ]]; then
				if [[ $INDEX_MODE_FIRST_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too 
					if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_FIRST_JOB_NUMBER ]]; then
						run_from_to_job_mode=1
					fi
				else
					run_from_to_job_mode=1
				fi
            else
				if [[ "$script_mode_value_2" == "$runsas_local_job" ]]; then 
					if [[ $INDEX_MODE_SECOND_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
						if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_SECOND_JOB_NUMBER ]]; then
							run_from_to_job_mode=2
						fi
					else
						run_from_to_job_mode=2
					fi
				else
					if  [[ $run_from_to_job_mode -eq 1 ]]; then
						run_from_to_job_mode=1
						if [[ "$script_mode_value_2" == "$script_mode_value_1" ]]; then
							run_from_to_job_mode=0
						fi
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
            if [[ "$script_mode_value_1" == "$runsas_local_job" ]]; then
				if [[ $INDEX_MODE_FIRST_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
					if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_FIRST_JOB_NUMBER ]]; then
						run_from_to_job_interactive_mode=1
					fi
				else
					run_from_to_job_interactive_mode=1
				fi
            else
                if [[ "$script_mode_value_2" == "$runsas_local_job" ]]; then
					if [[ $INDEX_MODE_SECOND_JOB_NUMBER -gt 0 ]]; then # In index mode (i.e. when a job number is specified), match the index too
						if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_SECOND_JOB_NUMBER ]]; then
							run_from_to_job_interactive_mode=2
						fi
					else
						run_from_to_job_interactive_mode=2
					fi
                else
                    if  [[ $run_from_to_job_interactive_mode -eq 1 ]]; then
                        run_from_to_job_interactive_mode=1
						if [[ "$script_mode_value_2" == "$script_mode_value_1" ]]; then
							run_from_to_job_interactive_mode=0
						fi
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
            if [[ "$script_mode_value_1" == "$runsas_local_job" ]]; then
				if [[ $INDEX_MODE_FIRST_JOB_NUMBER -gt 0 ]]; then
					if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_FIRST_JOB_NUMBER ]]; then
						run_from_to_job_interactive_skip_mode=1
					fi
				else
					run_from_to_job_interactive_skip_mode=1
				fi
            else
				# In index mode, match the index too.
                if [[ "$script_mode_value_2" == "$runsas_local_job" ]]; then
					if [[ $INDEX_MODE_SECOND_JOB_NUMBER -gt 0 ]]; then
						if [[ $JOB_COUNTER_FOR_DISPLAY -eq $INDEX_MODE_SECOND_JOB_NUMBER ]]; then
							run_from_to_job_interactive_skip_mode=2
						fi
					else
						run_from_to_job_interactive_skip_mode=2
					fi
                else
                    if  [[ $run_from_to_job_interactive_skip_mode -eq 1 ]]; then
                        run_from_to_job_interactive_skip_mode=1
						if [[ "$script_mode_value_2" == "$script_mode_value_1" ]]; then
							run_from_to_job_interactive_skip_mode=0
						fi
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
# Name: check_for_job_list_override
# Desc: If user has specified a file of jobs for the run, override the embedded job list.
#   In: --joblist
#  Out: <NA>
#------
function check_for_job_list_override(){
	for (( p=0; p<RUNSAS_PARAMETERS_COUNT; p++ )); do
		if [[ "${RUNSAS_PARAMETERS_ARRAY[p]}" == "--joblist" ]]; then
			if [[ "${RUNSAS_PARAMETERS_ARRAY[p+1]}" == "" ]]; then
				# Check for the jobs file (mandatory for this mode)
				printf "\n${red}*** ERROR: A file that contains a list of deployed jobs is required as a second arguement for this option (e.g.: ./runSAS.sh --joblist jobs.txt) ***${white}"
				clear_session_and_exit
			else
                # Check if the user has specified it before other arguments 
				if [[ "${RUNSAS_PARAMETERS_ARRAY[p+2]}" == "" ]]; then
                    check_if_the_file_exists ${RUNSAS_PARAMETERS_ARRAY[p+1]}
                    remove_empty_lines_from_file ${RUNSAS_PARAMETERS_ARRAY[p+1]}
                    add_a_newline_char_to_eof ${RUNSAS_PARAMETERS_ARRAY[p+1]}
                    # Replace the file that's used by runSAS
                    cp -f ${RUNSAS_PARAMETERS_ARRAY[p+1]} .job.list
				else 
                    # Check for the jobs file (mandatory for this mode)
                    printf "\n${red}*** ERROR: --joblist option must always be specified after all arguements (e.g. ./runSAS.sh -fu jobA jobB --joblist job.txt) ***${white}"
                    clear_session_and_exit
                fi
			fi
		fi
	done
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
#   In: PID 
#  Out: <NA>
#------
function running_processes_housekeeping(){
    if [[ ! -z ${1} ]]; then
        if [[ ! -z `ps -p $1 -o comm=` ]]; then
            if [[ "$KILL_PROCESS_ON_USER_ABORT" ==  "Y" ]]; then
                disable_enter_key
                printf "${white}Process (PID) details for the currently running job:\n${white}"
                # Show & kill!
                show_pid_details $1
                show_child_pid_details $1
                kill_a_pid $1               
                enable_enter_key
            else
                echo $1 > $RUNSAS_LAST_JOB_PID_FILE
                printf "${red}WARNING: The last job submitted by runSAS with PID $1 is still running/active in the background, auto-kill is off, terminate it manually using ${green}pkill -TERM -P $1${white}${red} command.\n\n${white}"
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

    # Get the last known PID launched by runSAS
    runsas_last_job_pid="$(<$RUNSAS_LAST_JOB_PID_FILE)"
	
    # Check if the PID is still active
	if [[ ! "$runsas_last_job_pid" == "" ]]; then
		if ! [[ -z `ps -p ${runsas_last_job_pid} -o comm=` ]]; then
			printf "${yellow}WARNING: There is a job (PID $runsas_last_job_pid) that is still active/running from the last runSAS session, see the details below.\n\n${white}"
			show_pid_details $runsas_last_job_pid
			printf "${red}\nDo you want to kill this process and continue? (Y/N): ${white}"
			disable_enter_key
			read -n1 ignore_process_warning
			if [[ "$ignore_process_warning" == "Y" ]] || [[ "$ignore_process_warning" == "y" ]]; then
				kill_a_pid $runsas_last_job_pid
			else
				printf "\n\n"
			fi
			enable_enter_key
		fi
	fi
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
        printf "\n${white}ENABLE_RUNTIME_COMPARE: ${green}$ENABLE_RUNTIME_COMPARE ${white}"                                           
        printf "\n${white}RUNTIME_COMPARE_FACTOR: ${green}$RUNTIME_COMPARE_FACTOR ${white}"                                               
        printf "\n${white}JOB_ERROR_DISPLAY_COUNT: ${green}$JOB_ERROR_DISPLAY_COUNT ${white}"                                               
        printf "\n${white}JOB_ERROR_DISPLAY_STEPS: $JOB_ERROR_DISPLAY_STEPS ${white}"                                             
        printf "\n${white}JOB_ERROR_DISPLAY_LINES_AROUND_MODE: ${green}$JOB_ERROR_DISPLAY_LINES_AROUND_MODE ${white}"                                   
        printf "\n${white}JOB_ERROR_DISPLAY_LINES_AROUND_COUNT: ${green}$JOB_ERROR_DISPLAY_LINES_AROUND_COUNT ${white}"                                 
        printf "\n${white}KILL_PROCESS_ON_USER_ABORT: ${green}$KILL_PROCESS_ON_USER_ABORT ${white}"                                          
        printf "\n${white}PROGRAM_TYPE_EXTENSION: ${green}$PROGRAM_TYPE_EXTENSION ${white}"                                            
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
		if [[ "$1" == "X" ]]; then
			clear_session_and_exit   
		fi
    fi 
}                                   
#------
# Name: reset()
# Desc: Clears the temporary files
#   In: script-mode
#  Out: <NA>
#------
function reset(){
    if [[ "$1" == "--reset" ]]; then
        # Clear the temporary files
        printf "${red}\nClear temporary files? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_tmp_files
        if [[ "$clear_tmp_files" == "Y" ]] || [[ "$clear_tmp_files" == "y" ]]; then    
            delete_a_file $RUNSAS_TMP_DIRECTORY/.tmp_s.log 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.tmp.log 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.email_body_msg.html 0 
            delete_a_file $RUNSAS_TMP_DIRECTORY/.sastrace.check 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.errored_job.log 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.email_terminal_print.html 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.runsas_last_job.pid 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.runsas_intro.done 0
            printf "${green}...(DONE)${white}"
        fi
        # Clear the session history files
        printf "${red}\nClear runSAS session history? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_session_files
        if [[ "$clear_session_files" == "Y" ]] || [[ "$clear_session_files" == "y" ]]; then    
            delete_a_file $RUNSAS_TMP_DIRECTORY/.runsas_session*.log
        fi
        # Clear the historical run stats
        printf "${red}\nClear historical runtime stats? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_his_files
        if [[ "$clear_his_files" == "Y" ]] || [[ "$clear_his_files" == "y" ]]; then    
            delete_a_file $RUNSAS_TMP_DIRECTORY/.job_delta*.* 0
            delete_a_file $RUNSAS_TMP_DIRECTORY/.job.stats 0
            printf "${green}...(DONE)${white}"
        fi
		# Clear redeploy parameters file
        printf "${red}\nClear job redeployment logs? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_depjob_files
        if [[ "$clear_depjob_files" == "Y" ]] || [[ "$clear_depjob_files" == "y" ]]; then    
			delete_a_file $RUNSAS_TMP_DIRECTORY/runsas_depjob_util*.log
        fi
        # Clear global user parameters file
        printf "${red}\nClear stored global user parameters? (Y/N): ${white}"
        disable_enter_key
        read -n1 clear_global_user_parms
        if [[ "$clear_global_user_parms" == "Y" ]] || [[ "$clear_global_user_parms" == "y" ]]; then    
            delete_a_file $RUNSAS_TMP_DIRECTORY/.runsas_global_user.parms
        fi

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
            cat $runsas_local_error_w_steps_tmp_log_file | awk '{print $0}' >> $EMAIL_BODY_MSG_FILE
        else
            cat $runsas_local_error_tmp_log_file | awk '{print $0}' >> $EMAIL_BODY_MSG_FILE
        fi
        # Send email
        echo "$TERMINAL_MESSAGE_LINE_WRAPPERS" >> $EMAIL_BODY_MSG_FILE
        echo "Job: $(<$runsas_local_errored_job_file)" >> $EMAIL_BODY_MSG_FILE
        echo "Log: $runsas_local_logs_root_directory/$current_job_log" >> $EMAIL_BODY_MSG_FILE
        add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
        send_an_email -v "" "Job $1 (of $2) has failed!" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE $runsas_local_logs_root_directory $current_job_log 
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
# Name: store_job_runtime_stats()
# Desc: Capture job runtime stats, single version of history is kept per job
#   In: job-name, total-time-taken-by-job, change-in-runtime, logname, start-timestamp, end-timestamp
#  Out: <NA>
#------
function store_job_runtime_stats(){
    # Remove the previous entry
    sed -i "/$1/d" $JOB_STATS_FILE
    # Add new entry 
    echo "$1 $2 ${3}% $4 $5 $6" >> $JOB_STATS_FILE # Add a new entry 
	echo "$1 $2 ${3}% $4 $5 $6" >> $JOB_STATS_DELTA_FILE # Add a new entry to a delta file
}
#------
# Name: get_job_hist_runtime_stats()
# Desc: Check job runtime for the last batch run
#   In: job-name
#  Out: <NA>
#------
function get_job_hist_runtime_stats(){
    hist_job_runtime=`awk -v pat="$1" -F" " '$0~pat { print $2 }' $JOB_STATS_FILE | head -1`
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
		printf "${white} (takes ~$hist_job_runtime secs)${white}"
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
    st_empty_var="                                     "

	get_job_hist_runtime_stats $st_job
	if [[ "$hist_job_runtime" != "" ]]; then
		# Record timestamp
		time_remaining_stats_curr_timestamp=`date +%s`
		
		# Calculate the time remaining in secs.
		if [ ! -z "$time_remaining_stats_last_shown_timestamp" ]; then
            let diff_in_seconds=$time_remaining_stats_curr_timestamp-$time_remaining_stats_last_shown_timestamp
            if [[ $diff_in_seconds -lt 0 ]]; then
                diff_in_seconds=0
            fi
			let time_remaining_in_secs=$time_remaining_in_secs-$diff_in_seconds
		else
			let time_remaining_in_secs=$hist_job_runtime
            let diff_in_seconds=0
		fi
		
		# Show the stats
        if [[ $time_remaining_in_secs -ge 0 ]]; then
            time_stats_msg=" ~$time_remaining_in_secs secs remaining...$st_empty_var" 
        else
		    time_stats_msg=" additional $((time_remaining_in_secs*-1)) secs elapsed......$st_empty_var" 
		fi
		
		# Record the message last shown timestamp
		time_remaining_stats_last_shown_timestamp=$time_remaining_stats_curr_timestamp
	else
		# Record timestamp
		time_since_run_msg_curr_timestamp=`date +%s`
		
		# Calculate the time remaining in secs.
		if [ ! -z "$time_since_run_msg_last_shown_timestamp" ]; then
            let diff_in_seconds=$time_since_run_msg_curr_timestamp-$time_since_run_msg_last_shown_timestamp
            if [[ $diff_in_seconds -lt 0 ]]; then
                diff_in_seconds=0
            fi
			let time_since_run_in_secs=$time_since_run_in_secs+$diff_in_seconds
		else
			let time_since_run_in_secs=0
            let diff_in_seconds=0
		fi
		
		# Show the stats
        if [[ $time_since_run_in_secs -ge 0 ]]; then
            time_stats_msg=" ~$time_since_run_in_secs secs elapsed...$st_empty_var" 
		fi
		
		# Record the message last shown timestamp
		time_since_run_msg_last_shown_timestamp=$time_since_run_msg_curr_timestamp
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
# Name: print_2_runsas_session_log()
# Desc: Keeps a track of what's done in the session for debugging etc.
#   In: msg
#  Out: <NA>
#------
function print_2_runsas_session_log(){
    create_a_file_if_not_exists $RUNSAS_SESSION_LOG_FILE
    printf "\n$1" >> $RUNSAS_SESSION_LOG_FILE
}
#------
# Name: write_current_job_details_on_screen()
# Desc: Print details about the currently running job on the terminal
#   In: job-name, row-position (optional)
#  Out: <NA>
#------
function write_current_job_details_on_screen(){
    printf "${white}Job ${white}"
    printf "%02d" $JOB_COUNTER_FOR_DISPLAY
    printf "${white} of $TOTAL_NO_OF_JOBS_COUNTER_CMD${white}: ${darkgrey_bg}$1${white} ${white}"
}
#------
# Name: write_skipped_job_details_on_screen()
# Desc: Show the skipped job details
#   In: job-name, row-position (optional)
#  Out: <NA>
#------
function write_skipped_job_details_on_screen(){
    printf "${grey}Job ${grey}"
    printf "%02d" $JOB_COUNTER_FOR_DISPLAY
    printf "${grey} of $TOTAL_NO_OF_JOBS_COUNTER_CMD: $1${white}"
	display_message_fillers_on_terminal $RUNSAS_DISPLAY_FILLER_COL_END_POS $RUNSAS_FILLER_CHARACTER 0 N 2 grey
	printf "${grey}(SKIPPED)\n${white}"
}
#------
# Name: debug()
# Desc: Debug code
#   In: <NA>
#  Out: <NA>
#------
function debug(){
    # Input parameters
    debug_var="${1:-Test}"
    debug_var_value=${!1}
    # Print
    printf "${red_bg}DEBUG: $debug_var $debug_var_value ${white}"
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
    job_name_from_the_list=`sed -n "${getname_id}p" $getname_file | awk -v getname_column=$getname_column -F "$getname_delimeter" '{print $getname_column}'`
    if [[ -z $job_name_from_the_list ]]; then
        printf "${red}*** ERROR: Job index is out-of-range, no job found at $1 in the list above. Please review the specified index and launch the script again ***${white}"
        clear_session_and_exit
    else
        if [[ "$getname_silent" == "" ]]; then
            printf "${white}Job ${darkgrey_bg}${job_name_from_the_list}${white} has been selected from the job list at $1.${white}\n"
        fi
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
    enable_enter_key keyboard
    setterm -cursor on
    if [[ $interactive_mode == 1 ]]; then
        reset
    fi
    running_processes_housekeeping $job_pid
    printf "${green}*** runSAS is exiting now ***${white}\n\n"
    exit 1
}
#------
# Name: get_current_terminal_cursor_position()
# Desc: Get the current cursor position, reference: https://stackoverflow.com/questions/2575037/how-to-get-the-cursor-position-in-bash
#   In: <NA>
#  Out: cursor_row_pos, cursor_col_pos
#------
function get_current_terminal_cursor_position() {
    local pos
    printf "${red}"
    IFS='[;' read -p < /dev/tty $'\e[6n' -d R -a pos -rs || echo "*** ERROR: The cursor position routine failed with error: $? ; ${pos[*]} ***"
    cursor_row_pos=${pos[1]}
    cursor_col_pos=${pos[2]}
    printf "${white}"
}
#------
# Name: scroll_up_row()
# Desc: Scroll up lines on terminal using ANSI/VT100 cursor control sequences
#   In: no-of-lines
#  Out: <NA>
#------
function scroll_up_row(){
    for (( i=1; i<=$1; i++ )); do
        echo -ne '\033M' # scrolls up one line
    done
}
#------
# Name: move_terminal_cursor()
# Desc: Moves the cursor to a specific point on terminal using ANSI/VT100 cursor control sequences
#   In: row-position, col-position
#  Out: <NA>
#------
function move_terminal_cursor(){
    # Input parameters
	target_row_pos=$1
	target_col_pos=$2
	
    # Get current terminal cursor positions 
	get_current_terminal_cursor_position
    move_terminal_cursor_current_row=$cursor_row_pos
    move_terminal_cursor_current_col=$cursor_col_pos
	
    # Calculate the offset from current to the target (row and colum)
	let row_offset=$move_terminal_cursor_current_row-$target_row_pos
	let col_offset=$move_terminal_cursor_current_col-2

	# Go to the specified row
	for (( i=1; i<=$row_offset; i++ )); do
        echo -ne '\033M'
    done
	
	# Go to the specified column
	echo -ne "\033[50D\033[${col_offset}C" 
}
#------
# Name: display_message_fillers_on_terminal()
# Desc: Fetch cursor position and populate the fillers
#   In: filler-character-upto-column, filler-character, optional-backspace-counts
#  Out: <NA>
#------
function display_message_fillers_on_terminal(){
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
}
#------
# Name: disable_keyboard_inputs()
# Desc: This function will disable user inputs via keyboard
#   In: <NA>
#  Out: <NA>
#------
function disable_keyboard_inputs(){
    # Disable user inputs via keyboard
    stty -echo < /dev/tty
}
#------
# Name: enable_keyboard_inputs()
# Desc: This function will enable user inputs via keyboard
#   In: <NA>
#  Out: <NA>
#------
function enable_keyboard_inputs(){
    # Enable user inputs via keyboard
    stty echo < /dev/tty
}
#------
# Name: disable_enter_key()
# Desc: This function will disable carriage return (ENTER key)
#   In: <NA>
#  Out: <NA>
#------
function disable_enter_key(){
    # Disable carriage return (ENTER key) during the script run
    stty igncr < /dev/tty
    # Disable keyboard inputs too if user has asked for it
    if [[ ! "$1" == "" ]]; then
        disable_keyboard_inputs
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
    stty -igncr < /dev/tty
    # Enable keyboard inputs too if user has asked for it
    if [[ ! "$1" == "" ]]; then
        enable_keyboard_inputs
    fi
}
#------
# Name: press_enter_key_to_continue()
# Desc: This function will pause the script and wait for the ENTER key to be pressed
#   In: before-newline-count, after-newline-count, color (default is green)
#  Out: <NA>
#------
function press_enter_key_to_continue(){
	# Set the color
	press_enter_key_to_continue_color=${3:-"green"}
	
    # Enable carriage return (ENTER key) during the script run
    enable_enter_key
	
	# Newlines (before)
    if [[ "$1" != "" ]] && [[ "$1" != "0" ]]; then
        for (( i=1; i<=$1; i++ )); do
            printf "\n"
        done
    fi
	
	# Show message
    printf "${!press_enter_key_to_continue_color}Press ENTER key to continue...${white}"
    read enter_to_continue_user_input
	
	# Newlines (after)
    if [[ "$2" != "" ]] && [[ "$2" != "0" ]]; then
        for (( i=1; i<=$2; i++ )); do
            printf "\n"
        done
    fi
	
    # Disable carriage return (ENTER key) during the script run
    enable_enter_key
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
# Name: validate_job_list()
# Desc: This function checks if the specified job's .sas file in server directory
#   In: job-list-filename
#  Out: <NA>
#------
function validate_job_list(){
    # For those enter key hitters :)
    disable_enter_key keyboard
	
	# Set the wait message parameters
	vjmode_show_wait_message="Checking few things in the server and getting things ready, please wait...."  
	
	# Show message
	printf "\n${red}$vjmode_show_wait_message${white}"
	
	# Reset the job counter for the validation routine
	job_counter=0
	
	if [[ "$script_mode" != "-j" ]]; then  # Skip the job list validation in -j(run-a-job) mode
		while IFS='|' read -r fid fname jid j jdep op jrc o so bservdir bsh blogdir bjobdir; do

            # Counter for the job
			let job_counter+=1

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

			# Check if the file exists
			if [[ "$o" != "--skip" ]] && [ ! -f "$vjmode_sas_deployed_jobs_root_directory/$j.$PROGRAM_TYPE_EXTENSION" ]; then
				printf "\n${red}*** ERROR: Job #$job_counter ${black}${red_bg}$j${white}${red} has not been deployed or mispelled because $j.$PROGRAM_TYPE_EXTENSION was not found in $vjmode_sas_deployed_jobs_root_directory *** ${white}"
                clear_session_and_exit
			fi

			# Check if there are any sastrace options enabled in the program file
			scan_sas_programs_for_debug_options $vjmode_sas_deployed_jobs_root_directory/$j.$PROGRAM_TYPE_EXTENSION
		done < $1
	fi
	
	# Remove the message, reset the cursor
	echo -ne "\r"
	printf "%${#vjmode_show_wait_message}s" " "
	echo -ne "\r"
	
	# Enable carriage return
    enable_enter_key keyboard
}
#------
# Name: preserve_batch_state()
# Desc: Preserve the state of the current batch run in a file for rerun/resume of batches on failure/abort
#   In: key, value
#  Out: <NA>
#------
function preserve_batch_state(){
    # Input parameters
    batchstate_key=$1
    batchstate_value=$2

    # Other parameters
    batchstate_root_directory=$RUNSAS_BATCH_STATE_PRESERVATION_FILE_ROOT_DIRECTORY

    # Create directory for runSAS batch state preservation (this is not inside runSAS temp directory for obvious reasons)
    create_a_new_directory "$batchstate_root_directory"

    # Determine the last batch run identifier for filename
    retrieve_a_keyval batchid 

    # Create a batch state file (if it's the first time)
    if [ ! -z "$batchid" ]; then
        batchstate_batchid=1 # first run, it seems
    else
        # Create the files etc., if it's a first call to this function (subsequent calls must just add/update the values)
        if [ ! -z "$batchstate_batchid" ]; then
            # Increment
            let batchstate_batchid=$batchid+1
            # Ensure the new batchid doesn't collide with batch state file (i.e. key-value store says one and the files tell a different story!)
            while [ ! -e $batchstate_root_directory/$batchstate_batchid.batch]; do
                batchstate_batchid=$batchid+1
                batchstate_file=$batchstate_root_directory/$batchstate_batchid.batch
            done
            # Finally, create file (if there's an error the script will abort anyway)
            create_a_file_if_not_exists "$batchstate_file"
        else
            # Looks like the function is called again in the session, just assign the filename
            batchstate_file=$batchstate_root_directory/$batchstate_batchid.batch
            # If the expected file doesn't exist, abort the whole process and notify the user
            if [ -e $batchstate_file ]; then
                printf "${red}*** ERROR: Batch state preservation file $batchstate_file does not exist or got deleted (errored on subsequent calls), share the error and trace info with developer to get more help ***${white}\n"
                printf "${red}*** TRACE: BATCHID=$BATCHID BATCHSTATE_BATCHID=$BATCHSTATE_BATCHID BATCHSTATE_KEY=$BATCHSTATE_KEY BATCHSTATE_VALUE=$BATCHSTATE_VALUE ***\n${white}"
                clear_session_and_exit
            fi
        fi
    fi

    # Update the global key-value store on successful creation of file
    store_a_keyval batchid $batchstate_batchid

	# Refresh the key-value pair (delete + create)
    sed -i "/$batchstate_key/d" $batchstate_file
    echo "$batchstate_key=$batchstate_val" >> $batchstate_file 
}
#------
# Name: inject_batch_state()
# Desc: Set the batch state from a previous run i.e. add the batch state preservation file to the current run
#   In: batchid
#  Out: <NA>
#------
function inject_batch_state(){
    # Input parameters
    inj_batchstate_batchid=$1

    # Other parameters
    inj_batchstate_root_directory=$RUNSAS_BATCH_STATE_PRESERVATION_FILE_ROOT_DIRECTORY

    # Looks like the function is called again in the session, just assign the filename
    inj_batchstate_file=$inj_batchstate_root_directory/$inj_batchstate_batchid.batch

    # Inject the batch state
    if [ ! -e $inj_batchstate_file ]; then
        . $inj_batchstate_file
        printf "${green}NOTE: Previous batch run session state has been restored successfully (Batch ID: $inj_batchstate_batchid) ${white}\n"
    fi
}
#------
# Name: store_a_keyval()
# Desc: Stores a key-value pair in a file
#   In: key, value, file
#  Out: <NA>
#------
function store_a_keyval(){
    # Parameters
    str_key=$1
    str_val=$2
    str_file=$3
    # Set a temp file by the name of key if the file is not specified
    if [[ "$str_file" == "" ]]; then
        str_file=$RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE
		create_a_file_if_not_exists $RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE
    fi
	# If the file exists remove the previous entry
	if [ -f "$str_file" ]; then
        sed -i "/$str_key/d" $str_file
    fi 
	# Add the new entry (or update the entry)
    echo "$str_key: $str_val" >> $str_file # Add a new entry 
}
#------
# Name: retrieve_a_keyval()
# Desc: Check job runtime for the last batch run
#   In: key, file
#  Out: <NA>
#------
function retrieve_a_keyval(){
    # Parameters
    ret_key=$1
    ret_file=$2

    # Set a temp file by the name of key if the file is not specified
    if [[ "$ret_file" == "" ]]; then
        ret_file=$RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE
		create_a_file_if_not_exists $RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE
    fi
	
    # Set the value found in the file to the key
    if [ -f "$ret_file" ]; then
        eval $ret_key=`awk -v pat="$ret_key" -F": " '$0~pat { print $2 }' $ret_file`
    fi   
}
#------
# Name: get_updated_value_for_a_key_from_user()
# Desc: Ask user for a new value for a key (if user has specified an answer show it as prepopulated and finally store the updated value for future use)
#   In: key, message, message-color, value-color, file (optional)
#  Out: <NA>
#------
function get_updated_value_for_a_key_from_user(){
    # Parameters
    keyval_key=$1
    keyval_message=$2
    keyval_message_color="${3:-green}"
    keyval_val_color="${4:-grey}"
    keyval_file=$4
	
    # First retrieve the value for the key from the global parameters file, if it is available.
    retrieve_a_keyval $keyval_key
	
    # Prompt 
    read -p "${!keyval_message_color}${keyval_message}${!keyval_val_color}" -i "${!keyval_key}" -e $keyval_key	
	
    # Store the value (updated value)
    store_a_keyval $keyval_key ${!keyval_key}
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
				if [[ "$depjob_from_job" == "--list" ]] || [[ "$depjob_from_job" == "--show" ]] || [[ "$depjob_from_job" == "--jobs" ]]; then
					print_file_content_with_index $depjob_job_file jobs
					clear_session_and_exit
				fi
				
				# Set the flag 
				depjob_in_filter_mode=1
				
				# Get the job name if it is the index
				if [[ ${#depjob_from_job} -lt $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
					printf "\n"
					get_name_from_list $depjob_from_job $depjob_job_file
					depjob_from_job_index=$depjob_from_job
					depjob_from_job=${job_name_from_the_list}
				fi
				if [[ ${#depjob_to_job} -lt $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
					get_name_from_list $depjob_to_job $depjob_job_file
					depjob_to_job_index=$depjob_to_job
					depjob_to_job=${job_name_from_the_list}
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
						printf "\n${green}No filters provided, getting ready to redeploy all jobs...\n${white}"
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
					if [[ ${#depjob_from_job} -lt $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
						printf "\n"
						get_name_from_list $depjob_from_job $depjob_job_file
						depjob_from_job_index=$depjob_from_job
						depjob_from_job=${job_name_from_the_list}
					fi
					if [[ ${#depjob_to_job} -lt $JOB_NUMBER_DEFAULT_LENGTH_LIMIT ]]; then
						get_name_from_list $depjob_to_job $depjob_job_file
						depjob_to_job_index=$depjob_to_job
						depjob_to_job=${job_name_from_the_list}
					fi
				fi
			fi
			
			# Create an empty file
			create_a_file_if_not_exists $depjob_job_file
			
			# Newlines
			printf "\n"
						
			# Retrieve SAS Metadata details from last user inputs, if you don't find it ask the user
			if [[ "$depjob_in_filter_mode" -eq "0" ]]; then	
				get_updated_value_for_a_key_from_user read_depjob_clear_files "Do you want clear all existing deployed SAS files from the server (Y/N): " red
			else 
				read_depjob_clear_files=N
			fi
            get_updated_value_for_a_key_from_user read_depjob_user "SAS Metadata username (e.g.: sas or sasadm@saspw): " 
			get_updated_value_for_a_key_from_user read_depjob_password "SAS Metadata password: " 
            get_updated_value_for_a_key_from_user read_depjob_appservername "SAS Application server name (e.g.: $SAS_APP_SERVER_NAME): " 
            get_updated_value_for_a_key_from_user read_depjob_serverusername "SAS Application/Compute server username (e.g.: ${SUDO_USER:-$USER}): " 
            get_updated_value_for_a_key_from_user read_depjob_serverpassword "SAS Application/Compute server password: " 
            get_updated_value_for_a_key_from_user read_depjob_level "SAS Level (e.g.: Specify 1 for Lev1, 2 for Lev2 and 3 for Lev3 and so on...): " 

            # Clear deployment directory for a fresh start (based on user input)
            if [[ "$read_depjob_clear_files" == "Y" ]]; then
                printf "${white}\nPlease wait, clearing all the existing deployed SAS files from the server directory $SAS_DEPLOYED_JOBS_ROOT_DIRECTORY...\n\n${white}"
                delete_a_file $SAS_DEPLOYED_JOBS_ROOT_DIRECTORY/*.sas
                printf "${green}\n\n${white}"
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
			depjob_log=$RUNSAS_TMP_DIRECTORY/runsas_depjob_util.log

			# Check if the utility exists? 
			if [ ! -f "$depjobs_scripts_root_directory/DeployJobs" ]; then
				printf "${red}*** ERROR: ${red_bg}${black}DeployJobs${white}${red} utility is not found on the server, cannot proceed with the $1 for now (try the manual option via SAS DI) *** ${white}"
				clear_session_and_exit
			fi

			# Wait for the user to confirm
			press_enter_key_to_continue 1 0 red

            # Counter
            depjob_to_jobtal_count=`cat $depjob_job_file | wc -l`
            depjob_job_curr_count=1
            depjob_job_deployed_count=0
            
            # Newlines
            retrieve_a_keyval depjob_total_runtime

            # Message to user
			printf "\n${green}Redeployment process started at $start_datetime_of_session_timestamp, it may take a while, so grab a cup of coffee or tea.${white}\n\n"

            # Add to audit log
            print_2_runsas_session_log $TERMINAL_MESSAGE_LINE_WRAPPERS
            print_2_runsas_session_log "Redeployment start timestamp: $start_datetime_of_session_timestamp"
            print_2_runsas_session_log "DepJobs SAS 9.x utility directory: $depjobs_scripts_root_directory"
			print_2_runsas_session_log "Metadata server: $depjob_host"
			print_2_runsas_session_log "Port: $depjob_port"
			print_2_runsas_session_log "Metadata user: $read_depjob_user"
			print_2_runsas_session_log "Metadata password (obfuscated): *******"
			print_2_runsas_session_log "Deployment type: $depjob_deploytype"
			print_2_runsas_session_log "Deployment directory: $depjob_sourcedir"
			print_2_runsas_session_log "Job directory (Metadata): $depjob_metarepository"
			print_2_runsas_session_log "Application server context: $depjob_appservername"
			print_2_runsas_session_log "Application server: $depjob_servermachine"
			print_2_runsas_session_log "Application server port: $depjob_serverport"
			print_2_runsas_session_log "Application server user: $depjob_serverusername"
			print_2_runsas_session_log "Application server password (obfuscated): *******"
			print_2_runsas_session_log "Batch server: $depjob_batchserver" 
			print_2_runsas_session_log "DepJobs SAS 9.x utility log: $depjob_log"
            print_2_runsas_session_log "Total number of jobs: $depjob_to_jobtal_count"
            print_2_runsas_session_log "Deleted existing SAS job files?: $read_depjob_clear_files"

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
					printf "${grey}Job ${grey}"
					printf "%02d" $depjob_job_curr_count
                    printf "${grey} of $depjob_to_jobtal_count: $job${white}"
                    display_message_fillers_on_terminal $((RUNSAS_DISPLAY_FILLER_COL_END_POS+35)) $RUNSAS_FILLER_CHARACTER 0 N 2 grey
                    printf "${grey}(SKIPPED)\n${white}"
                    let depjob_job_curr_count+=1
					continue
				fi	
                
				# Show the current state of the deployment
				printf "${green}---${white}\n"
                printf "${green}["
                printf "%02d" $depjob_job_curr_count
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
                
                # A way to check if the job was deployed at all?
                check_if_the_file_exists "$deployed_job_sas_file" noexit "Job was not deployed correctly. "

                # Fix the names (add underscores etc.)
				mv "$deployed_job_sas_file" "${deployed_job_sas_file// /_}"

                # Add it to audit log
                print_2_runsas_session_log "Reploying job $depjob_job_curr_count of $depjob_to_jobtal_count: $job"

                # Increment the job counter
                let depjob_job_curr_count+=1

                # Increment the deployed job counter
                let depjob_job_deployed_count+=1

			done < $depjob_job_file

            # Capture session runtimes
            end_datetime_of_session_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
            end_datetime_of_session=`date +%s`

			# Clear session
            depjob_total_runtime=$((end_datetime_of_session-start_datetime_of_session))
            printf "${green}\nThe redeployment of $depjob_job_deployed_count jobs completed at $end_datetime_of_session_timestamp and took a total of $depjob_total_runtime seconds to complete.${white}"

            # Store runtime for future use
            store_a_keyval depjob_total_runtime $depjob_total_runtime

            # Send an email
			if [[ "$ENABLE_EMAIL_ALERTS" == "Y" ]] || [[ "${ENABLE_EMAIL_ALERTS:0:1}" == "Y" ]]; then
				echo "The redeployment of $depjob_job_deployed_count job(s) is complete, took a total of $depjob_total_runtime seconds to complete. " > $EMAIL_BODY_MSG_FILE
				add_html_color_tags_for_keywords $EMAIL_BODY_MSG_FILE
				send_an_email -v "" "$depjob_job_deployed_count job(s) redeployed" $EMAIL_ALERT_TO_ADDRESS $EMAIL_BODY_MSG_FILE
            fi

            # End
            print_2_runsas_session_log "Redeployment end timestamp: $end_datetime_of_session_timestamp"
            print_2_runsas_session_log "Total time taken (in seconds): $depjob_total_runtime"

            # Enable enter key
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
                    get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[first_value_p]} .job.list 1
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
                    get_name_from_list ${RUNSAS_PARAMETERS_ARRAY[second_value_p]} .job.list 1
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
		while IFS=' ' read -r j o so bservdir bsh blogdir bjobdir; do
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
    printf "\n${white}The script was launched (in "${1:-'a default'}" mode) with PID $$ on $HOSTNAME at `date '+%Y-%m-%d %H:%M:%S'` by ${white}"
    printf '%s' ${white}"${SUDO_USER:-$USER}${white}"
    printf "${white} user\n${white}"
}
#------
# Name: display_progressbar_with_offset()
# Desc: Calculates the progress bar parameters (https://en.wikipedia.org/wiki/Block_Elements#Character_table & https://www.rapidtables.com/code/text/unicode-characters.html, alternative: Ã¢â€“Ë†)
#   In: steps-completed, total-steps, offset (-1 or 0), optional-message, active-color
#  Out: <NA>
#------
function display_progressbar_with_offset(){
    # Defaults
    progressbar_width=20
    progressbar_sleep_interval_in_secs=0.5
    progressbar_color_unicode_char=" "
    progressbar_grey_unicode_char=" "
    progressbar_default_active_color=$DEFAULT_PROGRESS_BAR_COLOR

    # Defaults for percentages shown on the terminal
    progress_bar_pct_symbol_length=1
    progress_bar_100_pct_length=3

    # Passed parameters
    progressbar_steps_completed=$1
	progressbar_total_steps=$2
    progressbar_offset=$3
	progressbar_post_message=$4
    progressbar_color=${5:-$progressbar_default_active_color}

    # Calculate the scale
    let progressbar_scale=100/$progressbar_width

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

    # Reset the terminal, backspacing operation defined by the length of the progress bar and the percentage string length
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

    # Show the percentage on terminal, right justified
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
		for (( i=1; i<=$progress_bar_pct_completed; i++ )); do
			printf "$progressbar_color_unicode_char"
		done		
        #printf "%0.s$progressbar_color_unicode_char" $(seq 1 $progress_bar_pct_completed)
    fi

    # Show the remaining "grey" block
    if [[ $progress_bar_pct_remaining -ne 0 ]]; then
        printf "${darkgrey_bg}"
		for (( i=1; i<=$progress_bar_pct_remaining; i++ )); do
			printf "$progressbar_color_unicode_char"
		done		
        #printf "%0.s$progressbar_grey_unicode_char" $(seq 1 $progress_bar_pct_remaining)
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
        # Remove the percentages from terminal
        for (( i=1; i<=$progress_bar_pct_symbol_length+$progress_bar_100_pct_length; i++ )); do
            printf "\b"
        done
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
    runsas_local_flowid="$1"
    runsas_local_flow="$2"    
    runsas_local_jobid="$3"
    runsas_local_job="$4"
    runsas_local_jobdep="$5"
    runsas_local_logicop="$6"
    runsas_local_max_jobrc="$7"
    runsas_local_opt="$8"
    runsas_local_subopt="${9}"
    runsas_local_app_root_directory="${10:-$SAS_APP_ROOT_DIRECTORY}"
    runsas_local_batch_server_root_directory="${11:-$SAS_BATCH_SERVER_ROOT_DIRECTORY}"
    runsas_local_sh="${12:-$SAS_DEFAULT_SH}"
    runsas_local_logs_root_directory="${13:-$SAS_LOGS_ROOT_DIRECTORY}"
    runsas_local_deployed_jobs_root_directory="${14:-$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY}"

    # Job dependencies are specifed using space as delimeter, convert it to an array
    runsas_local_jobdep_array=( $runsas_local_jobdep )
    runsas_local_jobdep_array_elem_count=${#runsas_local_jobdep_array[@]}

    # Unique flow-job key 
    runsas_local_flow_job_key=${runsas_local_flowid}_${runsas_local_jobid}
    
    # Set the return code to a dynamic variable (format: rc_<flow-id>_<job-id>)
    runsas_local_current_jobrc=rc_$runsas_local_flow_job_key

    # Remember the original terminal cursor position (this is used for repainting the progress bars etc)
    runsas_local_job_terminal_orig_row_pos=o_row_pos_$runsas_local_flow_job_key
    runsas_local_job_terminal_orig_col_pos=o_col_pos_$runsas_local_flow_job_key

    # Disable carriage return (ENTER key) to stop user from messing up the layout on terminal
    disable_enter_key keyboard

    # Reset the script level return codes
    script_rc=0

    # Increment the job counter for terminal display
    let JOB_COUNTER_FOR_DISPLAY+=1

    # Temporary "error" files
    runsas_local_error_tmp_log_file=$RUNSAS_TMP_DIRECTORY/${runsas_local_flowid}_${runsas_local_flowid}_${runsas_local_jobid}.err
    runsas_local_error_w_steps_tmp_log_file=$RUNSAS_TMP_DIRECTORY/${runsas_local_flowid}_${runsas_local_flowid}_${runsas_local_jobid}.stepserr
    runsas_local_errored_job_file=$RUNSAS_TMP_DIRECTORY/${runsas_local_flowid}_${runsas_local_flowid}_${runsas_local_jobid}.errjob
	
	# Reset
	time_stats_msg=""
	time_remaining_stats_last_shown_timestamp=""
	time_since_run_msg_last_shown_timestamp=""

    # Capture job runtime
	start_datetime_of_job_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
    start_datetime_of_job=`date +%s`

    # Set the start (i.e. pending) return code
    eval "$runsas_local_current_jobrc=$RC_JOB_PENDING"

    # If user has specified a different server context, switch it here
    if [[ "$runsas_local_opt" == "--server" ]]; then
        if [[ "$runsas_local_subopt" != "" ]]; then
            if [[ "$runsas_local_app_root_directory" == "" ]]; then
                runsas_local_app_root_directory=`echo "${runsas_local_app_root_directory/$SAS_APP_SERVER_NAME/$runsas_local_subopt}"`
            fi
            if [[ "$runsas_local_batch_server_root_directory" == "" ]]; then
                runsas_local_batch_server_root_directory=`echo "${runsas_local_batch_server_root_directory/$SAS_APP_SERVER_NAME/$runsas_local_subopt}"`
            fi
            if [[ "$runsas_local_logs_root_directory" == "" ]]; then
                runsas_local_logs_root_directory=`echo "${runsas_local_logs_root_directory/$SAS_APP_SERVER_NAME/$runsas_local_subopt}"`
            fi
            if [[ "$runsas_local_deployed_jobs_root_directory" == "" ]]; then
                runsas_local_deployed_jobs_root_directory=`echo "${runsas_local_deployed_jobs_root_directory/$SAS_APP_SERVER_NAME/$runsas_local_subopt}"`
            fi
        else
            printf "${yellow}WARNING: $runsas_local_opt was specified for $runsas_local_job job in the list without the server context name, defaulting to ${white}"
        fi
    fi

    # Log
    print_2_runsas_session_log $TERMINAL_MESSAGE_LINE_WRAPPERS
    print_2_runsas_session_log "Job No.: $JOB_COUNTER_FOR_DISPLAY"
    print_2_runsas_session_log "Job: $runsas_local_job"
    print_2_runsas_session_log "Opt: $runsas_local_opt"
    print_2_runsas_session_log "Sub-Opt: $runsas_local_subopt"
    print_2_runsas_session_log "App server: $runsas_local_app_root_directory"
    print_2_runsas_session_log "Batch server: $runsas_local_batch_server_root_directory"
    print_2_runsas_session_log "SAS shell: $runsas_local_sh"
    print_2_runsas_session_log "Logs: $runsas_local_logs_root_directory"
    print_2_runsas_session_log "Deployed Jobs: $runsas_local_deployed_jobs_root_directory"
    print_2_runsas_session_log "Start: $start_datetime_of_job_timestamp"

    # Retrieve cursor positions for the current job
    retrieve_a_keyval $runsas_local_job_terminal_orig_row_pos
    retrieve_a_keyval $runsas_local_job_terminal_orig_col_pos
    if [[ -z "${!runsas_local_job_terminal_orig_row_pos}" ]] || [[ -z "${!runsas_local_job_terminal_orig_col_pos}" ]]; then
        # Set the start (i.e. pending) return code
        get_current_terminal_cursor_position
        eval "$runsas_local_job_terminal_orig_row_pos=$cursor_row_pos"
        eval "$runsas_local_job_terminal_orig_col_pos=$cursor_col_pos"
        # Store for future use
        store_a_keyval $runsas_local_job_terminal_orig_row_pos ${!runsas_local_job_terminal_orig_row_pos}
        store_a_keyval $runsas_local_job_terminal_orig_col_pos ${!runsas_local_job_terminal_orig_col_pos}
    fi

    # Reset the cursor to the right positions (in every loop based on which job it is)
    move_terminal_cursor $runsas_local_job_terminal_orig_row_pos $runsas_local_job_terminal_orig_col_pos

    # Run all the jobs post specified job (including that specified job)
    run_from_a_job_mode_check
    if [[ "$run_from_mode" -ne "1" ]]; then
        write_skipped_job_details_on_screen $runsas_local_job
        continue
    fi

    # Run a single job
    run_a_single_job_mode_check
    if [[ "$run_a_job_mode" -ne "1" ]]; then
        write_skipped_job_details_on_screen $runsas_local_job
        continue
    fi

    # Run upto a job mode: The script will run everything (including) upto the specified job
    run_until_a_job_mode_check
    if [[ "$run_until_mode" -gt "1" ]]; then
        write_skipped_job_details_on_screen $runsas_local_job
        continue
    fi

    # Run from a job to another job (including the specified jobs)
    run_from_to_job_mode_check
    if [[ "$run_from_to_job_mode" -lt "1" ]]; then
        write_skipped_job_details_on_screen $runsas_local_job
        continue
    fi

    # Run from a job to another job in interactive (including the specified jobs)
    run_from_to_job_interactive_mode_check

    # Run from a job to another job (including the specified jobs)
    run_from_to_job_interactive_skip_mode_check
    if [[ "$run_from_to_job_interactive_skip_mode" -lt "1" ]]; then
        write_skipped_job_details_on_screen $runsas_local_job
        continue
    fi

    # Check if the prompt option is set by the user for the job
    if [[ "$runsas_local_opt" == "--skip" ]]; then
		write_skipped_job_details_on_screen $runsas_local_job
		continue
    fi

    # Display current job details on terminal, jobname is passed to the function
    write_current_job_details_on_screen $runsas_local_job
	
	# Check if the prompt option is set by the user for the job (over engineered!)
    if [[ "$runsas_local_opt" == "--prompt" ]]; then
		# Disable enter key
		disable_enter_key
		
		# Ask user
        run_or_skip_message="Do you want to run? (y/n): "		
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
			if [[ "$user_notified_job" != "$runsas_local_job" ]]; then 
				runsas_notify_email $runsas_local_job
				user_notified_job=$runsas_local_job
			fi
			run_or_skip_message="(notified) $run_or_skip_message_orig" 
			printf "${red}$run_or_skip_message${white}"
            read_until_user_provides_right_input 1
        done;
        
		# Act on the user request
        if [[ $run_job_with_prompt != Y ]] && [[ $run_job_with_prompt != y ]]; then
			# Remove the message, reset the cursor
			echo -ne "\r"
			printf "%175s" " "
			echo -ne "\r"
            write_skipped_job_details_on_screen $runsas_local_job
            continue
        fi
    fi

    # Check if the directory exists (specified by the user as configuration)
    check_if_the_dir_exists $runsas_local_app_root_directory $runsas_local_batch_server_root_directory $runsas_local_logs_root_directory $runsas_local_deployed_jobs_root_directory
    check_if_the_file_exists "$runsas_local_batch_server_root_directory/$runsas_local_sh" "$runsas_local_deployed_jobs_root_directory/$runsas_local_job.$PROGRAM_TYPE_EXTENSION"

    # Job launch function (standard template for all calls)
    function trigger_the_job(){
        nice -n 20 $runsas_local_batch_server_root_directory/$runsas_local_sh   -log $runsas_local_logs_root_directory/${runsas_local_job}_#Y.#m.#d_#H.#M.#s.log \
                                                                                -batch \
                                                                                -noterminal \
                                                                                -logparm "rollover=session" \
                                                                                -sysin $runsas_local_deployed_jobs_root_directory/$runsas_local_job.$PROGRAM_TYPE_EXTENSION & > $RUNSAS_SAS_SH_TRACE_FILE
    }
     
    # No dependency has been specified or specified as dependent on self
    if [[ "$runsas_local_jobdep" == "" ]] || [[ "$runsas_local_jobdep" == "$runsas_local_jobid" ]]; then
        # No dependency!
        # Each job is launched as a separate process (i.e each has a PID), the script monitors the log and waits for the process to complete.
        trigger_the_job
    else
        # Dependency has been specified, loop through each dependent to see if the current job is ready to run 
        total_jobrc=0
        
        # Dependency check loop
        for runsas_local_jobdep_i in $runsas_local_jobdep
        do
            # Calculate the return code allowed for all dependents (i.e. dependent job count x job rc specificed by the user)
            # NOTE: Return code for an incomplete job is -1
            runsas_local_jobrc_allowed_for_AND_op=`bc <<< "scale = 0; $runsas_local_jobdep_array_elem_count * $runsas_local_max_jobrc"`
            
            # Get the job names (indices are specified in the job dependency list) for return code retrieval (every job sets the return code after the run in to a variable named after the job itself)
            get_name_from_list $runsas_local_jobdep_i .job.list 4 $RUNSAS_JOBLIST_FILE_DEFAULT_DELIMETER "Y"  
            
            # Sum up the return codes (of all dependents) to evaluate the dependency graph
            let total_jobrc=$total_jobrc+${!runsas_local_current_jobrc}
        
            # Set the variables for "gate" success criteria (for OR & AND operators)
            if [[ ${!runsas_local_current_jobrc} -ge 0 ]] && [[ ${!runsas_local_current_jobrc} -le $runsas_local_max_jobrc ]]; then
                OR_check_passed=1
            fi
            if [[ $total_jobrc -ge 0 ]] && [[ $total_jobrc -le $runsas_local_jobrc_allowed_for_AND_op ]]; then 
                AND_check_passed=1
            fi
            
            # Finally, evaluate the dependency:
            # (1) AND: All jobs have completed successfully (or within the limits of specified return code by user) and this is the default if nothing has been specified
            # (2) OR: One of the job has completed
            if [[ $runsas_local_logicop == "OR" ]]; then
                if [[ $OR_check_passed -eq 1 ]]; then 
                    trigger_the_job    
                fi
            else   
                 if [[ $AND_check_passed -eq 1 ]] || [[ $total_jobrc -eq -1 ]]; then 
                    trigger_the_job
                fi             
            fi
        done 
    fi  

    # Count the no. of steps in the job
    total_no_of_steps_in_a_job=`grep -o 'Step:' $runsas_local_deployed_jobs_root_directory/$runsas_local_job.$PROGRAM_TYPE_EXTENSION | wc -l`

    # Get the PID details
    job_pid=$!
    pid_progress_counter=1

    # Paint the rest of the message on the terminal
    printf "${white}is running as PID $job_pid${white}"
	
	# Runtime (history)
	show_job_hist_runtime_stats $runsas_local_job
	
	# Get PID
    ps cax | grep -w $job_pid > /dev/null
    printf "${white} ${green}"

    # Sleep before the log is generated
    sleep 0.5

    # Get the current job log filename (absolute path), wait until the log is generated...
    while [[ ! "$current_job_log" =~ "log" ]]; do 
        sleep 0.25 
        current_job_log=`ls -tr $runsas_local_logs_root_directory/${runsas_local_job}*.log | tail -1`
        current_job_log=${current_job_log##/*/}
    done

    # Set the triggered return code
    eval "$runsas_local_current_jobrc=$RC_JOB_TRIGGERED"

    # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
    no_of_steps_completed_in_log=`grep -o 'Step:' $runsas_local_logs_root_directory/$current_job_log | wc -l`

    # Show time remaining statistics
    show_time_remaining_stats $runsas_local_job

    # Show progress bar
    display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job -1 "$time_stats_msg" $progressbar_color
    
    # Get runtime stats of the job
    get_job_hist_runtime_stats $runsas_local_job
    hist_job_runtime_for_current_job="${hist_job_runtime:-0}"
    
    # Check if there are any errors in the logs (as it updates, in real-time)
    $RUNSAS_LOG_SEARCH_FUNCTION -m${JOB_ERROR_DISPLAY_COUNT} -E --color "$ERROR_CHECK_SEARCH_STRING" -$JOB_ERROR_DISPLAY_LINES_AROUND_MODE$JOB_ERROR_DISPLAY_LINES_AROUND_COUNT $runsas_local_logs_root_directory/$current_job_log > $runsas_local_error_tmp_log_file
        
    # Again, suppress unwanted lines in the log (typical SAS errors!)
    remove_a_line_from_file ^$ "$runsas_local_error_tmp_log_file"
    remove_a_line_from_file "ERROR: Errors printed on page" "$runsas_local_error_tmp_log_file"

    # Return code check
    if [ -s $runsas_local_error_tmp_log_file ]; then
        script_rc=9
    fi

    # Check return code, abort if there's an error in the job run
    if [ $script_rc -gt 4 ]; then
        progressbar_color=red_bg
        # Refresh the progress bar
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job -1 "" $progressbar_color
        # Optionally, abort the job run on seeing an error
        if [[ "$ABORT_ON_ERROR" == "Y" ]]; then
            if [[ ! -z `ps -p $job_pid -o comm=` ]]; then
                kill_a_pid $job_pid
                wait $job_pid 2>/dev/null
                break
            fi
        fi
    else
        # Reset it to the default
        progressbar_color=$DEFAULT_PROGRESS_BAR_COLOR
    fi
    
    # Get the PID again for the next iteration
    ps cax | grep -w $job_pid > /dev/null

    # Check if there are any errors in the logs
    let job_error_display_count_for_egrep=JOB_ERROR_DISPLAY_COUNT+1
    egrep -m${job_error_display_count_for_egrep} -E --color "* $STEP_CHECK_SEARCH_STRING|$ERROR_CHECK_SEARCH_STRING" -$JOB_ERROR_DISPLAY_LINES_AROUND_MODE$JOB_ERROR_DISPLAY_LINES_AROUND_COUNT $runsas_local_logs_root_directory/$current_job_log > $runsas_local_error_w_steps_tmp_log_file

    # Check the job status and it's return code (check if it is still running too)
    if ! [[ -z `ps -p ${job_pid} -o comm=` ]]; then
        job_rc=$RC_JOB_TRIGGERED
    else
        job_rc=$?
    fi

    # Set the return code of job to a variable named after itself for easy reference and lookup
    eval "$runsas_local_current_jobrc=$job_rc";

    # Keep a track of jobs that has been triggered and has completed it's run (any state DONE/FAIL)
    if [[ ${!runsas_local_current_jobrc} -ge 0 ]]; then
        # Add to the runSAS array that keeps a track of how many jobs have completed the run
        if [[ ${#runsas_jobs_run_array[@]} -eq 0 ]]; then # Empty array!
           runsas_jobs_run_array+=( "$runsas_local_flow_job_key" ) 
        else 
            # Add new jobs only!
            for (( r=0; r<${#runsas_jobs_run_array[@]}; r++ )); do
                if [[ "${runsas_jobs_run_array[r]}" == "$runsas_local_flow_job_key" ]]; then
                    runsas_current_job_has_run_already=1
                else
                    runsas_jobs_run_array+=( "$runsas_local_flow_job_key" )
                fi
            done
        fi
    fi

    # If runSAS has executed all jobs already, set the flag
    if [[ ${#runsas_jobs_run_array[@]} -ge $TOTAL_NO_OF_JOBS_COUNTER_CMD ]]; then
        RUNSAS_BATCH_COMPLETE_FLAG=1
    fi

    # Double-check to ensure the job had no errors after the job completion
    if [ $script_rc -le 4 ] || [ ${!runsas_local_current_jobrc} -le 4 ]; then
        # Check if there are any errors in the logs (as it updates, in real-time)
		$RUNSAS_LOG_SEARCH_FUNCTION -m${JOB_ERROR_DISPLAY_COUNT} -E --color "$ERROR_CHECK_SEARCH_STRING" -$JOB_ERROR_DISPLAY_LINES_AROUND_MODE$JOB_ERROR_DISPLAY_LINES_AROUND_COUNT $runsas_local_logs_root_directory/$current_job_log > $runsas_local_error_tmp_log_file

        # Again, suppress unwanted lines in the log (typical SAS errors!)
		remove_a_line_from_file ^$ "$runsas_local_error_tmp_log_file"
        remove_a_line_from_file "ERROR: Errors printed on page" "$runsas_local_error_tmp_log_file"

        # Return code check
        if [ -s $runsas_local_error_tmp_log_file ]; then
            script_rc=9
        fi
    fi

    # Just check if the log looks complete to detect process kill by OS when resource utilization is above the allowed limit.
    # We are lookig for a two lines at the end of the file
    # if [ $script_rc -le 4 ] && [ ${!runsas_local_current_jobrc} -le 4 ]; then
    #     # Check if there are any errors in the logs (as it updates, in real-time)
    #     tail -$RUNSAS_SAS_LOG_TAIL_LINECOUNT $runsas_local_logs_root_directory/$current_job_log | grep "NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414" > $runsas_local_error_tmp_log_file
    #     tail -$RUNSAS_SAS_LOG_TAIL_LINECOUNT $runsas_local_logs_root_directory/$current_job_log | grep "NOTE: The SAS System used:" >> $runsas_local_error_tmp_log_file
    #     # Set RC
    #     if [ ! -s $runsas_local_error_tmp_log_file ]; then
    #         script_rc=95
    #         echo "ERROR: runSAS detected abnormal termination of the job/process by the server, there's no SAS error in the log file." > $runsas_local_error_tmp_log_file 
    #     fi
    # fi

    # ERROR: Check return code, abort if there's an error in the job run
    if [ $script_rc -gt 4 ] || [ ${!runsas_local_current_jobrc} -gt 4 ]; then
        # Find the last job that ran on getting an error (there can be many jobs within a job in the world of SAS!)
        sed -n '1,/^ERROR:/ p' $runsas_local_logs_root_directory/$current_job_log | sed 's/Job:             Sngl Column//g' | grep "Job:" | tail -1 > $runsas_local_errored_job_file

        # Format the job name for display
        sed -i 's/  \+/ /g' $runsas_local_errored_job_file
        sed -i 's/^[1-9][0-9]* \* Job: //g' $runsas_local_errored_job_file
        sed -i 's/[A0-Z9]*\.[A0-Z9]* \*//g' $runsas_local_errored_job_file

        # Display fillers (tabulated terminal output)
        display_message_fillers_on_terminal $RUNSAS_DISPLAY_FILLER_COL_END_POS $RUNSAS_FILLER_CHARACTER 0 N 1
		
		# Capture job runtime
		end_datetime_of_job_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
        end_datetime_of_job=`date +%s`

        # Failure (FAILED) message
        printf "\b${white}${red}(FAILED on ${end_datetime_of_job_timestamp} rc=${!runsas_local_current_jobrc}-$script_rc, took "
        printf "%04d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs)${white}\n"

        # Wrappers
        printf "${red}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n"

        # Log
        print_2_runsas_session_log "Job Status: ${red}*** ERROR ***${white}"

        # Depending on user setting show the log details
        if [[ "$JOB_ERROR_DISPLAY_STEPS" == "Y" ]]; then
            printf "%s" "$(<$runsas_local_error_w_steps_tmp_log_file)"
            print_2_runsas_session_log "Reason: ${red}\n"
            printf "%s" "$(<$runsas_local_error_w_steps_tmp_log_file)" >> $RUNSAS_SESSION_LOG_FILE
        else        
            printf "%s" "$(<$runsas_local_error_tmp_log_file)"
            print_2_runsas_session_log "Reason: ${red}"
            printf "%s" "$(<$runsas_local_error_tmp_log_file)" >> $RUNSAS_SESSION_LOG_FILE
        fi

        # Line separator
        printf "\n${red}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}\n"

        # Print last job
        printf "${red}Job: ${red}"
        printf "%s" "$(<$runsas_local_errored_job_file)"

        # Add failed job/step details to the log
        printf "${white}Job: ${red}" >> $RUNSAS_SESSION_LOG_FILE
        printf "%s" "$(<$runsas_local_errored_job_file)" >> $RUNSAS_SESSION_LOG_FILE  
        
        # Print the log filename
        printf "\n${white}${white}"
        printf "${red}Log: ${red}$runsas_local_logs_root_directory/$current_job_log${white}\n" 
        print_2_runsas_session_log "${white}Log: ${red}$runsas_local_logs_root_directory/$current_job_log${white}"  

        # Line separator
        printf "${red}$TERMINAL_MESSAGE_LINE_WRAPPERS${white}"
		
		# Send an error email
        runsas_error_email $JOB_COUNTER_FOR_DISPLAY $TOTAL_NO_OF_JOBS_COUNTER_CMD

        # Log
        print_2_runsas_session_log "${white}End: $end_datetime_of_job_timestamp${white}"

        # Clear the session
        clear_session_and_exi
    elif [ $script_rc -le 4 ] && [ ${!runsas_local_current_jobrc} -le 4 ] && [ ${!runsas_local_current_jobrc} -ge 0 ]; then
        # SUCCESS: Complete the progress bar with offset 0 (fill the last bit after the step is complete)
        # Display the current job status via progress bar, offset is -1 because you need to wait for each step to complete
        no_of_steps_completed_in_log=`grep -o 'Step:' $runsas_local_logs_root_directory/$current_job_log | wc -l`
        display_progressbar_with_offset $no_of_steps_completed_in_log $total_no_of_steps_in_a_job 0 ""

        # Capture job runtime
		end_datetime_of_job_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
        end_datetime_of_job=`date +%s`
		
		# Get last runtime stats to calculate the difference.
		get_job_hist_runtime_stats $runsas_local_job
		if [[ "$hist_job_runtime" != "" ]]; then
			job_runtime_diff_pct=`bc <<< "scale = 0; (($end_datetime_of_job - $start_datetime_of_job) - $hist_job_runtime) * 100 / $hist_job_runtime"`
		else
			job_runtime_diff_pct=0
		fi
		
		# Construct runtime difference messages, appears only when it crosses a threshold (i.e. reusing RUNTIME_COMPARE_FACTOR parameter here, default is 50%)
		if [[ $job_runtime_diff_pct -eq 0 ]]; then
			job_runtime_diff_pct_string=""
		elif [[ $job_runtime_diff_pct -gt $RUNTIME_COMPARE_FACTOR ]]; then
			job_runtime_diff_pct_string=" ${red}â¯…${job_runtime_diff_pct}%%${green}"
		elif [[ $job_runtime_diff_pct -lt -$RUNTIME_COMPARE_FACTOR ]]; then
			job_runtime_diff_pct=`bc <<< "scale = 0; -1 * $job_runtime_diff_pct"`
			job_runtime_diff_pct_string=" ${blue}â¯†${job_runtime_diff_pct}%%${green}"
		else
			job_runtime_diff_pct_string=""
		fi

        # Store the stats for the next time
        store_job_runtime_stats $runsas_local_job $((end_datetime_of_job-start_datetime_of_job)) $job_runtime_diff_pct $current_job_log $start_datetime_of_job_timestamp $end_datetime_of_job_timestamp

        # Display fillers (tabulated terminal output)
        display_message_fillers_on_terminal $RUNSAS_DISPLAY_FILLER_COL_END_POS $RUNSAS_FILLER_CHARACTER 1

        # Success (DONE) message
        printf "\b${white}${green}(DONE on ${end_datetime_of_job_timestamp}, took "
        printf "%04d" $((end_datetime_of_job-start_datetime_of_job))
        printf " secs)${job_runtime_diff_pct_string}${white}\n"

        # Log
        print_2_runsas_session_log "Job Status: ${green}DONE${white}"
        print_2_runsas_session_log "Log: $runsas_local_logs_root_directory/$current_job_log"
        print_2_runsas_session_log "End: $end_datetime_of_job_timestamp"
        print_2_runsas_session_log "Diff: $job_runtime_diff_pct"

        # Send an email (silently)
        runsas_job_completed_email $runsas_local_job $((end_datetime_of_job-start_datetime_of_job)) $hist_job_runtime_for_current_job $JOB_COUNTER_FOR_DISPLAY $TOTAL_NO_OF_JOBS_COUNTER_CMD
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
RUNSAS_GITHUB_PAGE=http://github.com/PrajwalSD/runSAS
RUNSAS_GITHUB_SOURCE_CODE_BRANCH=master
RUNSAS_GITHUB_SOURCE_CODE_URL=$RUNSAS_GITHUB_PAGE/raw/$RUNSAS_GITHUB_SOURCE_CODE_BRANCH/runSAS.sh

# System defaults 
RUNSAS_PARAMETERS_COUNT=$#
RUNSAS_PARAMETERS_ARRAY=("$@")
RUNSAS_MAX_PARAMETERS_COUNT=8
RUNSAS_SAS_LOG_TAIL_LINECOUNT=25
DEBUG_MODE_TERMINAL_COLOR=white
RUNSAS_DISPLAY_FILLER_COL_END_POS=100
RUNSAS_FILLER_CHARACTER=.
TERMINAL_MESSAGE_LINE_WRAPPERS=-----
JOB_NUMBER_DEFAULT_LENGTH_LIMIT=3
RUNSAS_TMP_DIRECTORY=.tmp
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
RC_JOB_PENDING=-2
RC_JOB_TRIGGERED=-1
RUNSAS_JOBLIST_FILE_DEFAULT_DELIMETER="|"
RUNSAS_BATCH_STATE_PRESERVATION_FILE_ROOT_DIRECTORY=.batch
RUNSAS_BATCH_COMPLETE_FLAG=0

# Timestamps
start_datetime_of_session_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
start_datetime_of_session=`date +%s`
job_stats_timestamp=`date '+%Y%m%d_%H%M%S'`

# Files
JOB_STATS_FILE=$RUNSAS_TMP_DIRECTORY/.job.stats
EMAIL_BODY_MSG_FILE=$RUNSAS_TMP_DIRECTORY/.email_body_msg.html
EMAIL_TERMINAL_PRINT_FILE=$RUNSAS_TMP_DIRECTORY/.email_terminal_print.html
JOB_STATS_DELTA_FILE=$RUNSAS_TMP_DIRECTORY/.job_delta.stats.$job_stats_timestamp
RUNSAS_LAST_JOB_PID_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_last_job.pid
RUNSAS_FIRST_USER_INTRO_DONE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_intro.done
SASTRACE_CHECK_FILE=$RUNSAS_TMP_DIRECTORY/.sastrace.check
RUNSAS_SESSION_LOG_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_session.log
RUNSAS_GLOBAL_USER_PARAMETER_KEYVALUE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_global_user.parms
RUNSAS_SAS_SH_TRACE_FILE=$RUNSAS_TMP_DIRECTORY/.runsas_sas_sh.trace

# Bash color codes for the terminal
set_colors_codes

# Initialization
create_a_new_directory -p $RUNSAS_TMP_DIRECTORY

# Parameters passed to this script at the time of invocation (modes etc.), set the default to 0
script_mode="$1"
script_mode_value_1="$2"
script_mode_value_2="$3"
script_mode_value_3="$4"
script_mode_value_4="$5"
script_mode_value_5="$6"
script_mode_value_6="$7"
script_mode_value_7="$8"

# Show run summary for the last run on user request
show_last_run_summary $script_mode

# Resets the session on user request
reset $script_mode

# Show parameters on user request
show_runsas_parameters $script_mode X

# Log (session variables)
print_2_runsas_session_log "================ *** runSAS launched on $start_datetime_of_session_timestamp by ${SUDO_USER:-$USER} *** ================\n"
print_unix_user_session_variables file $RUNSAS_SESSION_LOG_FILE

# Log
print_2_runsas_session_log $TERMINAL_MESSAGE_LINE_WRAPPERS
print_2_runsas_session_log "Host: $HOSTNAME"
print_2_runsas_session_log "PID: $$"
print_2_runsas_session_log "User: ${SUDO_USER:-$USER}"
print_2_runsas_session_log "Batch start: $start_datetime_of_session_timestamp"
print_2_runsas_session_log "Script Mode: $script_mode"
print_2_runsas_session_log "Script Mode Value 1: $script_mode_value_1"
print_2_runsas_session_log "Script Mode Value 2: $script_mode_value_2"
print_2_runsas_session_log "Script Mode Value 3: $script_mode_value_3"
print_2_runsas_session_log "Script Mode Value 4: $script_mode_value_4"
print_2_runsas_session_log "Script Mode Value 5: $script_mode_value_5"
print_2_runsas_session_log "Script Mode Value 6: $script_mode_value_6"
print_2_runsas_session_log "Script Mode Value 7: $script_mode_value_7"

# Idiomatic parameter handling is done here
validate_parameters_passed_to_script $1

# Override the jobs list, if specified.
check_for_job_list_override 

# Show the list, if the user wants to quickly preview before launching the script (--show or --jobs or --list)
show_the_list $1

# Check if the user wants to update the script (--update)
check_for_in_place_upgrade_request_from_user $1 $2

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
create_a_file_if_not_exists $JOB_STATS_FILE
archive_all_job_logs .job.list archives

# Print session details on terminal
show_server_and_user_details $1

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

# Check if the user wants to run a job in adhoc mode (i.e. the job is not specified in the list)
run_a_job_mode_check $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3 $script_mode_value_4 $script_mode_value_5 $script_mode_value_6 $script_mode_value_7

# Redeploy jobs routine (--redeploy option)
redeploy_sas_jobs $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3

# Print job(s) list on terminal
print_file_content_with_index .job.list jobs --prompt --skip --server

# Check if the user has specified a job number (/index) instead of a job name (pick the relevant job from the list) in different mode
convert_job_index_to_job_names

# Validate the jobs in list
validate_job_list .job.list

# Debug mode
print_to_terminal_debug_only "runSAS session variables"

# Get the consent from the user to trigger the batch 
press_enter_key_to_continue 0 1

# Check for rogue process(es), the last known pid is checked here
check_if_there_are_any_rogue_runsas_processes

# Hide the cursor
setterm -cursor off

# Reset the prompt variable
run_job_with_prompt=N

# Check if user has specified a delayed execution
process_delayed_execution 

# Send a launch email
runsas_triggered_email $script_mode $script_mode_value_1 $script_mode_value_2 $script_mode_value_3 $script_mode_value_4 $script_mode_value_5 $script_mode_value_6 $script_mode_value_7

# Trigger the job/flow
while [ $RUNSAS_BATCH_COMPLETE_FLAG = 0 ]; do
    while IFS='|' read -r flowid flow jobid job jobdep logicop jobrc opt subopt sappdir bservdir bsh blogdir bjobdir; do
        runSAS $flowid $flow $jobid ${job##/*/} $jobdep $logicop $jobrc $opt $subopt $sappdir $bservdir $bsh $blogdir $bjobdir
    done < .job.list
done

# Capture session runtimes
end_datetime_of_session_timestamp=`date '+%Y-%m-%d-%H:%M:%S'`
end_datetime_of_session=`date +%s`

# Print a final message on terminal
printf "\n${green}The batch run completed on $end_datetime_of_session_timestamp and took a total of $((end_datetime_of_session-start_datetime_of_session)) seconds to complete.${white}"

# Log
print_2_runsas_session_log $TERMINAL_MESSAGE_LINE_WRAPPERS
print_2_runsas_session_log "Batch end: $end_datetime_of_session_timestamp"
print_2_runsas_session_log "Total batch runtime: $((end_datetime_of_session-start_datetime_of_session)) seconds"

# Send a success email
runsas_success_email

# Clear the run history 
if [[ "$ENABLE_RUNSAS_RUN_HISTORY" != "Y" ]]; then 
    delete_a_file $JOB_STATS_DELTA_FILE 0
fi

# Tidy up
delete_a_file "$RUNSAS_TMP_DIRECTORY/*.err" 0
delete_a_file "$RUNSAS_TMP_DIRECTORY/*.stepserr" 0
delete_a_file "$RUNSAS_TMP_DIRECTORY/*.errjob" 0

# END: Clear the session, reset the terminal
clear_session_and_exit
