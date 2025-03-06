% EVmaker_STEGMRI_NRLmisc.m
%
% Github version:
% Makes EV files ("explanatory variable," FSL behavior files) from STEGA data, which tell FSL the task timing.
% Will automatically check Box and your local /Users/Shared/10_Connectivity/raw_data, and puts the output in both places.
% The output folder is called "beh"(avior) because that's BIDS format
%
% Makes EV files from a STEGAMRI  RUN (output) file. Exam no longer needed.
% Expects only one "XH#" file in the STEGA directory
% Updates 240201: creates "rest" condition too, which is for conn/gPPI; auto loops through sub
% Updates 240413: chmod 777
% Updates 240425: checks to see if it's local too. If not, copies.
% Update 250113: convert it into a function, which allows specification of individual SNs (vector of #s).
% You don't need to use any input variables, they all will auto-set (e.g. "all subj")
% "Output logic" is a 3-element logical vector that defaults to all 3 output locations: [box, local, server]. Note that decile is box-only due to formatting constraints.
%
% Doesn't create separate easy/hard conn directories.
% Doesn't create speed_timewise confound - will need to get from STEGAMRI_decode (if going to use it at all)

function successList = EVmaker_STEGAMRI_NRLmisc(subList,outputLogic,overwrite,saving,oneHandSub)

if nargin < 5
    oneHandSub=[1002;1019;1045]; % manually update with RH-only participants
end
if nargin < 4
    saving = 1;
end
if nargin < 3
    overwrite=0;
end
if nargin < 2
    outputLogic=[1 1 1]; % yes to Box, Local, Server 
end
if nargin < 1
    dirList=dir('/Users/labuser/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_SubjectData/10_*_data');
    numSub=length(dirList);
else
    numSub=length(subList);
    subTemp=append("10_",string(subList));
    subDirList=append(subTemp,"_data");
end

% internal setup
handList={'LH','RH'}; % for patients, maybe cut RH
decEasy={'DEC01','DEC02','DEC03','DEC04','DEC05'};
decHard={'DEC06','DEC07','DEC08','DEC09','DEC10'};
dataPath='/Users/labuser/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_Data/10_SubjectData';
localRawPath='/Users/Shared/10_Connectivity/raw_data';
serverPath='/Volumes/bphilip/Active/10_Connectivity/raw_data';
warning('off','MATLAB:MKDIR:DirectoryExists')
preBids=0;
successList=zeros(numSub,2);

for si=1:numSub
    % create/test directories
    if nargin < 1 % au
    subName=dirList(si).name;
    else
        subName=convertStringsToChars(subDirList(si));
    end
    if ~(strcmp(subName(4),'1') || strcmp(subName(4),'2')) || strcmp(subName,'10_1000_data') || strcmp(subName,'10_2063_data')
        fprintf('Skipping EVmaker for %s, not a legit participant\n',subName);
        continue
    end
    subNum=str2double(subName(4:7));
    successList(si,1)=subNum;
    dataDir=sprintf('%s/10_%i_Data/',dataPath,subNum);
    if preBids==1
        subDirEV=sprintf('10_%i_EV',subNum); % name for new EV dir
        decileDir=sprintf('/10_%i_decileEV',subNum);
    else
        subDirEV='beh/';
        decileDir=sprintf('sub-%i_EV-decile',subNum);
    end
    behPathBox=[dataDir,subDirEV];
    subPathLocal=sprintf('%s/sub-%i',localRawPath,subNum);
    behPathLocal=sprintf('%s/beh/',subPathLocal);
    behPathServer=sprintf('%s/sub-%i/beh/',serverPath,subNum);

    outputLogicSub=outputLogic; % this subject's settings begin as default
    if isfolder(behPathBox) % does Box directory exist
        if overwrite==0
            fprintf('Skipping Box creation of %i; output directory exists\n',subNum);
            outputLogicSub(1)=0;
        elseif overwrite==1
            fprintf('Overwriting Box directory for %i\n',subNum);
        end
    end
    if isfolder(subPathLocal)
        if isfolder(behPathLocal) % does local directory exist
            if overwrite==0
                fprintf('Skipping Local creation of %i; output directory exists\n',subNum);
                outputLogicSub(2)=0;
            elseif overwrite==1
                fprintf('Overwriting Local directory for %i\n',subNum);
            end
        end
    else
        fprintf('No Local subject directory for %i; local beh not written\n',subNum);
        outputLogicSub(2)=0;
    end
    if isfolder(behPathServer)
        if overwrite==0
            fprintf('Skipping Server creation of %i; output directory exists\n',subNum);
            outputLogicSub(3)=0;
        elseif overwrite==1
            fprintf('Overwriting Server directory for %i\n',subNum);
        end
    end


    % check #hands, then run through data
    if any(oneHandSub==subNum)
        numHands=1;
    else
        numHands=2;
    end
    mkdir(behPathBox);
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
            % to use this, must test integrating it into the SINGLE CONFOUND EV file

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
            blocki=1; % basic incrementor
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
            if saving>0
                %fprintf('Creating box EV files for sub-%i...',subNum)
                if preBids==1
                    evFileE=sprintf('EV_Easy_10_%i_%s%i_EV.txt',subNum,handName,runi);
                    evFileH=sprintf('EV_Hard_10_%i_%s%i_EV.txt',subNum,handName,runi);
                    evFileA=sprintf('EV_All_10_%i_%s%i_EV.txt',subNum,handName,runi);
                    evFileR=sprintf('EV_Rest_10_%i_%s%i_EV.txt',subNum,handName,runi); % shouldn't be needed
                else
                    evFileE=sprintf('sub-%i_task-draw%s_EV-easy_run-%i.txt',subNum,handName,runi);
                    evFileH=sprintf('sub-%i_task-draw%s_EV-hard_run-%i.txt',subNum,handName,runi);
                    evFileA=sprintf('sub-%i_task-draw%s_EV-all_run-%i.txt',subNum,handName,runi);
                    evFileR=sprintf('sub-%i_task-rest%s_EV-all_run-%i.txt',subNum,handName,runi);
                end
                saveMultiFile(evEasy,outputLogicSub,{[behPathBox,evFileE],[behPathLocal,evFileE],[behPathServer,evFileE]}); % custom script to save tab-delimited file in multiple possible locations
                saveMultiFile(evHard,outputLogicSub,{[behPathBox,evFileH],[behPathLocal,evFileH],[behPathServer,evFileH]});
                saveMultiFile(evAll,outputLogicSub,{[behPathBox,evFileA],[behPathLocal,evFileA],[behPathServer,evFileA]});
                saveMultiFile(evRest,outputLogicSub,{[behPathBox,evFileR],[behPathLocal,evFileR],[behPathServer,evFileR]});
            end % saving anything
            if saving==1

                mkdir(behPathBox,decileDir)
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
                saveMultiFile(evAll(:,2),outputLogicSub,{[behPathBox,connFileD],[behPathLocal,connFileD],[behPathServer,connFileD]});
                connFileO=sprintf('sub-%i_conn-onsets_task-draw%s_run-%i.txt',subNum,handName,runi);
                saveMultiFile(evAll(:,1),outputLogicSub,{[behPathBox,connFileO],[behPathLocal,connFileO],[behPathServer,connFileO]});
                connFileDR=sprintf('sub-%i_conn-durations_task-rest%s_run-%i.txt',subNum,handName,runi);
                saveMultiFile(evRest(:,2),outputLogicSub,{[behPathBox,connFileDR],[behPathLocal,connFileDR],[behPathServer,connFileDR]});
                connFileOR=sprintf('sub-%i_conn-onsets_task-rest%s_run-%i.txt',subNum,handName,runi);
                saveMultiFile(evRest(:,1),outputLogicSub,{[behPathBox,connFileOR],[behPathLocal,connFileOR],[behPathServer,connFileOR]});
                
            end % saving everything
        end % hand loop
    end % run loop

    if outputLogicSub(1)==1
        system(sprintf('chmod -R 777 %s',behPathBox));
    end
    if outputLogicSub(2)==1
        system(sprintf('chmod -R 777 %s',behPathLocal));
    end
    %fprintf('Ensured beh for %i\n',subNum);
    
    successList(si,2)=1;
end % subject loop