%% =========================================================
%  ΕΡΓΑΣΙΑ 4 - Υπολογιστική Νοημοσύνη
%  Μέρος 1: TSK Classification - Haberman's Survival Dataset
%  ---------------------------------------------------------
%  Απαιτήσεις: MATLAB R2020b+, Fuzzy Logic Toolbox
%  Dataset:    haberman.data (από UCI repository)
%              Στήλες: [age, year, nodes, survival_class]
%              Κλάσεις: 1 = επέζησε >=5 χρόνια, 2 = όχι
%% =========================================================

clear; clc; close all;

%% -------------------------------------------------------
%  ΒΗΜΑ 1: Φόρτωση Δεδομένων
%  -------------------------------------------------------
data = readmatrix('haberman.data', 'FileType', 'text', 'Delimiter', ',');

X = data(:, 1:3);   % Features: age, year, positive_nodes
Y = data(:, 4);     % Labels:   1 ή 2

fprintf('=== Dataset Info ===\n');
fprintf('Συνολικά δείγματα : %d\n', size(X,1));
fprintf('Κλάση 1 (επιβίωση): %d δείγματα\n', sum(Y==1));
fprintf('Κλάση 2 (θάνατος) : %d δείγματα\n', sum(Y==2));

%% -------------------------------------------------------
%  ΒΗΜΑ 2: Stratified Split 60% / 20% / 20%
%  -------------------------------------------------------
rng(42);

classes   = unique(Y);
train_idx = [];  val_idx = [];  test_idx = [];

for c = 1:length(classes)
    idx_c = find(Y == classes(c));
    idx_c = idx_c(randperm(length(idx_c)));

    n       = length(idx_c);
    n_train = round(0.6 * n);
    n_val   = round(0.2 * n);

    train_idx = [train_idx; idx_c(1 : n_train)];
    val_idx   = [val_idx;   idx_c(n_train+1 : n_train+n_val)];
    test_idx  = [test_idx;  idx_c(n_train+n_val+1 : end)];
end

X_train = X(train_idx, :);  Y_train = Y(train_idx);
X_val   = X(val_idx,   :);  Y_val   = Y(val_idx);
X_test  = X(test_idx,  :);  Y_test  = Y(test_idx);

fprintf('\n=== Split Info ===\n');
fprintf('Train: %d δείγματα | C1=%d, C2=%d\n', ...
    length(Y_train), sum(Y_train==1), sum(Y_train==2));
fprintf('Val  : %d δείγματα | C1=%d, C2=%d\n', ...
    length(Y_val),   sum(Y_val==1),   sum(Y_val==2));
fprintf('Test : %d δείγματα | C1=%d, C2=%d\n', ...
    length(Y_test),  sum(Y_test==1),  sum(Y_test==2));

%% -------------------------------------------------------
%  ΒΗΜΑ 3: Παράμετροι Εκπαίδευσης
%  -------------------------------------------------------
maxEpochs = 100;

% Ακτίνες SC: μικρή → περισσότεροι κανόνες, μεγάλη → λιγότεροι
radii_CI = [0.3, 0.8];
radii_CD = [0.3, 0.8];

models     = cell(1, 4);
trnErrors  = cell(1, 4);
valErrors  = cell(1, 4);
modelNames = {'CI r=0.3', 'CI r=0.8', 'CD r=0.3', 'CD r=0.8'};

%% -------------------------------------------------------
%  ΒΗΜΑ 4α: Μοντέλα 1 & 2 — Class-Independent SC
%  -------------------------------------------------------
fprintf('\n=== Εκπαίδευση Class-Independent Μοντέλων ===\n');

for i = 1:2
    r = radii_CI(i);
    fprintf('\nΜοντέλο %d (%s) ...\n', i, modelNames{i});

    % Δημιουργία αρχικού FIS με Subtractive Clustering
    scOpts  = genfisOptions('SubtractiveClustering', ...
                            'ClusterInfluenceRange', r);
    initFIS = genfis(X_train, Y_train, scOpts);

    % Αλλαγή output MF: linear -> constant (singleton)
    initFIS = setOutputMFtype(initFIS, 'constant');

    fprintf('  Αριθμος κανονων (αρχικα): %d\n', numel(initFIS.Rules));

    % Εκπαίδευση με hybrid method
    opts = anfisOptions('EpochNumber',       maxEpochs, ...
                        'InitialFIS',         initFIS, ...
                        'ValidationData',     [X_val, Y_val], ...
                        'OptimizationMethod', 1);

    [models{i}, trnErrors{i}, ~, ~, valErrors{i}] = ...
        anfis([X_train, Y_train], opts);

    fprintf('  Val RMSE (teliko): %.4f\n', valErrors{i}(end));
end

%% -------------------------------------------------------
%  ΒΗΜΑ 4β: Μοντέλα 3 & 4 — Class-Dependent SC
%  -------------------------------------------------------
fprintf('\n=== Εκπαίδευση Class-Dependent Μοντέλων ===\n');

for i = 1:2
    r = radii_CD(i);
    fprintf('\nΜοντέλο %d (%s) ...\n', i+2, modelNames{i+2});

    fisArray = cell(1, length(classes));
    for c = 1:length(classes)
        idx_c  = (Y_train == classes(c));
        X_c    = X_train(idx_c, :);
        Y_c    = Y_train(idx_c);

        % Αποφυγή zero-range σε inputs ΚΑΙ output
        % Το genfis απαιτεί max > min για κάθε μεταβλητή
        eps_val = 1e-6;
        for col = 1:size(X_c, 2)
            if max(X_c(:,col)) == min(X_c(:,col))
                X_c(1,col) = X_c(1,col) + eps_val;
            end
        end
        % Το output (Y_c) είναι σταθερό μέσα σε κάθε κλάση
        % οπότε πάντα χρειάζεται perturbation
        Y_c(1) = Y_c(1) + eps_val;

        scOpts      = genfisOptions('SubtractiveClustering', ...
                                    'ClusterInfluenceRange', r);
        fisTmp      = genfis(X_c, Y_c, scOpts);
        fisTmp      = setOutputMFtype(fisTmp, 'constant');
        fisArray{c} = fisTmp;
        fprintf('  Klasi %d: %d kanonies\n', classes(c), numel(fisTmp.Rules));
    end

    % Ενωση FIS
    combinedFIS = combineFIS(fisArray, X_train, Y_train);
    fprintf('  Synoliko FIS: %d kanonies\n', numel(combinedFIS.Rules));

    opts = anfisOptions('EpochNumber',       maxEpochs, ...
                        'InitialFIS',         combinedFIS, ...
                        'ValidationData',     [X_val, Y_val], ...
                        'OptimizationMethod', 1);

    [models{i+2}, trnErrors{i+2}, ~, ~, valErrors{i+2}] = ...
        anfis([X_train, Y_train], opts);

    fprintf('  Val RMSE (teliko): %.4f\n', valErrors{i+2}(end));
end

%% -------------------------------------------------------
%  ΒΗΜΑ 5: Αξιολόγηση στο Test Set
%  -------------------------------------------------------
fprintf('\n=== Axiologisi sto Test Set ===\n');

for i = 1:4
    Y_pred_raw = evalfis(models{i}, X_test);
    Y_pred     = round(Y_pred_raw);
    Y_pred     = max(1, min(2, Y_pred));

    fprintf('\n--- Montelo %d: %s ---\n', i, modelNames{i});
    computeMetrics(Y_test, Y_pred, i, modelNames{i});
end

%% -------------------------------------------------------
%  ΒΗΜΑ 6: Learning Curves
%  -------------------------------------------------------
plotLearningCurves(trnErrors, valErrors, modelNames);

%% -------------------------------------------------------
%  ΒΗΜΑ 7: Membership Functions
%  -------------------------------------------------------
plotMembershipFunctions(models, modelNames);

fprintf('\n=== Oloklirothike i ektelesi ===\n');