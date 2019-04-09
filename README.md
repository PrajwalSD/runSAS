# runSAS
The script allows you to run a SAS program or a batch of SAS programs via Bash environment with interactive and non-interactive execution modes.

# Screenshots
![runSAS in action](https://i.imgur.com/gidqfox.png)

# Prerequisites
SAS 9.x environment (Linux) with SAS BatchServer component is essential for the runSAS to execute or any equivalent (i.e. `sas.sh`, `sasbatch.sh` etc.) would work. The core dependencies are checked every launch of the script automatically.

# How to use the script?
  * Download/clone `runSAS.sh` and transfer it to the SAS server
  * Set the environment parameters (inside the script in the top section)
  * Execute the script (see the details on modes of execution below) as a user who has execution privileges (OS and SAS Metadata privileges)

# How to run the script? 
The script has multiple modes of execution, see `./runSAS.sh --help` for more details. 

* ### Non-Interactive mode
  If you want to run an end to end batch without any manual intervention.
  
  `*./runSAS.sh*`
  
* ### Interactive mode 
  If you want to run one job at a time through the list, the script waits for you to press an enter key to continue.
  
  `./runSAS.sh -i`
  
* ### Run until mode
  If you want to run until a specific job, the script will run all the jobs in the list until the specified job.
  
  `./runSAS.sh -u <name or index>`
  
  *NOTE: `name` refers to the job name in the list and `index` refers to the job number (if you are lazy!), you have a choice of using     either of them during the launch the script will find the relevant job name from the list*

* ### Run from mode
  If you want to run from a specific job, the script will skip the jobs and will start running from a specified job.
  
  `./runSAS.sh -f <name or index>`
  
* ### Run a single job mode
  If you want to run a specific job, the script will skip the other jobs and will start running only the specified job.
  
  `./runSAS.sh -o <name or index>`
  
* ### Run from a job to a job mode
  If you want to run a bunch of jobs together from one point to the other.
  
  `./runSAS.sh -t <name or index> <name or index>` 
