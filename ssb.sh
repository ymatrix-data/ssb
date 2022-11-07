#!/bin/bash

set -e

n_iterations=3
explain_analyze=""

curdir=$(pwd)
test_name=$(printf 't%(%Y%m%d)T\n' -1)
table_name="f_lz4_mars2"
generated_dir=$curdir/generated

ssb_database_name=""

scale="1" # scale of dataset, and located under generated/scale-${scale}-data/

set_session_guc_commands="set enable_indexscan=off;set gp_enable_minmax_optimization=off;"
query_optimized=""

# Registered query vs names
declare -A query_names_map
query_names_map['mxdb-11.sql']='Query 1.1'
query_names_map['mxdb-12.sql']='Query 1.2'
query_names_map['mxdb-13.sql']='Query 1.3'
query_names_map['mxdb-21.sql']='Query 2.1'
query_names_map['mxdb-22.sql']='Query 2.2'
query_names_map['mxdb-23.sql']='Query 2.3'
query_names_map['mxdb-31.sql']='Query 3.1'
query_names_map['mxdb-32.sql']='Query 3.2'
query_names_map['mxdb-33.sql']='Query 3.3'
query_names_map['mxdb-34.sql']='Query 3.4'
query_names_map['mxdb-41.sql']='Query 4.1'
query_names_map['mxdb-42.sql']='Query 4.2'
query_names_map['mxdb-43.sql']='Query 4.3'

# session guc setting, like -c 'set matrix.enable_mxvector=on' 
declare -A session_gucs

# global guc setting
declare -A custom_gucs

function show_help()
{
    cat << EOF
Run Star Schema Benchmark(SSB) against MatrixDB.

Args:
   -h
      Show help message.

   -n [test_name]

      Optional, specify a human readable name, checkout detail report in reports.f_lz4_mars2_${test_name}, 
      and test output(including explain analyze reports) are located at generated/scale-${scale}-data/reports/${test_name}.
   
   -a
      Optional, explain analyze is disable by default, output explain analyze report under generated/scale-${scale}-data/${test_name}/reports/

   -s [scale] 
      Required, scale of the generated dataset in gigabytes, and specify this option to run benchmark against a desired dataset with specified scale.

   -i [iterations]
      Optional, default is 5, set how many times you want to run every single query in your test(after warmup).

   -c [session_guc]
      Optional, applying parameter/guc on session, and you can specify multiple session gucs.
      specifying -c 'k1=v1' is equivalent psql -c "set k1=v1"

Usage:
    
    Run single session SSB against table [flat_mars2_with_enum] with warmup and multiple iteration support:

        ./ssb.sh -s 100 -t flat_mars2_with_enum -n bangtest01 -i 3

    Run single session SSB against table [flat_mars2_with_enum] with EXPLAIN ANALYZE report with -a

        ./ssb.sh -s 100 -t flat_mars2_with_enum -n bangtest01 -i 3 -a

    Set a few GUC settings with -g, then run the SSB benchmark:

        ./ssb.sh -s 100 -t flat_mars2_with_enum -n bangtest01 -i 3 -g shared_buffers="200MB" -a

EOF
}

function parse_args()
{
    OPTIND=1
    while getopts ":a :D:c:g:i:n:t:s:h" opt; do
    case "$opt" in
        s) scale="$OPTARG" ;;
        # FIXME: FORMAT JSON is unsupported when using mars2 against a flatten table
        a) explain_analyze="EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS)" ;;
        t) table_name="$OPTARG";;
        n) test_name="$OPTARG";;
        i) n_iterations="$OPTARG";;
        D) ssb_database_name="$OPTARG";;
        g)
        guc_key=$(echo "$OPTARG"|awk -F'=' '{ print $1 }')
        guc_value=$(echo "$OPTARG"|awk -F'=' '{ print $2 }')

        custom_gucs[$guc_key]=$guc_value
        ;;
        c)
        guc_key=$(echo "$OPTARG"|awk -F'=' '{ print $1 }')
        guc_value=$(echo "$OPTARG"|awk -F'=' '{ print $2 }')
        
        session_gucs[$guc_key]=$guc_value
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

################## MAIN ######################
parse_args $@

if [ "$scale" -gt "1000" ]; then
    echo "[WARN] You specified scale=${scale} larger than 1000GB, which is still an experimental feature."
fi

if [ "$scale" -gt "100" ]; then
    query_optimized="set statement_mem='32MB'"
else
    query_optimized=""
fi

reportdir="$generated_dir/scale-${scale}-data/reports/${test_name}"
mkdir -p $reportdir
rm -rf $reportdir/*

# dynamic int vs bigint against different scale=100..1000,
# using bigint for scale > 100
dynaint="int"
if [ "$scale" -gt "100" ]; then
    dynaint=bigint
fi

if [ -z "${ssb_database_name}" ]; then
    ssb_database_name="ssb_scale_${scale}"
fi

# recoding ssb results into report_table
report_table=reports.${table_name}_${test_name}

psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -v dynaint=${dynaint} -d $ssb_database_name \
    -c "create schema if not exists reports"

psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -v dynaint=${dynaint} -d $ssb_database_name \
    -c "create table if not exists ${report_table} (test_name text, scale int4, iterations int4, run_settings text, query_name text, duration_ms float4, created_at timestamp)"

run_settings=""
psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -v dynaint=${dynaint} -d $ssb_database_name \
    -c "delete from ${report_table} where test_name='${test_name}'"

function populate_custom_guc_settings
{
    echo "Populating custom grand unified configurations(GUC) or parameters in MatrixDB..."
    for key in ${!custom_gucs[@]}
    do
        run_settings="${run_settings}  ${key}=${custom_gucs[$key]}"
        # NOTE: gucs must be updated one by one to ensure 100% correctness and compatibility.
        gpconfig -c $key -v ${custom_gucs[$key]}
    done 
    mxstop -ar
}

# Since bash does not do floating point arithmetics, 
# it's a better idea to handle the calculation of min/max/avg in the MatrixDB.
# Here timing reports are generated as csv files, and explain analyze reports
# are exposed as json files and you can visualize these reports directly through
# [https://explain.dalibo.com/]

function run_single_query()
{
    filepath=$1

    qfname=$(basename $filepath)
    qname=${query_names_map[$qfname]}
    
    repeat_filepath_args="-f ${filepath}"         
    
    for i in $(seq 1 ${n_iterations})
    do
        # report_filepath="$reportdir/$(echo $qname|sed 's|Query |Query_|g')_r${i}_output.txt"
        # duration=$(cat $report_filepath| tail -n 1 | sed 's|Time: ||g' | sed 's| ms||g' | sed 's|(.*)||g')
        # test_name text, scale int4, run_settings text, query_name text, duration_ms float4, created_at timestamp
        repeat_filepath_args="$repeat_filepath_args -f ${filepath}"
    done

    # build session gucs from $session_gucs
    for key in ${!session_gucs[@]}
    do
        set_session_guc_commands="${set_session_guc_commands} set ${key}=${session_gucs[$key]};"
    done

    echo ""
    echo "running ${qname} for ${n_iterations} times after builtin warmup..."

    report_filepath="$reportdir/$(echo $qname|sed 's|Query |Query_|g')_output.txt"

    psql -Aqtbe \
            -v ON_ERROR_STOP=ON -v ON_ERROR_STOP=1 -v dynaint=${dynaint} -d $ssb_database_name -c "${set_session_guc_commands}${2}" \
            -v EXPLAIN_ANALYZE="${explain_analyze}" \
            -v tname="${table_name}" \
            -c "\timing" \
            $repeat_filepath_args > $report_filepath

    durations=$(cat $report_filepath |grep "^Time:"| awk '{print $2}'|tail -n ${n_iterations})
    
    for duration in $durations
    do
        psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -v dynaint=${dynaint} -d $ssb_database_name \
              -c "insert into ${report_table} values('${test_name}', ${scale}, ${n_iterations}, '${run_settings}', '${qname}', ${duration}, now())"
    done
}

# populate_custom_guc_settings $@

echo ""
echo "Running SSB benchmark queries in MatrixDB ..."
for qf in $(ls $curdir/queries)
do
    run_single_query "$curdir/queries/$qf" "${query_optimized}"
done

# Now output the execution report

echo "==============="
echo "Test <${test_name}> with scale=${scale} and iterations=${n_iterations}"
echo ""
psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name \
    -c "select query_name, float4(avg(duration_ms))::text || ' (ms)' as duration from ${report_table} where test_name='${test_name}' group by query_name;"

echo "==============="
echo "Total(min): $(psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name \
    -c "select sum(duration)::text || ' (ms)' as total from (select query_name, float4(min(duration_ms)) as duration from ${report_table} where test_name='${test_name}' group by query_name) as t1;")"
echo "Total(avg): $(psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name \
    -c "select sum(duration)::text || ' (ms)' as total from (select query_name, float4(avg(duration_ms)) as duration from ${report_table} where test_name='${test_name}' group by query_name) as t1;")"
echo "Total(max): $(psql -Aqt -P pager=off -v ON_ERROR_STOP=ON -d $ssb_database_name \
    -c "select sum(duration)::text || ' (ms)' as total from (select query_name, float4(max(duration_ms)) as duration from ${report_table} where test_name='${test_name}' group by query_name) as t1;")"
echo "==============="
