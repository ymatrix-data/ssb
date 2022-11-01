#!/bin/bash

cpu_cgroup_path=/sys/fs/cgroup/cpu
# get cpu cores in a physical machine
ncpucores=$(nproc)
if [ -f ${cpu_cgroup_path}/cpu.cfs_quota_us ]  && [ -f ${cpu_cgroup_path}/cpu.cfs_period_us ] ; then
  cfs_quota_us=$(cat ${cpu_cgroup_path}/cpu.cfs_quota_us)
  cfs_period_us=$(cat ${cpu_cgroup_path}/cpu.cfs_period_us)
  # judge whether inside a docker container, cpu cores is differ from physical machine 
  if [ $cfs_quota_us -ne -1 ] && [ $cfs_period_us -ne 0 ]; then
     ncpucores=`expr $cfs_quota_us / $cfs_period_us`
  fi
fi
nsegs=$(psql -d postgres -c "select count() from gp_segment_configuration where content >= 0 and role = 'p';" -t --csv)

declare -A checked_variables

checked_variables['max_parallel_workers_per_gather']=$(( ($ncpucores / $nsegs) - 1 ))
checked_variables['gp_cached_segworkers_threshold']='10'

for key in ${!checked_variables[@]}
do
    expected=${checked_variables[$key]}
    actual=$( psql -Aqt -P pager=off -d postgres -c "show ${key}" )

    if [ "${actual}" != "${expected}" ]; then

cat << EOF

[WARN] ${key} is set to [${actual}] but [${expected}] is expected, 
it's highly recommended to set this parameter before moving forward.

EOF
        echo "Do you want to update the parameter immediately?"
        read -p "Y/yes N/no: " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "[ERROR] failed to check environment..."
            exit 1
        else
            gpconfig -c ${key} -v "${expected}"
        fi
    else
        echo "${key}=${actual} ... ok"
    fi
done

# Reload gucs
mxstop -u

cat << EOF
Environment is properly configured, now you can start generate dataset and follow the guides to run SSB benchmark.
   
   ./generate_data.sh -s 1

EOF
