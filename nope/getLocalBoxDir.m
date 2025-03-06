% localBoxDir.m
% Returns the path to Box on a user's computer. Paths are hard-coded.
% Username is extracted from char(java.lang.System.getProperty('user.name'))

function boxPath = getLocalBoxDir

userName = char(java.lang.System.getProperty('user.name'));

if strcmp(userName,'bphilip')
    boxPath = '/Users/bphilip/Library/CloudStorage/Box-Box/';
elseif strcmp(userName,'kapiln') % Namarta: correct this if needed
    boxPath = 'something'; % Namarta: fill this in
elseif strcmp(userName,'labuser')
    boxPath = '/Users/labuser/Library/CloudStorage/Box-Box/';
else
    boxPath = 'ERROR';
    fprintf('Error: unknown username %s found in localBoxDir\n',userName);
end