% STEGAMRI_decode.m
%
% Takes a .json file from STEGA app and makes sense of it. Currently the output is clunky and requires memorization/notes on what variable
% is what; someday, redesign with tables.
%
% Designed 211210 - decile version from 10_200.
% Altered to a function call on 230413
% Update 231107 - removes outlier datapoints where absolute acceleration > 4 SD (per subject)
% 240228 - created & removed BlockData - it didn't fit in this data structure, handle it externally instead
%
% based on W2Hdecode.m and WTHrunner.m (from 04_), and STEGAMRI_decodePilot
% Remember that "end of run" counts as an activeStart.
% This code successfully only looks during active parts, ignores data between shape parts
%
% Trialdata {1}: real trial #, presented trial # including empties, block #, decile
% Trialdata {2}: raw data struct from STEGA
% Trialdata {3}: 1-6: trialNum, shapeID, thickness, partNum, partType, (partsmooth)
%            7-17: pen X/Y, target X/Y, distnce(px), velocity(pix/sec), directionError, pointNum, time, posAcc, block#
% summary = hand, run, trial, block, decile, shape, abs(direrr), smooth, speed, poserr(px), posAcc(px), numPoints
% outlierinfo: mean(accel), std(accel), mean(abs(accel)), std(abs(accel)), cutoff, # points cut, % cut

function [trialData, trialSummary, outlierInfo] = STEGAMRI_decode(jsonfile)

runFileName=jsonfile;
numTrialVars=17;
distanceMinimum=0.5; % minimum distnace is this many pixels

%% run number: determine from "_XH#_"
handloc=regexp(runFileName,'_[LR]H[123]_');
handChar=runFileName(handloc+1);
runChar=runFileName(handloc+3);

if strcmp(handChar,'L')
    handNum=0;
elseif strcmp(handChar,'R')%
    handNum=1;
else
    sprintf('Bad run number in STEGAMRI_decode: %s\n',runFileName);
end
runNum=str2double(runChar);

try
    fileJson=fileread(runFileName);
catch
    fileJson=fileread([runFileName(1:end-5),'_Run.json']);
end
fileRaw=jsondecode(fileJson);
fileData=fileRaw.runData;
examData=fileRaw.examDefinition;

fakeSize=size(fileData,1);
for sizer=1:fakeSize
    if iscell(fileData)
        thisCheckSpeed=fileData{sizer}.speed;
    else
        thisCheckSpeed=fileData(sizer).speed;
    end
    if thisCheckSpeed==0
        trueSize=sizer-1;
        break
    end
end

startTime=fileRaw.triggerTimeStamps(1);
restStarts=fileRaw.activeToRestTimeStamps-startTime;
activeStarts=fileRaw.restToActiveTimeStamps-startTime;
allStarts=[restStarts,zeros(size(restStarts));activeStarts,ones(size(activeStarts))];

timeHolder=[0,-1;allStarts];
[~,sorti]=sort(timeHolder(:,1));
timeSort=timeHolder(sorti,:);
timeMatrix=[timeSort,[diff(timeSort(:,1));0]]; % timestamp, event type, actualDir
numTimes=size(timeMatrix,1);
timeMatrix(end-1:end,2)=2;

%% next add Intended Dur/Timestamp columns

newMatrix=[timeMatrix,nan(numTimes,9)]; % ... 4=expectDur, 5=errorDur, 6=cumExpectEnd, 7=cumError, 8=cumActualEnd, 9=expectStart
for ni=1:numTimes
    thisEvent=newMatrix(ni,2);
    switch thisEvent
        case -1
            thisDuration=examData.restTimeBeforeStart;
        case 0
            thisDuration=examData.restBlock;
        case 1
            thisDuration=examData.activeBlock;
        case 2
            thisDuration=-1;
    end
    newMatrix(ni,4)=thisDuration;
end
finalRestInd=find(newMatrix(:,4)==-1,1);
newMatrix(finalRestInd-1,4)=examData.restTimeAfterEnd;
newMatrix(finalRestInd:end,4)=0;
newMatrix(:,5)=newMatrix(:,3)-newMatrix(:,4); % event duration error
newMatrix(:,6)=cumsum(newMatrix(:,4));
newMatrix(:,7)=cumsum(newMatrix(:,5));
newMatrix(:,8)=newMatrix(:,1)+newMatrix(:,3); % starttime + actualDir
newMatrix(:,9)=cumsum(newMatrix(:,4))-newMatrix(1,4);

% include decile labels
decileColumn=nan(numTimes,1);
decAccumulator=1;
try
    for decTargeti=1:numTimes
        isActiveBlock=newMatrix(decTargeti,2);
        if isActiveBlock~=1 % if this isn't actually a block
            decileColumn(decTargeti)=0;
        else
            findDecName=examData.order(decAccumulator).groupName;
            findDecNum=str2double(findDecName(4:5));
            decileColumn(decTargeti)=findDecNum;
            decAccumulator=decAccumulator+1;
        end
    end % decile labeling
catch
    fprintf('Deciles failed\n')
end


% Event Type	Len-Expect	Len-Actual	Len-Error	Cum-expect-End	Cum-Act-St	Cum-Act-End	Cum-Error
% now reorder: Type,LengthExpect,LengthActual,LengthError, CumExpectStart,CumActualStart*, CumExpectEnd, CumActualEnd, CumErrorEnd, decile
epochMatrix=[newMatrix(:,[2,4,3,5, 9,1,6,8,7]),decileColumn];

% ok that's the duration stuff.
%% Now let's get into the actual data values.

savingLegoWTH=0;

numTrials=size(fileRaw.runData,1);
trialDataRaw=cell(numTrials,3);
trialSummary=nan(numTrials,12);
realTrial=1;
for triali=1:numTrials
    if iscell(fileRaw.runData)
        simpleSpeed=fileRaw.runData{triali}.speed;
    else
        simpleSpeed=fileRaw.runData(triali).speed;
    end
    if simpleSpeed==0 % if no movement
        continue
    end
    if iscell(fileRaw.runData)
        thisTrialData=fileRaw.runData{triali};
        if iscell(fileRaw.runData{triali}.eachShapePart)
            trialStartRaw=fileRaw.runData{triali}.eachShapePart{1}.eachUserPoint{1}.time;
        else
            trialStartRaw=fileRaw.runData{triali}.eachShapePart(1).eachUserPoint{1}.time;
        end
    else
        trialStartRaw=fileRaw.runData(triali).eachShapePart(1).eachUserPoint.time;
        thisTrialData=fileRaw.runData(triali);
    end
    %trialStartRaw=fileRaw.runData(triali).eachShapePart(1).eachUserPoint.time;
    trialStartTime=trialStartRaw-startTime;
    trialBlockInd=find(epochMatrix(:,6)<trialStartTime,1,'last'); % look at epoch matrix for prev blockstart
    trialDecile=epochMatrix(trialBlockInd,10);
    trialDataRaw{realTrial,1}=[realTrial,triali,trialBlockInd/2,trialDecile]; % real trial #, trial # including empties, block #, decile
    trialDataRaw{realTrial,2}=thisTrialData;
    % now get the key data out.
    numParts=length(thisTrialData.eachShapePart);
    numPoints=length(thisTrialData.velocities);
    pointMatrix=nan(numPoints,numTrialVars);
    pointInd=1;
    trialLead=[triali,thisTrialData.shape.id,thisTrialData.shape.settings.shapeThickness]; % trial data: ti, shapeID, thickness
    for pi=1:numParts
        partData=thisTrialData.eachShapePart(pi);
        if iscell(partData)
            partData=partData{1}; % sometimes a 1x1 cell
        end
        partType=partData.shapePartData.type;
        if strcmp(partType,'Line')
            partX=partData.shapePartData.path(:,1);
            partY=partData.shapePartData.path(:,2);
            if range(partY)<1 % Y doesn't change: vertical
                typeValue=0;
            elseif range(partX)<1 % X doesn't change: horizontal
                typeValue=1;
            elseif partY(end)>partY(1) % if rising to right
                typeValue=2;
            elseif partY(end)<partY(1) % if lowering to right
                typeValue=3;
            end % end straightline-type
        elseif strcmp(partType,'SimiCircle') % typo in original raw data
            if partData.shapePartData.StartAngle==180 % hill
                typeValue=10;
            elseif partData.shapePartData.StartAngle==-180 % valley
                typeValue=11;
            end
        elseif strcmp(partType,'Circle')
            typeValue=20;
        else
            typeValue=-1;
        end % part-type evaluation. NOT YET USED
        partLead=[partData.id,typeValue,NaN]; % partID, partType
        numPoints=length(partData.eachUserPoint);
        for ui=1:numPoints
            if iscell(fileRaw.runData) && ~ischar(partData.speed)
                pointData=partData.eachUserPoint{ui};
            else
                pointData=partData.eachUserPoint(ui);
            end
            pointDistFloored=max(pointData.distanceFromShapePart,distanceMinimum); 
            pointLead=[pointData.pencilPoint',pointData.nearestPointOnShapePart',...
                pointDistFloored,pointData.velocity, pointData.smoothnessAngle,ui,pointData.time-startTime]; 
            pointPosAcc=1/pointDistFloored;
            pointMatrix(pointInd,:)=[trialLead,partLead,pointLead,pointPosAcc,NaN];
            % 1-6: trialNum, shapeID, thickness, partNum, partType, (partsmooth)
            % 7-16: pen X/Y, target X/Y, distnce, velocity(pix/sec), directionError, pointNum, time, posAcc
            pointInd=pointInd+1;
            % except, if vel > 1000 pix/sec, destroy? NO, instead do the scrubbing below instead. Hard to know how far is 1000 pix.
        end % point loop
        % recalculate velocity smoothness
        recentVel=pointMatrix(pointInd-ui:pointInd-1,12); % velocity data from that last bit
        pointMatrix(pointInd-ui:pointInd-1,6)=smoothCalc(recentVel); % velocity smoothness
        %velSmoothCalc=smoothCalc(recentVel);
        %dirSmoothCalc=smoothCalc(pointMatrix(pointInd-ui:pointInd-1,13));
        %pointMatrix(pointInd-ui:pointInd-1,6)=smoothCalc(pointMatrix(pointInd-ui:pointInd-1,13)); % direction smoothness
    end % part loop (allpoints)
    badRows=find(isnan(pointMatrix(:,1)),1);
    pointMatrix(badRows:end,:)=[];
    trialDataRaw{realTrial,3}=pointMatrix;

    shapeTensDigit=thisTrialData.shape.id;
    shapeHundredsDigit=(thisTrialData.shape.settings.shapeThickness)-10;
    shapeNum=(shapeHundredsDigit*10)+shapeTensDigit;
    % hand, run, trial, block, decile, shape, [direrr, smooth, speed, poserr]
    trialSummaryRaw(realTrial,:)=[handNum,runNum,realTrial,trialBlockInd/2,trialDecile,shapeNum,abs(mean(pointMatrix(:,13))),mean(pointMatrix(:,6)),mean(pointMatrix(:,12)),mean(pointMatrix(:,11)),mean(pointMatrix(:,16))];
    realTrial=realTrial+1;
end % trial loop

trialDataRaw(realTrial:end,:)=[]; % cut empties
trialSummaryRaw(realTrial:end,:)=[];

%% go back and add block#s separately, since those aren't within trial
mergedData=cell2mat(trialDataRaw(:,3));
% next 2 lines: https://www.mathworks.com/matlabcentral/answers/360259-can-i-used-cellfun-with-a-function-which-has-more-than-one-input
matwidth = @(x) size(x,1);
trialLengths=cellfun(matwidth,trialDataRaw(:,3));
for blocki=1:10
    blockStartTime=activeStarts(blocki);
    blockStopTime=activeStarts(blocki+1);
    blockIndices=find(mergedData(:,15)>=blockStartTime & mergedData(:,15)<=blockStopTime);
    mergedData(blockIndices,17)=blocki;
end
% now put that back into trials
pointNumsByTrial=[0;cumsum(trialLengths)];
for trialblock=1:realTrial-1
    thisTrialInds=pointNumsByTrial(trialblock)+1:pointNumsByTrial(trialblock+1);
    trialDataRaw{trialblock,3}(:,17)=mergedData(thisTrialInds,17);
end

%% data scrubbing: remove points where accel is above 4 SD
trialData=trialDataRaw;
nRealTrials=size(trialDataRaw,1);
trialSummary=trialSummaryRaw(1:nRealTrials,:);
outlierInfo=nan(nRealTrials,7);
for scrubi=1:nRealTrials
    checkTrial=trialDataRaw{scrubi,3};
    checkVel=checkTrial(:,12);
    checkVelAcc=[diff(checkVel);0];
    absAcc=abs(checkVelAcc);
    cutoff=mean(absAcc)+(4*std(absAcc));
    badPoints=absAcc>cutoff;
    pointsAboveCutoff=sum(badPoints);
    outlierInfo(scrubi,:)=[mean(checkVelAcc),std(checkVelAcc),mean(absAcc),std(absAcc),cutoff,pointsAboveCutoff,pointsAboveCutoff/length(checkVel)];
    scrubbedTrial=checkTrial;
    scrubbedTrial(badPoints,:)=nan(pointsAboveCutoff,numTrialVars);
    trialData{scrubi,3}=scrubbedTrial;
    trialSummary(scrubi,7:12)=[abs(mean(scrubbedTrial(:,13),'omitnan')),mean(scrubbedTrial(:,6),'omitnan'),mean(scrubbedTrial(:,12),'omitnan'),mean(scrubbedTrial(:,11),'omitnan'),mean(scrubbedTrial(:,16),'omitnan'),size(scrubbedTrial,1)];
end