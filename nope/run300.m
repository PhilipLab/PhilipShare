% run300
%
% Prepares to run 300-ROI on all subjects
% creates a fq300_roiRunner.txt that contains every script that must be run, which you do via "bash
% fq300_
% alter "modelLabels" variable to run for FSL, and/or OGRE, etc.

modelLabels={'FSL'}; %
deleteOld=0; % WARNING: if set, deletes the existing FQ300 directory first
subManual=1; % if 1, put in a manual sub list. If 0, automatically does all subjects
saving=1;
warning('off','MATLAB:table:ModifiedAndSavedVarnames')
roiInfo=readtable('/Users/Shared/ROI/300_ROI_Set/ROIs_300inVol_MNI_allInfo.txt');
roiAnat=table2array(readtable('/Users/Shared/ROI/300_ROI_Set/ROIs_anatomicalLabels.txt'))+1; % convert 0-7 to 1-8
anatKey={'cortexMid','cortexL','cortexR','hippocampus','amygdala','basalGanglia','thalamus','cerebellum'};
numRoi=300;
%handList={'LH','RH','RHflip','AH'};
handList={'LH','RH'};
numHands=length(handList);
wbList={'/Users/Shared/ROI/10_ROIs/roi-WB_hemi-L.nii.gz','/Users/Shared/ROI/10_ROIs/roi-WB_hemi-R.nii.gz','/Users/Shared/ROI/10_ROIs/roi-WB_hemi-B.nii.gz'};
wbLabels={'whole-lhem','whole-rhem','whole-brain'};
spaceList={'MNI152NLin2009cSym','MNI152NLin6Asym'};

%analysisLocal='/Users/Shared/10_Connectivity/derivatives/analysis';
analysisLocal='/Volumes/bphilip/Active/10_Connectivity/derivatives/analysis';
analysisRIS='/storage2/fs1/bphilip/Active/10_Connectivity/derivatives/analysis';
fslPrefixLocal='/usr/local/fsl/bin/featquery 1 ';
roiDirLocal='/Volumes/bphilip/Active/10_Connectivity/10_ROIs/300_ROI_Set';
roiDirRIS='/storage2/fs1/bphilip/Active/10_Connectivity/10_ROIs/300_ROI_Set';


%statString='6  stats/pe1 stats/cope1 stats/varcope1 stats/tstat1 stats/zstat1 thresh_zstat1';
statString='4  stats/pe1 stats/cope1 stats/varcope1 stats/zstat1';
if subManual==0
    subFolders=dir(sprintf('%s/sub-*',analysisLocal));
    numSub=length(subFolders);
else
    subHandCoded={'sub-2028','sub-2029','sub-2045','sub-2046','sub-2053','sub-2057'};
    %subHandCoded={'sub-1027','sub-1032','sub-1036','sub-1038','sub-1038','sub-1043','sub-1046','sub-2040','sub-2042','sub-2044'};
    %subHandCoded={'sub-1008','sub-1009','sub-1026','sub-1028','sub-1029','sub-2003','sub-2004','sub-2018','sub-2025','sub-2031','sub-2039'};
    numSub=length(subHandCoded);
end

for si=1:numSub
    if subManual==0
        subName=subFolders(si).name; % 10_XXXX
    elseif subManual==1
        subName=subHandCoded{si};
    end
    subNum=str2double(subName(end-3:end));
    for handi=1:numHands
        handName=handList{handi};
        if handi==2 && (strcmp(subName,'sub-1002') || strcmp(subName,('sub-1019'))) % known LH-onlys
            fprintf('Skipping %s hand %s\n',subName,handName);
            continue
        end
        for model=1:length(modelLabels) % pipeline & FSL
            modelName=modelLabels{model};
            for spacei=1:length(spaceList)
                spaceName=spaceList{spacei};
                % only loop through spaces if FMP
                if strcmp(modelName,'fMRIprep')
                    spaceString=sprintf('_space-%s',spaceName);
                else
                    spaceString=('');
                end
                % adapts to any
                localFeat=sprintf('%s/sub-%i/sub-%i_model-%s/sub-%i_level-2_task-draw%s_model-%s%s.gfeat/cope1.feat',analysisLocal,subNum,subNum,modelName,subNum,handName,modelName,spaceString);
                risFeat=sprintf('%s/sub-%i/sub-%i_model-%s/sub-%i_level-2_task-draw%s_model-%s%s.gfeat/cope1.feat',analysisRIS,subNum,subNum,modelName,subNum,handName,modelName,spaceString);
                if ~exist(localFeat,'dir') && ~exist(risFeat,'dir')
                    fprintf('No %s for %s_model-%s\n',modelName,subName,handName);
                    continue
                end
                fqLoc=[localFeat,'/fq300'];
                if deleteOld==1 && exist(fqLoc,'dir')
                    rmdir(fqLoc,'s');
                end
                [~,~]=mkdir(fqLoc);
                archNames={'x','y','z','network','anatomy'};
                roiArchive=table(roiInfo.x,roiInfo.y,roiInfo.z,roiInfo.netName,cell(300,1),'VariableNames',archNames);
                fqLocal=cell(304,1);
                fqRIS=cell(304,1);
                for roii=1:numRoi
                    thisX=roiInfo.x(roii,1);
                    thisY=roiInfo.y(roii,1);
                    thisZ=roiInfo.z(roii,1);
                    thisNet=roiInfo.netName{roii};
                    thisAnat=anatKey{roiAnat(roii)};
                    roi3dig=addz(roii,3); % 3-digit string
                    roiName=sprintf('sub-%i_task-draw%s_roi-%i_anat-%s_net-%s',subNum,handName,roii,thisAnat,thisNet);
                    roiLocal=sprintf('%s/300_ROI_split_2mm/300_roi%s-2mm.nii.gz',roiDirLocal,roi3dig);
                    outString=sprintf('fq300/roi%s',roi3dig);
                    cmdLocal=sprintf('%s %s %s %s -p -s %s',fslPrefixLocal,localFeat,statString,outString,roiLocal);
                    fqLocal{roii}=cmdLocal;
                    roiRIS=sprintf('%s/300_ROI_split_2mm/300_roi%s-2mm.nii.gz',roiDirRIS,roi3dig);
                    cmdRIS=sprintf('%s %s %s %s -p -s %s',fslPrefixLocal,risFeat,statString,outString,roiRIS);
                    fqRIS{roii}=cmdRIS;
                    roiArchive.anatomy{roii}=thisAnat; % save that
                end % roi loop
                % add three wholebrainers (MNI)
                for wbi=1:3
                    bonusString=sprintf('fq300/roi%i',300+wbi);
                    wbRoiSource=wbList{wbi};
                    wblString=sprintf('%s %s %s %s -p -s %s',fslPrefixLocal,localFeat,statString,bonusString,wbRoiSource);
                    wblRIS=sprintf('%s %s %s %s -p -s %s',fslPrefixLocal,risFeat,statString,bonusString,wbRoiSource);
                    fqLocal{300+wbi}=wblString;
                    fsRIS{300+wbi}=wblRIS;
                    tempStruct.x=0;
                    tempStruct.y=0;
                    tempStruct.z=0;
                    tempStruct.network='unassigned';
                    tempStruct.anatomy=wbLabels{wbi};
                    roiArchiveFull=[roiArchive;struct2table(tempStruct)]; % save that file
                end
                fqLocal{end}=sprintf('echo Finished roi300 for sub-%i_task-draw%s',subNum,handName);
                if saving==1
                    writetable(roiArchiveFull,sprintf('%s/fq300/sub-%i_task-draw%s_roiArchive.txt',localFeat,subNum,handName)); % archive of ROIs
                    writecell(fqLocal,sprintf('%s/fq300/sub-%i_task-draw%s_roiLocal.txt',localFeat,subNum,handName)); % text file of commands to run on local
                    writecell(fqRIS,sprintf('%s/fq300/sub-%i_task-draw%s_roiRIS.txt',localFeat,subNum,handName)); % text file of commands to run on local
                end
                %fprintf('Wrote files for %s hand %s\n',subName,handName)
            end % space loop
        end % model loop
    end % hand loop
end % sub loop