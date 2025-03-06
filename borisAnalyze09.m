% borisAnalyze09.m
%
% analyze the output of a BORIS video rating of one block of lego data. Does not work for prior variants (before 6/final of 09_LegoMethods)
% Input filename e.g. '.../09_149_B1_EM.xlsx'. Include the whole path.
%
% currently called by compareRaters09/10 & LegoAnalyze09/10
%
% Modified 4/12/2023 to correctly capture timing from consensus spreadsheets.
% Currently does NOT correctly capture events from consensus spreadsheets: takes events from rater 1. This only matters for advanced
% analysis (events other than start/stop/grasp)
% Modified 12/5/2023 to adapt to Boris update

function basicOutput = borisAnalyze09(fileName)
%function [blockInfo,legoInfo,modelTimeposts,saveTable] = borisAnalyze09(fileName)

legoInfo=nan(999,6);
legoi=1;
chunkedFileName=split(fileName,'/');
fileTail=split(chunkedFileName{end},'_');
subNum=str2double(fileTail{2});
blockNum=str2double(fileTail{3}(2));

warning('off','MATLAB:table:ModifiedAndSavedVarnames'); % don't bug me about this
rawTable=readtable(fileName,'ReadVariableNames',1);
% another round for if consensus
if strcmp('ZZ',fileName(end-6:end-5)) % if consensus
    % somehow variable names get lost sometimes in readTable
        timesOne=rawTable.Time1;
        actionOne=rawTable.Action1;
        modOne=rawTable.Mod1;
        timesTwo=rawTable.Time2;
        actionTwo=rawTable.Action2;
        %modTwo=rawTable.Mod2;
    IDcolumn=rawTable.ID1;
    % these have empty buffer at bottom but that's ok
    modelStartLogicalTwo=strcmp('Trial_Start',actionTwo); % 1 (true) where Trial Start
    modelStopLogicalTwo=strcmp('Trial_End',actionTwo); % ...Trial End
    modelStartIndsTwo=find(modelStartLogicalTwo); % index of Trial Start
    modelStopIndsTwo=find(modelStopLogicalTwo); % index of Trial End
    isConsensus=1;
    version='NA';
else % if not consensus
    timesOne=rawTable.Start_s_;
    actionOne=rawTable.Behavior;
    try
        modTwo=rawTable.Modifier_2;
        version='New'; % if that exists
    catch
        version='Old';
    end

    try % change in BORIS output structure?
        modOne=rawTable.Modifiers;
    catch
        modOne=rawTable.Modifier_1;
    end
    IDcolumn=rawTable.ObservationId;
    isConsensus=0;
    timesTwo=NaN;
end
% data fix
if iscell(timesOne)
    temp1=timesOne;
    timesOne=cellfun(@str2num,temp1);
end
if iscell(timesTwo)
    temp2=timesTwo;
    timesTwo=cellfun(@str2num,temp2);
end

% these have empty buffer at bottom but that's ok
modelStartLogicalOne=strcmp('Trial_Start',actionOne); % 1 (true) where Trial Start
modelStopLogicalOne=strcmp('Trial_End',actionOne); % ...Trial End
modelStartIndsOne=find(modelStartLogicalOne); % index of Trial Start
modelStopIndsOne=find(modelStopLogicalOne); % index of Trial End

numModels=length(modelStartIndsOne);
blockInfo=nan(numModels,3);
modelTimeposts=nan(numModels,2);
bii=1;
brickInfo=nan(999,3); % model, brick, L/R
for modeli=1:numModels
    modelModOne=modOne(modelStartIndsOne(modeli):modelStopIndsOne(modeli),:);
    modelTimesOne=timesOne(modelStartIndsOne(modeli):modelStopIndsOne(modeli));
    blockDur=modelTimesOne(end)-modelTimesOne(1); % all events in block
    leftList=strcmp('Left',modelModOne);
    rightList=strcmp('Right',modelModOne);
    moveList=contains(modelModOne,'Move');
    numMoves=sum(moveList);
    numLeft=sum(leftList);
    numRight=sum(rightList);
    numGrasps=numLeft+numRight;
    fracR=numRight/numGrasps;
    legoInfo(legoi,:)=[subNum,blockNum,blockDur,numLeft,numRight,fracR]; % there used to be a "6" after blocknum, huh
    blockInfo(modeli,:)=[fracR,blockDur,numMoves];
    % recal in a way that is needed for brick-by-brick info
    graspRealIndices=strcmp(modelModOne,'Right') | strcmp(modelModOne,'Left');
    realRight=strcmp('Right',modelModOne(graspRealIndices));
    if numGrasps > 5 % if more than 5 blocks...
        if any(strcmp(modelModOne,'participant-initiated')) % if due to their rebuild, use before it
            realRight=realRight(1:5);
            numGrasps=5;
        %elseif any(strcmp(modelModOne,'experimenter-initiated')) % if due to our rebuild, unsure
            %fprintf('Experimenter rebuild many grasps in %i block %i model %i\n',subNum,blockNum,modelNum);
            %bob=1;
        %else
            %fprintf('Unexpectedly many grasps in %i block %i model %i\n',subNum,blockNum,modeli);
        end
    end
    brickInfo(bii:bii+numGrasps-1,:)=[repmat(modeli,numGrasps,1),(1:numGrasps)',realRight];
    bii=bii+numGrasps;
    if isConsensus==1 % if another rater, average their times
        %modelModTwo=modTwo(modelStartIndsTwo(modeli):modelStopIndsTwo(modeli),:); % not currently used
        modelTimesTwo=timesTwo(modelStartIndsTwo(modeli):modelStopIndsTwo(modeli));
        avgStart=mean([modelTimesOne(1);modelTimesTwo(1)]);
        avgEnd=mean([modelTimesOne(end);modelTimesTwo(end)]);
        modelTimeposts(modeli,:)=[avgStart,avgEnd];
    else
        modelTimeposts(modeli,:)=[modelTimesOne(1),modelTimesOne(end)];
    end
    % fix data depending on # columns
    
    legoi=legoi+1;
end % model loop
legoInfo(legoi:end,:)=[];
brickEnder=max([bii;41]);
brickInfo(brickEnder:end,:)=[];

modOut=modOne;
if strcmp(version,'New') % new version of Boris has two modifier columns
    plainSize=size(rawTable,1);
    for ti=1:plainSize
        thisMod2=modTwo{ti};
        if ~isempty(thisMod2) % if something in modifier two
            modOut{ti}=[modOne{ti},'|',modTwo{ti}];
        end
    end
end

borisTimes=duration(0,0,timesOne,'format','mm:ss.SSS'); % convert to min:sec:ms

% this leaves you with: fileName, Behavior, Modifiers, Start_s_
% ...for rater 1 only! But that's fine b/c post-consensus, the 2 raters should agree.

% simple NumRebuilds
numCuedRebuilds=sum(strcmp(modOut,'experimenter-initiated'));
basicOutput.blockInfo=blockInfo; % for each block: FracR, duration, numMoves
basicOutput.legoInfo=legoInfo; % for each block: SN, block#, block duration, #left, #right, FracR
basicOutput.modelTimeposts=modelTimeposts;
basicOutput.saveTable=table(IDcolumn,actionOne,modOut,timesOne,'VariableNames',{'ID','Action','Mod','Time'});
basicOutput.borisTimes=borisTimes;
basicOutput.numModels=length(blockInfo);
basicOutput.numCuedRebuilds=numCuedRebuilds;
basicOutput.brickByBrick=brickInfo;