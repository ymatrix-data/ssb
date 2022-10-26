#!/bin/bash

set -e

default_scale=1
scale=$default_scale
raw_csv=""

# check requirements: make, gcc, tar, zstd
function check_requirements() {
    echo "Checking for required packages to be installed..."
    echo ""
    ext_pkgs="make gcc tar zstd"
    for p in $ext_pkgs
    do
        if [ "$(which $p)" = "" ]; then
            echo "'$p' is required but not found in $PATH"
        fi
        found_path=$(which $p)
        echo "'$p' is located in $found_path - ok."
    done
    echo ""
    echo "All required packages are installed."
    echo ""
}

function show_help()
{
    cat << EOF
Generate Dataset for MatrixDB(c) Star Schema Benchmark(SSB).

Args:
   -h
      Show help message.
   
   -r [rawfile]
      Optional, output files are compressed in Z-standard with ztsd, and you can specify -r to let dataset keep raw csv files.
   
   -s [scale] 
      Required, scale of the generated dataset. Generate dataset of gigabytes(GB) in specified scale, i.e, specify -s 10 will generate a 10GB dataset 

Usage:

    Generate 10GB dataset: 
    
        ./generate_data.sh -s 10

EOF
}

function parse_args()
{
    OPTIND=1
    while getopts ":r :s:h" opt; do
    case "$opt" in
        s) scale="$OPTARG" ;;
        r)
        raw_csv="true"
        ;;
        h)
        show_help
        exit 0
        ;;
        \?)
        printf "%s\n" "Invalid Option! -$OPTARG" >&2
        exit 1
        ;;
        :)
        printf "%s\n" "-$OPTARG requires an argument" >&2
        exit 1
        ;;
    esac
    done
    shift "$((OPTIND - 1))"
}

parse_args $@
if [ "$scale" -gt "1000" ]; then
    echo "[WARN] You specified scale=${scale} larger than 1000GB, which is still an experimental feature."
fi

check_requirements

################ Generate dateset ################
curdir=$(pwd)
generated=$curdir/generated
datadir=$generated/scale-${scale}-data

rm -rf $datadir
mkdir -p $datadir

dbgendir="$curdir/ssb-dbgen"

if [ -d "$dbgendir" ]; then
    rm -rf $dbgendir
fi
tar -zvxf ${dbgendir}.tar.gz
cd ${dbgendir}
make

cd $datadir
ln -nfs ${dbgendir}/dists.dss .
${dbgendir}/dbgen -s $scale -T c
${dbgendir}/dbgen -s $scale -T l
${dbgendir}/dbgen -s $scale -T p
${dbgendir}/dbgen -s $scale -T s

suffix=".zst"
if [ "$raw_csv" != "true" ]; then
    tables="customer lineorder part supplier"
    for table in $tables; do
        zstd --rm ${table}.tbl
    done
    suffix=""
fi


echo ""
cat << EOF
Successfully generated dataset of ${scale}GB under $datadir:

* customer: $datadir/customer.tbl${suffix}
* lineorder: $datadir/lineorder.tbl${suffix}
* part: $datadir/part.tbl${suffix}
* supplier: $datadir/supplier.tbl${suffix}

You can now import data into MatrixDB via:

    ./import_data.sh -s ${scale}

EOF
