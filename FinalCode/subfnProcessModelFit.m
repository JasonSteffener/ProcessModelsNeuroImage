function [ParameterToBS Parameters] = subfnProcessModelFit(data,PointEstFlag)
% PointEstFlag:
%           set to 0 if you only want to calculate the point estimate for
%           the model. This is used for each bootstrapping test.
%           set to 1 to estimate all parameters in the model.
%


Parameters = {};

switch data.ModelNum
    case '1'
        Nsteps = 11;
        ParameterToBS = struct('names','CondMod','values',zeros(1,Nsteps + 1),'probeValues',zeros(1,Nsteps + 1));
        Ndata = size(data.Y,1);
        % the code below works if there is a covariate or not
        
        % whether or not to run the regression at multiple values of the moderator
        % First, check to see if the interaction effect is significant or
        % not.
        S = subfnregstats(data.Y,[data.X data.M (data.M).*data.X data.COV]);
        % When this program is called during boot strapping it needs to
        % know whether or not to probe the interaction.
        % It should only check to see if the interaction is significant for
        % when the point estimate is being tested and not for any boot
        % strap re-estimates.
        %
        % If the probeMd flag is set to TRUE then check to see if the
        % interaction is significant. If so then leave the probeMod flag
        % set to TRUE. If the interaction is not significant then set the
        % flag to FALSE.
        if data.ProbeMod %
            % check to see if the interaction is significant! This should
            % only be checked the first time through.
            % if S.tstat.pval(4) < max(data.Thresholds)
            ParameterToBS.values(1,1) = S.beta(2);
            minM = min(data.M);
            maxM = max(data.M);
            rangeM = maxM - minM;
            stepM = rangeM/(Nsteps -1);
            probeM = [0 minM:stepM:maxM];
            for j = 2:Nsteps + 1
                temp = regress(data.Y,[data.X (data.M-probeM(j))  (data.M-probeM(j)).*data.X data.COV ones(Ndata,1)]);
                ParameterToBS.values(1,j) = temp(1);
                ParameterToBS.probeValues(1,j) = probeM(j);
            end
            
        else
            ParameterToBS.values = S.beta(2);
            ParameterToBS.probeValues = 0;
        end
        % Now all parameters of interest for the model are calculated.
        if PointEstFlag
            % Use the values from the calculations above
            Parameters = {};
            Parameters.const = subfnSetParameters('const', S, 1);
            Parameters.M = subfnSetParameters('M', S, 3);
            Parameters.X = subfnSetParameters('X', S, 2);
            Parameters.Int{1} = subfnSetParameters('Int', S, 4);
            Parameters.Model = subfnSetModelParameters(S);
            tcrit = tinv(1 - max(data.Thresholds)/2,length(data.X) - (4 + size(data.COV,2)));
            Parameters.JNvalue = subfnJohnsonNeyman(S.beta(2),S.covb(2,2),S.beta(4),S.covb(4,4),S.covb(2,4),tcrit);
        end

    case '4'
        % This is the simple mediation case which can handle covariates on
        % M and Y and multiple mediators, M.
        Nmed = size(data.M,2);
        Ndata = size(data.Y,1);
        a = zeros(Nmed,1);
        % covariates
        if size(data.COV,2) > 0 
            for i = 1:Nmed
                % A branch model
                temp1 = regress(data.M(:,i),[data.X data.COV ones(Ndata,1)]);
                a(i) = temp1(1);
            end
            % B branch model
            temp2 = regress(data.Y,[data.M data.X data.COV ones(Ndata,1)]);
            b = temp2(1:Nmed);
        % no covariates    
        else 
            
            for i = 1:Nmed
                % A branch model
                temp1 = regress(data.M(:,i),[data.X ones(Ndata,1)]);
                a(i) = temp1(1);
            end
            temp2 = regress(data.Y,[data.M data.X ones(Ndata,1)]);
             % B branch model
            b = temp2(1:Nmed);
        end
        % the indirect effect which will be bootstrapped
        ab = a.*b;
        ParameterToBS.values = ab;
        ParameterToBS.names = 'AB';
        % Now all parameters of interest for the model are calculated.
        if PointEstFlag 
            S1 = cell(Nmed,1);
            
            % TODO: Check to see if the models are the same whether there
            % are covariates or not like in MODEL 1.
            %
            if size(data.COV,2) > 0 % covariates
                % B branch model
                S2 = subfnregstats(data.Y,[data.M data.X data.COV]);
                for i = 1:Nmed
                    % A branch model
                    S1{i} = subfnregstats(data.M(:,i),[data.X data.COV]);
                end
                % C branch model
                S3 = subfnregstats(data.Y,[data.X data.COV]);
            else
                % B branch model
                S2 = subfnregstats(data.Y,[data.M data.X]);
                 for i = 1:Nmed
                     % A branch model
                    S1{i} = subfnregstats(data.M(:,i),[data.X ]);
                 end
                % C branch model
                S3 = subfnregstats(data.Y,data.X);    
            end
            Parameters = {};
            for i = 1:Nmed
                Parameters.Aconst{i} = subfnSetParameters('Aconst', S1{i}, 1);
                Parameters.A{i} = subfnSetParameters('A', S1{i}, 2);
                Parameters.AModel{i} = subfnSetModelParameters(S1{i});
                Parameters.B{i} = subfnSetParameters('B', S2, i+1);
                str = sprintf('Parameters.%s{i}.pointEst = ParameterToBS.values(i);',ParameterToBS.names);
                eval(str);
            end
            Parameters.BModel = subfnSetModelParameters(S2);
            Parameters.Bconst = subfnSetParameters('Bconst', S2,1);
            Parameters.C = subfnSetParameters('C', S3,2);
            Parameters.Cconst = subfnSetParameters('Cconst', S3,1);
            Parameters.CP = subfnSetParameters('CP', S2, length(S2.beta));
            Parameters.CModel = subfnSetModelParameters(S3);
            Parameters.JohnsonNeyman = -99;
        end
        
    case '14'
        % This is the moderated mediation model. The moderation (V) occurs
        % between the mediator(s) M and Y. The conditional effect of X on Y
        % via M is evaluated at multiple moderation values. The confidence
        % intervals for each of these moderating values are calculated via
        % bootstrapping. Since the model is calulated 22 (21 steps + 1 point 
        % estimate) times this model is then 22 times slower than the
        % simple mediation model.
        Nsteps = 11;
        Nmed = size(data.M,2);
        Ndata = size(data.Y,1);
        a = zeros(Nmed,1);
        % Find the values of the moderator for probing
        % what needs to be bootstrapped here is the point estimate but also
        % 20 values of the moderator and the J-N values.
        
        minV = min(data.V);
        maxV = max(data.V);
        rangeV = maxV - minV;
        stepV = rangeV/(Nsteps -1);
        probeV = [0 minV:stepV:maxV];
        ParameterToBS.values = zeros(Nmed,Nsteps+1);
        ParameterToBS.names = 'AB';
        % covariates
%         if size(data.COV,2) > 0 
            % test the interaction, if it is significant then probe the
            % interaction.
            Interaction = zeros(Ndata,Nmed);
            for j = 1:Nmed
                Interaction(:,j) = data.M(:,j).*(data.V);
                S1 = subfnregstats(data.M(:,j),[data.X data.COV]);
                a(j) = S1.beta(2);
            end
            S2 = subfnregstats(data.Y,[data.M (data.V) Interaction data.X data.COV]);
            ParameterToBS.values(:,1) = a.*(S2.beta(2:Nmed+1));
            % Check to see if the interaction effect is significantly large
            if S2.tstat.pval(4) < 0.05
                for k = 2:Nsteps + 1
                    Interaction = zeros(Ndata,Nmed);
                    for j = 1:Nmed
                        Interaction(:,j) = data.M(:,j).*(data.V - probeV(k));
                        S1 = subfnregstats(data.M(:,j),[data.X data.COV]);
                        a(j) = S1.beta(2);
                    end
                    S2 = subfnregstats(data.Y,[data.M (data.V - probeV(k)) Interaction data.X data.COV]);
                    ParameterToBS.values(:,k) = a.*(S2.beta(2:Nmed+1));
                end
%             end
%         else % no covariates
%             Interaction = zeros(Ndata,Nmed);
%             for j = 1:Nmed
%                 Interaction(:,j) = data.M(:,j).*(data.V);
%                 S1 = subfnregstats(data.M(:,j),[data.X]);
%                 a(j) = S1.beta(2);
%             end
%             S2 = subfnregstats(data.Y,[data.M (data.V) Interaction data.X]);
%             ParameterToBS.values(:,1) = a.*(S2.beta(2:Nmed+1));
%             % Check to see if the interaction effect is significantly large
%             
%             if S2.tstat.pval(4) < 0.05
%                 for k = 2:Nsteps + 1
%                     Interaction = zeros(Ndata,Nmed);
%                     for j = 1:Nmed
%                         Interaction(:,j) = data.M(:,j).*(data.V - probeV(k));
%                         S1 = subfnregstats(data.M(:,j),[data.X]);
%                         a(j) = S1.beta(2);
%                     end
%                     S2 = subfnregstats(data.Y,[data.M (data.V - probeV(k)) Interaction data.X]);
%                     ParameterToBS.values(:,k) = a.*(S2.beta(2:Nmed+1));
%                 end
%             end
        end
        
        Parameters = {};
        if PointEstFlag
            S1 = {};
            if size(data.COV,2) > 0 % covariates
                Interaction = zeros(Ndata,Nmed);
                for j = 1:Nmed
                    Interaction(:,j) = data.M(:,j).*(data.V);
                    % A branch model
                    S1{j} = subfnregstats(data.M(:,j),[data.X data.COV]);
                end
                % B branch model
                S2 = subfnregstats(data.Y,[data.M (data.V) Interaction data.X data.COV]);
                % C branch model
                S3 = subfnregstats(data.Y,[data.X data.COV]);
            else % no covariates
                Interaction = zeros(Ndata,Nmed);
                for j = 1:Nmed
                    Interaction(:,j) = data.M(:,j).*(data.V);
                    % A branch model
                    S1{j} = subfnregstats(data.M(:,j),[data.X]);
                end
                % B branch model
                S2 = subfnregstats(data.Y,[data.M (data.V) Interaction data.X]);
                % C branch model
                S3 = subfnregstats(data.Y,[data.X]);
            end
            % calculate the Johnson-Neyman value
            JNvalue = subfnJohnsonNeyman(S2.beta(2),S2.covb(2,2),S2.beta(4),S2.covb(4,4),S2.covb(2,4),data.tcrit);

            Parameters.JohnsonNeyman = JNvalue;
            for i = 1:Nmed
                Parameters.A{i} = subfnSetParameters('A', S1{i},2);
                Parameters.Aconst{i} = subfnSetParameters('Aconst', S1{i},1);
                Parameters.B{i} = subfnSetParameters('Aconst', S2,i + 1);
                Parameters.Int{i} = subfnSetParameters('Int',S2,1 + Nmed + 1 + i);
                
                for k = 1:length(probeV)
                    Parameters.AB{k,i}.PointEstFlag = ParameterToBS.values(i,k);
                    Parameters.AB{k,i}.V = probeV(k);
                end
            end
            Parameters.Bconst = subfnSetParameters('Bconst',S2,1);
            Parameters.V = subfnSetParameters('V',S2,Nmed+2);
            Parameters.C = subfnSetParameters('C',S3,2);
            Parameters.Cconst = subfnSetParameters('Cconst',S3,1);
            Parameters.CP = subfnSetParameters('Cconst',S2,1+Nmed+1+Nmed+1);
            
        end
            
end