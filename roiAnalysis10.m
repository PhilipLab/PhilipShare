% roiAnalysis10.m
%
% roi analysis for 10_connectivity.
% Currently only checks cope1 (draw>rest) mean.
% Currently skips the SubsWithOnlyL entirely.

% manually set these
hemiType='IC'; % SET TO "LR" or "IC" (ipsi-cosTtra) or 
glmmType='few'; % SET TO 'few' (new version, picks only strong+independent factos) or 'all' (old version, all factors)
forceHand=0; % if 1, forces handLH into GLMMs
behavSet=7; % see line 30 for choosing behavioral factors in analysis
plotting=0; % 1 for ipsi & contra on same axis; 2 for SFN24 (separate axis etc), 3 for simplified differnces
nPerm=00; % number of bootstrap distributions. Set to 0 to skip.
showDiffs=1; % if plotting, convert LH & RH values into (LH-RH), which is bad for stats but good for visualization

% unlikely to be changed
roiRadius=4;
cutOneHandSub=1;
convertVarsToDiff=1; % if 1, convert L/R to M/Lat
uniThresh=0.1;
showUnivariate=0;
roiList={'M1','SPL','IPS','7a','PMD','SMA'}; % fixed as of 240618
handList={'LH','RH'};
hemiList={'L','R'};
subsWithOnlyL=[1002,1019,1045]; % participants with no RH data

% select factors to test
if behavSet==1 % everything
    behavUnivarNames=["posAcc_M","posAcc_L","velSm_M","velSm_L","dirAcc_M","dirAcc_L","spd_M","spd_L","bisPos_M","bisPos_L","satPos_M","satPos_L"];
elseif behavSet==2 % try other acc/ps
    behavUnivarNames=["posAcc_M","posAcc_L","velSm_M","velSm_L","dirAcc_M","dirAcc_L","spd_M","spd_L","bisPos_M","bisPos_L","satPos_M","satPos_L","bisDir_M","bisDir_L","satDir_M","satDir_L","bisCmb_M","bisCmb_L","satCmb_M","satCmb_L"];
elseif behavSet==3 % reduced redundancies
    behavUnivarNames=["velSm_M","velSm_L","dirAcc_M","dirAcc_L","spd_M","spd_L","bisPos_M","bisPos_L","satPos_M","satPos_L"];
elseif behavSet==4 % LH/RH
    behavUnivarNames=["posAcc_LH","posAcc_RH","velSm_LH","velSm_RH","dirAcc_LH","dirAcc_RH","spd_LH","spd_RH","bisPos_LH","bisPos_RH","satPos_LH","satPos_RH"];
elseif behavSet==5 % LHRH and LM
    behavUnivarNames=["posAcc_LH","posAcc_RH","posAcc_M","posAcc_L","velSm_LH","velSm_RH","velSm_M","velSm_L","dirAcc_LH","dirAcc_RH","dirAcc_M","dirAcc_L","spd_LH","spd_RH","spd_M","spd_L","bisPos_LH","bisPos_RH","bisPos_M","bisPos_L","satPos_LH","satPos_RH","satPos_M","satPos_L"];
elseif behavSet==6 % LH only
    behavUnivarNames=["posAcc_LH","velSm_LH","dirAcc_LH","spd_LH","bisPos_LH","satPos_LH","bisDir_LH","satDir_LH"];
elseif behavSet==7 % lateralization only
    behavUnivarNames=["posAcc_L","velSm_L","dirAcc_L","spd_L","bisPos_L","satPos_L","satDir_L"];
elseif behavSet==8 % SAT only
    behavUnivarNames=["satPos_LH","satPos_RH","satPos_M","satPos_L","satDir_LH","satDir_RH","satDir_M","satDir_L"];
elseif behavSet==9 % RH only
    behavUnivarNames=["posAcc_RH","velSm_RH","dirAcc_RH","spd_RH","bisPos_RH","satPos_RH","bisDir_RH","satDir_RH"];
elseif behavSet==10 % LH or L
    behavUnivarNames=["posAcc_L","velSm_L","dirAcc_L","spd_L","bisPos_L","satPos_L","satDir_L","posAcc_LH","velSm_LH","dirAcc_LH","spd_LH","bisPos_LH","satPos_LH","bisDir_LH","satDir_LH"];
elseif behavSet==11 % LH/RH and L
    behavUnivarNames=["posAcc_LH","posAcc_RH","posAcc_L","velSm_LH","velSm_RH","velSm_L","dirAcc_LH","dirAcc_RH","dirAcc_L","spd_LH","spd_RH","spd_L","bisPos_LH","bisPos_RH","bisPos_L","satPos_LH","satPos_RH","satPos_L"];
elseif behavSet==12 % targeted for laterality exploraiton
    behavUnivarNames=["satPos_L","satPos_RH","satPos_LH"];
elseif behavSet==13 % super specific
    behavUnivarNames=["satPos_L"];
else
    fprintf('No univariate variables specified, defaulting toAll\n');
    behavUnivarNames=[]; % will fill in  'all' is later once they've been defined
end

numRoi=length(roiList);
w1=warning('off','MATLAB:table:ModifiedAndSavedVarnames');
w2=warning('off','stats:classreg:regr:lmeutils:StandardGeneralizedLinearMixedModel:Message_PLUnableToConverge');
roiFolder='/Users/bphilip/Documents/_LAMPlab/10L_Connectivity/10L_analyses/ap12_250108_FMP_sym'; % could rewrite this to pull from server, but I like my offline copy
behavFile='/Users/bphilip/Library/CloudStorage/Box-Box/NRL_shared/10_Connectivity/10_MRIanalysis/participants_250210_firststudy_Cut.tsv'; %firststudycut = 34 two-handers

cd(roiFolder);
fileSet=dir;
numFolders=length(fileSet);
behavRaw=readtable(behavFile,'ReadVariableNames',1,'FileType',"delimitedtext");
subList=behavRaw.participant_id;
if iscell(subList)
    subChar=char(subList); % convert to char to more easily cut by location (sub-XXXX to XXXX)
    subCharCut=subChar(:,5:end);
    subList=double(string(subCharCut));
end
numSubsTotal=length(subList);
existingSubWithOneHand=sum(any(subList==subsWithOnlyL));
numSubsReal=numSubsTotal-(existingSubWithOneHand*cutOneHandSub);

infoCell=cell(3,2);
numVars=numRoi*2*2; % rois * hemis * hand: actual vars NOT INCLUDING confounds
hasHand=[subList,ones(numSubsTotal,2)];
faceVecOpts=[validatecolor(uint8([229,229,229]));validatecolor(uint8([248,228,215]))]; % face colors for violins/bars: gray & brown
tileColoredRoi=[validatecolor(uint8([18,175,85]));validatecolor(uint8([251,200,110]));validatecolor(uint8([145,240,250]));...
    validatecolor(uint8([250,180,180]));validatecolor(uint8([250,24,250]));validatecolor(uint8([250,40,30]))]; % face colors for ROI: M1, SPL, IPS, 7a, PMD, SMA

%% generate variable names
vnames=cell(1,numVars+6);
nbi=1;
for nbr=1:numRoi % name build ROI
    nbiRoi=roiList{nbr};
    for nbhm=1:2 % name build hemi
        nbiHem=hemiList{nbhm};
        for nbh=1:2 % name build hand
            nbiHand=handList{nbh};
            vnames{nbi}=sprintf('%s_%shem_%s',nbiRoi,nbiHem,nbiHand);
            nbi=nbi+1;
        end
    end
end % roi list
% now add confounds etc
vnames{nbi}='isPatient';
vnames{nbi+1}='sexF';
vnames{nbi+2}='age';
vnames{nbi+3}='participant_id';
vnames{nbi+4}='hasLH';
vnames{nbi+5}='hasRH';
numVars=length(vnames);
vtList=cell(numVars,1);
[vtList{:}]=deal('double');
copeTable=table('Size',[numSubsTotal,numVars],'VariableTypes',vtList,'VariableNames',vnames);
copeTable.participant_id=subList;
copeTable.isPatient=behavRaw.isPatient;
copeTable.sexF=behavRaw.sexF;
copeTable.age=behavRaw.age; % put everything inside copetable for consistent editing
confoundLocations=nbi:nbi+5; % indices of those bonuses
%% build data
for fi=1:numSubsTotal
    subNum=subList(fi);
    isPatient=2-round(subNum/1000,0);
    oneHand=any(subsWithOnlyL==subNum); % currently won't work if someone is missing LH, but there should be no such patients ever
    if oneHand==1 % skip these subs entirely
        hasHand(fi,2:3)=[0,0];
        continue
    end
    copeTable.isPatient(fi)=isPatient;
    for ri=1:numRoi
        thisArea=roiList{ri};
        for hi=1:2
            thisHemi=hemiList{hi};
            for handi=1:2
                thisHand=handList{handi};
                variableName=sprintf('%s_%shem_%s',thisArea,thisHemi,thisHand);
                if handi==2 && oneHand==1 % if only one hand, don't run for RH
                    hasHand(fi,handi+1)=0;
                    copeTable.(variableName)(fi)=NaN;
                    continue
                end
                targetFile=sprintf('%s/sub-%i_task-draw%s_roi-%s_hemi-%s_sphere-%imm/report.txt',roiFolder,subNum,thisHand,thisArea,thisHemi,roiRadius);
                fqText=readcell(targetFile,'Range','B:B'); %2nd column is labels
                isCope = @(x) contains(x,'/cope1'); % make sure you have the row labeled "cope1"
                copeRow=cellfun(isCope,fqText);
                fqData=readmatrix(targetFile);
                meancope=fqData(copeRow,6); % column 6 is the mean value
                copeTable.(variableName)(fi)=meancope;
            end
        end
    end
end
copeTable.hasLH=hasHand(:,2);
copeTable.hasRH=hasHand(:,3);
if cutOneHandSub==1 % delete one-handed subjects
    copeTable(copeTable.hasRH==0,:)=[];
end

%% create difference data. THIS TOO needs automation
% Remember, what I want is: "where in ipsilateral hemisphere is more activity LH > RH?"
% first, hand version.
% use this to view Left-Right (hemi and hand) effects
dataLH=copeTable(:,{'M1_Lhem_LH','M1_Rhem_LH','SPL_Lhem_LH','SPL_Rhem_LH','IPS_Lhem_LH','IPS_Rhem_LH','7a_Lhem_LH','7a_Rhem_LH','PMD_Lhem_LH','PMD_Rhem_LH','SMA_Lhem_LH','SMA_Rhem_LH'});
dataRH=copeTable(:,{'M1_Lhem_RH','M1_Rhem_RH','SPL_Lhem_RH','SPL_Rhem_RH','IPS_Lhem_RH','IPS_Rhem_RH','7a_Lhem_RH','7a_Rhem_RH','PMD_Lhem_RH','PMD_Rhem_RH','SMA_Lhem_RH','SMA_Rhem_RH'});
lrLabels={'BOLD_M1_Lhem','BOLD_M1_Rhem','BOLD_SPL_Lhem','BOLD_SPL_Rhem','BOLD_IPS_Lhem','BOLD_IPS_Rhem','BOLD_7a_Lhem','BOLD_7a_RHem','BOLD_PMD_Lhem','BOLD_PMD_Rhem','BOLD_SMA_Lhem','BOLD_SMA_Rhem'};
% second and KEY, "where in ipsilateral (or contralateral) hemisphere is there LH>RH?"
dataLHci=copeTable{:,{'M1_Lhem_LH','M1_Rhem_LH','SPL_Lhem_LH','SPL_Rhem_LH','IPS_Lhem_LH','IPS_Rhem_LH','7a_Lhem_LH','7a_Rhem_LH','PMD_Lhem_LH','PMD_Rhem_LH','SMA_Lhem_LH','SMA_Rhem_LH'}}; % same as dataLH
dataRHci=copeTable{:,{'M1_Rhem_RH','M1_Lhem_RH','SPL_Rhem_RH','SPL_Lhem_RH','IPS_Rhem_RH','IPS_Lhem_RH','7a_Rhem_RH','7a_Lhem_RH','PMD_Rhem_RH','PMD_Lhem_RH','SMA_Rhem_RH','SMA_Lhem_RH'}}; % flipped from dataRH
ciLabels={'BOLD_M1_ipsi','BOLD_M1_contra','BOLD_SPL_ipsi','BOLD_SPL_contra','BOLD_IPS_ipsi','BOLD_IPS_contra','BOLD_7A_ipsi','BOLD_7A_contra','BOLD_PMD_ipsi','BOLD_PMD_contra','BOLD_SMA_ipsi','BOLD_SMA_contra'};

%% now get behavioral data
behavTable=behavRaw; % in case preprocessing was needed
if cutOneHandSub==1 % delete one-handed subjects
    behavTable(isnan(behavTable.posAcc_RH),:)=[];
end
doubleBehav=[behavTable;behavTable]; % double it so that LH/RH can be a variable
if isempty(behavUnivarNames) % default set beginning of file - only now have we defined variable names
    behavUnivarNames=string(behavTable.Properties.VariableNames(3:end-2));
end

%% univariate test
numBehavCoeffs=length(behavUnivarNames);
behavGlmTable=doubleBehav(:,behavUnivarNames);
confoundTable=copeTable(:,confoundLocations(1):confoundLocations(3)); % first 3 confounds: patient, sexF, age
handIsLH=[ones(height(behavTable),1);zeros(height(behavTable),1)]; % is LH the drawing hand?
predictorTableRaw=addvars([behavGlmTable,[confoundTable;confoundTable]],handIsLH,repmat((1:numSubsReal)',2,1),'NewVariableNames',{'handIsLH','subject'});
predictorTableFull=convertvars(predictorTableRaw,{'isPatient','sexF','handIsLH'},'logical');
%
numTests=1;
univarLHp=nan(numRoi*2,numBehavCoeffs+3); % each model contains N behavioral + 3 confounds
univarRHp=nan(numRoi*2,numBehavCoeffs+3);
univarAHp=nan(numRoi*2,numBehavCoeffs+3);
univarLHt=nan(numRoi*2,numBehavCoeffs+3);
univarRHt=nan(numRoi*2,numBehavCoeffs+3);
univarAHt=nan(numRoi*2,numBehavCoeffs+3);
univarLabels=cell(numRoi*2,numBehavCoeffs+3);
for univaria=1:numRoi*2
    if strcmp(hemiType,'IC')
        BOLDareaU=[dataLHci(:,univaria);dataRHci(:,univaria)];
        useLabels=ciLabels;
        univHands=1; % how many hands to use for univariate analysis? Combine them, that's the point of M/L!
    elseif strcmp(hemiType,'LR')
        BOLDareaU=[table2array(dataLH(:,univaria));table2array(dataRH(:,univaria))];
        useLabels=lrLabels;
        univHands=2;
    end
    glmTableU=addvars(predictorTableFull,BOLDareaU,'NewVariableNames',useLabels(univaria)); % add output (BOLD) variable

    mdlU=fitglm(glmTableU);%,'CategoricalVars',logical([0,0,0,1,1,0,1,0])); % don't need to label categoricals - fitglm does it automatically for logical variables
    mdlP=mdlU.Coefficients(:,4);

    handSet=["drawLH","drawRH"];
    predNamesU=glmTableU.Properties.VariableNames(1:numBehavCoeffs+3); % everything before (hand,sub,BOLD)

    for handi=1:univHands
        handInds=(1:numSubsReal)+(numSubsReal*(handi-1));
        if strcmp(hemiType,'IC')
            glmTableX=glmTableU;
            handString='';
        elseif strcmp(hemiType,'LR') % separate hands
            glmTableX=glmTableU(handInds,:);
            handString=sprintf('in hand %s',handSet{handi});
        end
        for bvar=1:length(predNamesU)
            numTests=numTests+1;
            mdlVarU=fitglm(glmTableX,'PredictorVars',glmTableX.Properties.VariableNames(bvar),'ResponseVar',useLabels{univaria});
            mdlVarP=mdlVarU.Coefficients(:,4);
            thresh=table2array(mdlVarP<uniThresh);
            threshVar=mdlVarU.Coefficients.Properties.RowNames(thresh);
            threshP=mdlVarU.Coefficients.pValue(thresh);
            for thri=1:length(threshP)
                if ~strcmp(threshVar{thri},'(Intercept)') && showUnivariate==1
                    fprintf('Separate %s: variable %s %s achieved %0.3f\n',useLabels{univaria},threshVar{thri},handString,threshP(thri));
                end
            end
            if strcmp(hemiType,'IC')
                univarAHp(univaria,bvar)=table2array(mdlVarP(2,1));
                univarAHt(univaria,bvar)=mdlVarU.Coefficients.tStat(2,1);
            elseif handi==1
                univarLHp(univaria,bvar)=table2array(mdlVarP(2,1));
                univarLHt(univaria,bvar)=mdlVarU.Coefficients.tStat(2,1);
            else
                univarRHp(univaria,bvar)=table2array(mdlVarP(2,1));
                univarRHt(univaria,bvar)=mdlVarU.Coefficients.tStat(2,1);
            end
            univarLabels{univaria,bvar}=glmTableX.Properties.VariableNames{bvar};
        end % bhvr var loop
    end% hand loop
end % ROImat(st loop
if strcmp(hemiType,'IC')
    univarPvalAH=array2table(univarAHp,'VariableNames',univarLabels(1,:)); % look at min(this)
    univarTvalAH=addvars(array2table(univarAHt,'VariableNames',univarLabels(1,:)),string(useLabels)','NewVariableNames',"ROI");
    univarTabsAH=addvars(abs(array2table(univarAHt,'VariableNames',univarLabels(1,:))),string(useLabels)','NewVariableNames',"ROI");
else
    % it would be nice to have these variables for LR analysis, but not yet sure if/how that would make sense.
    % Because L/R creates differences between LH-draw and RH-draw, whereas I/C is designed to compare LH-draw vs RH-draw
end


%% Multivariate! Automatically does both LR & IC (though only IC can do winnowed version)
% first, remove vars from table based on univariate
if behavSet >= 1
    varsToRemove={'isPatient'};
    predictorMultivariate=removevars(predictorTableFull,varsToRemove);
    univarT_AH=removevars(univarTabsAH,varsToRemove);
else
    varsToRemove=[];
    fprintf('No multivariate predictors set, defaulting to All\n');
    predictorMultivariate=predictorTableFull;
    univarT_AH=univarTvalAH;
end

tableHolderLR=cell(numRoi*2,1);
areaModelsIC=cell(numRoi*2,1);
tableHolderIC=cell(numRoi*2,1);
areaModelsLR=cell(numRoi*2,1);
locateSatLR=nan(numRoi*2,4);
locateSatIC=nan(numRoi*2,4);
locateBisLR=nan(numRoi*2,4);
locateBisIC=nan(numRoi*2,4);
simpleGLM_IC=cell(numRoi*2,1);
simpleGLM_LR=cell(numRoi*2,1);
LRmodels=cell(numRoi*2,1);
LRtables=cell(numRoi*2,1);
arear=nan(numRoi*2,2);
glmSize=size(glmTableU,1);
if nPerm>0 % only runs if bootstrapping
    bootDists=cell(numRoi*2,1);
    bootStats=cell(2,1);
    bootStats{1}=nan(numRoi*2,6);
    bootStats{2}=nan(numRoi*2,6);
end
simpleStats=nan(numRoi*2,3);
predictorVarsUsed=cell(numRoi*2,1);
for isLR=0:1
    for area=1:numRoi*2
        if isLR==0 % ipsi-contra
            BOLD_LH=dataLHci(:,area); % LH draw, contra/ipsi hemisphere
            BOLD_RH=dataRHci(:,area); % RH draw, ditto
            useLabels=ciLabels;
        elseif isLR==1
            BOLD_LH=table2array(dataLH(:,area)); % LH draw, left/right hemisphere
            BOLD_RH=table2array(dataRH(:,area)); % RH draw, ditto
            useLabels=lrLabels;
            continue % this jus skips the analysis in L/R space, which is where we currently are
        end
        BOLDarea=[BOLD_LH;BOLD_RH]; % these distributions are normal yay!
        splitName=split(useLabels{area},'_');
        suffix=splitName{3};
        % this next section will add variables to model from highest-T to lowest-T, until they start correlating significantly with
        % previously-added variables
        if strcmp(glmmType,'few') && isLR==0 % this currently only works for ipsi/contra >> someday consider adding a L/R version, see issues above
            if forceHand==1
                initialPredictor=predictorMultivariate(:,{'handIsLH','subject'}); % core model: hand, subject
                numInitial=2;
            else
                initialPredictor=predictorMultivariate(:,{'subject'}); % core model: subject only
                numInitial=1;
            end
            tRowAH=univarT_AH(matches(univarT_AH.ROI,useLabels{area}),1:end-1); % -1 to cut off that ROI label
            [~,tSorted]=sort(table2array(tRowAH),'descend'); % rank by absolute t-value
            varNamesSorted=tRowAH.Properties.VariableNames(tSorted); % get rank-sorted list of names
            accumulatedPredictors=[initialPredictor,predictorMultivariate(:,varNamesSorted{1})]; % start with Initial Predictor, and the highest absolute t-value
            numVarsToTest=width(tRowAH);
            keepVarList=nan(width(tRowAH),1);
            for vi=2:width(tRowAH) % check to see whether each new variable is correlated with the existing set
                keptDataToTest=accumulatedPredictors(:,numInitial+1:end); % all accumulated behavioral variables (skip initial predictors)
                newVarName=varNamesSorted{vi}; % find next on the list
                newVar=predictorMultivariate(:,{newVarName});
                [rVar,pVar]=corr([table2array(keptDataToTest),table2array(newVar)]); % correlation matrix with everything we've added so far
                interestingP=pVar(numInitial:end,end); % the "numInitial:" removes the check vs Hand (if it was forced). The 2nd "end" reduces it to the last col (last variable), b/c everything else already tested.
                pSet(vi)=min(interestingP);
                corrAlpha=0.05/width(keptDataToTest); % multiple comparison corrected
                keepThisYN=pSet(vi)>corrAlpha; % keep if not significantly correlated with anything we've yet tested.
                keepVarList(vi)=keepThisYN;
                % fprintf('Adding %s: min p %0.3f, alpha %0.3f, keep %i\n',newVarName,min(interestingP),corrAlpha,keepThisYN);
                if keepThisYN==1
                    accumulatedPredictors=[accumulatedPredictors,newVar];
                end
            end % winnowing variable loop
            predictorVarsUsed{area}=accumulatedPredictors.Properties.VariableNames;
            predictorMultivariateArea=accumulatedPredictors;
        else % if not doing all that, keep all the predictors
            predictorMultivariateArea=predictorMultivariate;
        end % GLMM variable winnowing
        numBehavFactors=width(predictorMultivariateArea)-2;

        numTests=width(predictorMultivariateArea)-1;
        [hsimple,psimple,~,ssimple]=ttest(BOLD_LH,BOLD_RH,'alpha',.05/numTests);
        simpleStats(area,:)=[ssimple.tstat,psimple,hsimple]; % in case I want to check some basic t-tests

        glmTable=addvars(predictorMultivariateArea,BOLDarea,'NewVariableNames',useLabels(area)); % add output (BOLD) variable

        % here make it GLMM (or as matlab calls it, GLME)
        predNames=predictorMultivariateArea.Properties.VariableNames(1:end-1);
        numPred=length(predNames);
        predString='';
        for pi=1:(numPred-1)
            thisPredName=predNames{pi};
            if ~strcmp(thisPredName,'subject') % skip Subject b/c it will be added to end as random-factor
                predString=strcat(predString,predNames{pi}," + ");
            end
        end
        predString=strcat(predString,predNames{pi+1});
        mmFormula=sprintf('%s ~ %s + (1|subject)',useLabels{area},predString); % add random-factor Subject
        mmdl=fitglme(glmTable,mmFormula);
        mmrsq=mmdl.Rsquared.Adjusted;

        % regular glm for archive
        simpleFormula=sprintf('%s ~ %s',useLabels{area},predString);
        smdl=fitglm(glmTable,simpleFormula);

        % bootstrap to test model p-value, IF it was turned on by setting nPerm > 0
        if nPerm>0
            bootDists=cell(nPerm,1);
            bootOut=nan(nPerm,1);
            for pi=1:nPerm
                randTable=glmTable;
                for vi=1:numPred
                    randSet=randsample(numSubsReal*2,numSubsReal*2,'true'); % going to randomly assign BOLD
                    randTable(:,end)=randTable(randSet,end);
                end
                parmodel=fitglme(randTable,mmFormula);
                bootOut(pi)=parmodel.Rsquared.Adjusted;
            end
            bootDists{area}=bootOut;
            bootThresh=prctile(bootOut,95);
            if mmrsq>max(bootOut) % where in distribution is actual model? If totally outside dist, 1.0
                modelPercentile=1;
            else
                modelPercentile=find(sort(bootOut)>mmrsq,1)/nPerm;
            end
            bootStats{isLR+1}(area,:)=[mean(bootOut),median(bootOut),std(bootOut),bootThresh,mmrsq,1-modelPercentile];
            fprintf('GLMM for %s (%i factors): adjr2 %0.3f is p=%0.3f in bootstrap dist (%0.3f ± %0.3f, thresh %0.3f )\n',useLabels{area},numBehavFactors,mmrsq,1-modelPercentile,mean(bootOut),std(bootOut),bootThresh);
            arear(area,:)=[mmrsq,1-modelPercentile];
        else
            fprintf('GLMM for %s (%i factors): adjr2 %0.3f\n',useLabels{area},numBehavFactors,mmdl.Rsquared.Adjusted);
            arear(area,1)=mmdl.Rsquared.Adjusted;
        end
        coefTable=dataset2table(mmdl.Coefficients);
        % save the models & results in output variables to review later
        if isLR==0
            areaModelsIC{area}=mmdl; % THE GOOD STUFF - the model results
            tableHolderIC{area}=glmTable;
            simpleGLM_IC{area}=smdl;
            simpleGLM_LR{area}=smdl;
        elseif isLR==1
            areaModelsLR{area}=mmdl;
            tableHolderLR{area}=glmTable;
        end
        BOLDdiff=dataLHci(:,area)-dataRHci(:,area);
    end
end

%% pat vs control
dataPTci=[dataLHci(copeTable.isPatient==1,:);dataRHci(copeTable.isPatient==1,:)];
dataCTci=[dataLHci(copeTable.isPatient==0,:);dataRHci(copeTable.isPatient==0,:)];
groupStats=nan(12,5);
groupStatsS=cell(12,1);
for patcol=1:12
    thisPat=dataPTci(:,patcol);
    thisCtl=dataCTci(:,patcol);
    [h,p,ci,s]=ttest2(thisPat,thisCtl);
    effSize=meanEffectSize(thisPat,thisCtl);
    groupStats(patcol,:)=[p,table2array(effSize),0]; % p, effect, ci(low), ci(high), errorbar (1/2 of inter-error)
    groupStats(patcol,5)=abs((groupStats(patcol,3)-groupStats(patcol,4)))/2;
    groupStatsS{patcol}=s;
end
% plot patient vs control (if I've selected any plotting)
if plotting>0 % two separate ones, for ease
    figure(3);
    ttop=tiledlayout(1,6,'TileSpacing','none');
    for tiletop=[1,3,5,7,9,11] % this puts Ipsi above Contra in 2x5
        nexttile;
        bar(groupStats(tiletop,2),'FaceColor',faceVecOpts(1,:));
        axis([0.3 1.7 -0.95 0.8]);
        if tiletop==1
            yticks(-1:.2:1);
        else
            yticks(-1);
        end
        xticks(0);
        hold on;
        errorbar(groupStats(tiletop,2),groupStats(tiletop,5),'k');
        legend('off');
        set(gcf,'position',[400,300,1200,400])
    end
    figure(4);
    tbot=tiledlayout(1,6,'TileSpacing','none');
    for tilebottom=[2,4,6,8,10,12] % this puts Ipsi above Contra in 2x5
        nexttile;
        bar(groupStats(tilebottom,2),'FaceColor',faceVecOpts(2,:));
        hold on;
        axis([0.3 1.7 -0.95 .8]);
        if tilebottom==2
            yticks(-1:.2:1);
        else
            yticks(-1);
        end
        xticks(0);
        errorbar(groupStats(tilebottom,2),groupStats(tilebottom,5),'k');
        legend('off');
        set(gcf,'position',[800,300,1200,400])
    end
end

%% visualizations of main data
% 1 = one set of axes, 2 = two sets of axes (ipsi vs contra), 3 = two axes, difference scores
if plotting==1
    f=figure(1);
    t=tiledlayout(2,6,'TileSpacing','compact','Padding','compact');
    for tilei=[1,3,5,7,9,11,2,4,6,8,10,12] % this puts Ipsi above Contra in 2x5
        nexttile;
        isContra=isOdd(tilei);
        if isOdd(tilei) % contralateral
            faceVec=validatecolor(uint8([248,228,215])); % convert from output of my Color Picker app
        else
            faceVec=validatecolor(uint8([229,229,229]));
        end
        if showDiffs==1
            tileData=[zscore(dataLHci(:,tilei)),zscore(dataRHci(:,tilei))]; % LH(1) is ipsi-LH, RH(1) is ipsi-RH
            violin(tileData,'xlabel',{'LH','RH'},'mc',[],'medc','k','facecolor',faceVec,'edgecolor',[.2,.2,.2]);
        end
        line([0,4],[0,0],'LineStyle','--','Color','black');
        tempTitle=ciLabels{tilei}(6:end); % title treats _ as subscripts, so fix
        fixTitle=replace(tempTitle,'_','-');
        title(fixTitle);
        %title(thisTitle);
        legend('off');
    end
    ylabel(t,'BOLD %SC');
elseif plotting==2
    for side=0:1
        fi=figure;
        t=tiledlayout(1,6,'TileSpacing','none','Padding','compact');
        for tilei=[1,3,5,7,9,11]+side % ipsi (gray) on top)
            nexttile;
            line([0,4],[0,0],'LineStyle',':','Color','black','LineWidth',2);
            hold on
            set(gca,'layer','bottom');
            set(gca,'ygrid','on');
            tileData=[(dataLHci(:,tilei)),(dataRHci(:,tilei))];
            v=violin(tileData,'xlabel',{'LH','RH'},'mc',[],'medc','k','facecolor',faceVecOpts(side+1,:),'edgecolor','k','facealpha',1);
            set(v(2),'edgecolor',[.5,.5,.5]);
            set(v,'linewidth',3);
            set(gca,'tickdir','both');
            set(gca,'linewidth',2);
            if tilei<=2 % leftmost
                yticks(-3:6);
                set(gca,'YTickLabel',repmat(" ",8,1));
                set(gca,'TickDir','both');
                set(gca,'Xcolor',[0 0 0]);
            else % non-leftmost
                set(gca,'YTickLabel',[]);
            end
            axValues=axis;
            axis([axValues(1),axValues(2),-2.5,6]); % standardize scale
            legend('off');
        end % tile loop
        set(gcf,'position',[400+(200*side),300+(200*side),1200,400])
    end % side (figure) loop
elseif plotting==3 % difference values
    for side=0:1
        fi=figure;
        t=tiledlayout(1,6,'TileSpacing','none','Padding','compact');
        for tileSimple=1:6
            tilei=((tileSimple*2)-1)+side; % this is same tilei as above
            nexttile;
            line([0,4],[0,0],'LineStyle',':','Color','black','LineWidth',2);
            hold on
            set(gca,'layer','bottom');
            set(gca,'ygrid','on');
            tileData=(dataLHci(:,tilei))-(dataRHci(:,tilei));
            v=violin(tileData,'xlabel',{''},'mc',[],'medc','k','facecolor',faceVecOpts(side+1,:),'edgecolor','k','facealpha',1);
            set(v,'edgecolor',tileColoredRoi(tileSimple,:));
            set(v,'linewidth',3);
            set(gca,'tickdir','both');
            set(gca,'linewidth',1);
            if tileSimple==1 % leftmost
                yticks(-6:6);
                set(gca,'YTickLabel',repmat(" ",8,1));
                set(gca,'TickDir','both');
                set(gca,'Xcolor',[0 0 0]);
            else
                set(gca,'YTickLabel',[]);
            end
            axValues=axis;
            axis([axValues(1),axValues(2),-5,4]); % standardize scale
            legend('off');
        end % tile loop
        set(gcf,'position',[400+(200*side),300+(200*side),1200,400])
    end % side (figure) loop
end
% note: to create a blank violin, change medc to [] then add to each frame: set(v,'Visible','off'); set(gca,'ygrid','off');