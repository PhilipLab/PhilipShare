% compareRaters10
%
% Based on compareRaters09, looks to see where two lego raters differ in their coding of participant video.
% BASIC analysis: left/right, start/stop, and various error
%
% Revised 230614 to call borisAnalyze09 instead of borisAnalyze10. The later script is deprecated.
% Revised 231205 to handle changes in Boris output structure
% TO ADD: externally identify which is N5 and which is S5.

%% settings
threshold=1.0; % time in sec: how far apart must model durations be, before it flags a problem?
saveSummary=1; % 0 or 1: save index file?
saveComparisons=1; % 0 or 1: save _ZZ comparison files?

%%setup
dataDir='/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_BORIS-analysis/10_Basic_Lego_Scoring';
logFile='/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_BORIS-analysis/_LegoDataLog10.xlsx';
subNames=readmatrix(logFile,'Range','A2:A455','Sheet','LegoTask','OutputType','char');
emptyRows=cellfun(@isempty,subNames);
lastExists=find(emptyRows==0,1,'last'); % locate where there's actual data (in untitled array)
subNames(lastExists+1:end)=[]; % cut empties
blockList=readmatrix(logFile,'Range',sprintf('B2:B%i',lastExists+1),'Sheet','LegoTask','OutputType','double'); % +1 is b/c Excel file has header row, unlike cell array
raterList1=readmatrix(logFile,'Range',sprintf('C2:C%i',lastExists+1),'Sheet','LegoTask','OutputType','char');
raterList2=readmatrix(logFile,'Range',sprintf('D2:D%i',lastExists+1),'Sheet','LegoTask','OutputType','char');
consensusDate=readmatrix(logFile,'Range',sprintf('E2:E%i',lastExists+1),'Sheet','LegoTask','OutputType','datetime');
numSub=length(subNames);
reportText=cell(numSub*24,3); % each sub has two 4-models and two 8-models
reportRow=2; % start at 2 because then I'll use row 1 for headers
exceptionCatcher=zeros(3,1); % error tracker: no raters, no rater2, consensus exists, 

%% compare raters' excel files
numRows=length(blockList);
for ri=1:numRows
    thisName=subNames{ri};
    if strcmp(thisName,'10_1036')
        bob=1;
    end
    subNum=str2double(thisName(4:end));
    blockNum=blockList(ri);
    if isempty(raterList1{ri}) || strcmp(raterList1{ri},'n/a') % no ratings
        exceptionCatcher(1)=exceptionCatcher(1)+1;
        continue
    elseif isempty(raterList2{ri})
        exceptionCatcher(2)=exceptionCatcher(2)+1;
        continue
    elseif ~isnat(consensusDate(ri)) && strcmp('datetime',class(consensusDate(ri))) % consensus done
        ratingFileZ=sprintf('%s/%s_B%i_ZZ.xlsx',dataDir,thisName,blockNum);
        basicConsensus=readtable(ratingFileZ);
        identical=isequal(basicConsensus.Action1,basicConsensus.Action2);
        if identical==0
            reportText{reportRow,1}=thisName;
            reportText{reportRow,2}=blockNum;
            reportText{reportRow,3}='Consensus date listed, but ZZ actions not identical';
            reportRow=reportRow+1;
        end
        exceptionCatcher(3)=exceptionCatcher(3)+1;
        continue
    else % if both present, and no consensus yet, compare the data
        ratingFile1=sprintf('%s/%s_B%i_%s.xlsx',dataDir,thisName,blockNum,raterList1{ri});
        basic1=borisAnalyze09(ratingFile1); % 09 is fine! No need for separate exp09/exp10!
        ratingFile2=sprintf('%s/%s_B%i_%s.xlsx',dataDir,thisName,blockNum,raterList2{ri});
        basic2=borisAnalyze09(ratingFile2);
        numModels=basic1.numModels;

        % now do comparrisons
        reporter=cell(2,1); % max size
        reporter{1}='Ok!';
        repi=1;

        eventFail=[];
        if size(basic2.saveTable,1)~=size(basic1.saveTable,1) % if they don't line up, can't even compare them
            reporter{repi}='Event count mismatch. ';
            repi=repi+1;
        else % if they do match sizes, figure out the error types.
            if ~all(cellfun(@strcmp,basic1.saveTable.Action,basic2.saveTable.Action))
                reporter{repi}='Action type mismatch. ';
                repi=repi+1;
            end
            if ~all(cellfun(@strcmp,basic1.saveTable.Mod,basic2.saveTable.Mod))
                reporter{repi}='Modifier mismatch. ';
                repi=repi+1;
            end
        end
        %modelReporter=cell(mi,1); % for saving in ZZ consensus file
        misStarts=[]; misEnds=[];
        for mi=1:numModels
            if abs(basic1.modelTimeposts(mi,1)-basic2.modelTimeposts(mi,1))>=threshold % if start times are off
                misStarts=[misStarts;mi];
            end
            if abs(basic1.modelTimeposts(mi,2)-basic2.modelTimeposts(mi,2))>=threshold % if end times are off
                misEnds=[misEnds;mi];
            end
        end % model loop
        timeErrors=cell(2,1);
        ti=1;
        if ~isempty(misStarts)
            timeErrors{ti}=sprintf('Trial_Start mismatch in models %s. ',num2str(misStarts'));
            ti=ti+1;
        end
        if ~isempty(misEnds)
            timeErrors{ti}=sprintf('Trial_End mismatch in models %s. ',num2str(misEnds'));
            ti=ti+1;
        end
        reportLine=sprintf('%s%s%s%s',reporter{:},timeErrors{:});
        reportText{reportRow,1}=thisName;
        reportText{reportRow,2}=blockNum;
        reportText{reportRow,3}=reportLine;
        reportRow=reportRow+1;
        fullCompFile=sprintf('%s/%s_B%i_ZZ.xlsx',dataDir,thisName,blockNum);
        if saveComparisons==1 && exist(fullCompFile,'file')==0 % won't overwrite
            % rename for legibility
            r1table=renamevars(basic1.saveTable,{'ID','Action','Mod','Time'},{'ID1','Action1','Mod1','Time1'});
            r2table=renamevars(basic2.saveTable,{'ID','Action','Mod','Time'},{'ID2','Action2','Mod2','Time2'});
            t1table=table(basic1.borisTimes,'VariableNames',{'Time1b'});
            t2table=table(basic2.borisTimes,'VariableNames',{'Time2b'});
            writetable(r1table,fullCompFile,'sheet','consensus','Range','A:D','writemode','overwritesheet');
            writetable(r2table,fullCompFile,'sheet','consensus','Range','E:H');
            writetable(t1table,fullCompFile,'sheet','consensus','Range','I:I');
            writetable(t2table,fullCompFile,'sheet','consensus','Range','J:J');
            % identical backups
            writetable(r1table,fullCompFile,'sheet','original','Range','A:D','writemode','overwritesheet');
            writetable(r2table,fullCompFile,'sheet','original','Range','E:H');
            writetable(t1table,fullCompFile,'sheet','original','Range','I:I');
            writetable(t2table,fullCompFile,'sheet','original','Range','J:J');
            % save timing mismatch info
            if ti==1 % if no timing errors, add a special note to say so
                timeErrors{1}='No timing errors';
            end
            writecell(timeErrors,fullCompFile,'sheet','timing','writemode','overwritesheet');
            %writecell(timeErrors,sprintf('%s/%s',dataDir,compFileName),'sheet','timing','writemode','overwritesheet');
            fprintf('Created %s_B%i_ZZ.xlsx\n',thisName,blockNum)
        end % end saving

    end % rater presence check
end % LegoDataLog row loop
reportText(reportRow:end,:)=[];

%% save data
if saveSummary==1
    allTimeInfo=datevec(datetime);
    ymd=allTimeInfo(1:3); % keep only YMD
    reportText{1,1}='SUB_ID';
    reportText{1,2}='BLOCK';
    reportText{1,3}='ERRORS';
    summaryFileName=sprintf('%s/LegoCompare_%i%s%s.xlsx',dataDir,ymd(1)-2000,addz(ymd(2),2),addz(ymd(3),2));
    writecell(reportText,summaryFileName,'writemode','overwritesheet');
    writematrix('FINISHED?',summaryFileName,'Range','D1:D1');
end
