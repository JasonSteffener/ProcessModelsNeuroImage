function WriteOutResults(ResultsFolder)
% Take the results from an analysis and write out results as NIFTI images.

setenv('FSLOUTPUTTYPE','NIFTI');
path1 = getenv('PATH');
path1 = [path1 ':/usr/local/fsl/bin'];
setenv('PATH', path1);

if nargin == 0
    ResultsFolder = spm_select(1,'dir','Select analysis directory');
end


fprintf(1,'%s\n',ResultsFolder);

% Check to see if there are Permute results
if ~isempty(dir(fullfile(ResultsFolder,'Results','Permute_*.mat')))
    ModelType = 'permutation';
elseif ~isempty(dir(fullfile(ResultsFolder,'Results','BootStrap*.mat')))
    ModelType = 'bootstrap';
else
    errordlg('Unknown results');
end
load(fullfile(ResultsFolder,'data','ModelInfo'))
ModelInfo.ResultsPath = ResultsFolder;

ModelInfo.BaseDir = ResultsFolder;
%% WRITE OUT ALL IMAGES from the regression models
% Load up the point estimate results
%F = dir(fullfile(ResultsFolder,'Results','PointEstimate*.mat'));
%load(fullfile(ResultsFolder,'Results',F(1).name))

%WriteOutParameterMaps('beta', Parameters, ModelInfo)
%WriteOutParameterMaps('B', Parameters, ModelInfo)
%WriteOutParameterMaps('t', Parameters, ModelInfo)

%WriteOutPathPointEstimate(Parameters,ModelInfo)
%% Find the number of results files
switch ModelType
    case 'permutation'
        % Load the data/parameters used in this analysis
        
        
        % locate the results files
        F = dir(fullfile(ResultsFolder,'Results','Permute_count*.mat'));
        NFiles = length(F);
        
        % Check to see if the analyses are completed
%         if ~(NFiles == ModelInfo.NJobSplit)
%             Button = questdlg('The analysis is not complete, continue anyway?','Continue?','Yes','No','Yes');
%             if strmatch(Button, 'No')
%                 error('This analysis is not complete.');
%             end
%         end
        
        % load a single results fle to determine the size of the paths
        load(fullfile(ResultsFolder,'Results',F(1).name))
        % m: steps in this moderated path for dimension 1
        % n: steps in this moderated path for dimension 2
        % o: number of paths
        % p: number of permutaions for this chunk of results
        [m n o p] = size(MaxPaths);

        % The files may each contain different number of permutations
        Nperm = 0;
        PermPerFile = zeros(NFiles,1);
        RunningSum = zeros(NFiles+1,1);
        
        for i = 1:NFiles
            FindUnder = findstr(F(i).name,'_');
            FindSamp = findstr(F(i).name,'Samp');
            NumPermThisFile = str2double(F(i).name(FindUnder(end)+1:FindSamp(1)-1));
            Nperm = Nperm + NumPermThisFile;
            PermPerFile(i) = NumPermThisFile;
            RunningSum(i+1) = RunningSum(i) + NumPermThisFile;
        end
        RunningSum = RunningSum(2:end);
        % Update the ModelInfo structure if needed
%         if ~(ModelInfo.Nperm == Nperm)
%             ModelInfo.Nperm = Nperm;
%             Str = sprintf('save %s ModelInfo',fullfile(ResultsFolder,'data','ModelInfo'));
%             eval(Str);
%         end
        
        % Create the structures to hold the permutation results for the
        % path values and the standardized parameter estimates
        MaxPermPaths = -99999*ones(m,n,o,Nperm);
        MinPermPaths = -99999*ones(m,n,o,Nperm);
        [mB nB pB] = size(MaxBeta);
        MaxPermB = -99999*ones(mB,nB,Nperm);
        MinPermB = -99999*ones(mB,nB,Nperm);
        MaxTFCEt = -99999*ones(mB,nB,Nperm);
        MinTFCEt = -99999*ones(mB,nB,Nperm);
        MaxTFCEpaths = -99999*ones(m,n,o,Nperm);
        MinTFCEpaths = -99999*ones(m,n,o,Nperm);
        % load the data and put the permutation results in these structures
        for i = 1:NFiles
            Indices = (RunningSum(i)-PermPerFile(i)+1):RunningSum(i);
            load(fullfile(ResultsFolder,'Results',F(i).name))
            MaxPermPaths(:,:,:,Indices) = MaxPaths;
            MinPermPaths(:,:,:,Indices) = MinPaths;
            MaxPermB(:,:,Indices) = MaxBeta;
            MinPermB(:,:,Indices) = MinBeta;
            MaxTFCEt(:,:,Indices) = TFCEtMax;
            MinTFCEt(:,:,Indices) = TFCEtMin;

            %MaxTFCEpaths(:,:,:,Indices) = reshape(squeeze(TFCEpathsMax(:,:,1,:)), 1,n,o,PermPerFile(i));
            MaxTFCEpaths(:,:,:,Indices) = TFCEpathsMax;
            %MinTFCEpaths(:,:,:,Indices) = reshape(squeeze(TFCEpathsMin(:,1,:)), 1,1,o,PermPerFile(i));
            MinTFCEpaths(:,:,:,Indices) = TFCEpathsMin;
        end
        
        
        % Reshape the path estimates for the next step of writing them out
        % as images
        PointEstimatePath = zeros(m,n,o,length(Parameters));
        PointEstimatePathtfce = zeros(m,n,o,length(Parameters));
        PointEstimateB = zeros(mB, nB, length(Parameters));
        PointEstimatet = zeros(mB, nB, length(Parameters));
        PointEstimatettfce = zeros(mB, nB, length(Parameters));
        for i = 1:length(Parameters)
            for kk = 1:o
                PointEstimatePath(:,:,kk,i) = Parameters{i}.PathsTnorm{kk};
            end
            PointEstimateB(:,:,i) = Parameters{i}.B;
            PointEstimatet(:,:,i) = Parameters{i}.t;
        end
        % Calculate the TFCE for the point estimate paths
        for ii = 1:m
            for jj = 1:n
                for kk = 1:o
                    
                    DataForThisTest = squeeze(PointEstimatePath(ii,jj,kk,:));
                    % Since the TFCE expects t maps, Z normalize the path
                    % coefficients so that they are in the expected range.
                    PointEstimatePathtfce(ii,jj,kk,:) = subfnCalcTFCE((DataForThisTest), ModelInfo, ModelInfo.TFCEparams);
                end
            end
        end
                
        for i = 1:mB
            for j = 1:nB
                if PointEstimatet(i,j,1) ~= 0
                    fprintf(1,'i = %d, j = %d\n',i,j);
                    DataForThisTest = squeeze(PointEstimatet(i,j,:));
                    PointEstimatettfce(i,j,:) = subfnCalcTFCE(DataForThisTest, ModelInfo, ModelInfo.TFCEparams);
                end
            end
        end
        % For this to work with the TFCE estimation the Parameter maps,
        % which are saved to files need to be TFCE converted.
        %%%%%%% TO DO
        % Create the TFCE parameter estimate images
        
        WriteOutPermutationPaths(ModelInfo,MaxPermPaths,MinPermPaths,PointEstimatePath,o,m,'perm',Nperm)

        
        WriteOutPermutationPaths(ModelInfo,MaxTFCEpaths,MinTFCEpaths,PointEstimatePathtfce,o,m,'tfce',Nperm)
%         figure
%         subplot(311)
%         hist(squeeze(MaxTFCEpaths(1,1,1,:)),100)
%         subplot(312)
%         hist(squeeze(PointEstimatePathtfce(1,1,1,:)),100)
%         subplot(313)
%         hist(squeeze(MinTFCEpaths(1,1,1,:)),100)
        
        WriteOutPermutationB(ModelInfo,MaxPermB,MinPermB,PointEstimateB,'permB',Nperm)
        WriteOutPermutationB(ModelInfo,MaxTFCEt,MinTFCEt,PointEstimatettfce,'tfceT',Nperm)
        
    case 'bootstrap'
        % There is a problem here fusing the split results back together
        
        
        % locate the results files
        F = dir(fullfile(ResultsFolder,'Results','BootStrap*.mat'));
        NFiles = length(F);
        
        % Check to see if the analyses are completed
        if ~(NFiles == ModelInfo.NJobSplit)
            error('This analysis is not complete.');
        end
        
        % load a single results fle to determine the size of the paths
        load(fullfile(ResultsFolder,'Results',F(1).name))
        if exist('Results','var')
            Parameters = Results;
        end
        [m n] = size(Parameters{1}.Paths{1});
        % Prespecify the data structures
        PointEstimate = zeros(m,n,ModelInfo.Nvoxels);
        % Create a structure to contain the parameters from all analysis chunks
        AllParameters = cell(ModelInfo.Nvoxels,1);
        % m: path number
        % n: probed level in the path
        %         BCaCIUpper = zeros(n,m,length(ModelInfo.Thresholds),ModelInfo.Nvoxels);
        %         BCaCILower = zeros(n,m,length(ModelInfo.Thresholds),ModelInfo.Nvoxels);
        %
        NvoxelsPerJob = ceil(ModelInfo.Nvoxels/ModelInfo.NJobSplit);
        
        Indices = [];
        % Cycle over each file
        for k = 1:NFiles
            % get the indices
            % load each results file
            load(fullfile(ResultsFolder,'Results',F(k).name))
            if exist('Results','var')
                Parameters = Results;
            end
            
            %ModelInfo.Indices = [ModelInfo.Indices Parameters
            % cycle over the voxels in the results file
            for i = 1:length(Parameters)
                % what is the overall index of voxels as described by this
                % chunk of results
                
                Index = (k-1)*NvoxelsPerJob + i;
                AllParameters{Index} = Parameters{i};
                for ii = 1:m
                    
                    PointEstimate(ii,:,Index) = Parameters{i}.Paths{ii};
                    
                end
                % cycle over thresholds
                %                 PathNumber = 1;
                %                 for j = 1:length(ModelInfo.Thresholds)
                %                     BCaCIUpper(:,:,j,Index) = squeeze(Parameters{i}.BCaCI.Paths(:,:,1,PathNumber,j));
                %                     BCaCILower(:,:,j,Index) = squeeze(Parameters{i}.BCaCI.Paths(:,:,2,PathNumber,j));
                %                 end
            end
        end
        % WriteOutBootstrapPaths(ModelInfo,PointEstimate,BCaCIUpper,BCaCILower,m,n)
        % WriteOutParameterMaps('BCaCI.p',AllParameters,ModelInfo)
        
        
        % Write out the FDR thresholded p maps also
        
        WriteOutParameterMaps('BCaCI.p',AllParameters,ModelInfo,1)
        WriteOutParameterMaps('BCaCI.Z',AllParameters,ModelInfo)
        WriteOutSingleMap('BCaCI.PathsZ',AllParameters,ModelInfo)
        WriteOutSingleMap('BCaCI.PathsP',AllParameters,ModelInfo)
        WriteOutSingleMap('BCaCI.PathsP',AllParameters,ModelInfo,1)
end



%%
function WriteOutBootstrapPaths(ModelInfo,PointEstimate,BCaCIUpper,BCaCILower,m,n)
%% WRITE OUT THE PATH IMAGES FOR THE BOOTSTRAP TEST

for i = 1:m % cycle over path number
    for j = 1:n % cycle over probed level in the path
        
        % write unthresholed path estimate
        Vo = ModelInfo.DataHeader;
        Vo.fname = (fullfile(ModelInfo.ResultsPath,sprintf('Path%d_level%d.nii',i,j)));
        % Prepare the data matrix
        I = zeros(ModelInfo.DataHeader.dim);
        % Extract the path data values
        temp = squeeze(PointEstimate(i,j,:));
        I(ModelInfo.Indices) = temp;
        % Write the images
        spm_write_vol(Vo,I);
    end
end
% Write out the thresholded path images
for k = 1:length(ModelInfo.Thresholds)
    for i = 1:m % cycle over path number
        for j = 1:n % cycle over probed level in the path
            
            % Find those locations where the product ofthe confidence
            % intervals is greater then zero. These are locatons where the
            % CI do not include zero.
            temp = squeeze(BCaCILower(j,i,k,:).*BCaCIUpper(j,i,k,:)) > 0;
            Vo = ModelInfo.DataHeader;
            Vo.fname = (fullfile(ModelInfo.ResultsPath,sprintf('Path%d_level%d_%0.3f.nii',i,j,ModelInfo.Thresholds(k))));
            % Prepare the data matrix
            I = zeros(ModelInfo.DataHeader.dim);
            
            I(ModelInfo.Indices) = temp;
            % Write the images
            spm_write_vol(Vo,I);
        end
    end
end



function WriteOutPermutationPaths(ModelInfo,MaxPermPaths,MinPermPaths,PointEstimate,o,m,Tag,Nperm)
%% WRITE OUT THE PATH IMAGES FOR THE PERMUTATION TEST
% cycle over the thresholds requested
% This allows the images to be written out even if the processing is not
% complete;
%Nperm = size(MaxPermPaths,4);



% Find the number in a sorted list of permutations that corresponds to
% the threshold.


for kk = 1:o % cycle over the number of paths
    
    % cycle over the probed value for dimension 1
    % The code does not handle multidimensional interactions yet.
    for i = 1:m
        % sort the max and min permutation results
        sMax(:,i) = sort(squeeze(MaxPermPaths(i,:,kk,:)),'descend');
        sMin(:,i) = sort(squeeze(MinPermPaths(i,:,kk,:)));
        % find the permutation value based on the sorted values
        
        
        % write unthresholded path estimate
        Vo = ModelInfo.DataHeader;
        Vo.fname = (fullfile(ModelInfo.ResultsPath,sprintf('Path%d_level%d_pe_%s.nii',kk,i,Tag)));
        % Prepare the data matrix
        I = zeros(ModelInfo.DataHeader.dim);
        % Extract the path data values
        temp = squeeze(PointEstimate(i,1,kk,:));
        I(ModelInfo.Indices) = temp;
        % Write the images
        spm_write_vol(Vo,I);
        
        % Find the locations that exceed the two-tailed threshold
        probTemp = zeros(ModelInfo.Nvoxels,1);
        for ind = 1:ModelInfo.Nvoxels
            if temp(ind) > 0
                probTemp(ind) = length(find(temp(ind) > sMax))/Nperm;
            else
                probTemp(ind) = length(find(temp(ind) < sMin))/Nperm;
            end
        end
        % Create the thresholded path output file name.
        Vo.fname=(fullfile(ModelInfo.ResultsPath,sprintf('Path%d_level%d_%s_NPerm_%d.nii',kk,i,Tag,Nperm)));
        I = zeros(Vo.dim);
        I(ModelInfo.Indices) = probTemp;
        % Write the image.
        spm_write_vol(Vo,I);
    end
end


function WriteOutPermutationB(ModelInfo,MaxB,MinB,PointEstimate,InTag,Nperm)

% cycle over the thresholds requested

Tag = sprintf('%s',InTag);
% Find the number in a sorted list of permutations that corresponds to
% the threshold.

% cycle over columns
for i = 1:ModelInfo.Nvar
    if sum(ModelInfo.Direct(:,i))
        % CONSTANT TERMS ARE ROW 1
        
        % cycle over the rows in the model
        for j = 1:ModelInfo.Nvar
            if ModelInfo.Direct(j,i)
                % create the filename describing the dependent and
                % independent effects
                FileName = sprintf('Model%d_DEP%s_IND%s_%s_NPerm_%d.nii',i,ModelInfo.Names{i},ModelInfo.Names{j},Tag,Nperm);
                % sort the max and min permutation results
                sMax = sort(squeeze(MaxB(j+1,i,:)),'descend');
                sMin = sort(squeeze(MinB(j+1,i,:)));
                % find the permutation value based on the sorted values
                temp = squeeze(PointEstimate(j+1,i,:));
                probTemp = zeros(ModelInfo.Nvoxels,1);
                for ind = 1:ModelInfo.Nvoxels
                    if temp(ind) > 0
                        probTemp(ind) = length(find(temp(ind) > sMax))/Nperm;
                    else
                        probTemp(ind) = length(find(temp(ind) < sMin))/Nperm;
                    end
                end
                
              
                
                
                I = zeros(ModelInfo.DataHeader.dim);
%                whos temps(ModelInfo.DataHeader.dim);
                I(ModelInfo.Indices) = probTemp;
                % Create the header for this image
                Vo = ModelInfo.DataHeader;
                Vo.fname = fullfile(ModelInfo.ResultsPath,FileName);
                spm_write_vol(Vo,I);
            end
        end
        % Interaction terms
        if sum(ModelInfo.Inter(:,i))
            InterVar = find(ModelInfo.Inter(:,i));
            FileName = sprintf('Model%d_DEP%s_IND',i,ModelInfo.Names{i});
            for j = 1:length(InterVar)
                FileName = sprintf('%s%sX',FileName,ModelInfo.Names{InterVar(j)});
            end
            FileName = sprintf('%s_%s.nii',FileName(1:end-1),Tag);
            
            % sort the max and min permutation results
            sMax = sort(squeeze(MaxB(ModelInfo.Nvar+2,i,:)),'descend');
            sMin = sort(squeeze(MinB(ModelInfo.Nvar+2,i,:)));
            % find the permutation value based on the sorted values
            
            temp = squeeze(PointEstimate(ModelInfo.Nvar+2,i,:));
            probTemp = zeros(ModelInfo.Nvoxels,1);
            for ind = 1:ModelInfo.Nvoxels
                if temp(ind) > 0
                    probTemp(ind) = length(find(temp(ind) > sMax))/Nperm;
                else
                    probTemp(ind) = length(find(temp(ind) < sMin))/Nperm;
                end
            end
            
            
            
            I = zeros(ModelInfo.DataHeader.dim);
            I(ModelInfo.Indices) = squeeze(temp);
            % Create the header for this image
            Vo = ModelInfo.DataHeader;
            Vo.fname = fullfile(ModelInfo.ResultsPath,FileName);
            spm_write_vol(Vo,I);
        end
    end
end
