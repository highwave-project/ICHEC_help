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

The Basilisk source files are in the HIGHWAVE project directory on ICHEC already along with the graphics libraries for OSMesa and GLU. To ensure issue free compilation of your basilisk code it is recommended to follow this proceedure.

### Setting up Basilisk for the First Time

- Install Basilisk on your local computer for development purposes. You can follow the [Basilisk installation instructions](http://basilisk.fr/src/INSTALL)
- While logged into ICHEC, edit your `.bashrc` file which is in your home directory to include the following lines.

```bash
export BASILISK=/ichec/work/ndear024a/rsmith/basilisk/src
export PATH=$PATH:$BASILISK

export MESA=$BASILISK/../mesa-17.2.4
export GLU=$BASILISK/../glu-9.0.0
```

### Additional Libraries

It may be easier to locally install OSMesa, GLU and FFmpeg yourself afterwhich you should not have to worry about exporting those paths and them being linked. The following code block can be copy and pasted to the terminal, and may take an hour or two to finish.

```bash
mkdir ~/ffmpeg_sources
cd ~/ffmpeg_sources && \
wget https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2 && \
tar xjvf nasm-2.15.05.tar.bz2 && \
cd nasm-2.15.05 && \
./autogen.sh && \
PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
make -j10 && \
make install

cd ~/ffmpeg_sources && \
git -C x264 pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
cd x264 && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static --enable-pic && \
PATH="$HOME/bin:$PATH" make -j10 && \
make install

cd ~/ffmpeg_sources && \
wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2 && \
tar xjvf x265.tar.bz2 && \
cd multicoreware*/build/linux && \
PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off ../../source && \
PATH="$HOME/bin:$PATH" make -j10 && \
make install

cd ~/ffmpeg_sources && \
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
tar xjvf ffmpeg-snapshot.tar.bz2 && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --ld="g++" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-libx264 \
  --enable-libx265 && \
PATH="$HOME/bin:$PATH" make -j10 && \
make install

cd ~
wget http://basilisk.fr/src/gl/mesa-17.2.4.tar.gz
tar xzvf mesa-17.2.4.tar.gz
cd mesa-17.2.4
./configure --prefix=$HOME/local --enable-osmesa \
            --with-gallium-drivers=swrast                \
            --disable-driglx-direct --disable-dri --disable-gbm --disable-egl
make -j10
make install

cd ~
wget http://basilisk.fr/src/gl/glu-9.0.0.tar.gz
tar xzvf glu-9.0.0.tar.gz
cd glu-9.0.0
./configure --prefix=$HOME/local
make -j10
make install
```

### Compiling Basilisk

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
