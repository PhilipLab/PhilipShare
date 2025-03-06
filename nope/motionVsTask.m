% motionVsTask.m
% evaluates motion*task correlation

calculateCorrs=1;
saveCorrs=1;
checkOutliers=1;

analysisDir='/Volumes/bphilip/Active/10_Connectivity/derivatives/analysis';
rawDir='/Volumes/bphilip/Active/10_Connectivity/raw_data';
allSubDirs=dir(sprintf('%s/sub-*/sub-*_model-fMRIprep',analysisDir));
numSubDirs=length(allSubDirs);
corrData=table;
allDesigns=cell(numSubDirs,6);
numVolumes=488;
%%
if calculateCorrs==1
    for si=1:numSubDirs
        subWordLoc=strfind(allSubDirs(si).name,'sub-');
        subName=allSubDirs(si).name(subWordLoc+4:subWordLoc+7);
        subDir=sprintf(sprintf('%s/sub-%s/sub-%s_model-fMRIprep',analysisDir,subName,subName));
        runDirs=dir(sprintf('%s/*space-MNI152NLin6Asym.feat',subDir));
        numRuns=length(runDirs);
        runCorrs=nan(numRuns,3);
        allDesigns{si,1}=str2double(subName);
        for ri=1:numRuns
            runFeatDir=runDirs(ri).name;
            designFile=readmatrix(sprintf('%s/%s/design.mat',subDir,runFeatDir),'fileType','text','NumHeaderLines',5);

            % columns are: easy, easy-deriv, hard, hard-deriv, 5 motion variables, N outliers. All but outliers come preloaded as mean-zero
            taskTiming=[designFile(:,1)+designFile(:,3),designFile(:,2)+designFile(:,4),sum(designFile(:,1:4),2)]; % task, dask-DV, sumum(designFile(:,1:4),2);

            % now load the confound timeline
            drawWordLoc=strfind(runFeatDir,'draw');
            runWordLoc=strfind(runFeatDir,'run');
            handName=runFeatDir(drawWordLoc+4:drawWordLoc+5);
            runName=runFeatDir(runWordLoc+4);
            confoundFile=sprintf('%s/sub-%s/regressors/sub-%s_fdmotionvalues_task-draw%s_run-%s.txt',rawDir,subName,subName,handName,runName);
            runFDs=[0;readmatrix(confoundFile)]; % pad with 0 at start since FDs are differences
            runCorrs(ri,:)=corr(taskTiming,runFDs);
            runIdentifier=repmat([str2double(subName),strcmp(handName,'RH'),str2double(runName)],numVolumes,1);
            allDesigns{si,ri}=[runIdentifier,taskTiming,runFDs];
        end
        corrData=[corrData;{str2double(subName),mean(runCorrs(:,1).^2),mean(runCorrs(:,2).^2),mean(runCorrs(:,3).^2)}];
        corrMaxes=[corrMaxes;{str2double(subName),max(runCorrs(:,1).^2),max(runCorrs(:,2).^2),max(runCorrs(:,3).^2)}];
        fprintf('Finished calculating subject %s\n',subName);
    end
    corrData=renamevars(corrData,["Var1","Var2","Var3","Var4"],["SN","Main","Deriv","Combo"]);
end

%% recalculate it without reducing from runs>subs - look at all runs
corrsByRun=table('Size',[numSubDirs*6,7],'VariableTypes',repmat("double",7,1),'VariableNames',["Sub","HandRH","Run","Main","Deriv","Sum","Greater"]);
for reSub=1:numSubDirs
    for reRun=1:6
        reData=allDesigns{reSub,reRun};
        if isempty(reData)
            corrsByRun((reSub-1)*6+reRun,:)=array2table(nan(1,7));
            continue
        end
        threeCorrs=corr(reData(:,4:6),reData(:,7)).^2;
        corrsByRun((reSub-1)*6+reRun,:)=array2table([reData(1,1:3),threeCorrs',max(threeCorrs(1:2))]);
    end
end
nanIndices=isnan(corrsByRun.Sub);
corrsByRun(nanIndices,:)=[];
[runGreaterOutliers,runMaxThresh]=findStandardOutliers(corrsByRun(:,7)); % use only "greater"
grOutliers=addvars(corrsByRun(:,1),runGreaterOutliers,'NewVariableNames',"Out");

%%
if saveCorrs==1
    saveDir=sprintf('%s/NRL_Shared/10_Connectivity/10_MRIanalysis/',getLocalBoxDir);
    writetable(corrData,sprintf('%s/corrData_%s.csv',saveDir,dateYMD));
    writetable(corrsByRun,sprintf('%s/corrsByRun_%s.csv',saveDir,dateYMD));
    writetable(corrMaxes,sprintf('%s/corrMaxRuns_%s.csv',saveDir,dateYMD));
    writecell(allDesigns,sprintf('%s/designsForCorr_%s.csv',saveDir,dateYMD));
end
% fasincating, here it's 1009, 2000, 2002, 2039

%%
if checkOutliers==1
    outliers=nan(numSubDirs,3);
    thresholds=nan(1,3);
    for coli=1:3
        dataCol=table2array(corrMaxes(:,coli+1));
        [colOutlier,upper]=findStandardOutliers(dataCol);
        outliers(:,coli)=colOutlier;
        thresholds(coli)=upper;
    end
    corrOutliers=addvars(corrData,outliers(:,1),outliers(:,2),outliers(:,3),'NewVariableNames',["OutMain","OutDeriv","OutCombo"]);
end
% this catches 1020, 2011