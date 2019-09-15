# runSAS
The script allows you to run a SAS program or a batch of SAS programs via Bash environment in various interactive and non-interactive execution modes.

# Screenshots/Videos
![runSAS in action](https://i.imgur.com/ixP3jzh.png)

# Prerequisites
SAS 9.x environment (Linux) with SAS BatchServer component is essential for the runSAS to execute or any equivalent would work (i.e. `sas.sh`, `sasbatch.sh` etc.). The core script dependencies are checked at every launch of the script automatically.

# Is there a help menu?
 `./runSAS.sh --help`

# How can I see the version of the script?
 `./runSAS.sh --version`
 
# How can I update to the latest version?
 `./runSAS.sh --update`

# How to use the script?
  * Download/clone `runSAS.sh` and transfer it to the SAS server
  * Set the environment parameters (inside the script in the top section)
  * Specify the list of the job(s)/program(s) you want to run (use --prompt or -p to allow a user to skip a job in the runtime)
  * Execute the script (see the details on modes of execution below) as a user who has execution privileges (OS and SAS Metadata privileges)

# How to run the script? 
The script has multiple modes of execution, see `./runSAS.sh --help` for more details. 

* ### Non-Interactive mode
  If you want to run an end to end batch without any manual intervention.
  
  `./runSAS.sh`
  
* ### Interactive mode (-i)
  If you want to run one job at a time through the list, the script waits for you to press an enter key to continue.
  
  `./runSAS.sh -i`
  
* ### Adhoc job mode (-j)
  If you want to run any deployed job which is not in the job list, you can run using this mode

  `./runSAS.sh -j`
  
* ### Run upto mode (-u)
  If you want to run until a specific job, the script will run all the jobs in the list until the specified job.
  
  `./runSAS.sh -u <name or index>`
  
  *NOTE: `name` refers to the job name in the list and `index` refers to the job number (if you are lazy!), you have a choice of using     either of them during the launch the script will find the relevant job name from the list*

* ### Run from mode (-f)
  If you want to run from a specific job, the script will skip the jobs and will start running from a specified job.
  
  `./runSAS.sh -f <name or index>`
  
* ### Run a single job mode (-o)
  If you want to run a specific job, the script will skip the other jobs and will start running only the specified job.
  
  `./runSAS.sh -o <name or index>`
  
 * ### Run a single adhoc job mode (-j)
   If you want to run a specific job which is not in the list (adhoc run)
  
   `./runSAS.sh -j <name or index>`
  
* ### Run from a job up to a job mode (-fu)
  If you want to run a bunch of jobs from one point to the other.
  
  `./runSAS.sh -fu <name or index> <name or index>` 
  
* ### Run from a job up to a job interactive mode (-fui)
  If you want to run in an interactive mode from one job to the other job (__runs the rest__ in a non-interactive mode)  
  
  `./runSAS.sh -fui <name or index> <name or index>` 
  
* ### Run from a job to a job interactive skip mode (-fuis)
  If you want to run in an interactive mode from one job to the other job (__skips__ the rest)" 
  
  `./runSAS.sh -fuis <name or index> <name or index>` 
  
# How to enable email alerts?
The script can send email alerts on different scenarios, to enable it set `EMAIL_ALERTS=Y` inside the script with the email address(es) (in parameters section).
* Sends an email when the batch has triggered
* Sends an email when a job has finished
* Sends an email when a job has failed (with log and error snippet in the email body)
* Sends an email when the batch has completed (with a runtime statistics)

![runSAS job failed email alert](https://i.imgur.com/OGGLMFo.png)

_Tip: To disable email alerts temporarily for a run, just append `--noemail` during the launch i.e. `./runSAS.sh --noemail`, this will not send any emails for that specific run._

# Can I schedule a batch run?
Currently runSAS supports a simple time based delay. just add `--delay <time-in-seconds>` during the launch i.e. `./runSAS.sh --delay 3600` to delay a batch run by 1 hour.

# How do I stop/abort a runSAS run?
Just press CTRL+C, runSAS is designed gracefully exit even in the case of user intervention. If `KILL_PROCESS_ON_USER_ABORT=Y` was set then the running job process will be killed/terminated on user abort, turn it off if you want the last job process to complete the run even when the user has aborted the batch run.
 
# Tips
* To preview the job list use `./runSAS.sh --jobs`
* To see the last run details use `./runSAS.sh --last`
* To skip a job from the list during the run, add `--skip` in front of the job name in the list
* To reset runSAS script, use `./runSAS.sh --reset` (restore it to first time use state, will clear all temporary files etc.)
* To stop email alerts (temporarily, instead of disabling it) for a run, append `--noemail` to the launch e.g.: `./runSAS.sh --noemail`
* To override the default server parameters by job, add `--server` option followed by the server parameters: `<jobname> --server <sas-server-name> <sasapp-dir> <batch-server-dir> <sas-sh> <logs-dir> <deployed-jobs-dir>`
* runSAS stores temporary files under `.tmp` folder in script root directory.
* If runSAS run history is enabled (i.e. `ENABLE_RUNSAS_RUN_HISTORY=Y`) you can view the historical run stats files in the `.tmp` folder.
* Progress bar goes red when an error is detected in log, runSAS waits for SAS to complete the run until it shows the error on console, to change this behaviour set `ABORT_ON_ERROR=Y`
