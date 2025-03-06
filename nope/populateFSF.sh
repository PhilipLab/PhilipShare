#!/usr/bin/env bash

helpmsg(){
    echo "populateFSF.sh creates .fsf files for a new participant, from a BIDS template. Assumes you want 3 runs each of RH & LH."
    echo "Core operation is first-level only, but can do second-level also (but they must all exist in template subject)"
    echo "OK to have the same subject be input and output; this will populate from LH1 to all 6 runs"
    echo "    -i --input --template --fsf"
    echo "        REQUIRED: a fsf file to use as template. CURRENTLY MUST BE LH1, specifically with BIDS name e.g:"
    echo "          sub-XXXX_task-drawLH_run-1[_optional-suffixes].fsf"
    echo "    -s --sub"
    echo "        REQUIRED: subject number output. Assumes same directory strcture as input"
    echo "    -o --output"
    echo "        Optional: overwrite output directory"
    echo "    -t --two --l2"
    echo "        Optional (flag): ADD level two. Requires all three files to be set in template subject."
    echo "    -T --TWO --L2"
    echo "        Optional (flag): ONLY level two (skip level one). (If you pick both -t and -T, behavior will be -T)"
    echo "    -nr --noright"
    echo "        Optional (flag): skip RH."
    echo "    -nl --noleft"
    echo "        Optional (flag): skip LH."
    echo "    -f --flip"
    echo "        Optional (flag): add the RHflip (irrespective of whether you do or don't skip RH via -nr)"
    echo "    -h --help -help"
    echo "        Echo this help message."
    exit
    }
if((${#@}<1));then
    helpmsg
    exit
fi

# defaults
DOTWO=0; DOONE=1; DOFLIPRH=0; DORH=1; DOLH=1;

arg=("$@")
for((i=0;i<${#@};++i));do
    #echo "i=$i ${arg[i]}"
    case "${arg[i]}" in
        -s | --sub)
            SUBNUM=${arg[((++i))]}
            #echo "SUBNUM=$SUBNUM"
            ;;
        -i | --template | --fsf | --input)
            INFILE=${arg[((++i))]}
            #echo "INPUT FILE=$INFILE"
            ;;
        -o | --output)
            OUTDIR=${arg[((++i))]}
            #echo "OUTPUT DIR=$OUTDIR"
            ;;
        -t | --two | --l2)
            DOTWO=1
            ;;
        -T | --TWO | --L2)
            DOONE=0
            DOTWO=1
            ;;
        -f | --flip)
            DOFLIPRH=1
            ;;
        -nr | --noright)
            DORH=0
            ;;
        -nl | --noleft )
            DOLH=0
            ;;
        -h | --help | -help)
            helpmsg
            exit
            ;;
        *) unexpected+=(${arg[i]})
            ;;
    esac
done

# this is some weak error checking.
if [ ! -f "${INFILE}" ];then
    echo "Input file not found: ${INFILE}"
else
    echo "Input file found: ${INFILE}"
fi

# now we extract the info we need from the input filepath - https://stackoverflow.com/questions/23162299/how-to-get-the-last-part-of-dirname-in-bash
PATHTO="$(dirname $INFILE)" 
MODELDIR="$(basename $PATHTO)"
PREPATH_SUB="$(dirname $PATHTO)" # should be .../derivatives/analsis/sub-XXX/ (only needed to get next line)
PREPATH="$(dirname $PREPATH_SUB)" # should be .../derivatives/analysis 
# now pull
TEMP=${MODELDIR#*-} # sub-N_model-X becomes N_model-X
MODELNAME=${TEMP#*-} # N_model-X becomes X
INSUB=${TEMP%_*} # N_model-X becomes N
SUFFIX=${INFILE#*run-[0-9]} # everything after run designation

# create directory if needed
OUTDIR=${PREPATH}/sub-${SUBNUM}/sub-${SUBNUM}_model-${MODELNAME}/
if [ ! -d "${OUTDIR}" ];then
    mkdir -p ${OUTDIR}
fi

# create level 1 files if specified by inputs
if [ $DOONE = 1 ]; then
    # name & create equivalent LH1. Because this is baseline, always made (delete later if LH=0)
    LHBASE=${OUTDIR}/sub-${SUBNUM}_task-drawLH_run-1${SUFFIX} # start by naming a LH_run-1 file for new subject
        echo "Performing L1 build: ${INSUB} -> ${SUBNUM}"
    cp $INFILE ${LHBASE} # copy LH_run1 from template subject to new subject 
    sed -i '' 's/'${INSUB}'/'${SUBNUM}'/g' $LHBASE # update subject number

    # mirror to RH
    if [ $DORH = 1 ]; then
        RHBASE=${OUTDIR}/sub-${SUBNUM}_task-drawRH_run-1${SUFFIX} # this section copies LH_run-1 to RH_run-1 and changes "LH" to "RH"
        cp ${LHBASE} ${RHBASE}
        sed -i '' 's/LH/RH/g' $RHBASE
    fi

    # mirror to RHflip
    if [ $DOFLIPRH = 1 ]; then
        RHFBASE=${OUTDIR}/sub-${SUBNUM}_task-drawRHflip_run-1${SUFFIX} # this section copies LH_run-1 to RH_run-1 and changes "LH" to "RH"
        cp ${LHBASE} ${RHFBASE}
        sed -i '' 's/LH/RH/g' $RHFBASE
        sed -i '' 's/drawRH_/drawRHflip_/g' $RHFBASE # this will convert some thingsyou don't want flipped, so fix those:
        sed -i '' 's/RHflip_run-1_reg/RH_run-1_reg'/g $RHFBASE
        sed -i '' 's/RHflip_EV/RH_EV/g' $RHFBASE
        #sed -i '' 's/drawRH_run-1_OGRE-preproc/drawRHflip_run-1_OGRE-preproc/g' $RHBASE
    fi
    

    # build runs 2-3
    for run in 2 3; do
        if [ $DOLH = 1 ]; then
            LHNEW=${OUTDIR}/sub-${SUBNUM}_task-drawLH_run-${run}${SUFFIX} # establish new filename with new run #
            cp ${LHBASE} ${LHNEW} # make the new file
            sed -i '' 's/run-1/run-'${run}'/g' ${LHNEW} # in the new file, replace run-1 with run-X
        fi
        if [ $DORH = 1 ]; then
            RHNEW=${OUTDIR}/sub-${SUBNUM}_task-drawRH_run-${run}${SUFFIX}  # do it all again for RH
            cp ${RHBASE} ${RHNEW}
            sed -i '' 's/run-1/run-'${run}'/g' ${RHNEW}
        fi
        if [ $DOFLIPRH = 1 ]; then
            RHFNEW=${OUTDIR}/sub-${SUBNUM}_task-drawRHflip_run-${run}${SUFFIX}  # do it all again for RH
            cp ${RHFBASE} ${RHFNEW}
            sed -i '' 's/run-1/run-'${run}'/g' ${RHFNEW}
        fi
    done
else
    echo "Skipping L1 build for ${SUBNUM}"
fi

if [ $DOLH = 0 ]; then
    rm ${LHBASE}
fi


# now do level 2, if called. Requires the template subject to have all available files (LH, RH, AH)
# surely a more elegant way to do this by setting inputs to for loop, but not worth coding
if [ $DOTWO = 1 ]; then
    echo "Performing L2 build: ${INSUB} -> ${SUBNUM}" 
    if [ $DOLH = 1 ]; then
        L2BASE_L=${PREPATH}/sub-${INSUB}/sub-${INSUB}_model-${MODELNAME}/sub-${INSUB}_level-2_task-drawLH_model-${MODELNAME}${SUFFIX} # template level2.fsf
        TWONEW_L=${OUTDIR}/sub-${SUBNUM}_level-2_task-drawLH_model-${MODELNAME}${SUFFIX} # new subject filename
        cp ${L2BASE_L} ${TWONEW_L} 
        sed -i '' 's/'${INSUB}'/'${SUBNUM}'/g' $TWONEW_L # update subject number. (That's it, because nothing else differs between subj in level2)
    fi
    if [ $DORH = 1 ]; then
        L2BASE_R=${PREPATH}/sub-${INSUB}/sub-${INSUB}_model-${MODELNAME}/sub-${INSUB}_level-2_task-drawRH_model-${MODELNAME}${SUFFIX} # template level2.fsf
        TWONEW_R=${OUTDIR}/sub-${SUBNUM}_level-2_task-drawRH_model-${MODELNAME}${SUFFIX} # new subject filename
        cp ${L2BASE_R} ${TWONEW_R} 
        sed -i '' 's/'${INSUB}'/'${SUBNUM}'/g' $TWONEW_R # update subject number. (That's it, because nothing else differs between subj in level2)
    fi
    if [ $DOLH = 1 ] && [ $DORH = 1 ]; then 
        L2BASE_A=${PREPATH}/sub-${INSUB}/sub-${INSUB}_model-${MODELNAME}/sub-${INSUB}_level-2_task-drawRH_model-${MODELNAME}${SUFFIX} # template level2.fsf
        TWONEW_A=${OUTDIR}/sub-${SUBNUM}_level-2_task-drawAH_model-${MODELNAME}${SUFFIX} # new subject filename
        cp ${L2BASE_A} ${TWONEW_A} 
        sed -i '' 's/'${INSUB}'/'${SUBNUM}'/g' $TWONEW_A # update subject number. (That's it, because nothing else differs between subj in level2)
    fi
    # for hand in LH RH AH; do # loop through the types of L2 analysis
    #     L2BASE=${PREPATH}/sub-${INSUB}/sub-${INSUB}_model-${MODELNAME}/sub-${INSUB}_level-2_task-draw${hand}_model-${MODELNAME}${SUFFIX} # template level2.fsf
    #     TWONEW=${OUTDIR}/sub-${SUBNUM}_level-2_task-draw${hand}_model-${MODELNAME}${SUFFIX} # new subject filename
    #     cp ${L2BASE} ${TWONEW} 
    #     sed -i '' 's/'${INSUB}'/'${SUBNUM}'/g' $TWONEW # update subject number. (That's it, because nothing else differs between subj in level2)
    # done
    if [ $DOFLIPRH = 1 ]; then
        # also do this for RHflip
        for hand in RHflip AHflip; do
            L2BASE=${PREPATH}/sub-${INSUB}/sub-${INSUB}_model-${MODELNAME}/sub-${INSUB}_level-2_task-draw${hand}_model-${MODELNAME}${SUFFIX} # template level2.fsf
            TWONEW=${OUTDIR}/sub-${SUBNUM}_level-2_task-draw${hand}_model-${MODELNAME}${SUFFIX} # new subject filename
            cp ${L2BASE} ${TWONEW} 
            sed -i '' 's/'${INSUB}'/'${SUBNUM}'/g' $TWONEW # update subject number. (That's it, because nothing else differs between subj in level2)
        # also, update AH
        #sed -i '' 's/RH/RHflip/g' ${PREPATH}/sub-${INSUB}/sub-${INSUB}_model-${MODELNAME}/sub-${INSUB}_level-2_task-drawAH_model-${MODELNAME}${SUFFIX}
        done
    fi
fi