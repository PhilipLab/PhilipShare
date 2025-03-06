% decodeVariableCollector.m
%
% Function for the repetitive variable handling in STEGAMRI_decode_runner.m
% Put in a table & table varname, and a scale factor (e.g. -1, 1000, etc. Defaults to 1)

function [LHdat,RHdat,meandat,lat] = decodeVariableCollector (dataTable,inputString,scalefactor)

if nargin <3 
    scalefactor=1;
end

LHvar=sprintf("%sLH",inputString);
RHvar=sprintf("%sRH",inputString);
LHdat=(table2array(dataTable(:,LHvar))).*scalefactor;
RHdat=(table2array(dataTable(:,RHvar))).*scalefactor;
meandat=mean([LHdat,RHdat],2,'omitnan');
lat=(RHdat-LHdat)./(abs(LHdat)+abs(RHdat)); % absolute value handles negatives; see https://pmc.ncbi.nlm.nih.gov/articles/PMC2726301/ eq. 4
