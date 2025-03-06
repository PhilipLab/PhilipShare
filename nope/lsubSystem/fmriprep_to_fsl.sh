#!/usr/bin/env bash

helpmsg(){
    echo "fmriprep_to_fsl.sh modifies fMRIprep L1 outputs to prepare for L2"
    echo "You should have already run populateFSF.sh to create the relevant FSF files."
    echo "Drawn from: https://mumfordbrainstats.tumblr.com/post/166054797696/feat-registration-workaround"
    echo "    -d -m -a -p -i --dir --modeldir --analysis --path --input"
    echo "        REQUIRED: an analysis directory (contains multiple .fsf/.feat files)"
    echo "        Example: /Volumes/LAMPbackup/10_Connectivity/derivatives/analysis/sub-2000/sub-2000_model-fMRIprep/"
    echo "    -r --run"
    echo "        Flag: if the L1 analyses aren't finished, then run them"
    echo "    -t --two"
    echo "        Optional. Flag: run all L2 analyses after modifying the L1 outputs. (Existing finished copies are renamed/moved)"
    echo "    -s --select"
    echo "        Optional. Flag: Use INSTEAD of '-t' to select a hard-coded subset of L2 analyses"
    echo "    -h --help -help"
    echo "        Echo this help message."
    exit
    }
if((${#@}<1));then
    helpmsg
    exit
fi

# defaults
RUNONE=0; RUNTWO=0; SELECT=0;

arg=("$@")
for((i=0;i<${#@};++i));do
    #echo "i=$i ${arg[i]}"
    case "${arg[i]}" in
        -d | -m | -a | -p | -i | --dir | --modeldir | --modelpath | --analysis | --analysisdir | --analysispath | --input )
            MODELPATH=${arg[((++i))]}
            #echo "SUBNUM=$SUBNUM"
            ;;
        -r | --run )
            RUNONE=1
            ;;
        -t | --two )
            RUNTWO=1
            ;;
        -s | --select )
            SELECT=1
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
if [ ! -d "${MODELPATH}" ];then
    echo "Model directory not found: ${MODELPATH}"
    else
    echo "Model directory found: ${MODELPATH}"
fi

# now we extract the info we need from the input filepath - https://stackoverflow.com/questions/23162299/how-to-get-the-last-part-of-dirname-in-bash
MODELDIR="$(basename $MODELPATH)" # just the current folder (not full path)
TEMP=${MODELDIR#*-} # sub-N_model-X becomes N_model-X
MODELNAME=${TEMP#*-} # N_model-X becomes X
SUBNUM=${TEMP%_*} # N_model-X becomes N

for FSFFILE in ${MODELPATH}/*.fsf; do
    #check is it L2, skip those
    if [[ ! $FSFFILE == *"level-2"* ]]; then 
        FSFROOT=${FSFFILE%.*} # XXX.fsf becomes XXX
        FEATDIR="${FSFROOT}.feat" # then add .feat to end, to make it a true feat directory
        FEATFILECHECK="${FSFROOT}.feat/rendered_thresh_zstat1.png" # a file that would only exist in a completed run
        if [ ! -d ${FEATDIR} ]; then # if the .feat directory doesn't exist, either error or run it
            if [ $RUNONE = 1 ]; then
                echo "Running FSF file (be patient): $(basename "${FSFFILE}")"
                /usr/local/fsl/bin/feat ${FSFFILE}
            else
                echo "ERROR: missing ${FEATDIR}, use -r to auto-run"
            fi
        elif [ ! -f ${FEATFILECHECK} ]; then # handle if directory exists but is incomplete
            if [ $RUNONE = 1 ]; then
                rm -r ${FEATDIR}
                echo "Replacing incomplete FSF file (be patient): $(basename "${FSFFILE}")"
                /usr/local/fsl/bin/feat ${FSFFILE}
            else
                 echo "ERROR: ${FEATDIR} was incomplete. Use -r to auto-clean and -run"
            fi
        else echo "Using existing $(basename "${FSFFILE}"), confirmed by presence of $(basename "${FEATFILECHECK}")"
        fi
        # remove reg_standard if it exists
        if [ -d "${FEATDIR}/reg_standard" ]; then
            #rm -rf "${FEATDIR}/reg_standard"
            mv "${FEATDIR}/reg_standard/" "${FEATDIR}/reg_standard_orig/"
        fi
        cp -R "${FEATDIR}/reg/" "${FEATDIR}/reg_orig"
        # delete reg directory .mat files, replace with identity matrix
        for MATFILE in ${FEATDIR}/reg/*.mat; do
            echo "Replacing $(basename "${MATFILE}")"
            cp /usr/local/fsl/etc/flirtsch/ident.mat ${MATFILE}
        done
        # overwrite the standard.nii.gz image with the mean_func.nii.gz
        cp ${FEATDIR}/mean_func.nii.gz ${FEATDIR}/reg/standard.nii.gz
    fi
done

# run L2 files, after making those corrections
if [ $RUNTWO = 1 ]; then
    for L2NAME in ${MODELPATH}/*_level-2*.fsf; do
        L2DIR="${L2NAME}.gfeat"
        L2FILE="${L2NAME}.fsf"
        if [ -d ${L2DIR} ]; then
            mv ${L2DIR} ${L2DIR}_old
        fi
        echo "Running level 2: $(basename "${L2FILE}")"
        /usr/local/fsl/bin/feat ${L2FILE}
    done
fi

if [ $SELECT = 1 ]; then
    for L2SELECT in RH_model-fMRIprep_space-MNI152NLin6Asym LH_model-fMRIprep_space-MNI152NLin6Asym LH_model-fMRIprep_space-MNI152NLin2009cSym RH_model-fMRIprep_space-MNI152NLin2009cSym RHflip_model-fMRIprep_space-MNI152NLin2009cSym; do
        L2SELNAME=${MODELPATH}/sub-${SUBNUM}_level-2_task-draw${L2SELECT}
        L2SDIR=${L2SELNAME}.gfeat
        L2SFILE=${L2SELNAME}.fsf
        if [ -d ${L2SDIR} ]; then
            mv ${L2SDIR} ${L2SDIR}_old
        fi
        echo "Running level 2: $(basename "${L2SFILE}")"
        /usr/local/fsl/bin/feat ${L2SFILE}
    done
fi
echo "Finished fmriprep_to_fsl.sh for sub-${SUBNUM}"