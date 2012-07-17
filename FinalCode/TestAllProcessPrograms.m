% functions
% bootSE
% subfnBootStrp
% subfnFindConfidenceIntervals
% subfnProcessModelFit


clear
% Test new mediation code
N = 112;
Gr = round(rand(N,1));
Nmed = 3;
M = randn(N,Nmed) + 10; 
X = zeros(N,1);
for i = 1:Nmed
    X = X + 0.25*M(:,i) + randn(N,1)*0.15 + i;
end
Y = 0.25*M(:,1) + randn(N,1)*0.15 + 0.5.*X.*M(:,1);

V = randn(N,1); 
W = randn(N,1); 
%corr([X M V W Y])
%corr([X M Y])
%regress(Y,[X ones(N,1)])
%regress(M,[X ones(N,1)])
%%
clear
load ModMeddata
data = {};
data.Xname = 'X';
data.Yname = 'Y';
data.Mname = 'M';
data.Vname = 'V';
data.Wname = 'W';
data.X = X;
data.Y = Y;
data.M = M;
data.STRAT = [];
data.COV = [];%randn(N,2);
data.V = V;
data.W = V;
data.Q = [];
data.R = [];
data.ModelNum = '4';
data.Thresholds = [0.05 0.01 0.005];
data.Indices = 1;
data.Nboot = 5000;

% Calculate the full stats of the model
%[ParameterToBS Parameters] = subfnProcessModelFit(data,data.ModelNum,PointEst);

%tic
Parameters = subfnVoxelWiseProcessBatch(data);
%toc

%Parameters{1}
subfnPrintResults(Parameters{1})

%%
% MODEL 4
fid = 1;
fprintf(1,'======================================================\n');
fprintf(1,'Model = %s\n',Parameters.ModelNum);
fprintf(1,'\tY = %s\n',data.Yname);
fprintf(1,'\tX = %s\n',data.Xname);
fprintf(1,'\tM = %s\n',data.Mname);

fprintf(1,'Sample size = %d\n\n',length(data.X));

fprintf(1,'Indirect effect of %s on %s via %s (a*b pathway)\n',data.Xname,data.Yname,data.Mname);
fprintf(1,'%8s\t%8s\t%8s\t%8s\n','Effect','Boot SE','BootLLCI','BootUPCI');
fprintf(1,'%8.4f\t%8.4f\t%8.4f\t%8.4f\n',Parameters{1}.AB1{1}.pointEst,Parameters{1}.AB1{1}.bootSE,Parameters{1}.AB1{1}.BCaci.alpha05(1),Parameters{1}.AB1{1}.BCaci.alpha05(2));

% Print out Model 1
for i = 1:size(data.M,2)
    fprintf(fid,'******************************************************\n')
    fprintf(1,'Outcome: %s\n\n',Parameters{1}.Model1{i}.Outcome)
    subfnPrintModelSummary(Parameters{1}.Model1{i}.Model,fid)
    subfnPrintModelResults(Parameters{1}.Model1{i},fid)
end

% Print out Model 2
fprintf(fid,'******************************************************\n')
fprintf(1,'Outcome: %s\n\n',Parameters{1}.Model2.Outcome)
subfnPrintModelSummary(Parameters{1}.Model2.Model,fid)
subfnPrintModelResults(Parameters{1}.Model2,fid)

% Print out Model 3
fprintf(fid,'******************************************************\n')
fprintf(1,'Outcome: %s\n\n',Parameters{1}.Model3.Outcome)
subfnPrintModelSummary(Parameters{1}.Model3.Model,fid)
subfnPrintModelResults(Parameters{1}.Model3,fid)



%%
% plot probe
% Nprobe = length(Parameters{1}.CondAB{1});
% probeValues = zeros(Nprobe-1,1);
% EffectValues  = zeros(Nprobe-1,1);
% se  = zeros(Nprobe-1,1);
% lowerCI = zeros(Nprobe-1,1);
% upperCI = zeros(Nprobe-1,1);
% for i = 2:Nprobe
%     probeValues(i-1) = Parameters{1}.CondAB{1}{i}.probeValue;
%     EffectValues(i-1) = Parameters{1}.CondAB{1}{i}.pointEst;
%     se(i-1) = Parameters{1}.CondAB{1}{i}.bootSE;
%     temp = Parameters{1}.CondAB{1}{i};
%     lowerCI(i-1) = temp.BCaci.alpha05(1);
%     upperCI(i-1) = temp.BCaci.alpha05(2);
% end
% 
% for i = 1:Nprobe - 1 
%     fprintf(1,'%10.4f\t%10.4f\t%10.5f\t%10.4f\t%10.4f\n',probeValues(i),EffectValues(i),se(i),lowerCI(i),upperCI(i));
% end
