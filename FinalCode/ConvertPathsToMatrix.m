function data = ConvertPathsToMatrix(Paths,PathNumber)
% number of bootstraps
Nrepeats = size(Paths,2);
NumStepsMod = size(Paths{1}{1}{:},2);
% Number of elements in the path. This number does NOT need to be the same
% for each path because some paths may contain an interaction and others
% may NOT.

PathSize = numel(Paths{1}{PathNumber});
data = zeros(PathSize,NumStepsMod,Nrepeats);
for i = 1:Nrepeats
    for j = 1:PathSize
        data(j,:,i) = Paths{i}{PathNumber}{j};
    end
end
