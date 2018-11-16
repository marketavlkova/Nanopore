#!/bin/bash
### this script is for basecalling DNA sequencing data from Nanopore
### made by Marketa Vlkova in 16-November-2018
### example to run: bash DNAbasecall.sh 20181114_0525_2018_Nov_14_mv_genomic_plasmids
### the script is expected to be run from your /data/nanopore_YYYY/ directory

### define function for easier parallel basecalling
basecall() {
  echo $1 started
  nice -10 read_fast5_basecaller.py -i $1 -t 8 -s $2 -f FLO-MIN106 -k SQK-RBK004 --barcoding -r -n 4000 -o fastq,fast5 -q 0 --disable_filtering
  echo $1 completed
}

cd $1/fast5/        ### go to directory fast5
N=`ls | wc -l`      ### store number of directories in fast5 directory as a variable
PAR=$(( N / 5 ))    ### count how many directories will be stored in one of the fast5_{1..5} directory

### check if the files should be partitioned (in the case it's multiple times on the same dataset)
printf "Do you wish to partition all $N directories in fast5 into 5 directories? (y/n) \n"
read ANS
if [ "$ANS" != "${ANS#[Yy]}" ]
then
  if [ -d "./fast5_1" ]
  then
    printf "It looks like fast5_1 directory already exists. Are you sure you want to proceed? (y/n) \n"
    read ANS2
  fi
  if [ ! -d "./fast5_1" ] || [ "$ANS2" != "${ANS2#[Yy]}" ]
  then
    ### move all directories in fast5 evenly into 5 newly created directories
    for VAR in {1..5}                   ### loop and assign values 1 to 5 to variable VAR
    do
      mkdir fast5_$VAR                  ### make directories fast5_1 to fast5_5
      if [ $VAR -eq 5 ]                 ### if this is the last run throught the loop
      then
        PAR=$( expr `ls | wc -l` - 5 )  ### change PAR number to number of all remaining directories except for fast5_* dirs
      fi
      mv `ls | head -$PAR` fast5_$VAR   ### move directories listed as 1 to PAR into the newly created fast5_* dir
    done
    printf "Files partitioned \n"
  fi
fi

### check if proceed with basecalling
printf "Do you wish to proceed with basecalling? (y/n) \n"
read BAR
### check if pool seq cumarries and collate .fastq files
printf "Do you wish to pool sequence summaries after basecalling? (y/n) \n"
read POO
printf "Do you wish to collate fastq files? (y/n) \n"
read COL

### parallel basecalling
if [ "$BAR" != "${BAR#[Yy]}" ]
then
  basecall ./fast5_1 alb_basecall_1 &
  basecall ./fast5_2 alb_basecall_2 &
  basecall ./fast5_3 alb_basecall_3 &
  basecall ./fast5_4 alb_basecall_4 &
  basecall ./fast5_5 alb_basecall_5 &
  wait
  printf "Basecalling finished \n"
fi

### pooling sequence summaries
if [ "$POO" != "${POO#[Yy]}" ]
then
  for FILE in alb_basecall_*/seq*txt
  do
    echo $FILE
    tail -n +2 $FILE >> all_seq_summary.txt
  done
  cut -f 2,4,5,6,13,14,20 all_seq_summary.txt > sequencing_summary.txt
  printf "Summaries pooled \n"
fi


### collating fastq files
if [ "$COL" != "${COL#[Yy]}" ]
then
  ### create empty files called according to your barcodes
  for BC in alb_basecall_1/workspace/*
  do
    ### check whether the collated fastq files exist
    if [ -f "${BC#*/*/}".fastq ]
    then
      printf "File "${BC#*/*/}".fastq already exists. If you continue its content might be duplicated. Are you sure you want to proceed? (y/n) \n"
      read DUP
      if [ "$DUP" == "${DUP#[Yy]}" ]
      then
        break 2
      fi
    ### if not create them
    else
      touch "${BC#*/*/}".fastq
    fi
  done
  ### collate
  for REP in {1..5}
  do
    for RUN in *.fastq
    do
      AIM="${RUN%.*}"
      cat alb_basecall_$REP/workspace/$AIM/*.fastq >> $RUN
    done
  done
  printf "fastq files collated \n"
fi

### following is the original collating by Olin
### works only for directory alb_basecall_1/
# for DIR in alb_basecall_1/workspace/barcode*
# do
#   echo $DIR
#   cat ${DIR}/*fastq > ${DIR/alb_basecall_1\/workspace\//}.fastq
#   cat ${DIR/call_1/call_2}/*fastq >> ${DIR/alb_basecall_1\/workspace\//}.fastq
#   cat ${DIR/call_1/call_3}/*fastq >> ${DIR/alb_basecall_1\/workspace\//}.fastq
#   cat ${DIR/call_1/call_4}/*fastq >> ${DIR/alb_basecall_1\/workspace\//}.fastq
#   cat ${DIR/call_1/call_5}/*fastq >> ${DIR/alb_basecall_1\/workspace\//}.fastq
# done
