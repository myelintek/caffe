#!/bin/bash

function clean_up {
	echo CLEAN UP!!
	exit
}

trap clean_up SIGTERM SIGINT SIGHUP


if [ ! $# == 2 ] && [ ! $# == 3 ]; then
    echo "Error: need 2 ~ 3 parameter."
    echo "Useage: $0 [log_file] [iter number] [net_file](optional)"
    exit
fi

file="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
netfile="$(cd "$(dirname "$3")"; pwd)/$(basename "$3")"
logfile="$(cd "$(dirname "$1")"; pwd)/log-$(basename "$1")"
statfile="$(cd "$(dirname "$1")"; pwd)/stat-$(basename "$1")"
sumfile="$(cd "$(dirname "$1")"; pwd)/sum-$(basename "$1")"

iters=$2

#echo $file

cur=$(pwd)

#real_path= ls -l $0
#real_path="$(ls -l "$0" | cut -d '>' -f 2)"

foo=$(ls -l "$0")
real_path="${foo##* }"
#echo $real_path
src=$(dirname $real_path)

#if [ $src == '' ]; then
#    src=$0
#fi


#echo $src
cd $src

if [ ! -f $file ]; then
    echo file not exists.
    exit
fi

if [ ! -e $netfile ]; then
    echo netfile not exists. continue? \(y/n\)
    read ans
    while true ; do
        if [ $ans == 'n' ] || [ $ans == 'N' ] ; then
            exit
        elif [ ! $ans == 'y' ] || [ ! $ans == 'Y' ] ; then
            break
        else
            echo enter y/n
        fi
    done
fi

perl log_parser.pl $iters < $file | perl merge_rank_and_time_align.pl | perl trans_endpoint_to_timestampAndPeriod.pl $iters > $logfile


perl do_statics.pl < $logfile > $statfile


if [ -f $netfile ]; then
    perl do_summarize.pl $netfile < $statfile > $sumfile
fi

cd $cur

