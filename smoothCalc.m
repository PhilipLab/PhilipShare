% smoothCalc.m
%
% CURRENTLY D
% 
% Takes in a raw velocity profile and produces a Smoothness Score for that
% vector. Doesn't care how long vector is, treats it as one unit.
% Velocity = a vector of velocities
% Filter = FWHM gaussian filter (default 0 in case you've filtered data externally, e.g. with lowpass)
%
% Formula follows ExtractCodesSober: zero-crossing in acceleration profile

function [smoothness,velUse] = smoothCalc(velocity,kernel)

if nargin ==1
    kernel=0;
end

zeroCrossings=0;

velUse=fgsmooth(velocity,kernel);
accel=[0;diff(velUse)]; % doesn't matter whether you Diff before or after smoothing
numPoints=length(accel);
for i=2:numPoints
    prevAcc=accel(i-1);
    thisAcc=accel(i);
    if prevAcc < 0 && thisAcc >= 0
        zeroCrossings=zeroCrossings+1;
    elseif prevAcc > 0 && thisAcc <= 0
        zeroCrossings=zeroCrossings+1;
    end
end
smoothness=-1*zeroCrossings; % convert from Rough to Smooth