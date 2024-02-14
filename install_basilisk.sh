JOBS=$(nproc)
# Where the basilisk will be installed
INSTALL_PREFIX=${INSTALL_PREFIX:-$HOME}
# Where the dependecies (osmesa, glu, ffmpeg) will be installed
DEPS_PREFIX=${DEPS_PREFIX:-"$HOME/local"}

if [[ ! -z $TESTING ]]; then
    source $HOME/.bashrc
    echo "Testing only"
    cd $BASILISK/test
    make -j "$JOBS" >/dev/null || { echo 'testing failed' && exit 1; }
    exit 0
fi

# clean up old folders
rm -rf $INSTALL_PREFIX/basilisk* $DEPS_PREFIX/ffmpeg* $DEPS_PREFIX/mesa* $DEPS_PREFIX/glu*
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
    tar xzf basilisk.tar.gz -C $INSTALL_PREFIX >/dev/null
    rm basilisk.tar.gz
fi

# if on a cluster with module, check if the following can be loaded
if which module; then
    module load GCC CMake Mesa Mako intel FFmpeg
fi

echo "Building Basilisk..."
cd $INSTALL_PREFIX/basilisk/src
ln -s config.gcc config
make -k -j "$JOBS" >/dev/null
make  # incase of any failures from previous command

if [[ -e "$HOME/.zshrc" ]]; then
    shellrc="$HOME/.zshrc"
else
    shellrc="$HOME/.bashrc"
fi

if ! grep -q 'BASILISK' $shellrc; then
    # Ask user to modify PATH
    while true; do
        msg="Add basilisk to PATH in $shellrc (y/n)? "
        read -p "$msg" yn
        case $yn in
            [Yy] | [Yy]es )
                echo "Export environment variables to shell config"
                echo -e '\n#Basilisk Env' >> "$shellrc"
                echo "export BASILISK=$PWD" >> "$shellrc"
                echo 'export PATH=$PATH:$BASILISK' >> "$shellrc"  # single quotes to not expand $PATH
                break;;
            [Nn] | [Nn]o ) break;;
            * ) echo "Please answer y or n.";;
        esac
    done
fi

if [[ ! -z $BUILD_GRAPHICS ]]; then
    echo "Graphics building enabled..."

    if ! which ffmpeg; then
        mkdir $DEPS_PREFIX/ffmpeg_sources

        if ! which nasm; then # Install asm compiler
            echo "---------------- Asm"
            cd $DEPS_PREFIX/ffmpeg_sources
            wget https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2 >/dev/null
            tar xjvf nasm-2.15.05.tar.bz2 >/dev/null
            cd nasm-2.15.05 
            ./autogen.sh >/dev/null
            PATH="$DEPS_PREFIX/bin:$PATH" ./configure --prefix="$DEPS_PREFIX/ffmpeg_build" --bindir="$DEPS_PREFIX/bin" >/dev/null
            make -j "$JOBS" >/dev/null || { echo 'nasm build failed' && exit 1; }
            make install >/dev/null || { echo 'nasm install failed' && exit 1; }
        fi

        if ! which x264; then # Install support for x264 video encoding
            echo "---------------- x264"
            cd $DEPS_PREFIX/ffmpeg_sources && \
            git clone --depth 1 https://code.videolan.org/videolan/x264.git >/dev/null
            cd x264 && \
            PATH="$DEPS_PREFIX/bin:$PATH" PKG_CONFIG_PATH="$DEPS_PREFIX/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$DEPS_PREFIX/ffmpeg_build" --bindir="$DEPS_PREFIX/bin" --enable-static --enable-pic >/dev/null
            PATH="$DEPS_PREFIX/bin:$PATH" make -j "$JOBS" >/dev/null || { echo 'x264 build failed' && exit 1; }
            make install >/dev/null || { echo 'x264 install failed' && exit 1; }
        fi

        if ! which x265; then # Install support for x265 video encoding
            echo "---------------- x265"
            cd $DEPS_PREFIX/ffmpeg_sources && \
            wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2 >/dev/null
            tar xjvf x265.tar.bz2 >/dev/null
            cd multicoreware*/build/linux && \
            PATH="$DEPS_PREFIX/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX/ffmpeg_build" -DENABLE_SHARED=off ../../source >/dev/null
            PATH="$DEPS_PREFIX/bin:$PATH" make -j "$JOBS" >/dev/null || { echo 'x265 build failed' && exit 1; }
            make install >/dev/null || { echo 'x265 install failed' && exit 1; }
        fi

        echo "---------------- FFMPEG"
        cd $DEPS_PREFIX/ffmpeg_sources && \
        wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 >/dev/null
        tar xjvf ffmpeg-snapshot.tar.bz2 >/dev/null
        cd ffmpeg && \
        PATH="$DEPS_PREFIX/bin:$PATH" PKG_CONFIG_PATH="$DEPS_PREFIX/ffmpeg_build/lib/pkgconfig" ./configure \
        --prefix="$DEPS_PREFIX/ffmpeg_build" \
        --pkg-config-flags="--static" \
        --extra-cflags="-I$DEPS_PREFIX/ffmpeg_build/include" \
        --extra-ldflags="-L$DEPS_PREFIX/ffmpeg_build/lib" \
        --extra-libs="-lpthread -lm" \
        --ld="g++" \
        --bindir="$DEPS_PREFIX/bin" \
        --enable-gpl \
        --enable-libx264 \
        --enable-libx265 >/dev/null
        PATH="$DEPS_PREFIX/bin:$PATH" make -j "$JOBS" >/dev/null || { echo 'ffmpeg build failed' && exit 1; }
        make install >/dev/null || { echo 'ffmpeg install failed' && exit 1; }
    fi

    if ! /sbin/ldconfig -N -v $(sed 's/:/ /g' <<< $LD_LIBRARY_PATH)| grep libOSMesa.so; then
        cd $DEPS_PREFIX
        echo "---------------- OSMESA"
        wget http://basilisk.fr/src/gl/mesa-17.2.4.tar.gz >/dev/null
        tar xzvf mesa-17.2.4.tar.gz >/dev/null
        cd mesa-17.2.4
        ./configure --prefix=$DEPS_PREFIX --enable-osmesa \
                    --with-gallium-drivers=swrast                \
                    --disable-driglx-direct --disable-dri --disable-gbm --disable-egl >/dev/null
        make -j "$JOBS" >/dev/null || (echo 'osmesa build failed' && exit 1)
        make install >/dev/null || (echo 'osmesa install failed' && exit 1)
    fi

    # I guess always install GLU
    cd $DEPS_PREFIX
    echo "---------------- GLU"
    wget http://basilisk.fr/src/gl/glu-9.0.0.tar.gz >/dev/null
    tar xzvf glu-9.0.0.tar.gz >/dev/null
    cd glu-9.0.0
    export CFLAGS="-I$DEPS_PREFIX/include"
    export LDFLAGS="-L$DEPS_PREFIX/lib"
    ./configure --prefix=$DEPS_PREFIX >/dev/null
    make -j "$JOBS" >/dev/null || { echo 'glu build failed' && exit 1; }
    make install >/dev/null || { echo 'glu install failed' && exit 1; }
    cd ..

    # Ask user to add dependencies to different paths.
    while true; do
        msg="Add $DEPS_PREFIX/bin to PATH in $shellrc (y/n)? "
        read -p "$msg" yn
        case $yn in
            [Yy] | [Yy]es )
                echo "export PATH=\$PATH:$DEPS_PREFIX/bin" >> "$shellrc"
                echo "Done"
                break;;
            [Nn] | [Nn]o ) break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    while true; do
        msg="Add $DEPS_PREFIX/lib to LIBRARY_PATH in $shellrc (y/n)? "
        read -p "$msg" yn
        case $yn in
            [Yy] | [Yy]es )
                echo "export LIBRARY_PATH=$DEPS_PREFIX/lib\${LIBRARY_PATH:+:\$LIBRARY_PATH}" >> "$shellrc"
                echo "Done"
                break;;
            [Nn] | [Nn]o ) break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    while true; do
        msg="Add $DEPS_PREFIX/lib to LD_LIBRARY_PATH in $shellrc (y/n)? "
        read -p "$msg" yn
        case $yn in
            [Yy] | [Yy]es )
                echo "export LD_LIBRARY_PATH=$DEPS_PREFIX/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}" >> "$shellrc"
                break;;
            [Nn] | [Nn]o ) break;;
            * ) echo "Please answer y or n.";;
        esac
    done
    while true; do
        msg="Add $DEPS_PREFIX/include to C_INCLUDE_PATH in $shellrc (y/n)? "
        read -p "$msg" yn
        case $yn in
            [Yy] | [Yy]es )
                echo "export C_INCLUDE_PATH=$DEPS_PREFIX/lib\${C_INCLUDE_PATH:+:\$C_INCLUDE_PATH}" >> "$shellrc"
                echo "Done"
                break;;
            [Nn] | [Nn]o ) break;;
            * ) echo "Please answer y or n.";;
        esac
    done

    echo "Cleaning up..."
    cd $DEPS_PREFIX && rm -rf *.tar.gz ffmpeg_sources
else
    echo "Graphics build disabled..."
fi

CFLAGS="-I$DEPS_PREFIX/include -std=gnu99"
LDFLAGS="-L$DEPS_PREFIX/lib"
cd $HOME/basilisk/src/ppr
make && cd ../gl 
make libglutils.a libfb_osmesa.a || { echo "failed building src/gl" && exit 1; }

echo "Installation finished..."
