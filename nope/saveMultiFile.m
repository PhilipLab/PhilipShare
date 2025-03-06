% saveMultiFile.m
%
% Function called by EVmaker_STEGMRA_NRLmisc
%
% when it's time to save a TAB-SEPARATED file (e.g. for EVs), this will send it to the specified locations.
% Inputs: data (column-organized array), [logical matrix of locations], ["string array of locations"], permissionString ('w','p','r', etc)
% E.g. saveMultiFile=(data,[1,0,1],{'loc1','loc2','loc3'},overwriteString)
%
% "permissionString" is optional (defaults to 'w' write/overwrite; see e.g. doc fopen), the rest are mandatory
% Saves them in 0.3f precision, tab-separated text files.

function fidList = saveMultiFile(data,outLogic,outLocs,permissionString)

if nargin==3
    permissionString='w';
elseif nargin < 3
    fprintf('Error in saveMultiFiles: first 3 arguments required\n');
end

if length(outLogic)~=length(outLocs)
    fprintf('Error in saveMultiFiles: logic length doesn''t match location length\n');
end
if ~iscell(outLocs)
    fprintf('Error in saveMultiFiles: output locations must be cell array (of strings)\n');
end
numLocs=length(outLogic);
fidList=nan(numLocs,1);

numCols=size(data,2);
outputShape='';
for buildi=1:numCols
    outputShape=[outputShape,'%0.3f\t'];
end
outputShape(end)='n';


for li=1:numLocs
    if outLogic(li)==0
        continue
    elseif outLogic(li)~=1
        fprintf('Error in saveMultiFiles: outlogic must be 1/0 logical\n');
    end
    thisLoc=outLocs{li};
    delimitSpots=strfind(thisLoc,'/');
    behDir=thisLoc(1:delimitSpots(end));
    if ~isfolder(behDir)
        mkdir(behDir);
    end
    fid=fopen(outLocs{li},permissionString); 
    fprintf(fid,outputShape,data');
    fclose(fid);
    fidList(li)=fid;
end % location loop
