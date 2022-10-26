#!/bin/bash

set -e

# constants
COPY_IMPORT="copy"
MXGATE_IMPORT="mxgate"
ssb_database_name=""

# default settings
import_type=$MXGATE_IMPORT # must be one of [copy, mxgate]
scale="1" # scale of dataset, and located under generated/scale-${scale}-data/

function show_help()
{
    cat << EOF
Import generated dataset import database via COPY, mxgate or external tables.

!!!WARNING!!! this script will cleanup existing data, and make sure you have backup everything before you go.

Args:
   -h
      Show help message.

   -D [custom_database_name]
      Specify custom database name to import generated dataset.

   -s [scale] 
      Required, scale of the generated dataset in gigabytes, and specify this option to import a desired dataset with specified scale.
      
   -t [import_type]
    Optional, import type, must be one of copy|mxgate, default is mxgate

Usage:
    Import 1G dataset into target MatrixDB:
        ./import_data.sh -s 1

    Import 1G dataset into target MatrixDB via copy:
        ./import_data.sh -s 1 -t copy

    Import 1G dataset into a custom database:
        ./import_data.sh -s 1 -D mydatabase_1g
    
    Below environment variables are also supported to allow you to connect to a custom MatrixDB cluster:
        PGHOST, PGPORT, PGUSER, PGPASSWORD

EOF
}

# check requirements: zstdcat
function check_requirements() {
    echo "Checking for required packages to be installed..."
    echo ""
    ext_pkgs="zstdcat"
    for p in $ext_pkgs
    do
        if [ "$(which $p)" = "" ]; then
            echo "[ERROR] '$p' is required but not found in $PATH, you may install these dependencies and retry."
        fi
        found_path=$(which $p)
        echo "'$p' is located in $found_path - ok."
    done
    echo ""
    echo "All required packages are installed."
    echo ""
}

function parse_args()
{
    OPTIND=1
    while getopts ":t:D:s:h" opt; do
    case "$opt" in
        s) scale="$OPTARG" ;;
        t) import_type="$OPTARG";;
        D) ssb_database_name="$OPTARG";;
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

function do_copy_import() {
    ssb_database_name=$1
    if [ -z "$ssb_database_name" ]; then
        echo "ssb_database_name is required."
        exit 1
    fi

    generated_datadir=$2
    if [ -z "$generated_datadir" ]; then
        generated_datadir="./generated/scale-${scale}-data"
    fi

    import_data_dir=$3
    if [ -z "$import_data_dir" ]; then
        import_data_dir=./import_data
    fi

    tables="lineorder customer part supplier"
    for t in $tables
    do
        echo "Importing table $t ..."

        import_sql="copy ${t} from program 'zstdcat --quiet ${datadir}/${t}.tbl.zst' with (format csv, delimiter ',', header off);"
        psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "$import_sql"
        # ANALYZE table after importing the data
        psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "ANALYZE ${t}"
        echo "Finished importing table $t ..."
    done
}

function do_mxgate_import()
{
    ssb_database_name=$1
    if [ -z "$ssb_database_name" ]; then
        echo "ssb_database_name is required."
        exit 1
    fi

    generated_datadir=$2
    if [ -z "$generated_datadir" ]; then
        generated_datadir="./generated/scale-${scale}-data"
    fi

    import_data_dir=$3
    if [ -z "$import_data_dir" ]; then
        import_data_dir=./import_data
    fi

    echo "do_mxgate_import $@"

    tables="customer lineorder part supplier"
    for table in $tables; do
        zstdcat --quiet ${generated_datadir}/${table}.tbl.zst \
        | mxgate \
            --db-database=${ssb_database_name} \
            --source=stdin \
            --time-format=raw \
            --format=csv \
            --target=${table} \
            --delimiter=, \
            --parallel=128 \
            --stream-prepared=3 \
            --interval=250 \
            $NULL
        
        psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "ANALYZE ${table}"
    done
}

parse_args $@
if [ "$scale" -gt "1000" ]; then
    echo "[WARN] You specified scale=${scale} larger than 1000GB, which is still an experimental feature."
fi

check_requirements

curdir=$(pwd)
import_data_dir=$curdir/import_data
generated=$curdir/generated
datadir=$generated/scale-${scale}-data

# dynamic int vs bigint against different scale=100..1000,
# using bigint for scale > 100
dynaint="int"
if [ "$scale" -gt "100" ]; then
    dynaint=bigint
fi

# Separated database name for given scale.
if [ -z "${ssb_database_name}" ]; then
    ssb_database_name="ssb_scale_${scale}"
fi

if [ "$( psql -Aqt -P pager=off -d postgres -c "SELECT 1 FROM pg_database WHERE datname='${ssb_database_name}'" )" = '1' ]
then
    echo "[ERROR] database [${ssb_database_name}] exists, please drop it or use a custom database name."
    exit 1
else
    echo "Database does not exist, creating ${ssb_database_name}..."
    psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -v dynaint=${dynaint} -d postgres -c "create database ${ssb_database_name}"
fi

psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -v dynaint=${dynaint} -d $ssb_database_name -f $import_data_dir/ddl.sql

echo "import_type=${import_type}"

if [ "$import_type" = "${COPY_IMPORT}" ]; then
    do_copy_import "${ssb_database_name}" "${datadir}" "${import_data_dir}"
fi

if [ "$import_type" = "${MXGATE_IMPORT}" ]; then
    do_mxgate_import "${ssb_database_name}" "${datadir}" "${import_data_dir}"
fi

echo ""
cat << EOF
Successfully import dataset of ${scale}GB under $datadir into database [${ssb_database_name}]:

* customer: $datadir/customer.tbl${suffix}
* lineorder: $datadir/lineorder.tbl${suffix}
* part: $datadir/part.tbl${suffix}
* supplier: $datadir/supplier.tbl${suffix}

Now you can generate a flatten table to run SSB benchmark.

   ./generate_flat_table.sh -s ${scale} -D ${ssb_database_name}

EOF