#!/bin/bash
#set -ex
export FAST_NODE=1
export SLOW_NODE=0
export STATS_PERIOD=5
export MOVE_HOT_AND_COLD_PAGES=no
export SHRINK_PAGE_LISTS=yes # page migration policy will be used.
export FORCE_NO_MIGRATION=no
export NR_RUNS=1 # how many times the experiments repeat.
export MIGRATION_BATCH_SIZE=8
export MIGRATION_MT=4 # how many cpu threads you want to use for page migration.
export PREFER_FAST_NODE=yes

export BENCH_SIZE="8GB"

#MEM_SIZE="16GB"
MEM_SIZE="4GB"
#MEM_SIZE="unlimited"

RES_FOLDER="results-mm-manage-fast-${MEM_SIZE}-${MIGRATION_MT}-threads"
#RES_FOLDER="results-mm-manage-fast-${MEM_SIZE}-policy-bd0ca72ef"
#RES_FOLDER="results-mm-manage-second-version-fast-${MEM_SIZE}"

#BENCHMARK_LIST="canneal-mt graph500-omp"
#BENCHMARK_FOLDERS="canneal graph500"
#BENCHMARK_LIST="503.postencil 551.ppalm 553.pclvrleaf 555.pseismic 556.psp 559.pmniGhost 560.pilbdc 563.pswim 570.pbt graph500-omp canneal-mt"
#BENCHMARK_LIST="503.postencil 551.ppalm 553.pclvrleaf 555.pseismic 556.psp 559.pmniGhost 560.pilbdc 563.pswim 570.pbt graph500-omp"
#BENCHMARK_LIST="503.postencil 551.ppalm 553.pclvrleaf 555.pseismic 559.pmniGhost 560.pilbdc 563.pswim 570.pbt graph500-omp"
#BENCHMARK_LIST="556.psp 559.pmniGhost 560.pilbdc 563.pswim 570.pbt graph500-omp"
#BENCHMARK_LIST="570.pbt graph500-omp"
BENCHMARK_LIST="graph500-omp"
#BENCHMARK_LIST="551.ppalm"
#BENCHMARK_LIST="570.pbt"
#BENCHMARK_LIST="556.psp"
#BENCHMARK_LIST="x264 streamcluster"
#BENCHMARK_FOLDERS="x264 streamcluster"
#BENCHMARK_LIST="559.pmniGhost 560.pilbdc 563.pswim 570.pbt graph500-omp"
#BENCHMARK_FOLDERS="dedup"
#BENCHMARK_LIST="memcached-user"
#BENCHMARK_FOLDERS="memcached-user"
#BENCHMARK_LIST="data-caching"
#BENCHMARK_FOLDERS="data-caching"

## Different migration options.
## - all-remote-access: All Slow
## - all-local-access: All Fast.
## - non-thp-migration
## - tph-migration
## - exchange-pages
##
#PAGE_REPLACEMENT_SCHEMES="all-remote-access non-thp-migration thp-migration opt-migration exchange-pages"
#PAGE_REPLACEMENT_SCHEMES="all-remote-access all-local-access non-thp-migration thp-migration opt-migration"
#PAGE_REPLACEMENT_SCHEMES="non-thp-migration thp-migration opt-migration"
#PAGE_REPLACEMENT_SCHEMES="non-thp-migration thp-migration"
#PAGE_REPLACEMENT_SCHEMES="thp-migration opt-migration"
#PAGE_REPLACEMENT_SCHEMES="opt-migration exchange-pages"
#PAGE_REPLACEMENT_SCHEMES="concur-only-opt-migration concur-only-exchange-pages"
#PAGE_REPLACEMENT_SCHEMES="exchange-pages"
#PAGE_REPLACEMENT_SCHEMES="opt-migration"
PAGE_REPLACEMENT_SCHEMES="non-thp-migration"

#MEM_SIZE_LIST="unlimited" # specify a list of fast memory sizes (GB).
#MEM_SIZE_LIST=$(seq 4 4 28)
MEM_SIZE_LIST=$(seq 4 4)

#export NO_MIGRATE=""

#THREAD_LIST="20" # how many hardware threads applications wants.
THREAD_LIST="4"
#MEMHOG_THREAD_LIST=$(seq 6 6)
MEMHOG_THREAD_LIST=0

read -a BENCH_ARRAY <<< "${BENCHMARK_LIST}"

echo "BENCH_ARRAY: $BENCH_ARRAY"

#THRESHOLD=`cat /proc/zoneinfo | grep -A 5 "Node 1" | grep high | awk '{print $2}' `
#THRESHOLD=$((-THRESHOLD/64))

#sudo sysctl vm/times_kmigrationd_threshold=${THRESHOLD}

trap "./create_die_stacked_mem.sh remove;  exit" INT


sudo sysctl vm/migration_batch_size=${MIGRATION_BATCH_SIZE}
sudo sysctl vm/limit_mt_num=${MIGRATION_MT}

## Cannot find SCAN_DIVISOR.
#if test ${SCAN_DIVISOR} -gt 0 ;  then
#sudo sysctl vm/scan_divisor=${SCAN_DIVISOR}
#fi


for i in $(seq 1 ${NR_RUNS});
do
	echo "ROUND: $i"
	for MEM_SIZE in ${MEM_SIZE_LIST};
	do
		echo "Memsize: $MEM_SIZE"

		if [[ "x${MEM_SIZE}" != "xunlimited" ]]; then
			MEM_SIZE="${MEM_SIZE}GB"
		fi

		RES_FOLDER="results-mm-manage-prefer-fast-${MEM_SIZE}-policy"
		if [ ! -d "${RES_FOLDER}" ]; then
		echo "Prepare folders"
		mkdir -p ${RES_FOLDER}
		fi

		for B_IDX in $(seq 0 $((${#BENCH_ARRAY[@]}-1)));
		do
			echo "B_IDX: $B_IDX"
			echo ${BENCH_ARRAY[${B_IDX}]}" at "${BENCH_FOLDER_ARRAY[${B_IDX}]}
			export BENCH=${BENCH_ARRAY[${B_IDX}]}

			echo "BENCH: $BENCH"

			if [ ! -d "${RES_FOLDER}/${BENCH}" ]; then
				mkdir -p ${RES_FOLDER}/${BENCH}
			fi

			for SCHEME in ${PAGE_REPLACEMENT_SCHEMES};
			do

				if [[ "x${MEM_SIZE}" != "xunlimited" ]]; then
					./create_die_stacked_mem.sh node_size ${FAST_NODE} ${MEM_SIZE}
				else
					./create_die_stacked_mem.sh
					export MOVE_HOT_AND_COLD_PAGES=yes
				fi
				echo "Memory size set."

				#sudo sysctl vm.enable_prefetcher=0
				export SCHEME=${SCHEME}
				echo "Configuration: ${SCHEME}"

				for THREAD in ${THREAD_LIST};
				do
					echo "Thread: $THREAD"

					for MEMHOG_THREADS in ${MEMHOG_THREAD_LIST};
					do
						export MEMHOG_THREADS=${MEMHOG_THREADS}

						if [ "${SCHEME}" == "all-remote-access" ]; then
							export NO_MIGRATION=yes
							sudo sysctl vm.sysctl_enable_thp_migration=1

							./run_bench.sh ${THREAD};
						fi

						if [ "${SCHEME}" == "all-local-access" ]; then
							export NO_MIGRATION=yes
							sudo sysctl vm.sysctl_enable_thp_migration=1

							./run_bench.sh ${THREAD};
						fi

						if [ "${SCHEME}" == "non-thp-migration" ]; then
							export NO_MIGRATION=no

							sudo sysctl vm.sysctl_enable_thp_migration=0
							./run_bench.sh ${THREAD};
							sudo sysctl vm.sysctl_enable_thp_migration=1
						fi

						if [ "${SCHEME}" == "thp-migration" ]; then
							export NO_MIGRATION=no
							sudo sysctl vm.sysctl_enable_thp_migration=1

							./run_bench.sh ${THREAD};
						fi
						if [ "${SCHEME}" == "opt-migration" ] || [ "${SCHEME}" == "concur-only-opt-migration" ]; then
							export NO_MIGRATION=no
							sudo sysctl vm.sysctl_enable_thp_migration=1

							./run_bench.sh ${THREAD};
						fi
						if [ "${SCHEME}" == "exchange-pages" ] || [ "${SCHEME}" == "basic-exchange-pages" ] || [ "${SCHEME}" == "concur-only-exchange-pages" ]; then
							export NO_MIGRATION=no
							sudo sysctl vm.sysctl_enable_thp_migration=1

							./run_bench.sh ${THREAD};
						fi
						if [ "${SCHEME}" == "non-thp-exchange-pages" ]; then
							export NO_MIGRATION=no

							sudo sysctl vm.sysctl_enable_thp_migration=0
							./run_bench.sh ${THREAD};
							sudo sysctl vm.sysctl_enable_thp_migration=1
						fi

						sleep 5
						./create_die_stacked_mem.sh remove

					done # MEMHOG
				done # THREAD LIST
			done # SCHEME

			mv result-${BENCH_ARRAY[${B_IDX}]}-* ${RES_FOLDER}/${BENCH}/
		done # BENCH

	done # MEM_SIZE
done # i

