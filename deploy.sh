#!/bin/bash
set -e

# Set the versions of the assembler, compiler and debugger to download & build
BINUTILS_VERSION="2.37"
GCC_VERSION="11.2.0"
GDB_VERSION="11.1"

# Boolean whether to print command output to stdout
OUTPUT=true

# Archive type, xz uses LZMA compression, gz uses GZIP compression 
# Choose 'xz' if you're low on disk space, or have a metered/slow internet connection
# or 'gz' if you've got a fast internet connection and want faster decompression times
AT="gz"

# Number of jobs = Number of CPU Cores + 1
export MAKEFLAGS="-j$JOBS"

function CheckOS {
    if [ $(uname) == "Darwin" ]; then
        OS="MacOS"
        JOBS=$(sysctl -n hw.ncpu)
    elif [ $(uname) == "Linux" ]; then
        OS="Linux"
        JOBS=$(nproc)
    fi

    if [ $OS == "MacOS" ]
    then
        echo -e "\033[92mYou appear to be running macOS, which requires the Xcode command line tools to be installed. Checking to see if developer tools are installed...\033[0m"
        if xcode-select --install 2>&1 | grep -q "installed"; then
            echo "Xcode is installed, continuing..."
        else
            echo -e "\033[92mThis tool can either call the Xcode installer, or you can choose to install it manually.\033[0m"
            echo "Press any key to continue, or CTRL-C to exit."
            read -n 1
            echo "Launching Xcode Installer now..."
            xcode-select --install
            exit 1

        fi
        
    fi
}

function CheckPrerequisites {
    echo -e "\033[92mChecking build prerequisites...\033[0m"
    local missing=0
    
    for cmd in gcc g++ make bison flex m4; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "\033[91mMissing: $cmd\033[0m"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo -e "\033[93mInstalling missing packages...\033[0m"
        if [ "$OS" == "Linux" ]; then
            sudo apt update
            sudo apt install -y gcc g++ make bison flex m4
        elif [ "$OS" == "MacOS" ]; then
            echo "Please install missing tools: brew install bison flex m4"
            exit 1
        fi
    else
        echo -e "\033[92mAll prerequisites found!\033[0m"
    fi
}

function pause {
    read -s -n 1 -p "Press any key to continue . . ."
    echo ""
}

function SetVars {

    echo -e "\033[92mExport variables \033[0m"
	export PREFIX="$HOME/.i686-elf/"
	export TARGET=i686-elf
	export PATH="$PREFIX/bin:$PATH"
}

function persistVars {
	# echo "#compiler target arch variables for i686-elf-* (OSDev)"
	echo 'export PREFIX="$HOME/.i686-elf/"' >> $HOME/.bashrc
	echo "export TARGET=i686-elf" >> $HOME/.bashrc
	echo 'export PATH="$PREFIX/bin:$PATH"' >> $HOME/.bashrc
}

function mkdirs {
	
    echo -e "\033[92mCreating directories...\033[0m"
	mkdir -p i686-elf-src
	cd i686-elf-src 
	# Make directories
	mkdir -p build-binutils
	mkdir -p build-gcc
	mkdir -p build-gdb
	mkdir -p $HOME/.i686-elf
}




function DownloadSources () {
    
	echo -e "\033[92mDownload sources\033[0m"
    if [ "$AT" == "gz" ]
    then
        echo "Using GZIP compression"
    fi
    if [ "$AT" == "xz" ]
    then
        echo "Using LZMA compression"
    fi
    if [ $OUTPUT == false ]
    then
        wget -cq https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.$AT
	    wget -cq https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.$AT
    	wget -cq https://ftp.gnu.org/gnu/gdb/gdb-$GDB_VERSION.tar.$AT

    else
        wget -c https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.$AT
	    wget -c https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.$AT
	    wget -c https://ftp.gnu.org/gnu/gdb/gdb-$GDB_VERSION.tar.$AT

    fi
	
	if [ "$AT" == "gz" ]	
	then
		for filename in *.tar.gz
		do	
		    echo -e "\033[92mExtracting tar.gz archive...\033[0m"
            if [ $OUTPUT == false ]
            then
                tar -xzf $filename > /dev/null
            else
    			tar -xvzf $filename
            fi
		done
	elif [ "$AT" == "xz" ]
	then
		for filename in *.tar.xz
		do	
		    echo -e "\033[92mExtracting tar.xz archive...\033[0m"
			if [ $OUTPUT == false ]
            then
                tar -xf $filename
            else
                tar -xvf $filename
            fi
		done
	fi

	echo -e "\033[92mDownload GCC prerequisites\033[0m"
	cd gcc-*/
    if [ $OUTPUT == false ]
    then
        contrib/download_pre* > /dev/null
    else
        contrib/download_pre*
    fi
	cd ..
}



# Onto the main build!

function MakeBinutils {
    echo -e "\033[92mConfigure, build and install binutils\033[0m"

    cd $HOME/i686-elf-src
    rm -rf build-binutils
    mkdir build-binutils
    cd build-binutils
	
    if [ $OUTPUT == false ]
    then
        ../binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror > binutils-configure.txt > /dev/null
        make > binutils-make.txt > /dev/null 
	    make install > binutils-install.txt > /dev/null
    else
        ../binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror > binutils-configure.txt
        make > binutils-make.txt
	    make install > binutils-install.txt
    fi
	cd ..
}


function MakeGCC {
    echo -e "\033[92mConfigure, build and install GCC cross compiler\033[0m"
    
    # Verify binutils installed correctly
    if ! command -v $TARGET-as &> /dev/null; then
        echo -e "\033[91mError: $TARGET-as not found in PATH. Did binutils install correctly?\033[0m"
        echo "Current PATH: $PATH"
        exit 1
    fi
    
    cd $HOME/i686-elf-src
    rm -rf build-gcc
    mkdir build-gcc
    cd build-gcc
    
    if [ $OUTPUT == false ]
    then
        ../gcc-$GCC_VERSION/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c --without-headers --disable-multilib > gcc-configure.log 2>&1
        make all-gcc > all-gcc.log 2>&1 
        make all-target-libgcc > all-target-libgcc.log 2>&1
        make install-gcc > install-gcc.log 2>&1
        make install-target-libgcc > install-target-libgcc.log 2>&1
    else
        echo "Configuring GCC..."
        ../gcc-$GCC_VERSION/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c --without-headers --disable-multilib 2>&1 | tee gcc-configure.log
        
        # Check if configure succeeded
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo -e "\033[91mGCC configure failed! Check gcc-configure.log\033[0m"
            exit 1
        fi
        
        echo "Building GCC (this will take 15-30 minutes)..."
        make -j$JOBS all-gcc 2>&1 | tee all-gcc.log
        echo "Building libgcc..."
        make -j$JOBS all-target-libgcc 2>&1 | tee all-target-libgcc.log
        echo "Installing GCC..."
        make install-gcc 2>&1 | tee install-gcc.log
        make install-target-libgcc 2>&1 | tee install-target-libgcc.log
    fi
    
    cd ../..
}

function MakeGDB {
    echo -e "\033[92mConfigure, build and install GDB\033[0m"
    
    cd $HOME/i686-elf-src
    rm -rf build-gdb
    mkdir build-gdb
    cd build-gdb
    
    if [ $OUTPUT == false ]
    then
        ../gdb-$GDB_VERSION/configure --target=$TARGET --disable-nls --disable-werror --prefix=$PREFIX > gdb-configure.log 2>&1
        make > gdb-make.log 2>&1
        make install > gdb-install.log 2>&1
    else
        echo "Configuring GDB..."
        ../gdb-$GDB_VERSION/configure --target=$TARGET --disable-nls --disable-werror --prefix=$PREFIX 2>&1 | tee gdb-configure.log
        echo "Building GDB (this may take a while)..."
        make -j$JOBS 2>&1 | tee gdb-make.log
        echo "Installing GDB..."
        make install 2>&1 | tee gdb-install.log
    fi
    
    cd $HOME
}


function cleanUp {

    echo -e "\033[92mCleaning up source files...\033[0m"
	rm -rf i686-elf-src
}


function main() {
    pushd $HOME
    arg=$1
    CheckOS
    CheckPrerequisites
    
    if [ "$*" == "--silent" ]
    then
        OUTPUT=false
    fi

    if [ "$arg" == "--clean" ] || [ "$arg" == "-c" ]
	then
		cleanUp
        exit
	fi

    SetVars
	mkdirs
    
    if [ "$arg" == "--download" ] || [ "$arg" == "-dl" ]
	then
		DownloadSources
        exit
	elif [ "$arg" == "makebin" ]
	then
		echo -e "\033[92mMaking i686 Binutils\033[0m"
        DownloadSources
		MakeGDB
		
	elif [ "$arg" == "makegcc" ]
	then
		echo -e "\033[92mMaking i686 Binutils + GCC\033[0m"
		DownloadSources
        MakeBinutils
		MakeGCC
		
	elif [ "$arg" == "makegdb" ]
	then
		echo -e "\033[92mMaking i686 Binutils + GDB\033[0m"
        DownloadSources
		MakeBinutils
		MakeGDB
		
	elif [ "$arg" == "nopersist" ]
	then
        DownloadSources
        MakeBinutils
        MakeGCC
        MakeGDB
        
    else
	    if [ $OUTPUT == false ]
        then
            echo -e "\033[92mRunning quietly...\033[0m"
        else
            echo -e "\033[92mRunning normally...\033[0m"
		fi
		persistVars
		DownloadSources

		MakeBinutils
		MakeGCC
		MakeGDB

		
	fi
    cleanUp
    popd
    exit
}

main $@
