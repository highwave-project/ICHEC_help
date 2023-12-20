if [[ ! -z $TESTING ]]; then
    echo "Testing only"
    cd $BASILISK/test
    make -k -j $(nproc)
    exit 0
fi

# Install packages
if [[ ! -z $LOCAL_INSTALL ]]; then
    echo "Local installation with access to sudo for installing"
    if which apt; then
        sudo apt update
        sudo apt install darcs make gawk gfortran gnuplot imagemagick ffmpeg graphviz valgrind gifsicle pstoedit mesa-utils libgl-dev freeglut3 freeglut3-dev
    elif which pacman; then
        sudo pacman -S darcs make gawk gcc-fortran gnuplot imagemagick ffmpeg graphviz valgrind gifsicle pstoedit
    fi
    # Clone the Basilisk repo
    darcs clone --lazy http://basilisk.fr/basilisk
else
    echo "Installation with no access to sudo"
    wget http://basilisk.fr/basilisk/basilisk.tar.gz
    tar xzf basilisk.tar.gz
fi

echo "Building Basilisk..."
cd basilisk/src
ln -s config.gcc config
make -k -j $(nproc)
make   # incase of any failures from previous command

cd ppr && make && cd ..
cd gl && make libglutils.a libfb_osmesa.a && cd ..

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
            cd $HOME/ffmpeg_sources && \
            wget https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2 && \
            tar xjvf nasm-2.15.05.tar.bz2 && \
            cd nasm-2.15.05 && \
            ./autogen.sh && \
            PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
            make -j $(nproc) --silent && \
            make install
        fi

        if ! which x264; then # Install support for x264 video encoding
            echo "---------------- x264"
            cd $HOME/ffmpeg_sources && \
            git -C x264 pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
            cd x264 && \
            PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static --enable-pic && \
            PATH="$HOME/bin:$PATH" make -j $(nproc) --silent && \
            make install
        fi

        if ! which x265; then # Install support for x265 video encoding
            echo "---------------- x265"
            cd $HOME/ffmpeg_sources && \
            wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2 && \
            tar xjvf x265.tar.bz2 && \
            cd multicoreware*/build/linux && \
            PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off ../../source && \
            PATH="$HOME/bin:$PATH" make -j $(nproc) --silent && \
            make install
        fi

        echo "---------------- FFMPEG"
        cd $HOME/ffmpeg_sources && \
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
        PATH="$HOME/bin:$PATH" make -j $(nproc) --silent && \
        make install
    fi

    cd $HOME
    echo "---------------- OSMESA"
    wget http://basilisk.fr/src/gl/mesa-17.2.4.tar.gz
    tar xzvf mesa-17.2.4.tar.gz
    cd mesa-17.2.4
    ./configure --prefix=$HOME/local --enable-osmesa \
                --with-gallium-drivers=swrast                \
                --disable-driglx-direct --disable-dri --disable-gbm --disable-egl
    make -j $(nproc) --silent
    make install

    cd $HOME
    echo "---------------- GLU"
    wget http://basilisk.fr/src/gl/glu-9.0.0.tar.gz
    tar xzvf glu-9.0.0.tar.gz
    cd glu-9.0.0
    ./configure --prefix=$HOME/local
    make -j $(nproc) --silent
    make install
    cd ..

    echo "export PATH=$PATH:$HOME/local" >> "$shellrc"

    echo "Cleaning up..."
    cd $HOME && rm -r *.tar.gz ffmpeg_sources
else
    echo "Graphics build disabled..."
fi

echo "Installation finished..."
