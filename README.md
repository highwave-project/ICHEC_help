# ICHEC Commands

A short but useful quick-start guide to ICHEC. This is written for Linux users as many of the commands can be more difficult using a Windows system (if you dont use Linux, I recommend starting to use Linux).

## Contents

- [Logging In](#logging-in)
- [Filesystem and Copying](#filesystem-and-copying)
- [Loading Modules and Environments](#loading-modules-and-environments)
- [Requesting Compute Nodes](#requesting-compute-nodes)
- [Useful Commands](#useful-commands)
- [Using Aliases](#using-aliases)
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
cd ../../../work/<project_code>
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

Compute nodes can be run interactively, or you can queue longer jobs to run with more resourses.

```bash
# Interactive
srun -p DevQ -N 1 -A <myproj_id> -t 1:00:00 --pty bash
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

Then you can edit the aliases in a seperate file

```bash
vim ~/.bash_aliases

# Inside the .bash_aliases file
alias envload="module load conda/2; source activate python3; source activate <your_env_name>"
```

---

## Other SLURM Commands

See the [ICHEC website](https://www.ichec.ie/academic/national-hpc/documentation/slurm-commands)
