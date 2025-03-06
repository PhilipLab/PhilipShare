% legoAnalyze10
%
% pulls basic lego data (only) for 10_Connectivity.
% STEGA data comes from STEGAMRI_decode_runner.
%
% Select which blocks to use. (Unfortunately not everyone did N10, but all 4 still correlates better with N5+N10 (r=0.98) than N5 alone
% (0.89). If I use N5+N10 and compare the one-condition vs the two-condition... no diff, t = -1.4, p = 0.15. Whew.
%
% As of 250219, outliers are 2044 and 1055 only - they get calculated by this script.

%% inputs
omitList=[1000,1021,1042,2008,2014,2015,2020,2027,2034,2055,2063]; % participants with behav but no MRI 250101. (Don't skip outliers)
saveExcel=0;
saveBrick=0;
visualizeNumMoves=0; % for outlier calculation

%% fixed settings
useCond=["n5";"n10"]; % combine n5+n10.
warning('off','MATLAB:table:ModifiedAndSavedVarnames'); % don't bug me about this
legoDir='/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_BORIS-analysis';
counterbalanceFile='/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/IHC_DataCollection_250107.csv'; % download from REDCap
numUseBlocks=length(useCond);
% next 2 lines convert the "useblocks" input into a vector of which of those to use, in key order
condList=["n5";"n10";"s5";"s10"];
condsToUse=[ismember("n5",useCond),ismember("n10",useCond),ismember("s5",useCond),ismember("s10",useCond)];

%% first identify which subj to review. Any subj that has all its runs listed in here
legoLog=[legoDir,'/_LegoDataLog10.xlsx']; % this file contains dates & names of dataset that has received consensus judgment
logData=readtable(legoLog,'Sheet','LegoTask');
emptyRows=cellfun(@isempty,logData.Participant);
lastExists=find(emptyRows==0,1,'last'); % locate where there's actual data, in case other lab members have put in rando notes
logSub=nan(lastExists,2); % list of possible subj with logical y/n in column 2
for li=1:lastExists
    conSubStr=logData.Participant{li};
    conSubNum=str2double(conSubStr(4:end)); % turn sub-XXXX into XXXX
    logSub(li,1)=conSubNum;
    conDate=logData.ConsensusDate(li);
    if isnat(conDate) || conSubNum<1000 || ismember(conSubNum,omitList)  % no consensus date, or discardable subj, or on Omit List
        logSub(li,2)=0;
    else
        logSub(li,2)=1;
    end
end
subsToCheck=unique(logSub(:,1));
numCheckSub=length(subsToCheck);
subList=[subsToCheck,zeros(numCheckSub,1)]; % start like  subsToCheck, below will remove subj that don't have all bits done
for checki=1:numCheckSub
    thisCheckSub=subsToCheck(checki);
    subCheckData=logSub(logSub(:,1)==thisCheckSub,:);
    numOfBlocks=size(subCheckData,1);
    if sum(subCheckData(:,2))~=numOfBlocks
        subList(subList==thisCheckSub,:)=[];
    else
        subList(subList==thisCheckSub,2)=numOfBlocks;
    end
end
numSub=length(subList); % by now this should be [subnum, #blocks] only for sub with real consensus data

%% identify counterbalance
cbImport=readtable(counterbalanceFile);
cbRaw=table(cbImport.record_id,cbImport.ihc_lego_order_n5,cbImport.ihc_lego_order_n10,cbImport.ihc_lego_order_s5,cbImport.ihc_lego_order_s10,...
    'VariableNames',{'ID','n5','n10','s5','s10'});
condOrderList=nan(numSub,5);
cbSubList=convertCharsToStrings(cbRaw.ID);
for cbi=1:numSub
    thisSub=subList(cbi,1);
    [~,subRow]=ismember(sprintf("10_%i",thisSub),cbSubList);
    if subRow==0
        fprintf('Error: no lego data for sub %i\n',thisSub);
        continue
    end
    locationList=table2array(cbRaw(subRow,2:5)); % we ordered them N5, N10, S5, S10 above when building cbRaw
    locationList(locationList==5)=NaN; % 5's are Nans
    % huh, order was saved in REDCap as "0,1,2,4", must fix to "1,2,3,4"
    locationList(locationList==4)=3;
    locationList=locationList+1;
    % when you only have two it's "1, NAN, 2, NAN", so fix that too
    if isnan(locationList(2))
        locationList=[locationList(1),locationList(3),NaN,NaN];
    end
    condOrderList(cbi,:)=[thisSub,locationList]; % list of the 4 conditions in order
end

%% extract & analyze data
handUseData=nan(numSub,2); % all conditions
handCondData=nan(numSub,2); % specific conditions
numMoves=nan(numSub,5); % subNum, mean-of-blocks, b1, b2, b3, b4
for si=1:numSub
    subNum=subList(si,1);
    thisNumBlocks=subList(si,2);
    numMoves(si,1)=subNum;
    rowInOrders=find(condOrderList(:,1)==subNum);
    subUsage=nan(thisNumBlocks,1);
    subKeepUsage=nan(thisNumBlocks,1);
    subByBrick=nan(40,length(useCond));
    subBricki=1;
    for bi=1:thisNumBlocks
        fileName=sprintf('%s/10_Basic_Lego_Scoring/10_%i_B%i_ZZ.xlsx',legoDir,subNum,bi);
        legoAnalysis=borisAnalyze09(fileName);
        subUsage(bi)=mean(legoAnalysis.blockInfo(:,1));
        % do I keep this condition?
        blockCondition=condOrderList(rowInOrders,bi+1);
        if condsToUse(blockCondition)==1 % if this condition is one of the ones we keep
            subKeepUsage(bi)=mean(legoAnalysis.blockInfo(:,1));
            subByBrick(1:40,subBricki)=legoAnalysis.brickByBrick(1:40,3); % only take 1-40 if there are excess - we only have 40 bricks!
            subBricki=subBricki+1;
        end
        numBricks=size(legoAnalysis.brickByBrick,1);
        numMoves(si,bi+2)=sum(legoAnalysis.blockInfo(:,3));
    end
    handUseData(si,:)=[subNum,mean(subUsage)];
    handCondData(si,:)=[subNum,mean(subKeepUsage,'omitnan')];
    if saveBrick==1
        if size(subByBrick,2) ~= length(useCond); fprintf('Warning: %i columns in DBB for sub-%i\n',size(subByBrick,2),subNum); end
        saveBrickName=sprintf('%s/10_Data_By_Brick/sub-%i_HandUsage.csv',legoDir,subNum);
        writematrix(subByBrick,saveBrickName);
    end
    numMoves(si,2)=mean(numMoves(si,3:end),'omitnan');
end
meanMoves=numMoves(:,2);
outlierThresh=prctile(meanMoves,75)+(3*iqr(meanMoves));
if visualizeNumMoves==1
    scatter(meanMoves,1:length(meanMoves),'.');
    text(meanMoves,1:length(meanMoves),num2str(numMoves(:,1)));
    xlabel('Avg. num moves');
    ylabel('Subject (meaningless)');
end

%% save data
if saveExcel==1
    allTimeInfo=datevec(datetime);
    ymd=allTimeInfo(1:3); % keep only YMD
    saveLegoFileName=sprintf('%s/10_LegoData_%i%s%s.xlsx',legoDir,ymd(1)-2000,addz(ymd(2),2),addz(ymd(3),2));
    writematrix(handCondData,saveLegoFileName);
end