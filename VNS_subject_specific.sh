#!/bin/bash

helpmsg(){
    echo ">> VNS_subject_specific.sh DISTANCE# [DIRECTORY_WITH_CORE_EXAM_FILES]"
    echo " Creates participant-specific exam files for the VNS-REHAB MRI study. ONCE PER PARTICIPANT, NOT EVERY VISIT."
    echo " Use patient's "drawing-check" form for the following procedure:"
    echo "  1. Find a point that represents the patient's average OFF-PERFECT ERROR (distance from shape MIDLINE)" 
    echo "  2. At that point, measure the OFF-ROAD DISTANCE (distance from shape EDGE, mm). Might be zero!"
    echo "      (If it is zero, run this script anyways to produce a subject-specific record)"
    echo " Optionally you may also specify the Core Examfile Directory. If not it will use a default."
    echo " Example: VNS_subject_specific.sh 10 /Users/bphilip/Library/CloudStorage/Box-Box/_BoxMayo/VNS_Rehab/examfiles_VNS"
    exit
    }
if [ -z "$1" ]; then
    helpmsg
    exit
fi

default_exampath="/Users/bphilip/Library/CloudStorage/Box-Box/_BoxMayo/VNS_Rehab/examfiles_VNS"

# take input variables. Note that these are errors on a LARGE shape. 
DISTANCE=$1
if [[ "$#" < 2 ]]; then
    EXAMPATH=$default_exampath
    echo "Using default exam path $EXAMPATH"
else
    EXAMPATH=$2
    echo "Selected exam path $EXAMPATH"
fi
datestr=$(date +%y%m%d) # date YYMMDD

# math:
errorPixels=$((DISTANCE * 6)) # 5.8 pixels/mm

halfError=$((errorPixels / 2))
fifthError=$((errorPixels / 5))

outputLow=$((fifthError + 60))
outputMed=$((halfError + 70))
outputHigh=$((errorPixels + 80))

# now copy & edit exam file
outputPath="${EXAMPATH}/examfiles_${datestr}"
mkdir $outputPath
for run in run1 run2 run3 practice1 practice2; do
    rawFile="${EXAMPATH}/C3t_${run}_CORE.json"
    outFile="${outputPath}/C3t_${run}_${datestr}.json"
    cp -R $rawFile $outFile
    sed -i '' 's/_CORE/_'${datestr}'/g' ${outFile} # update examName
    # to avoid accidentally double-editing, add a pattern-breaking FLAG for values already edited
    sed -i '' 's/: 60/:FLAG '${outputLow}'/g' ${outFile} # low values
    sed -i '' 's/: 70/:FLAG '${outputMed}'/g' ${outFile} # med values
    sed -i '' 's/: 80/:FLAG '${outputHigh}'/g' ${outFile} # high values
    # now clean up flag
    sed -i '' 's/:FLAG/:/g' ${outFile}
    #echo "Setting values ${outputLow} ${MED_INPUT} ${outputHigh} in file ${outFile}"
done
echo "Set path width pixel values for ${datestr} as ${outputLow}, ${outputMed}, ${outputHigh}"

