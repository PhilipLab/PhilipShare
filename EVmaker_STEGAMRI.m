% EVmaker_STEGMRI.m
%
% Makes EV files from a STEGAMRI  RUN (output) file. Exam no longer needed.
% Expects only one "LH#" or "RH#" file in the STEGA directory - will die if you have duplicates
% Updates 240201: creates "rest" condition too, which is for conn/gPPI; auto loops through sub
% Updates 240413: chmod 777
%
% This could be much more efficient (especially in file saving) 
%
% Doesn't create separate easy/hard conn directories.

%% input controls
overwrite=0; % if 0, only creates new; if 1; trashes old too
saving=1; % 0 = off, 1 = all (easy/hard, deciles, conn), 2 = easy/hard only
preBids=0; % turn on to force old pre-BIDS format
oneHandSub=[1002;1019]; % manually update with RH-only participants

%% internal setup
dirList=dir('/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_SubjectData/10_*_data');
numSub=length(dirList);
handList={'LH','RH'}; % for patients, maybe cut RH
decEasy={'DEC01','DEC02','DEC03','DEC04','DEC05'};
decHard={'DEC06','DEC07','DEC08','DEC09','DEC10'};
dataPath='/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_SubjectData';
warning('off','MATLAB:MKDIR:DirectoryExists')

for si=16:numSub % something is weird abot 17
    % create/test directories
    subName=dirList(si).name;
    if ~(strcmp(subName(4),'1') || strcmp(subName(4),'2')) || strcmp(subName,'10_1000_data')
        fprintf('Skipping EVmaker for %s\n',subName);
        continue
    end
    subNum=str2double(subName(4:7));
    dataDir=sprintf('%s/10_%i_Data/',dataPath,subNum);
    if preBids==1
        subDirEV=sprintf('10_%i_EV',subNum); % name for new EV dir
        decileDir=sprintf('/10_%i_decileEV',subNum);
    else
        subDirEV='beh/';
        decileDir=sprintf('sub-%i_EV-decile',subNum);
    end
    behPath=[dataDir,subDirEV];
    if isfolder(sprintf('%s%s',behPath)) % does behavior directory exist
        if overwrite==0
            fprintf('Skipping %i; output directory exists\n',subNum);
            %continue
        elseif overwrite==1
            fprintf('Overwriting %i output directory\n',subNum);
        end
    end
    % check #hands, then run through data
    if any(oneHandSub==subNum)
        numHands=1;
    else
        numHands=2;
    end
    mkdir(behPath);
    for runi=1:3
        for hi=1:numHands
            handName=handList{hi};
            handID=[handName,num2str(runi)];
            stegaDir=sprintf('%s/10_%i_STEGA/',dataDir,subNum);
            cd(stegaDir); % move into STEGA data directory
            fileSet=dir;
            numFiles=length(fileSet);
            for fi=1:numFiles
                thisFileName=fileSet(fi).name;
                located=strfind(thisFileName,sprintf('_%s%i_',handName,runi)); % do we have _RH1_ formulation?
                falsePos=strfind(thisFileName,'mock'); % don't ever use these
                prac=strfind(thisFileName,'prac'); % or these
                if ~isempty(located) && isempty(falsePos) && isempty(prac)
                    runFile=[stegaDir,thisFileName];
                    continue
                end
            end % file loop
            runJson=fileread(sprintf('%s%s_STEGA/%s',runFile));
            runNum=runFile(10);

            runData=jsondecode(runJson);
            examData=runData.examDefinition;

            %% velocity confound - this is bad approach, it's not actually time-linked to go/rest. Instead get from the STEGAMRI_decode scripts.
            % velocities=runData.runData.velocities; % this is in pixels/sec, which I don't love, but I don't see any good way to normaliz
            % subDirVel='velocities';
            % mkdir(behPath,subDirVel);
            % velFileName=sprintf('%s%s/sub-%i_task-draw%s_velocity_run-%i.txt',behPath,subDirVel,subNum,handName,runi);
            % fidSP=fopen(velFileName,'w'); % overwrite existing file
            % fprintf(fidSP,'%0.3f\n',velocities');
            % fclose(fidSP);
 
            %% identify block IDs & durations from exam file
            numBlocks=length(examData.order);
            timingData=nan(numBlocks,4); % cols: condition, starttime, duration
            blockLen=examData.activeBlock;

            decList=nan(numBlocks,1);
            decNames=cell(numBlocks,1);
            for exami=1:numBlocks
                thisBlockName=examData.order(exami).groupName;
                if strcmp(thisBlockName,decEasy{1}) || strcmp(thisBlockName,decEasy{2}) || strcmp(thisBlockName,decEasy{3}) || strcmp(thisBlockName,decEasy{4}) || strcmp(thisBlockName,decEasy{5})
                    timingData(exami,1)=0;
                elseif strcmp(thisBlockName,decHard{1}) || strcmp(thisBlockName,decHard{2}) || strcmp(thisBlockName,decHard{3}) || strcmp(thisBlockName,decHard{4}) || strcmp(thisBlockName,decHard{5})
                    timingData(exami,1)=1;
                end
                decList(exami)=str2double(thisBlockName(4:5)); % number part of decile name
                decNames{exami}=thisBlockName;
            end
            timingData(:,3)=blockLen; % fixed value (block dur)
            timingData(:,4)=1; % fixed value (magnitude)

            %% determine timings from run file
            activeTimes=runData.restToActiveTimeStamps-runData.triggerTimeStamps(1);
            restTimes=runData.activeToRestTimeStamps-runData.triggerTimeStamps(1);
            for blocki=1:numBlocks
                timingData(blocki,2)=activeTimes(blocki);
            end

            %% reformat into ev files of: startime, duration, 1.0
            mkdir(dataDir,subDirEV);
            evEasy=timingData(timingData(:,1)==0,2:4);
            evHard=timingData(timingData(:,1)==1,2:4);
            evAll=timingData(:,2:4);
            % generate rest data
            evRest=nan(numBlocks+1,3);
            evRest(:,3)=1;
            evRest(1,1:2)=[0,examData.restTimeBeforeStart];
            for rbi=1:numBlocks-1 % doesn't handle last rest well, since
                evRest(rbi+1,1)=evAll(rbi,1)+evAll(rbi,2); % end of previous block
                evRest(rbi+1,2)=evAll(rbi+1,1)-(evAll(rbi,1)+evAll(rbi,2)); % start of next block - start of rest
            end
            evRest(end,1)=evAll(end,1)+evAll(end,2);
            actualEndTime=runData.triggerTimeStamps(end)-runData.triggerTimeStamps(1)+median(diff(runData.triggerTimeStamps)); % 1 TR after last TR-start signal
            evRest(end,2)=actualEndTime-evRest(end,1);
            % save
            if saving>0 % these are the basic things that always save
                if preBids==1 % old format
                    evFileE=sprintf('EV_Easy_10_%i_%s%i_EV.txt',subNum,handName,runi);
                    evFileH=sprintf('EV_Hard_10_%i_%s%i_EV.txt',subNum,handName,runi);
                    evFileA=sprintf('EV_All_10_%i_%s%i_EV.txt',subNum,handName,runi);
                    evFileR=sprintf('EV_Rest_10_%i_%s%i_EV.txt',subNum,handName,runi); % shouldn't be needed
                else % newer BIDS-compliant format
                    evFileE=sprintf('sub-%i_task-draw%s_EV-easy_run-%i.txt',subNum,handName,runi);
                    evFileH=sprintf('sub-%i_task-draw%s_EV-hard_run-%i.txt',subNum,handName,runi);
                    evFileA=sprintf('sub-%i_task-draw%s_EV-all_run-%i.txt',subNum,handName,runi);
                    evFileR=sprintf('sub-%i_task-rest%s_EV-all_run-%i.txt',subNum,handName,runi);
                end
                fidE=fopen([behPath,evFileE],'w'); % overwrite existing file
                fprintf(fidE,'%0.3f\t%0.3f\t%0.3f\n',evEasy');
                fclose(fidE);
                fidH=fopen([behPath,evFileH],'w'); % overwrite existing file
                fprintf(fidH,'%0.3f\t%0.3f\t%0.3f\n',evHard');
                fclose(fidH);
                fidA=fopen([behPath,evFileA],'w'); % overwrite existing file
                fprintf(fidA,'%0.3f\t%0.3f\t%0.3f\n',evAll');
                fclose(fidA);
                fidR=fopen([behPath,evFileR],'w'); % overwrite existing file
                fprintf(fidR,'%0.3f\t%0.3f\t%0.3f\n',evRest');
                fclose(fidR);
            end % saving anything
            if saving==1 % optional save files (deciles, outputs for CONN)
                mkdir(behPath,decileDir)
                for deci=1:10 % deciles
                    thisDecData=timingData(deci,2:4);
                    if preBids==1
                        decileName=sprintf('EV_%s_10_%i_%s%i_EV.txt',decNames{deci},subNum,handName,runi);
                    else
                        decileName=sprintf('sub-%i-EV_task-draw%s_decile-%s_run-%i.txt',subNum,handName,addz(decList(deci),2),runi);
                    end
                    fidD=fopen([dataDir,subDirEV,decileDir,'/',decileName],'w'); % overwrite existing file
                    fprintf(fidD,'%0.3f\t%0.3f\t%0.3f\n',thisDecData');
                    fclose(fidD);
                end
                % now Conn stuff
                connFileD=sprintf('sub-%i_conn-durations_task-draw%s_run-%i.txt',subNum,handName,runi);
                connFileO=sprintf('sub-%i_conn-onsets_task-draw%s_run-%i.txt',subNum,handName,runi);
                fidCD=fopen([behPath,connFileD],'w');
                fprintf(fidCD,'%0.3f\t',evAll(:,2));
                fclose(fidCD);
                fidCO=fopen([behPath,connFileO],'w');
                fprintf(fidCO,'%0.3f\t',evAll(:,1));
                fclose(fidCO);
                connFileDR=sprintf('sub-%i_conn-durations_task-rest%s_run-%i.txt',subNum,handName,runi);
                connFileOR=sprintf('sub-%i_conn-onsets_task-rest%s_run-%i.txt',subNum,handName,runi);
                fidCDR=fopen([behPath,connFileDR],'w');
                fprintf(fidCDR,'%0.3f\t',evRest(:,2));
                fclose(fidCDR);
                fidCOR=fopen([behPath,connFileOR],'w');
                fprintf(fidCOR,'%0.3f\t',evRest(:,1));
                fclose(fidCOR);
            end % saving everything
        end % hand loop
    end % run loop
    fprintf('Finished EV files for sub %i\n',subNum);
    system(sprintf('chmod -R 777 %s',behPath));
end % subject loop
