#!/usr/bin/env bash

helpmsg(){
    echo "prepMotionOutliers.sh creates motion outlier files. Uses --fd (framewise displacement) with default settings."
    echo "For more info on FD and the underlying math, see help for fsl_motion_outliers"
    echo "Will run on every _bold.nii.gz file in the input directory."
    echo "Outputs: "fd" is the outlier timepoints (used as confounds in analysis), "fdmotionvalues" is the actual framewise displacement (archival)"
    echo "    -s --sub"
    echo "        REQUIRED: subject number. Don't include sub-X, just the number."
    echo "    -i --input"
    echo "        Optional: input directory. If not chosen, uses /Users/Shared/10_Connectivity/raw_data/sub-XXX/func"
    echo "    -o --output"
    echo "        Optional: output directory. If not chosen, uses /Users/Shared/10_Connectivity/raw_data/sub-XXX/regressors"
    echo "    -h --help -help"
    echo "        Echo this help message."
    exit
    }
if((${#@}<1));then
    helpmsg
    exit
fi


arg=("$@")
for((i=0;i<${#@};++i));do
    #echo "i=$i ${arg[i]}"
    case "${arg[i]}" in
        -s | --sub)
            SUBNUM=${arg[((++i))]}
            echo "SUBNUM=$SUBNUM"
            ;;
        -i | --input)
            INDIR=${arg[((++i))]}
            echo "INPUT DIR=$INDIR"
            ;;
        -o | --output)
            OUTDIR=${arg[((++i))]}
            echo "OUTPUT DIR=$OUTDIR"
            ;;
        -h | --help | -help)
            helpmsg
            exit
            ;;
        *) unexpected+=(${arg[i]})
            ;;
    esac
done

if [ -z "${INDIR}" ];then
    INDIR=/Users/Shared/10_Connectivity/raw_data/sub-${SUBNUM}/func
fi

if [ -z "${OUTDIR}" ];then
    OUTDIR=/Users/Shared/10_Connectivity/raw_data/sub-${SUBNUM}/regressors
fi

# make the output directory
mkdir -p $OUTDIR

for FILENAME in ${INDIR}/*_bold.nii.gz; do
# https://stackoverflow.com/questions/69468283/how-to-extract-part-of-string-in-bash-using-regex?noredirect=1&lq=1
    TASKNAME=`echo ${FILENAME}  | sed -E -e 's/.*(drawLH|drawRH|rest).*/\1/g'` # this will look for our 3 pre-existing task names
    RUNNAME=`echo ${FILENAME}  | sed -E -e 's/.*(-1|-2|-3).*/\1/g'` # this looks for a hypthen followed by a #1-3. Will break if we have "-X" elsewhere. More robust version would look fully for "run-X"
    OUTFILE=${OUTDIR}/sub-${SUBNUM}_fd_task-${TASKNAME}_run${RUNNAME}.txt
    echo "Creating ${OUTFILE}"
    fsl_motion_outliers -i ${FILENAME} -o ${OUTFILE} -s ${OUTDIR}/sub-${SUBNUM}_fdmotionvalues_task-${TASKNAME}_run${RUNNAME}.txt --fd
done
chmod 777 ${OUTDIR}