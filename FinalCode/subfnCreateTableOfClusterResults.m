function [posOutStruct negOutStruct] = subfnCreateTableOfClusterResults

Paal = '/share/studies/CogRes/GroupAnalyses/ModMedCogRes/masks/raal.nii';
Pba = '/share/studies/CogRes/GroupAnalyses/ModMedCogRes/masks/rbrodmann.nii';
% load the atlas maps
Vba = spm_vol(Pba);
Vaal = spm_vol(Paal);
Iaal = spm_read_vols(Vaal);
Iba = spm_read_vols(Vba);


% Select the thresholded image
InputImage = spm_select(1,'image');
choice = questdlg('Is this image thresholded?', ...
	'Thresholded?', ...
	'yes','no','yes');

switch choice
    case 'yes'
        HeightThreshold = 0.5;
        ExtentThreshold = 0.5;
    case 'no'
        prompt = {'Enter height threshold:','Enter extent threshold:'};
        dlg_title = 'Input for thresholds';
        num_lines = 1;
        def = {'1.96','100'};
        answer = inputdlg(prompt,dlg_title,num_lines,def);
        HeightThreshold = answer{1};
        ExtentThreshold = answer{2};
        InputImage = subfnApplyThresholdsToImages(InputImage,HeightThreshold,ExtentThreshold);
end

% Create the table of results using SPM
% POSITIVE DIRECTION
[SPM xSPM] = DisplayCov(InputImage,HeightThreshold,ExtentThreshold);
NumLocalMaxima = 3;
DistancebetweenMaxima = 8;

posOutStruct = findAALandBAfromTabDat(xSPM,NumLocalMaxima,DistancebetweenMaxima,Iaal,Iba);


% NEGATIVE DIRECTION
% load the image
V = spm_vol(InputImage);
I = spm_read_vols(V);
% find the activations in the negative direction
F = find(I < -HeightThreshold);
[x y z] = ind2sub(V.dim,F);
negXYZ = [x y z];
negXYZmm = (SPM.xVol.M*[negXYZ ones(length(negXYZ),1)]')';
negZ = I(F)';
negxSPM = xSPM;
negxSPM.Z = negZ;
negxSPM.XYZ = negXYZ';
negxSPM.XYZmm = negXYZmm(:,1:3)';
negxSPM.title = 'negative direction';


negOutStruct = findAALandBAfromTabDat(negxSPM,NumLocalMaxima,DistancebetweenMaxima,Iaal,Iba);
fprintf(1,'===== %s ======\n','POSITIVE DIRECTION');
WriteTableOutResultsToScreen(posOutStruct,InputImage)
fprintf(1,'===== %s ======\n','NEGATIVE DIRECTION');
WriteTableOutResultsToScreen(negOutStruct,InputImage)


% Find the negative clusters

% find the locations of the maxima for each cluster

% fine the locations of the local maxima in each cluster

% find teh BA/AAL locations for these maxima


function WriteTableOutResultsToScreen(OutStruct,InputImage)
NCl = length(OutStruct.t);
fid = 1;
fprintf(fid,'===== %s ======\n',InputImage);
fprintf(fid,'%-20s\t%5s\t%5s\t%5s\t%5s\t%5s\t%10s\t%10s\n','Region','Lat','BA','Xmm','Ymm','Zmm','Z','ClSize');
for i = 1:NCl
    fprintf(fid,'%-20s\t%5s\t%5d\t',OutStruct.aal{i}(1:end-2), OutStruct.aal{i}(end),OutStruct.ba(i));
    fprintf(fid,'%5d\t%5d\t%5d\t',OutStruct.loc(i,:));
    fprintf(fid,'%10.2f\t%10s\n', OutStruct.t(i),OutStruct.k{i});
end
fprintf(fid,'=============================================================\n');

function [AALList BAList] = subfnLocalFindAALandBA(XYZ, Iaal, Iba)
[aalCol1 aalCol2 aalCol3] = textread('/share/studies/CogRes/GroupAnalyses/ModMedCogRes/masks/aal.nii.txt','%d%s%d');
NVoxels = size(XYZ,1);
AALList = {};
BAList = zeros(NVoxels,1);
for i = 1:NVoxels
    CurrentValue = Iaal(XYZ(i,1), XYZ(i,2), XYZ(i,3));
    BAList(i,1) = Iba(XYZ(i,1), XYZ(i,2), XYZ(i,3));
    if CurrentValue
        AALList{i} = aalCol2{CurrentValue};
    else
        AALList{i} = '**empty**';
    end
end



function OutStruct = findAALandBAfromTabDat(xSPM,NumLocalMaxima,DistancebetweenMaxima,Iaal,Iba)
TabDat = spm_list('table',xSPM,[NumLocalMaxima,DistancebetweenMaxima,'']);
% Read the table 
NClust = size(TabDat.dat,1);
XYZmm = zeros(NClust,3);
TList = zeros(NClust,1);
ZList = zeros(NClust,1);
pList = zeros(NClust,1);
ClList = {};%zeros(NClust,1);
%
Hdr = char(TabDat.hdr(2,:));
for i = 1:length(Hdr)
    element = deblank(Hdr(i,:));
    switch element
        case {'equivk'}
            KCol = i;
        case {'T'}
            TCol = i;
        case {'equivZ'}
            ZCol = i;
    end
end
for i = 1:NClust
    XYZmm(i,:) = TabDat.dat{i,end}(:)';
    TList(i,1) = TabDat.dat{i,TCol};
    ZList(i,1) = TabDat.dat{i,ZCol};
    pList(i,1) = TabDat.dat{i,end - 1};
    tempCl = TabDat.dat{i,KCol};
    if ~isempty(tempCl)
        ClList{i} = num2str(tempCl);
    else
        ClList{i} = '--';
    end
end

XYZ = (inv(xSPM.Vspm.mat)*([XYZmm ones(length(XYZmm),1)])')';
% This program finds the AAL and Brodmann Area labels for all XYZ mm
% coordinates it is passed.
[AALList BAList] = subfnLocalFindAALandBA(XYZ(:,1:3),Iaal,Iba);

OutStruct = {};
OutStruct.loc = XYZmm;
OutStruct.t = TList;
OutStruct.Z = ZList;
OutStruct.p = pList;
OutStruct.k = ClList';
OutStruct.aal = AALList';
OutStruct.ba = BAList;





