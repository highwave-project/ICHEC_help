JOBS=$(nproc)

if [[ ! -z $TESTING ]]; then
    source $HOME/.bashrc
    echo "Testing only"
    cd $BASILISK/test
    make -j "$JOBS" >/dev/null || { echo 'testing failed' && exit 1; }
    exit 0
fi

# clean up old folders
rm -rf basilisk* ffmpeg* bin* "local*" mesa* glu* 
# Install packages
if [[ ! -z $LOCAL_INSTALL ]]; then
    echo "Local installation with access to sudo for installing"
    if which apt; then
        sudo apt update >/dev/null
        sudo apt install darcs make gawk gfortran gnuplot imagemagick ffmpeg graphviz valgrind gifsicle pstoedit mesa-utils libgl-dev freeglut3 freeglut3-dev libosmesa6-dev >/dev/null
    elif which pacman; then
        sudo pacman -S darcs make gawk gcc-fortran gnuplot imagemagick ffmpeg graphviz valgrind gifsicle pstoedit
    fi
    # Clone the Basilisk repo
    darcs clone --lazy http://basilisk.fr/basilisk >/dev/null
else
    echo "Installation with no access to sudo"
    wget http://basilisk.fr/basilisk/basilisk.tar.gz
    tar xzf basilisk.tar.gz >/dev/null
fi

# if on a cluster with module, check if the following can be loaded
if which module; then
    module load GCC CMake Mesa Mako intel gcc
fi

echo "Building Basilisk..."
cd basilisk/src
ln -s config.gcc config
make -k -j "$JOBS" >/dev/null
make  # incase of any failures from previous command

if [[ -e "$HOME/.zshrc" ]]; then
    shellrc="$HOME/.zshrc"
else
    shellrc="$HOME/.bashrc"
fi

if ! grep -q 'BASILISK' $shellrc; then
    echo "Export environment variables to shell config"
    echo -e '\n#Basilisk Env' >> "$shellrc"
    echo "export BASILISK=$PWD" >> "$shellrc"
    echo 'export PATH=$PATH:$BASILISK' >> "$shellrc"  # single quotes to not expand $PATH
fi

if [[ ! -z $BUILD_GRAPHICS ]]; then
    echo "Graphics building enabled..."

    if ! which ffmpeg; then
        mkdir $HOME/ffmpeg_sources

        if ! which nasm; then # Install asm compiler
            echo "---------------- Asm"
            cd $HOME/ffmpeg_sources
            wget https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2 >/dev/null
            tar xjvf nasm-2.15.05.tar.bz2 >/dev/null
            cd nasm-2.15.05 
            ./autogen.sh >/dev/null
            PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" >/dev/null
            make -j "$JOBS" >/dev/null || { echo 'nasm build failed' && exit 1; }
            make install >/dev/null || { echo 'nasm install failed' && exit 1; }
        fi

        if ! which x264; then # Install support for x264 video encoding
            echo "---------------- x264"
            cd $HOME/ffmpeg_sources && \
            git clone --depth 1 https://code.videolan.org/videolan/x264.git >/dev/null
            cd x264 && \
            PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static --enable-pic >/dev/null
            PATH="$HOME/bin:$PATH" make -j "$JOBS" >/dev/null || { echo 'x264 build failed' && exit 1; }
            make install >/dev/null || { echo 'x264 install failed' && exit 1; }
        fi

        if ! which x265; then # Install support for x265 video encoding
            echo "---------------- x265"
            cd $HOME/ffmpeg_sources && \
            wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2 >/dev/null
            tar xjvf x265.tar.bz2 >/dev/null
            cd multicoreware*/build/linux && \
            PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off ../../source >/dev/null
            PATH="$HOME/bin:$PATH" make -j "$JOBS" >/dev/null || { echo 'x265 build failed' && exit 1; }
            make install >/dev/null || { echo 'x265 install failed' && exit 1; }
        fi

        echo "---------------- FFMPEG"
        cd $HOME/ffmpeg_sources && \
        wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 >/dev/null
        tar xjvf ffmpeg-snapshot.tar.bz2 >/dev/null
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
        --enable-libx265 >/dev/null
        PATH="$HOME/bin:$PATH" make -j "$JOBS" >/dev/null || { echo 'ffmpeg build failed' && exit 1; }
        make install >/dev/null || { echo 'ffmpeg install failed' && exit 1; }
    fi

    cd $HOME
    echo "---------------- OSMESA"
    wget http://basilisk.fr/src/gl/mesa-17.2.4.tar.gz >/dev/null
    tar xzvf mesa-17.2.4.tar.gz >/dev/null
    cd mesa-17.2.4
    ./configure --prefix=$HOME/local --enable-osmesa \
                --with-gallium-drivers=swrast                \
                --disable-driglx-direct --disable-dri --disable-gbm --disable-egl >/dev/null
    make -j "$JOBS" >/dev/null || (echo 'osmesa build failed' && exit 1)
    make install >/dev/null || (echo 'osmesa install failed' && exit 1)

    cd $HOME
    echo "---------------- GLU"
    wget http://basilisk.fr/src/gl/glu-9.0.0.tar.gz >/dev/null
    tar xzvf glu-9.0.0.tar.gz >/dev/null
    cd glu-9.0.0
    ./configure --prefix=$HOME/local >/dev/null
    make -j "$JOBS" >/dev/null || { echo 'glu build failed' && exit 1; }
    make install >/dev/null || { echo 'glu install failed' && exit 1; }
    cd ..

    echo "export CFLAGS=-I$HOME/local/include" >> "$shellrc"
    echo "export LDFLAGS=-L$HOME/local/lib" >> "$shellrc"

    echo "Cleaning up..."
    cd $HOME && rm -rf *.tar.gz ffmpeg_sources
else
    echo "Graphics build disabled..."
fi

CFLAGS="-I$HOME/local/include -std=gnu99"
LDFLAGS="-L$HOME/local/lib"
cd $HOME/basilisk/src/ppr
make && cd ../gl 
make libglutils.a libfb_osmesa.a || { echo "failed building src/gl" && exit 1; }

echo "Installation finished..."
