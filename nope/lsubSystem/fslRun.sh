#!/bin/bash 

helpmsg(){
    echo "fslRun.sh runs a directory of FSL files. Uses -r -t (or -s for fMRIprep)"
    echo "For details see fsl_directory_run.sh"
    echo "    -d -p -i --input --dir --path"
    echo "        Full path to directory that contains fsf files"
    echo "        Example: /storage2/fs1/bphilip/Active/10_Connectivity/derivatives/analysis/sub-1009/sub-1009_model-fMRIprep"
    exit
    }
if((${#@}<1));then
    helpmsg
    exit
fi

FEATDIR=""

arg=("$@")
for((i=0;i<${#@};++i));do
    case "${arg[i]}" in
        -d | -p | -i | --input | --dir | --path )
            FEATDIR=${arg[((++i))]}
            ;;
        -h | --help | -help)
            helpmsg
            exit
            ;;
        *) unexpected+=(${arg[i]})
            ;;
    esac
done

DATADIR=/storage2/fs1/bphilip/Active
LSF_DOCKER_PRESERVE_ENVIRONMENT=false
LSF_DOCKER_ENTRYPOINT=/bin/sh
LSF_DOCKER_VOLUMES="/storage2/fs1/bphilip/Active:/storage2/fs1/bphilip/Active" 
FSLDIR=/usr/local/fsl
temp1=$(basename $FEATDIR) # the last folder name
model=${temp1#*model-} # everything after "model-"
temp2=${temp1#*-} # 1009_model
sub=${temp2%_*}
#sub=sub-2040

if [ $model == "fMRIprep" ]; then
    flags="-r -s -f"
    echo "Preparing for fMRIprep conversions"
elif [ $model = "OGRE" ]; then
    flags="-r -t -o"
    echo "Preparing for OGRE conversions"s
else
    flags="-r -t"
fi

#echo "bsub -J FSLDIR -n 4 -R 'rusage[mem=16GB]' -G compute-bphilip -q general -oo /storage2/fs1/bphilip/Active/10_Connectivity/logs/featlogs/featRun_job%J_sub${sub}.txt -a 'docker(ghcr.io/washu-it-ris/fsl:6.0.7.12)' /bin/bash -i ${DATADIR}/fsl_directory_run.sh -i ${DATADIR}/10_Connectivity/derivatives/analysis/sub-${sub}/sub-${sub}_model-${model} ${flags}"

bsub -J FSLDIR -n 4 -R 'rusage[mem=16GB]' -G compute-bphilip -q general -oo /storage2/fs1/bphilip/Active/10_Connectivity/logs/featlogs/featRun_job%J_sub${sub}.txt -a 'docker(ghcr.io/washu-it-ris/fsl:6.0.7.12)' /bin/bash -i ${DATADIR}/fsl_directory_run.sh -i ${DATADIR}/10_Connectivity/derivatives/analysis/sub-${sub}/sub-${sub}_model-${model} ${flags}

