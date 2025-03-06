% dateYMD.m
%
% [stringDate,numDate] = formatDate;
%
% Creates date string in YYMMDD format.

function [stringDate,numDate] = dateYMD

allTimeInfo=datevec(datetime);
ymd=allTimeInfo(1:3); % keep only YMD
stringDate=sprintf('%i%s%s',ymd(1)-2000,addz(ymd(2),2),addz(ymd(3),2));
numDate=str2double(stringDate);