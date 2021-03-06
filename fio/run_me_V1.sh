#!/bin/bash

# Author: Karan Singh
# Inspired by Olli Tourunen <Olli.Tourunen@csc.fi>

###########
## Notes ##
###########
# 1. sequential write with large block size first, so  that the test files are fully laid out before other tests

# Mount point where block device is mounted
fio_test_dir=/mnt/bench-disk

# Test size in MB
fio_test_size=100

# Number of workers
workers=16

# Output directory to store fio results
fio_output_dir=$fio_test_dir/fio_output

# Different block sizes to test with. Example : 8192k 4096k 2048k 1024k 512k 256k 128k 64k 32k 16k 4k 2k 1k
block_size="1024k"

# The test method that should be used by fio, Example : write randwrite readwrite read randread
test_method="write"

# Repeat the test for better averaging
repeat=1


echo 3 > /proc/sys/vm/drop_caches

if [ -d "$fio_output_dir" ]; then
   echo "$fio_output_dir directory already exists, renaming existing directory"
   mv $fio_output_dir ${fio_output_dir}'_'`date +"%d-%m-%Y-%H-%M-%S"`
   echo "Creating new $fio_output_dir directory"
   mkdir $fio_output_dir
else
   echo "Creating new $fio_output_dir directory"
   mkdir $fio_output_dir
fi

echo " ================================================= "
echo "               Starting Benchmarking "
echo " ================================================= "

for fio_test in $test_method ; do
  for bs in $block_size ; do
    for ((i=1;i<=$repeat;i+=1)) ; do
      for ((size=$fio_test_size,nw=1;nw<=$workers;nw*=2,size/=2)); do
        echo "starting test fio_$fio_test-$i-$nw-$bs"
        fio --directory=$fio_test_dir --randrepeat=0 --size=${size}M --runtime=300 \
            --direct=1 --bs=$bs --timeout=60 --numjobs=$nw --name=fio-nw$nw --rw=$fio_test \
            --group_reporting --eta=never --output=$fio_output_dir/`hostname`_fio_$fio_test-$i-$nw-$bs.out;
        if [ ! $? -eq 0 ]; then
          echo "error"
          exit 1
        fi

        grep iops $fio_output_dir/`hostname`_fio_$fio_test-$i-$nw-$bs.out
        sleep 1
      done
    done
  done
done

# Loop to extract result of fio test , creates a file with name results/fio_result_%date
for fio_test in $test_method ; do
  for bs in $block_size ; do
    for ((i=1;i<=$repeat;i+=1)) ; do
      for ((size=$fio_test_size,nw=1;nw<=$workers;nw*=2,size/=2)); do
	grep --with-filename iops $fio_output_dir/`hostname`_fio_$fio_test-$i-$nw-$bs.out | sort -t "-" -k 2n | sed -r "s/.*fio_output\///" >> results/fio_result_`hostname`_`date +"%d-%m-%Y-%H-%M-%S"`
      done
    done
  done
done
echo " ================================================= "
echo "               Benchmarking Completed "
echo " Results : results/fio_result_`hostname`_`date +"%d-%m-%Y-%H-%M"`-*"
echo " ================================================= "
