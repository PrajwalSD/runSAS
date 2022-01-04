# Introduction
runSAS is essentially a bash shell script desigined to execute SAS programs or SAS Data Integration Studio jobs. It's feature rich with support for concurrency (as _flows_), job fail recovery options, email notifications, log monitoring, and has many useful interactive and non-interactive modes.

The primary motivation behind this side project was to provide existing SAS 9.x environments with a simple CLI-based tool to manage SAS programs/jobs without the need for an additional third-party softwares/programs. 

This is useful for SAS sites where a third-party SAS job schedulers like LSF or Control-M is not installed, the projects can extend runSAS as per their needs preferrably contribute back to this.

# Screenshots
Flows:
![runSAS in action](https://i.imgur.com/KpcXvic.png)
Load balancing:
![runSAS flows](https://i.imgur.com/AlaBIOh.png)
Error handling:
![runSAS on error](https://i.imgur.com/OFbN6S6.png)

# Prerequisites
SAS 9.x environment (Linux) with SAS BatchServer component is essential for the runSAS to execute or any equivalent would work(i.e. `sas.sh`, `sasbatch.sh` etc.). This is typically present in every SAS 9.x installation.

All other script dependencies are checked at every launch of the script automatically.

# Get started?
  * Download `runSAS.sh` (or clone the repo) and transfer it to a SAS compute server (Linux based)
  * Open `runSAS.sh` in edit mode and:
    * Set the user parameters in the header section as per your SAS environment configuration
    * Specify the list of the job(s)/program(s) you want to run with dependencies
  * Execute the script simply by using `./runSAS.sh` command as a user who has job/program execution privileges (OS and SAS Metadata privileges)
  
   _Tip: There are many invocation options and useful features in the script all of it is discussed in later sections below_
  
# Configuring Parameters
runSAS has 4 user parameter sections within the script:
  * ### SAS 9.4 parameters – Provide SAS environment details
    * `SAS_HOME_DIRECTORY`: AS Home directory (e.g.: `/SASInside/SASHome`)
    * `SAS_INSTALLATION_ROOT_DIRECTORY`: SAS installation root directory (e.g.: `/SASInside/SAS`)
    * `SAS_APP_SERVER_NAME`: Name of the SAS Application Server Context (e.g.: `SASApp`)
    * `SAS_LEV`: SAS level (e.g.: `Lev1` or `Lev2` `...`)
    * `SAS_DEFAULT_SH`: SAS shell script name that executes the SAS program/job (e.g.: `sasbatch.sh`)
    * `SAS_APP_ROOT_DIRECTORY`: Path for the SAS Application Server Context directory (e.g.: `SASInside/SAS/Lev1/SASApp`)
    * `SAS_BATCH_SERVER_ROOT_DIRECTORY`: Path for the SAS Batch Server directory (e.g.: `/SASInside/SAS/Lev1/SASApp/BatchServer`)
    * `SAS_LOGS_ROOT_DIRECTORY`: Path for the logs directory (e.g.: `/SASInside/SAS/Lev1/SASApp/BatchServer/Logs`)
    * `SAS_DEPLOYED_JOBS_ROOT_DIRECTORY`: Path for the deployed jobs directory (e.g.: `/SASInside/SAS/Lev1/SASApp/SASEnvironment/SASCode/Jobs`)
    
  * ### Job/flow list – Provide a list of jobs/flows to run (append the optional parameters to the mandatory parameters with no whitespaces)
    * Syntax: 
      `flow-id|flow-nm|job-id|job-nm|dependent-job-id|dependency-type|job-rc-max|job-run-flag|options|sub-options|sasapp-dir|batchserver-dir|sas-sh|log-dir|job-dir|`

    * Details:
      * `flow-id`: Flow identifer (has to be a number)
      * `flow-nm`: Flow name (no spaces allowed in the name)
      * `job-id`: Job identifer (has to be a number)
      * `job-nm`: Job name (typically a deployed job file name, no spaces allowed in the name)
      * `dependent-job-id`: Job ID of a dependent(s), specify them as a comma-delimited list (e.g.: `1,2,3`) or with hyphen (e.g.: `1-3`) if there are more than one dependent jobs
      * `dependency-type`- Possible values here are `AND` (i.e., run after all of it's dependents have completed) and `OR` (i.e., run if at least one of the dependents has completed) 
      * `job-rc-max`: Specify the limit (e.g., 0 or 4), return codes above this will halt the run
      * `job-run-flag`: `Y/N` to indicate if you want to deactivate this job in the flow
      * `options`(optional): Possible values here are `--prompt` (user will be prompted to continue), `--server` (speficic SAS server related options can be provided for a job to overrides the global option)
      * `sub-options`(optional, if `options` is not `--server`): Name of the SAS Application Server Context (e.g.: `SASApp`)
      * `sasapp-dir`(optional, if `options` is not `--server`): Path for the SAS Application Server Context directory (e.g.: `SASInside/SAS/Lev1/SASApp`)
      * `batchserver-dir`(optional, if `options` is not `--server`): Path for the SAS Batch Server directory (e.g.: `/SASInside/SAS/Lev1/SASApp/BatchServer`)
      * `sas-sh`(optional, if `options` is not `--server`): SAS shell script name that executes the SAS program/job (e.g.: `sasbatch.sh`)
      * `log-dir`(optional, if `options` is not `--server`): Path for the logs directory (e.g.: `/SASInside/SAS/Lev1/SASApp/BatchServer/Logs`)
      * `job-dir`(optional, if `options` is not `--server`): Path for the deployed jobs directory (e.g.: `/SASInside/SAS/Lev1/SASApp/SASEnvironment/SASCode/Jobs`)
      
    Example (specifying a flow with jobs):
    ```
    1|Flow_A|1|Job_1|1|AND|4|Y|
    1|Flow_A|2|Job_2|2|AND|0|Y|--prompt
    1|Flow_A|3|Job_3|3|AND|4|Y|
    2|Flow_B|4|Job_4|1,2,3|AND|4|Y|
    2|Flow_B|5|Job_5|5|AND|4|Y|
    ```
    _Tip: You can simply provide a list of jobs without anything else if you're not using the flows, runSAS will automatically create one flow (OR multiple flows depending on the `GENERATE_SINGLE_FLOW_FOR_ALL_JOBS` parameter) with all jobs in it_
    
    Example (specifying just jobs):
    ```
    Job_1
    Job_2,--skip
    Job_3
    Job_4
    Job_5
    ```
  * ### Email settings – Configure the email parameters (script has an inline explanation for each parameter)
    * `ENABLE_EMAIL_ALERTS`: `Y` to enable all 4 alert types (`YYYY` is the extended format, `<trigger-alert><job-alert><error-alert><completion-alert>`)
    * `EMAIL_ALERT_TO_ADDRESS`: Provide email addresses separated by a semi-colon  
    * `EMAIL_ALERT_USER_NAME`: This is used as FROM address for the email alerts
  
  * ### runSAS script overrides – A collection of script behavior control parameters (script has an inline explanation for each parameter, keep the defaults if you're unsure)
    * `ENABLE_DEBUG_MODE=N`: Enables the debug mode, specifiy `Y/N`                       
    * `RUNTIME_COMPARISON_FACTOR=30`: Runtime change threshold, increase this to display only higher `%` difference              
    * `KILL_PROCESS_ON_USER_ABORT=Y`: The rogue processes are automatically killed by the script on user abort            
    * `ENABLE_RUNSAS_RUN_HISTORY=N`: Enables runSAS flow/job runtime history, specify `Y/N`             
    * `ABORT_ON_ERROR=N`: Set to `Y` to abort as soon as runSAS sees an `ERROR` in the log file (i.e don't wait for the job to complete)                          
    * `ENABLE_SASTRACE_IN_JOB_CHECK=Y`: Set to `N` to turn off the warnings on sastrace           
    * `ENABLE_RUNSAS_DEPENDENCY_CHECK=Y`: Set to `N` to turn off the script dependency checks           
    * `BATCH_HISTORY_PERSISTENCE=ALL`: Specify a postive number to control the number of batches preserved by runSAS  (e.g. `50` will preserve last 50 runs), `ALL` will keep everything              
    * `CONCURRENT_JOBS_LIMIT=ALL`: Specify the available job slots as a number (e.g. `2`), `ALL` will use the CPU count instead (`nproc --all`) and `MAX` will spawn all jobs
    * `CONCURRENT_JOBS_LIMIT_MULTIPLIER=1`: Specify a positive number to increase the available job slots (e.g. `1x`, `2x`, `3x``...`), will be used a multiplier to the above parameter
    * `ERROR_CHECK_SEARCH_STRING="^ERROR"`: This is what is `grep`ped in the log        
    * `STEP_CHECK_SEARCH_STRING="Step:"`: This is searched for the SAS Step in the log          
    * `SASTRACE_SEARCH_STRING="^options sastrace"`: This is used for searching the `options sastrace ...` option in SAS log
    
# Additional "Hidden" Script Parameters
There are additional set of script behavior control parameters, it's kept hidden away deep in the code in the bottom third of the script intentionally, typically they don't require changing and defaults should just work fine. An inline explanation for each parameter is provided in the script for reference.
  * ### Parameters
    * `EMAIL_USER_MESSAGE=`: This will be appended to email subject
    * `GENERATE_SINGLE_FLOW_FOR_ALL_JOBS=N`: If set to `Y` runSAS will create a single flow for all jobs instead of one flow per job 
    * `EMAIL_ATTACHMENT_SIZE_LIMIT_IN_BYTES=8000000`: This is the log file size limit (sent as email attachment)
    * `SERVER_PACKAGE_INSTALLER_PROGRAM=yum`: Package installer is used by runSAS for auto-installation of depdendencies
    * `RUNSAS_LOG_SEARCH_FUNCTION=egrep`: runSAS uses this as search util to detect errors in job logs
    * `RUNSAS_DETECT_CYCLIC_DEPENDENCY=Y`: If set to `N` runSAS will NOT detect cyclic dependencies in job flows before the batch run
    * `GENERATE_SINGLE_FLOW_FOR_ALL_JOBS=N`: If set to `Y` runSAS will create a single flow for all jobs instead of one flow per job  
    * `RUNSAS_PRINT2DEBUG_LOGGING=Y`: This outputs a useful essential batch run related info to `.tmp/.runsas.debug` file

# Can I save batch status info to a SAS environment (as a dataset or into a database table)?
Yes, runSAS can save batch run related info in real-time to a SAS dataset or to a database table of your choice. To enable this feature, set the following parameters (these parameters can be found in the "Hidden" script parameters section). An inline explanation for each parameter is provided in the script for reference.

In nutshell, runSAS generates a new SAS program file by using the parameters. This SAS program is designed to take in the batch run details and update in real-time into a specified table/dataset, runSAS calls and executes this program (just like other SAS programs/jobs) at regular checkpoints to keep the batch status up-to-date

This is very useful if you need reporting/tracking from a SAS environment. Please note that the table is not used to control the behaviour of runSAS' flow. 

  * `UPDATE_BATCH_STATUS_TO_SAS_DATASET_FLAG=Y`                                                
  * `UPDATE_BATCH_STATUS_SAS_DATASET_PATH=$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY`                   
  * `UPDATE_BATCH_STATUS_SAS_DATASET_LIBREF=runsas`                                            
  * `UPDATE_BATCH_STATUS_SAS_DATASET_NAME=RUNSAS_BATCH_STATUS`                                 
  * `UPDATE_BATCH_STATUS_SAS_PROGRAM_FILE_NAME=runsas_update_batch_status.sas`                 
  * `UPDATE_BATCH_STATUS_SAS_PROGRAM_FILE_DEPLOYED_DIRECTORY=$SAS_DEPLOYED_JOBS_ROOT_DIRECTORY`

# Is there a help menu?
 `./runSAS.sh --help`

# How can I see the version of the script?
 `./runSAS.sh --version`
 
# How can I update to the latest version?
 `./runSAS.sh --update`          
   
# Does runSAS support parallel execution (flows)?
Yes, runSAS supports parallel execution of SAS jobs as flows. Specify details about a flow in the script parameters section with right dependencies. runSAS has options to control the level of parallelism (use `CONCURRENT_JOBS_LIMIT` parameter to set the right value for the environment)

# How to run the script? 
The script has multiple modes of execution, see `./runSAS.sh --help` for more details. 

* ### Non-Interactive mode
  If you want to run an end to end batch without any manual intervention.
  
  `./runSAS.sh`
  
* ### Interactive mode (-i)
  If you want to run one job at a time through the list, the script waits for you to press an enter key to continue. Add `--byflow` to pause after each flow instead of jobs
  
  `./runSAS.sh -i`
  
* ### Adhoc job mode (-j)
  If you want to run any deployed job which is not in the job list, you can run using this mode

  `./runSAS.sh -j`
  
* ### Run upto mode (-u)
  If you want to run until a specific job, the script will run all the jobs in the list until the specified job.
  
  `./runSAS.sh -u <job-index>`
  
  *NOTE: `name` refers to the job name in the list and `index` refers to the job number (if you are lazy!), you have a choice of using     either of them during the launch the script will find the relevant job name from the list*

* ### Run from mode (-f)
  If you want to run from a specific job, the script will skip the jobs and will start running from a specified job.
  
  `./runSAS.sh -f <job-index>`
  
* ### Run a single job mode (-o)
  If you want to run a specific job, the script will skip the other jobs and will start running only the specified job.
  
  `./runSAS.sh -o <job-index>`
  
 * ### Run a single adhoc job mode (-j)
   If you want to run a specific job which is not in the list (adhoc run)
  
   `./runSAS.sh -j <job-index>`
  
* ### Run from a job up to a job mode (-fu)
  If you want to run a bunch of jobs from one point to the other.
  
  `./runSAS.sh -fu <from-job-index> <to-job-index>` 
  
* ### Run from a job up to a job interactive mode (-fui)
  If you want to run in an interactive mode from one job to the other job (__runs the rest__ in a non-interactive mode)  
  
  `./runSAS.sh -fui <from-job-index> <to-job-index>` 
  
* ### Run from a job to a job interactive skip mode (-fuis)
  If you want to run in an interactive mode from one job to the other job (__skips__ the rest)" 
  
  `./runSAS.sh -fuis <from-job-index> <to-job-index>` 
  
# Can runSAS redeploy SAS DI jobs?
Yes, it can. All you need to do is create a file that contains the list of jobs that needs to be redeployed and provide that as an argument to --redeploy option. Do note that the job name should also contain the full path (relative to 'SAS Folders')

`./runSAS.sh --redeploy <job-list-file>`

If you want to display the jobs from the job list file, specify '--list' as shown below

`./runSAS.sh --redeploy <job-list-file> --list`

You can provide filters to the --redeploy option to redeploy a single job or range (from the jobs file)

`./runSAS.sh --redeploy <job-list-file> <from-job-index> <to-job-index>`

_NOTE: DEPLOY feature is not built into runSAS yet_
  
# How to enable email alerts?
The script can send email alerts on different scenarios, to enable it set `EMAIL_ALERTS=Y` inside the script with the email address(es) (in parameters section).
* Sends an email when the batch has triggered
* Sends an email when a job has finished
* Sends an email when a job has failed (with log and error snippet in the email body)
* Sends an email when the batch has completed (with a runtime statistics)

![runSAS email](https://i.imgur.com/xsAQiDq.png)

_Tip: To disable email alerts temporarily for a run, just append `--noemail` during the launch i.e. `./runSAS.sh --noemail`, this will not send any emails for that specific run. If you want to send an email for a specific batch append `--mail <email-address>` at the end_

# Can I delay the execution?
Yes, runSAS supports a simple time based delay. just add `--delay <time-in-seconds>` during the launch. As an example `./runSAS.sh --delay 3600` to delay a batch run by 1 hour.

# How to schedule runSAS batch?
runSAS supports batch (non-interactive) mode for scheduling purposes, simply append `--batch --nocolors` to the launch command. If you're intending to use it within a wrapper script then use the typical `$?` to capture the exit return code from runSAS.sh script (success=0 and error=1). Example: `nohup ./runSAS.sh -fu 2 3 --batch --nocolors &`

# How's job/flow failure managed?
runSAS will detect job failures and notify the user via email with error info and logs, the failed batch can be resumed via `--resume <batchid>` option e.g. `./runSAS.sh --resume 420`

# How do I stop/abort a runSAS run?
Just press CTRL+C, runSAS is designed gracefully exit even in the case of user intervention. If `KILL_PROCESS_ON_USER_ABORT=Y` was set then the running job process will be killed/terminated on user abort, turn it off if you want the last job process to complete the run even when the user has aborted the batch run.

# Can I see the batch status on a browser?
Yes, you can forward the console output to [seashells.io](https://seashells.io/) to see the batch status updates in real-time. No installation is required unless nc (netcat) is not pre-installed.
 
# Tips
* To preview the job list use `./runSAS.sh --jobs`
* To see the last run details use `./runSAS.sh --last`
* To skip a job from the list during the run, add `--skip` in front of the job name in the job list
* To reset runSAS script, use `./runSAS.sh --reset` (you can restore the script state to the initial state, user is presented with choices on what to delete)
* To stop email alerts (temporarily, instead of disabling it) for a run, append `--noemail` to the launch e.g.: `./runSAS.sh --noemail`
* To enable email alerts just for a batch append `--mail <email-address>`
* To add messages/tags to a batch use `--message <your-message-goes-here>` e.g. `./runSAS.sh -u 2 --message "Second Incremental"`
* To override the default server parameters by job, add `--server` option followed by the server parameters: `<jobname> --server <sas-server-name> <sasapp-dir> <batch-server-dir> <sas-sh> <logs-dir> <deployed-jobs-dir>`
* runSAS stores temporary "hidden" files under `.tmp/` folder in script root directory which contains useful batch run related info for debugging or for tracing the runs. 
* If runSAS run history is enabled (i.e. `ENABLE_RUNSAS_RUN_HISTORY=Y`) you can view the historical run stats files in the `.tmp/` folder.
* Progress bar goes red when an error is detected in log, runSAS waits for SAS to complete the run until it shows the error on console, to change this behaviour set `ABORT_ON_ERROR=Y`
* runSAS by default has a minimum debugging enabled (i.e. `RUNSAS_PRINT2DEBUG_LOGGING=Y`), detailed script log useful for debugging the script is stored in `.tmp/.runsas.debug` file.
