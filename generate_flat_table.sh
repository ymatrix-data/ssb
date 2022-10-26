#!/bin/bash

set -e

# default setting
scale=1

index_columns="s_region,c_region,p_mfgr,s_nation,c_nation,p_category,lo_orderdate"
partition_interval="1"
partition_unit="year"

ssb_database_name=""

enum_table_name=f_lz4_mars2

function show_help()
{
    cat << EOF
Generate fat table with dataset in given scale.

Args:
   -h
      Show help message.
   
   -D [custom_database_name]
      Specify custom database name to generate a flatten table.

   -s [scale] 
      Required, scale of the generated dataset in gigabytes(GB), and specify this option to 
      create the flatten along with desired dataset.

   -i [partition_interval]
      Optional, default '1 year', specify custom partition interval.
   

Usage:

    Generate flat table with 1GB dataset.

        ./generate_flat_table.sh -s 1
    
    Generate flat table with monthly partition.

        ./generate_flat_table.sh -s 1 -i '1 month'
EOF
}

function parse_args()
{
    OPTIND=1
    while getopts ":h :o:D:i:m:p:e:t:c:s:x" opt; do
    case "$opt" in
        s) scale="$OPTARG" ;;
        i)
        partition_interval=$(echo "$OPTARG"|awk -F'=' '{ print $1 }')
        partition_unit=$(echo "$OPTARG"|awk -F'=' '{ print $2 }')
        ;;
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

parse_args $@
if [ "$scale" -gt "1000" ]; then
    echo "[WARN] You specified scale=${scale} larger than 1000GB, which is still an experimental feature."
fi

# Separated database name for given scale.
if [ -z "${ssb_database_name}" ]; then
    ssb_database_name="ssb_scale_${scale}"
fi

if [ "$( psql -Aqt -P pager=off -d postgres -c "SELECT 1 FROM pg_database WHERE datname='${ssb_database_name}'" )" = '1' ]
then
    echo ""
else
    echo "[ERROR] database ${ssb_database_name} does not exist please generate and import the dataset before generate the flatten table..."
    exit 1
fi

if [ "$( psql -Aqt -P pager=off -d ${ssb_database_name} -c "SELECT 1 FROM pg_class WHERE relname='${enum_table_name}'" )" = '1' ]
then
    echo "[ERROR] table [${enum_table_name}] exists in database [${ssb_database_name}], you may drop this table or use a custom database."
    echo ""
    exit 1
fi

curdir=$(pwd)
internal_dir="$curdir/generate_flat_table"

# dynamic int vs bigint against different scale=100..1000,
# using bigint for scale > 100
dynaint="int"
if [ "$scale" -gt "100" ]; then
    dynaint=bigint
fi

echo "Creating enum types..."
psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "drop type if exists e_c_nation cascade; create type e_c_nation as enum ('ALGERIA', 'ARGENTINA', 'BRAZIL', 'CANADA', 'CHINA', 'EGYPT', 'ETHIOPIA', 'FRANCE', 'GERMANY', 'INDIA', 'INDONESIA', 'IRAN', 'IRAQ', 'JAPAN', 'JORDAN', 'KENYA', 'MOROCCO', 'MOZAMBIQUE', 'PERU', 'ROMANIA', 'RUSSIA', 
'SAUDI ARABIA', 'UNITED KINGDOM', 'UNITED STATES', 'VIETNAM')"
psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "drop type if exists e_c_region cascade; create type e_c_region as enum ('AFRICA', 'AMERICA', 'ASIA', 'EUROPE', 'MIDDLE EAST');"
psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "drop type if exists e_p_mfgr cascade; create type e_p_mfgr as enum ('MFGR#1', 'MFGR#2', 'MFGR#3', 'MFGR#4', 'MFGR#5');"


# mars extension is required before populating a table using mars2 engine.
psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name -c "create extension if not exists matrixts"

# create table with enum columns
psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON \
          -d $ssb_database_name \
          -v withopts= \
          -v tname=${enum_table_name} \
          -v dynaint=${dynaint} \
          -v e_lo_orderpriority=text \
          -v e_lo_shipmode=text \
          -v e_c_city=text \
          -v e_c_nation=e_c_nation \
          -v e_c_region=e_c_region \
          -v e_c_mktsegment=text \
          -v e_s_city=text \
          -v e_s_nation=e_c_nation \
          -v e_s_region=e_c_region \
          -v e_p_mfgr=e_p_mfgr \
          -v e_p_category=text \
          -v e_p_brand=text \
          -v e_p_color=text \
          -v e_p_type=text \
          -v e_p_container=text \
          -f ${internal_dir}/ddl.sql

psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON \
    -v dynaint=${dynaint} \
    -d $ssb_database_name \
    -c "create index on ${enum_table_name} using mars2_btree(${index_columns})"

psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON \
          -d $ssb_database_name \
          -v withopts= \
          -v dynaint=${dynaint} \
          -v tname=${enum_table_name} \
          -v e_lo_orderpriority=text \
          -v e_lo_shipmode=text \
          -v e_c_city=text \
          -v e_c_nation=e_c_nation \
          -v e_c_region=e_c_region \
          -v e_c_mktsegment=text \
          -v e_s_city=text \
          -v e_s_nation=e_c_nation \
          -v e_s_region=e_c_region \
          -v e_p_mfgr=e_p_mfgr \
          -v e_p_category=text \
          -v e_p_brand=text \
          -v e_p_color=text \
          -v e_p_type=text \
          -v e_p_container=text \
          -f ${internal_dir}/prejoin.sql

psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name \
            -c "ANALYZE ${enum_table_name}"

psql -Aqtbe -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name \
            -c "VACUUM ${enum_table_name}"

echo ""
cat << EOF
Flatten table ${enum_table_name} is successfully generated in database ${ssb_database_name}.

Now you can run SSB benchmark.

   ./ssb.sh -s ${scale} -D ${ssb_database_name}

EOF