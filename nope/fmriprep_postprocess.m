% fmriprep_postprocess.m
%
% Extracts regressor info from fmriprep output, integrates with externally-
% produced motion outlier files (from FMO). Also applies skull-stripping: creates/labels t1_brain as FSL needs, and creates "desc-preprocBrain" func files
% 241202: also creates .json's for skull-stripped files
% 250113: also ensres BEH folder if did't exist (by copying from local or invoking EVmaker_STEGAMRI_NRLmisc.m)
%
% Automatically checks for existing files and creates missing ones only; will not overwrite anything unless you set overwrite=1.

overwrite=0;
saveConnFMP=0; % turn on if saving specifically to Conn_fmriprep. Make sure 
subjSkipForConn=[1002,1019,2052]; % if using the above, skip these subj
preprocDir='/Volumes/bphilip/Active/10_Connectivity/derivatives/preprocessed';
fpDir='/Volumes/bphilip/Active/10_Connectivity/derivatives/fmriprep';
rawDataDir='/Volumes/bphilip/Active/10_Connectivity/raw_data';
connDir='/Volumes/bphilip/Active/10_Connectivity/derivatives/Conn_fmriprep/fmriprep';
spaces=["MNI152NLin6Asym_res-2","MNI152NLin2009cSym_res-2"]; %,"MNI152NLin2009cAsym_res-2"]; 


dirList=dir(sprintf('%s/sub-*',fpDir));
numSub=length(dirList);
numSpaces=length(spaces);

for si=1:numSub
    thisDir=dirList(si).name;
    if contains(thisDir,'html') % don't look at sub-XXXX.html file, just the sub-XXXX directory
        continue
    end
    subInd=regexp(thisDir,'sub-[0-9]{4}');
    subName=thisDir(subInd+4:subInd+7);

    outputDir=sprintf('%s/sub-%s/regressors',fpDir,subName);
    funcDir=sprintf('%s/sub-%s/func',fpDir,subName);
    anatDir=sprintf('%s/sub-%s/anat',fpDir,subName);
    ctsFileList=dir(sprintf('%s/sub-%s_task-draw*_run-*_desc-confounds_timeseries.tsv',funcDir,subName));
    ctsNumFiles=length(ctsFileList);

    % Check for missing files. Skip sub if a file is missing.
    missingFiles = false;
    for fi=1:ctsNumFiles
        thisFile=ctsFileList(fi).name;
        runInd=regexp(thisFile,'run-[0-9]');
        runName=thisFile(runInd+4);
        handInd=regexp(thisFile,'[A-Z]H_');
        handName=thisFile(handInd:handInd+1);
        outlierFile=sprintf('%s/sub-%s/regressors/sub-%s_fd_task-draw%s_run-%s.txt',rawDataDir,subName,subName,handName,runName);
        if ~isfile(outlierFile)
            warning('%s: Missing required file %s. Skipping subject.', subName, outlierFile);
            missingFiles = true;
            break;
        end
    end

    if missingFiles
        continue; % Skip the subject if any file is missing
    end


    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    readmeFileName=sprintf('%s/sub-%s_regressorReadme.txt',outputDir,subName);
    
     if isfile(readmeFileName) && overwrite==0 % Skip existing readme file
        fprintf('%s: Regressors found, ',subName);
    else
        fprintf('%s: Regressors created, ',subName);
        for fi=1:ctsNumFiles
            thisFile=ctsFileList(fi).name;
            try
                % Extract LH or RH
                handInd=regexp(thisFile,'[A-Z]H_');
                handName=thisFile(handInd:handInd+1);
                % Extract run #
                runInd=regexp(thisFile,'run-[0-9]');
                runName=thisFile(runInd+4);
                % Get fmriprep outputs
                rawTable=readtable(sprintf('%s/%s',funcDir,thisFile),'FileType','delimitedtext');
                rotx=rawTable.rot_x;
                roty=rawTable.rot_y;
                rotz=rawTable.rot_z;
                transx=rawTable.trans_x;
                transy=rawTable.trans_y;
                transz=rawTable.trans_z;
                % Find existing motion outlier files
                outlierFile=sprintf('%s/sub-%s/regressors/sub-%s_fd_task-draw%s_run-%s.txt',rawDataDir,subName,subName,handName,runName);
                if ~isfile(outlierFile)
                    warning('%s: Outlier file %s missing, skipping.', subName, outlierFile);
                    continue;
                end
                outlierData=readmatrix(outlierFile);
                % Combine all regressors
                allRegressors=[transx,transy,transz,rotx,roty,rotz,outlierData];
                saveFileName=sprintf('%s/sub-%s_task-draw%s_run-%s_regressorsCombined.txt',outputDir,subName,handName,runName);
                writematrix(allRegressors,saveFileName,'Delimiter','tab');
                scrubFileName=sprintf('%s/sub-%s_task-draw%s_run-%s_desc-scrubbingFMO.tsv',funcDir,subName,handName,runName);
                writematrix(outlierData,scrubFileName,'FileType','text','Delimiter','tab');
                if saveConnFMP==1 && ~any(str2double(subName)==subjSkipForConn)
                    scrubFileAlt=sprintf('%s/sub-%s/func/sub-%s_task-draw%s_run-%s_desc-scrubbingFMO.tsv',connDir,subName,subName,handName,runName);
                    writematrix(outlierData,scrubFileAlt,'FileType','text','Delimiter','tab');
                end
            catch ME
                warning('%s: Error processing file %s: %s', subName, thisFile, ME.message);
                continue;
            end
        end % file loop
        % Save readme
        readmeText='regressorsCombined.txt file columns: trans_x, trans_y, trans_z, rot_x, rot_y, rot_z, (outliers)\nOutliers determined by fsl_motion_outliers -fd';
        writematrix(readmeText,readmeFileName);
     end

     %% check for Beh
     behDirServer=sprintf('%s/sub-%s/beh/',rawDataDir,subName);
     behDirBox=sprintf('%s/NRL_Shared/10_Connectivity/10_Data/10_SubjectData/10_%s_data/beh',getLocalBoxDir,subName);
     behDirLocal=sprintf('/Users/Shared/10_Connectivity/raw_data/sub-%s/beh',subName);
     if ~isfolder(behDirServer) && ~isfolder(behDirBox)% if neither exists
         EVmaker_STEGAMRI_NRLmisc(str2double(subName));
         fprintf('Beh created.\n');
     elseif ~isfolder(behDirServer) && isfolder(behDirLocal) % if exists on local-but-not-server, try that first for faster copying
         fprintf('Beh copied from local.\n')
         copyfile(behDirLocal,behDirServer);
     elseif ~isfolder(behDirServer) && isfolder(behDirBox) % if exists on box only
         fprintf('Beh copying from Box.\n');
         copyfile(behDirBox,behDirServer);
     else
         fprintf('Beh found.\n');
     end


     % if ~isfolder(behDirServer)
     %         fprintf(' Beh created.\n');
     %         EVmaker_STEGAMRI_NRLmisc(str2double(subName));
     %     else
     %         fprintf(' Beh copied.\n');
     %     end
     %     copyfile behDirBox behDirServer
     % else
     %     fprintf(' Beh found.\n');
     % end

    %% create T1_brain
    fprintf(' Brains:');
    for spci=1:numSpaces % could recode this to use the * like func brains?
        thisSpaceName=spaces(spci);
        t1FileSpaceName=sprintf('%s/sub-%s_space-%s_desc-preproc_T1w',anatDir,subName,thisSpaceName);
        t1MaskSpaceName=sprintf('%s/sub-%s_space-%s_desc-brain_mask',anatDir,subName,thisSpaceName);
        maskedSpaceFileName=sprintf('%s/sub-%s_space-%s_desc-preproc_T1w_brain',anatDir,subName,thisSpaceName);
        if ~isfile([maskedSpaceFileName,'.nii.gz']) || overwrite==1
            fprintf(' c%i',spci); % c for creating
            system(sprintf('/usr/local/fsl/bin/fslmaths %s.nii.gz -mas %s.nii.gz %s.nii.gz',t1FileSpaceName,t1MaskSpaceName,maskedSpaceFileName));
            copyfile(sprintf('%s.json',t1FileSpaceName),sprintf('%s.json',maskedSpaceFileName));
            system(sprintf('sed -i '''' ''s/"SkullStripped": false/"SkullStripped": true/g'' %s.json',maskedSpaceFileName));
        else
            fprintf(' f%i',spci); % f for found
        end
    end 
    t1FileName=sprintf('%s/sub-%s_desc-preproc_T1w',anatDir,subName);
    t1MaskName=sprintf('%s/sub-%s_desc-brain_mask',anatDir,subName);
    maskedFileName=sprintf('%s/sub-%s_desc-preproc_T1w_brain',anatDir,subName);
    if ~isfile([maskedFileName,'.nii.gz']) || overwrite==1
        fprintf(' cGen');
        system(sprintf('/usr/local/fsl/bin/fslmaths %s.nii.gz -mas %s.nii.gz %s.nii.gz',t1FileName,t1MaskName,maskedFileName));
        copyfile(sprintf('%s.json',t1FileName),sprintf('%s.json',maskedFileName));
        system(sprintf('sed -i '''' ''s/"SkullStripped": false/"SkullStripped": true/g'' %s.json',maskedFileName));
    else
        fprintf(' fGen');
    end
    fprintf('.')

    %% create func brain - this just automatically gets all possible spaces via the *
    funcFileList=dir(sprintf('%s/sub-%s_task-draw*H_run-*desc-preproc_bold.nii.gz',funcDir,subName)); % this won't catch Flips
    funcNumFiles=length(funcFileList);
    fprintf(' Func (%i):',funcNumFiles);
    for ffi=1:funcNumFiles
        thisFuncFile=funcFileList(ffi).name;
        descSpot=strfind(thisFuncFile,'desc');
        maskFuncFile=sprintf('%s/%sdesc-brain_mask',funcDir,thisFuncFile(1:descSpot-1));
        outFuncFile=sprintf('%s/%sdesc-preprocBrain_bold',funcDir,thisFuncFile(1:descSpot-1));
        if ~isfile([outFuncFile,'.nii.gz']) || overwrite==1
            maskingString=sprintf('/usr/local/fsl/bin/fslmaths %s/%s -mas %s.nii.gz %s.nii.gz',funcDir,thisFuncFile,maskFuncFile,outFuncFile);
            system(maskingString);
            thisFuncJson=sprintf('%s/%s.json',funcDir,thisFuncFile(1:end-7)); % replace suffix
            copyfile(thisFuncJson,sprintf('%s.json',outFuncFile));
            system(sprintf('sed -i '''' ''s/"SkullStripped": false/"SkullStripped": true/g'' %s.json',outFuncFile));
            fprintf(' c%i',ffi);
        else
            fprintf(' f%i',ffi);
        end
        drawSpot=strfind(thisFuncFile,'draw');
        flipFuncFile=outFuncFile;
    end

    % copy out the t1_brain to a permanent location (needed for FSL)
    preprocPath=sprintf('%s/sub-%s/',preprocDir,subName);
    if ~isdir(preprocPath)
        mkdir(preprocPath);
    end
    t1newPath=sprintf('%s/sub-%s_desc-preproc_T1w_brain.nii.gz',preprocPath,subName);
    if ~isfile(t1newPath)
        copyfile([maskedFileName,'.nii.gz'],t1newPath);
        fprintf(' Storing T1B');
    end


    fprintf(' Done!\n')
end % sub loop