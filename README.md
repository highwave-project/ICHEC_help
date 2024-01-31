# ICHEC Commands

A short but useful quick-start guide to ICHEC. This is written for Linux users as many of the commands can be more difficult using a Windows system (if you dont use Linux, I recommend starting to use Linux).

## Contents

- [Logging In](#logging-in)
- [Filesystem and Copying](#filesystem-and-copying)
- [Loading Modules and Environments](#loading-modules-and-environments)
- [Requesting Compute Nodes](#requesting-compute-nodes)
- [Schedule multiple similar jobs](#schedule-multiple-similar-jobs)
- [Useful Commands](#useful-commands)
- [Using VSCode on ICHEC](#using-vscode-on-ichec)
- [Using Aliases](#using-aliases)
- [Basilisk](#basilisk)
- [Other SLURM Commands](#other-slurm-commands)

---

## Logging In

To get logged on to the supercomputer, we use a Secure Shell (SSH) connection. You must first generate public and private keys for your connection.
On Linux this is easily done as follows

```bash
ssh-keygen -t ed25519
# Press enter to accept the default location or give it a more specifc filename
# You can also choose to enter a password or just press enter again

cat ~/.ssh/id_ed25519.pub
```

Copy the output from `cat` and email it to the [ICHEC Support](mailto:support@ichec.ie).

After your public key is added, you can SSH login

```bash
ssh <username>@kay.ichec.ie
```

For more details see [ICHEC SSH Keys](https://www.ichec.ie/academic/national-hpc/documentation/tutorials/setting-ssh-keys)

---

## Filesystem and Copying

Once logged in, you will be in your home directory. You will have access to another work directory where you can store larger files and folders. To get to the work folder you need to go up several directories and then select the work directory and your project code.

```bash
cd /ichec/work/<project_code>
# make a personal directory for your work
mkdir <username>
```

To copy files from your local system to your folders on ICHEC we use SCP

```bash
# Format: scp <local_path> <username>@kay.ichec.ie:~/<remote_path>

scp project/my_file.c <username>@kay.ichec.ie:~/project/my_new_file.c

# Use the flag -r for recursively copying files inside folders
scp -r project <username>@kay.ichec.ie:~/project
```

To copy from ICHEC to your local machine simply reverse the order of the paths.
It is also easy to use rsync where you may want to include certain files and exclude others using the following

```bash
rsync -r <username>@kay.ichec.ie:<remote_path> <local_path> --include file_pattern* --exclude unwanted_files*
```

---

## Loading Modules and Environments

To load compilers for C and C++ codes the intel modules must be loaded.

```bash
module load intel/2019
```

To setup a conda environment using a YML file, enter the following into the terminal

```bash
# Load Anaconda and Python
module load conda/2
source activate python3

# Install the conda env from YML file
conda env create -f <environment.yml>

# Finally activate the new environment
source activate <new_env>
```

---

## Requesting Compute Nodes

Compute nodes can be run interactively (up to 1 hour and DevQ only), or you can queue longer jobs to run with more resourses.

```bash
# Interactive
##srun -p DevQ -N 1 -A <project_id> -t 1:00:00 --pty bash  # DEPRECATED
salloc -p <queue_name> -N 1 -A <project_id> -t <walltime>
```

To submit jobs in a batch and non-interactively, create a bash file with the following

```bash
#!/bin/sh

#SBATCH --time=00:20:00
#SBATCH --nodes=2
#SBATCH -A <myproj_id>
#SBATCH -p DevQ

module load intel/2019

mpirun -n 80 <path_to_file_to_run>
```

and replacing <myproj_id> with your project id, and the relevent file at the bottom. Then submit the job with the following command in the shell

```bash
sbatch mybatchjob.sh
```

---

## Schedule multiple similar jobs

If you want to submit a lot of similar jobs you can do that using a job array. This can be done by adding the following option to the bash file.

Submit a job array with index values between 0 and 30:

```bash
#SBATCH --array=0-30
```

Submit a job array with index values of 1, 3, 5 and 7:

```bash
#SBATCH --array=1,3,5,7
```

Submit a job array with index values between 1 and 7 with a step size of 2 (i.e. 1, 3, 5 and 7)

```bash
#SBATCH --array=1-7:2
```

Each job has the following environment variables set:

1. **`SLURM_ARRAY_JOB_ID`**: The first job ID
1. **`SLURM_ARRAY_TASK_ID`**: The job array index value
1. **`SLURM_ARRAY_TASK_COUNT`**: The number of tasks in the job array
1. **`SLURM_ARRAY_TASK_MAX`**: The highest job array index value
1. **`SLURM_ARRAY_TASK_MIN`**: The lowest job array index value

For example the following job submission will generate 3 jobs:

```bash
#!/bin/sh

#SBATCH --array=1-3
#SBATCH --time=00:20:00
#SBATCH --nodes=2
#SBATCH -A <myproj_id>
#SBATCH -p DevQ
```

If the `sbatch` responds:

```bash
Submitted batch job 36
```

The following environment variables will be set:

```bash
SLURM_JOB_ID=36
SLURM_ARRAY_JOB_ID=36
SLURM_ARRAY_TASK_ID=1
SLURM_ARRAY_TASK_COUNT=3
SLURM_ARRAY_TASK_MAX=3
SLURM_ARRAY_TASK_MIN=1

SLURM_JOB_ID=37
SLURM_ARRAY_JOB_ID=36
SLURM_ARRAY_TASK_ID=2
SLURM_ARRAY_TASK_COUNT=3
SLURM_ARRAY_TASK_MAX=3
SLURM_ARRAY_TASK_MIN=1

SLURM_JOB_ID=38
SLURM_ARRAY_JOB_ID=36
SLURM_ARRAY_TASK_ID=3
SLURM_ARRAY_TASK_COUNT=3
SLURM_ARRAY_TASK_MAX=3
SLURM_ARRAY_TASK_MIN=1
```

### **Complete example**

The following job submission will create 7 jobs (0 to 6). Each job will run an executable with a different xml file as input. All jobs will have 1 node and a limit wall time of 1 hour:

```bash
#!/bin/bash

#SBATCH --array=0-6
#SBATCH -A <myproj_id>
#SBATCH --nodes=1
#SBATCH -p DevQ
#SBATCH --time=1:00:00

module load <dependencies>

<executable> input_file_${SLURM_ARRAY_TASK_ID}.xml
```

Two additional options are available to specify a job's stdin, stdout, and stderr file names: **%A** will be replaced by the value of SLURM_ARRAY_JOB_ID (as defined above) and **%a** will be replaced by the value of SLURM_ARRAY_TASK_ID (as defined above). The default output file for a job array is `slurm-%A_%a.out`.

To cancel a job or multible jobs you can use:

```bash
# Cancel array ID 1 to 3 from job array 20
scancel 20_[1-3]

# Cancel array ID 4 and 5 from job array 20
scancel 20_4 20_5

# Cancel all elements from job array 20
scancel 20

# Cancel jobs from 12345 to 12367
scancel {12345..12367}
```

**Note**: Even though you can schedule as many jobs as you want ICHEC only allows for 2 jobs to run simultaneously per user.

---

## Useful Commands

To see your currently queued jobs

```bash
squeue  #list all jobs
squeue -u $USER  # list your jobs
```

To quickly check the project balance , enter the follwing in the terminal

```bash
mybalance
```

If you want to display plots, you need to login with the `-X` flag

Graphics Login

```bash
ssh -X <username>@kay.ichec.ie
```

Where `<username>` will be your assigned ichec username.

---

## Using VSCode on ICHEC

VIm is great for quick editing of files, but if you would like to continue using an IDE such as VSCode, you can set up a remote connection with ease.

![Remotes on VSCode](sshremote.png)

On your local computer, install the `Remote Development` extension pack. Open VSCode and you will see the remote connection symbol on the bottom left (orange button with two arrows, it will say "open a remote window" when hovering over it with the mouse). Click this and select "Connect to Host". Enter the ssh command you normally use to connect to ICHEC "ssh -X username@kay.ichec.ie", and your password. Add this host to the ssh config file. A new remote window VSCode will open, and down in the bottom left corner you will see the host that you have connected to.

---

## Using Aliases

To help with particularly long commands (eg for loading a coinda env) it can be useful to setup a bash alias.
First make sure the following is in your .bashrc file

```bash
vim ~/.bashrc

# Inside the .bashrc file
if [ -f ~/.bash_aliases ]; then
. ~/.bash_aliases
fi
```

Then you can edit the aliases in a seperate file (recommended) or just put them into the .bashrc file.

```bash
vim ~/.bash_aliases

# Inside the .bash_aliases file
alias envload="module load conda/2; source activate python3; source activate <your_env_name>"
alias qu="squeue -u $USER"
```

---

## Basilisk

[![Basilisk Installer](https://github.com/highwave-project/ICHEC_help/actions/workflows/basilisk.yml/badge.svg)](https://github.com/highwave-project/ICHEC_help/actions/workflows/basilisk.yml)

To ensure issue free compilation of your basilisk code it is recommended to use the install script, you can also follow the steps on the [Basilisk website](http://basilisk.fr/src/INSTALL) yourself.

### Helpful links

- [Basilisk C manual](http://basilisk.fr/Basilisk%20C)
- [Installation guide](http://basilisk.fr/src/INSTALL)
- [Tutorial](http://basilisk.fr/Tutoria)
- [Examples](http://basilisk.fr/src/examples/README)

### Setting up Basilisk for the First Time

- An install script is provided in this repo. You can download and run it with the following command.
- NOTE: the environment variables you should select based on the install you want. If you do not explicitely set these, the default will be an install without sudo and without ffmpeg/OSMesa/GLU.
    - `export LOCAL_INSTALL=yes`: you have sudo access
    - `export BUILD_GRAPHICS=yes`: you require ffmpeg compiled, or OSMesa or GLU (This may take a long time...)
    - You likely only require one of the above, as if you have sudo access you can simply install the graphics binaries

```bash
cd ~
wget https://raw.githubusercontent.com/highwave-project/ICHEC_help/main/install_basilisk.sh
chmod a+x install_basilisk.sh
./install_basilisk.sh
```

- NOTE: Depending on the cluster you are installing on, you may need to `module load` some dependencies such as the gcc compiler and cmake. If possible you can also load the graphics libraries such as ffmpeg, osmesa and glu.

<details>
<summary>Example of setting flags</summary>

- Install Basilisk on your local computer for development purposes. You can follow the [Basilisk installation instructions](http://basilisk.fr/src/INSTALL)

```bash
cd ~ && \
wget https://raw.githubusercontent.com/highwave-project/ICHEC_help/main/install_basilisk.sh && \
chmod a+x install_basilisk.sh && \
export LOCAL_INSTALL=yes && \
./install_basilisk.sh
```

- Redo the install on the remote cluster. You should be in the folder which contains basilisk

```bash
cd ~ && \
wget https://raw.githubusercontent.com/highwave-project/ICHEC_help/main/install_basilisk.sh && \
chmod a+x install_basilisk.sh && \
export BUILD_GRAPHICS=yes && \
./install_basilisk.sh
```

</details>

### Additional Libraries

It may be easier to locally install OSMesa, GLU and FFmpeg yourself afterwhich you should not have to worry about exporting those paths and them being linked. This can be achieved through the install script above with `export BUILD_GRAPHICS=yes`

### Compiling Basilisk

- Basilisk comes with a helpful Makefile that can be used in compilation. You just need to create your own Makefile for your project and include the following

```makefile
CFLAGS += -O2
include $(BASILISK)/Makefile.defs
```

Because the Basilisk code is on ICHEC it is possible to compile directly with the qcc compiler, however if using MPI then the following method should be used.

- On your local computer you should compile to source with the MPI flag

```bash
qcc -source -D_MPI=1 example.c -I$BASILISK

# On ICHEC you can also compile with the command
$BASILISK/qcc -source -D_MPI=1 example.c -I$BASILISK
```

- This produces the source file `_example.c` which should be copied over to ICHEC (Note the underscore prefix!).
- On ICHEC you can then use the `mpicc` compiler to generate the executable.

```bash
module load intel/2019u5
mpicc -Wall -std=c99 -O2 _example.c -o example -L$BASILISK/gl -L$MESA/lib -L$GLU/lib -L$BASILISK/ppr -lOSMesa -lGLU -lfb_osmesa -lppr -lglutils -lgfortran -lm
```

- You may not require all the above libraries depending on your code (graphics with OSMesa or compiling fortran code etc.), but it is okay to copy paste the full line anyways.

---

## Other SLURM Commands

See the [ICHEC website](https://www.ichec.ie/academic/national-hpc/documentation/slurm-commands) and the [SLURM documentation](https://slurm.schedmd.com/documentation.html)

# Meluxina

Information about Meluxina HPC.

## Project ID and Resources

The command `myquota` can be used to monitor the resources (CPU/GPU hours, storage) as well as the user and project directories.

## Build/Interactive jobs

To build anything in Meluxina you need to allocated an iteractive node. This can be done with salloc:
```bash
salloc -A <project_number> -p cpu --qos defualt -N 1 -t 2-0:00:0 srun --mpi=none --pty bash -l
```

The above allocate a cpu interactive job and launches bash. It is also adviced to disable MPI via `--mpi=none` for building. The `-l` option is important as it launches bash as a login shell (if not the module command won't work).

Different QOS(`--qos`) can be specified like `test` if needed (`test` has higher priority but max time is 30 min).

## Batch jobs

The job submition is almost the same, however there are some things that are importand. In the shebang the `-l` option is important for the module command to work. Also, the number of cores are 64 in Meluxina. 

### Example MPI
```bash
#!/bin/bash -l
#SBATCH --nodes=5                          # number of nodes
#SBATCH --ntasks=640                       # number of tasks
#SBATCH --qos=default                      # SLURM qos
#SBATCH --ntasks-per-node=128              # number of tasks per node
#SBATCH --cpus-per-task=1                  # number of cores per task
#SBATCH --time=00:15:00                    # time (HH:MM:SS)
#SBATCH --partition=cpu                    # partition
#SBATCH --account=<myproj_id>                # project account

srun ./hello_world_mpi
```

### Example OpenMP

```bash
#!/bin/bash -l
#SBATCH --nodes=5                          # number of nodes
#SBATCH --ntasks=160                       # number of tasks
#SBATCH --ntasks-per-node=32               # number of tasks per node
#SBATCH --cpus-per-task=4                  # number of cores (OpenMP thread) per task
#SBATCH --time=00:15:00                    # time (HH:MM:SS)
#SBATCH --partition=cpu                    # partition
#SBATCH --qos=default                      # SLURM qos
#SBATCH --account=<myproj_id>                # project account


srun ./hello_world_mpiopenmp
```

### Example GPU job
```bash
#!/bin/bash -l
#SBATCH --nodes=1                          # number of nodes
#SBATCH --ntasks=8                         # number of tasks
#SBATCH --ntasks-per-node=4                # number of tasks per node
#SBATCH --gpus-per-task=1                  # number of gpu per task
#SBATCH --cpus-per-task=1                  # number of cores per task
#SBATCH --time=00:15:00                    # time (HH:MM:SS)
#SBATCH --partition=gpu                    # partition
#SBATCH --qos=default                      # SLURM qos
#SBATCH --account=<myproj_id>                # project account

srun ./hello_world_gpu
```


## Partitions and QOS

Information about the partitions and the QOS ca be found the [Meluxina quick start](https://docs.lxp.lu/first-steps/quick_start/).
