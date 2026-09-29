% =========================================================
%  ΕΡΓΑΣΙΑ 4 - Υπολογιστική Νοημοσύνη
%  Μέρος 2: TSK Classification - Epileptic Seizure Dataset
%  ---------------------------------------------------------
%  Προσέγγιση: Class-Dependent SC (ανά κλάση ξεχωριστά)
%  + Singleton outputs + nearestClass classification
%  
%  ΔΙΟΡΘΩΣΗ C5=0: Χρήση class-specific SC στο RAW (μη
%  κανονικοποιημένο) feature space για κάθε κλάση, ώστε
%  τα clusters να έχουν πραγματικά διαφορετικές θέσεις.
%  Η normalization εφαρμόζεται ΜΕΤΑ τον εντοπισμό clusters.
% =========================================================
clear; clc; close all;

%% -------------------------------------------------------
%  ΒΗΜΑ 1: Φόρτωση Δεδομένων
%  -------------------------------------------------------
fprintf('=== ΜΕΡΟΣ 2: Epileptic Seizure Recognition ===\n\n');
T          = readtable('epileptic_seizure_data.csv');
dataMatrix = table2array(T(:, 2:end));
X_all      = dataMatrix(:, 1:end-1);
Y_all      = dataMatrix(:, end);

classes = unique(Y_all);
nC      = numel(classes);
fprintf('Δείγματα: %d  |  Features: %d  |  Κλάσεις: %d\n', ...
    size(X_all,1), size(X_all,2), nC);
for c = classes'
    fprintf('  Κλάση %d: %d δείγματα\n', c, sum(Y_all==c));
end

%% -------------------------------------------------------
%  ΒΗΜΑ 2: Stratified Split  60/20/20
%  -------------------------------------------------------
rng(42);
trn_idx=[]; val_idx=[]; tst_idx=[];
for c = classes'
    ic  = find(Y_all==c); ic = ic(randperm(numel(ic)));
    n   = numel(ic); n1 = round(0.6*n); n2 = round(0.2*n);
    trn_idx = [trn_idx; ic(1:n1)];
    val_idx = [val_idx; ic(n1+1:n1+n2)];
    tst_idx = [tst_idx; ic(n1+n2+1:end)];
end
% Raw (non-normalized) splits — used for SC cluster discovery
X_trn_raw = X_all(trn_idx,:); Y_trn = Y_all(trn_idx);
X_val_raw = X_all(val_idx,:); Y_val = Y_all(val_idx);
X_tst_raw = X_all(tst_idx,:); Y_tst = Y_all(tst_idx);

% Z-score (fit on train raw)
mu  = mean(X_trn_raw); sg = std(X_trn_raw); sg(sg==0)=1;
X_trn = (X_trn_raw - mu) ./ sg;
X_val = (X_val_raw - mu) ./ sg;
X_tst = (X_tst_raw - mu) ./ sg;

fprintf('\nSplit: Train=%d  Val=%d  Test=%d\n', numel(Y_trn),numel(Y_val),numel(Y_tst));

%% -------------------------------------------------------
%  ΒΗΜΑ 3: Feature Selection — Relief (on normalized train)
%  -------------------------------------------------------
fprintf('\n=== Feature Selection (Relief) ===\n');
[feat_rank, ~] = relieff(X_trn, Y_trn, 10);
fprintf('Top-15: %s\n', mat2str(feat_rank(1:15)));

%% -------------------------------------------------------
%  ΒΗΜΑ 4: Grid Search + 5-fold CV
%  -------------------------------------------------------
nF_vals   = [2, 4, 6, 8, 10];
r_vals    = [0.3, 0.5, 0.7, 0.9];
nFolds    = 5;
epochs_cv = 30;

% 20% stratified subsample για CV
cv_idx=[];
for c=classes'
    ic=find(Y_trn==c); ic=ic(randperm(numel(ic)));
    cv_idx=[cv_idx; ic(1:round(0.2*numel(ic)))];
end
Xcv_n   = X_trn(cv_idx,:);     % normalized
Xcv_raw = X_trn_raw(cv_idx,:); % raw (για SC)
Ycv     = Y_trn(cv_idx);
fprintf('\n=== Grid Search (5-fold CV, %d δείγματα) ===\n', numel(Ycv));

gs_err = nan(numel(nF_vals), numel(r_vals));
cnt = 0;
for fi = 1:numel(nF_vals)
    nf   = nF_vals(fi);
    sf   = feat_rank(1:nf);

    for ri = 1:numel(r_vals)
        r   = r_vals(ri);
        cnt = cnt+1;
        fprintf('[%2d/20] nFeat=%2d  r=%.1f  ', cnt, nf, r);

        cvp  = cvpartition(Ycv,'KFold',nFolds,'Stratify',true);
        ferr = nan(nFolds,1);
        for fold = 1:nFolds
            trIdx = cvp.training(fold);
            vaIdx = cvp.test(fold);
            Xf_n  = Xcv_n(trIdx, sf);
            Xf_r  = Xcv_raw(trIdx, sf);
            Yf    = Ycv(trIdx);
            Xfv_n = Xcv_n(vaIdx, sf);
            Yfv   = Ycv(vaIdx);
            try
                fis  = buildTSK(Xf_r, Xf_n, Yf, classes, r);
                opts = anfisOptions('EpochNumber',             epochs_cv,...
                                    'InitialFIS',              fis,      ...
                                    'OptimizationMethod',      1,        ...
                                    'DisplayANFISInformation', false,    ...
                                    'DisplayErrorValues',      false,    ...
                                    'DisplayStepSize',         false,    ...
                                    'DisplayFinalResults',     false);
                tr_fis = anfis([Xf_n, Yf], opts);
                Yraw   = evalfis(tr_fis, Xfv_n);
                Ypred  = nearestClass(Yraw, classes);
                ferr(fold) = mean(Ypred ~= Yfv);
            catch
                ferr(fold) = 1.0;
            end
        end
        gs_err(fi,ri) = mean(ferr,'omitnan');
        fprintf('CV Error = %.4f\n', gs_err(fi,ri));
    end
end

%% -------------------------------------------------------
%  ΒΗΜΑ 5: Βέλτιστες Παράμετροι
%  -------------------------------------------------------
[~,mi] = min(gs_err(:));
[best_fi,best_ri] = ind2sub(size(gs_err),mi);
best_nf    = nF_vals(best_fi);
best_r     = r_vals(best_ri);
best_feats = feat_rank(1:best_nf);

fprintf('\n=== Βέλτιστες Παράμετροι ===\n');
fprintf('  nFeatures=%d  r=%.1f  CV Error=%.4f\n', best_nf,best_r,gs_err(best_fi,best_ri));
fprintf('  Features: %s\n', mat2str(best_feats));

fprintf('\n%-8s','nF\\r');
for r=r_vals; fprintf('  r=%.1f  ',r); end; fprintf('\n');
for fi=1:numel(nF_vals)
    fprintf('%-8d',nF_vals(fi));
    for ri=1:numel(r_vals); fprintf('  %.4f  ',gs_err(fi,ri)); end
    fprintf('\n');
end
fprintf('\nGrid 2MFs: %d κανόνες  |  Grid 3MFs: %d κανόνες\n',2^best_nf,3^best_nf);

%% -------------------------------------------------------
%  ΒΗΜΑ 6: Διαγράμματα Grid Search
%  -------------------------------------------------------
figure('Name','Grid Search','Position',[50 50 1400 420]);
subplot(1,3,1);
imagesc(gs_err); colorbar; colormap('hot');
xticks(1:numel(r_vals)); xticklabels(arrayfun(@(x)num2str(x,'%.1f'),r_vals,'Uni',false));
yticks(1:numel(nF_vals)); yticklabels(arrayfun(@num2str,nF_vals,'Uni',false));
xlabel('Radius r_\alpha'); ylabel('# Features'); title('CV Error Heatmap','FontWeight','bold');
hold on; plot(best_ri,best_fi,'g*','MarkerSize',16,'LineWidth',2.5); hold off;
subplot(1,3,2);
plot(nF_vals,mean(gs_err,2),'b-o','LineWidth',1.8,'MarkerFaceColor','b');
xlabel('# Features'); ylabel('Mean CV Error'); title('Error vs Features'); grid on;
subplot(1,3,3);
plot(r_vals,mean(gs_err,1),'r-o','LineWidth',1.8,'MarkerFaceColor','r');
xlabel('Radius r_\alpha'); ylabel('Mean CV Error'); title('Error vs Radius'); grid on;
sgtitle('Grid Search — 5-fold CV (Μέρος 2)','FontSize',13);
saveas(gcf,'part2_gridsearch.png');

%% -------------------------------------------------------
%  ΒΗΜΑ 7: Εκπαίδευση Τελικού Μοντέλου
%  -------------------------------------------------------
fprintf('\n=== Εκπαίδευση Τελικού Μοντέλου ===\n');
Xtr_r = X_trn_raw(:, best_feats);  % raw για SC
Xtr_n = X_trn(:, best_feats);      % normalized για anfis
Xval_n = X_val(:, best_feats);
Xtst_n = X_tst(:, best_feats);

initFIS = buildTSK(Xtr_r, Xtr_n, Y_trn, classes, best_r);
fprintf('Κανόνες SC: %d  |  Grid 2MF: %d  |  Grid 3MF: %d\n', ...
    numel(initFIS.Rules), 2^best_nf, 3^best_nf);

opts_f = anfisOptions('EpochNumber',       100,             ...
                       'InitialFIS',         initFIS,         ...
                       'ValidationData',     [Xval_n, Y_val], ...
                       'OptimizationMethod', 1);
[trainedFIS, trnErr, ~, ~, valErr] = anfis([Xtr_n, Y_trn], opts_f);

%% -------------------------------------------------------
%  ΒΗΜΑ 8: Αξιολόγηση
%  -------------------------------------------------------
fprintf('\n=== Αξιολόγηση ===\n');
Yraw  = evalfis(trainedFIS, Xtst_n);
Ypred = nearestClass(Yraw, classes);

fprintf('Κατανομή: ');
for c=classes'; fprintf('C%d=%d  ',c,sum(Ypred==c)); end; fprintf('\n');
computeMetrics(Y_tst, Ypred, classes, 'Part2 Final Model');

%% -------------------------------------------------------
%  ΒΗΜΑ 9: Διαγράμματα
%  -------------------------------------------------------
figure('Name','Learning Curves','Position',[50 50 900 500]);
plot(trnErr,'b-','LineWidth',1.8,'DisplayName','Training');  hold on;
plot(valErr,'r--','LineWidth',1.8,'DisplayName','Validation');
xlabel('Epochs'); ylabel('RMSE'); grid on; legend; 
title('Learning Curves — Τελικό Μοντέλο (Μέρος 2)');
saveas(gcf,'part2_learning_curve.png');

figure('Name','Predictions vs Actual','Position',[50 50 1000 400]);
ns=min(300,numel(Y_tst));
plot(Y_tst(1:ns),'b.','MarkerSize',10,'DisplayName','Actual');  hold on;
plot(Ypred(1:ns),'r.','MarkerSize',6,'DisplayName','Predicted');
xlabel('Sample'); ylabel('Class'); yticks(1:5); ylim([0.5 5.5]);
legend; grid on;
title(sprintf('Predictions vs Actual (πρώτα %d test samples)',ns));
saveas(gcf,'part2_predictions.png');

plotMFs(initFIS,   'Αρχικό FIS (πριν εκπαίδευση)',  'init');
plotMFs(trainedFIS,'Τελικό FIS (μετά εκπαίδευση)',  'final');

fprintf('\n=== Ολοκληρώθηκε ===\n');

%% =========================================================
%  ΤΟΠΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
%% =========================================================

function fis = buildTSK(X_raw, X_norm, Y, classes, r)
% Class-dependent SC on RAW data → MF positions in raw space
% → rescale MF parameters to normalized space → build combined FIS
    nInp = size(X_norm,2);
    
    % Compute normalization params from this fold's training data
    mu_r = mean(X_raw); sg_r = std(X_raw); sg_r(sg_r==0)=1;

    fis = sugfis('Name','TSK_CD');
    for i=1:nInp
        lo=min(X_norm(:,i)); hi=max(X_norm(:,i));
        if lo>=hi; hi=lo+1e-4; end
        fis=addInput(fis,[lo,hi],'Name',sprintf('in%d',i));
    end
    fis=addOutput(fis,[min(classes)-0.5, max(classes)+0.5],'Name','out1');

    mfOff=zeros(1,nInp); outOff=0;
    rAnt=[]; rCon=[];

    for ci=1:numel(classes)
        c   = classes(ci);
        Xc_raw = X_raw(Y==c,:);
        if size(Xc_raw,1)<2; continue; end

        % SC in RAW space → different cluster centers per class
        scOpt = genfisOptions('SubtractiveClustering','ClusterInfluenceRange',r);
        try
            tmpFIS = genfis(Xc_raw, c*ones(size(Xc_raw,1),1), scOpt);
        catch
            tmpFIS = makeFallback(Xc_raw, mu_r, sg_r, c);
        end

        nR = numel(tmpFIS.Rules);

        % Rescale MF parameters from raw → normalized space
        for i=1:nInp
            for mi=1:numel(tmpFIS.Inputs(i).MembershipFunctions)
                mf  = tmpFIS.Inputs(i).MembershipFunctions(mi);
                p   = mf.Parameters;
                % gaussmf params: [sigma, center]
                % normalize center, scale sigma
                p_n = [(p(1)/sg_r(i)), (p(2)-mu_r(i))/sg_r(i)];
                fis = addMF(fis,sprintf('in%d',i),mf.Type, p_n,...
                    'Name',sprintf('c%d_i%d_m%d',c,i,mi));
            end
        end

        for ri=1:nR
            fis=addMF(fis,'out1','constant',double(c),...
                'Name',sprintf('c%d_r%d',c,ri));
            outOff=outOff+1;
        end

        for ri=1:nR
            ant=tmpFIS.Rules(ri).Antecedent+mfOff;
            ant(tmpFIS.Rules(ri).Antecedent==0)=0;
            rAnt=[rAnt; ant]; rCon=[rCon; outOff-nR+ri];
        end
        for i=1:nInp
            mfOff(i)=mfOff(i)+numel(tmpFIS.Inputs(i).MembershipFunctions);
        end
    end

    if isempty(rAnt); error('buildTSK: κανείς κανόνας'); end
    fis=addRule(fis,[rAnt, rCon, ones(size(rAnt,1),2)]);
end

function f=makeFallback(Xc_raw, mu_r, sg_r, c)
    n=size(Xc_raw,2); mu=mean(Xc_raw); sg=std(Xc_raw); sg(sg<1e-4)=1e-4;
    f=sugfis;
    for i=1:n
        f=addInput(f,[mu(i)-4*sg(i),mu(i)+4*sg(i)],'Name',sprintf('in%d',i));
        f=addMF(f,sprintf('in%d',i),'gaussmf',[sg(i),mu(i)],'Name','mf1');
    end
    f=addOutput(f,[c-0.5,c+0.5],'Name','out1');
    f=addMF(f,'out1','constant',double(c),'Name','out1');
    f=addRule(f,[ones(1,n),1,1,1]);
end

function Yp=nearestClass(Yraw,classes)
    Yraw=Yraw(:); cl=classes(:)';
    [~,mi]=min(abs(Yraw-cl),[],2);
    Yp=classes(mi);
end

function computeMetrics(Y_true, Y_pred, classes, modelName)
    k=numel(classes); N=numel(Y_true);
    E=zeros(k,k);
    for i=1:k
        for j=1:k; E(i,j)=sum(Y_pred==classes(i)&Y_true==classes(j)); end
    end
    fprintf('\nError Matrix — %s\n',modelName);
    fprintf('       '); for j=1:k; fprintf('  C%d   ',classes(j)); end; fprintf('\n');
    for i=1:k
        fprintf('PC%d :  ',classes(i));
        for j=1:k; fprintf('%4d   ',E(i,j)); end; fprintf('\n');
    end
    OA=sum(diag(E))/N; xir=sum(E,2); xjc=sum(E,1)';
    fprintf('\nOA = %.4f (%.2f%%)\n',OA,OA*100);
    fprintf('%-6s  PA        UA\n','Class');
    for i=1:k
        PA=0; if xjc(i)>0; PA=E(i,i)/xjc(i); end
        UA=0; if xir(i)>0; UA=E(i,i)/xir(i); end
        fprintf('C%-5d  %.4f    %.4f\n',classes(i),PA,UA);
    end
    kappa=(N*sum(diag(E))-sum(xir.*xjc))/(N^2-sum(xir.*xjc));
    fprintf('Kappa = %.4f\n',kappa);
    figure('Name',sprintf('Confusion — %s',modelName),'Position',[50 50 700 600]);
    confusionchart(Y_true,Y_pred,...
        'Title',sprintf('Confusion Matrix — %s',modelName),...
        'RowSummary','row-normalized','ColumnSummary','column-normalized');
    saveas(gcf,sprintf('confusion_%s.png',strrep(lower(modelName),' ','_')));
end

function plotMFs(fis,titleStr,tag)
    nInp=min(3,numel(fis.Inputs));
    figure('Name',titleStr,'Position',[50 50 1200 380]);
    for i=1:nInp
        subplot(1,nInp,i); hold on;
        mfs=fis.Inputs(i).MembershipFunctions;
        rng_=fis.Inputs(i).Range;
        xv=linspace(rng_(1),rng_(2),300);
        cols=lines(numel(mfs));
        for mi=1:numel(mfs)
            yv=evalmf(xv,mfs(mi).Parameters,mfs(mi).Type);
            plot(xv,yv,'Color',cols(mi,:),'LineWidth',1.5);
        end
        title(sprintf('Input %d  (%d MFs)',i,numel(mfs)));
        xlabel(fis.Inputs(i).Name); ylabel('Membership');
        ylim([0 1.1]); grid on; hold off;
    end
    sgtitle(titleStr,'FontSize',12);
    saveas(gcf,sprintf('mfs_part2_%s.png',tag));
end