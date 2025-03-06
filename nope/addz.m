% addz.m
%
% Adds zeros to build a string of desired length, from a number.
%
% [S] = addz (A, B)
%
% A is the number or string you want to work with.
% B is the output length you desire.
% S is a string, based on the number A, with preceding zeros added to make
% it length B.

function keystring = addz (instring, outlength)

if ~ischar(instring),
    keystring=num2str(instring);
else
    keystring=instring;
end

if length(keystring)>outlength,
    disp(strcat('addz.m: number ',keystring,' already over desired length ',outlength));
    return
end

while length(keystring)<outlength,
    keystring=strcat('0',keystring);
end