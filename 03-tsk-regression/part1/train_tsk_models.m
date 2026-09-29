%% =========================================================
%  ΜΕΡΟΣ 1 - Βήμα 2: Εκπαίδευση 4 TSK Μοντέλων με ANFIS
%% =========================================================

clear; clc; close all;

%% --- Φόρτωση δεδομένων ---
load('airfoil_split.mat');  % D_train, D_val, D_test

%% --- Παράμετροι εκπαίδευσης ---
num_epochs = 100;

% Ορισμός 4 μοντέλων: [num_MFs, output_type]
% output_type: 'constant' = Singleton, 'linear' = Polynomial
models_config = {
    2, 'constant';   % TSK_model_1
    3, 'constant';   % TSK_model_2
    2, 'linear';     % TSK_model_3
    3, 'linear';     % TSK_model_4
};

model_names = {'TSK\_model\_1', 'TSK\_model\_2', 'TSK\_model\_3', 'TSK\_model\_4'};

%% --- Δομές αποθήκευσης αποτελεσμάτων ---
trained_fis  = cell(4, 1);
val_errors   = cell(4, 1);
train_errors = cell(4, 1);
best_fis     = cell(4, 1);

%% --- Εκπαίδευση μοντέλων ---
for m = 1:4
    fprintf('\n========================================\n');
    fprintf(' Εκπαίδευση μοντέλου %d/%d: %s\n', m, 4, strrep(model_names{m}, '\', ''));
    fprintf('   MFs ανά είσοδο: %d | Τύπος εξόδου: %s\n', ...
        models_config{m,1}, models_config{m,2});
    fprintf('========================================\n');

    num_mf   = models_config{m, 1};
    out_type = models_config{m, 2};

    %% --- Αρχικοποίηση FIS με genfis1 ---
    % genfis1: grid partitioning
    % mf_type: 'gbellmf' (bell-shaped)
    % overlap ~0.5 εξασφαλίζεται αυτόματα με το genfis1
    genfis_opt = genfisOptions('GridPartition');
    genfis_opt.NumMembershipFunctions = num_mf;
    genfis_opt.InputMembershipFunctionType = 'gbellmf';

    fis_init = genfis(D_train(:,1:5), D_train(:,6), genfis_opt);

    % Ορισμός τύπου εξόδου (Singleton ή Polynomial)
    for r = 1:length(fis_init.Rules)
        fis_init.output.mf(r).type = out_type;
        if strcmp(out_type, 'constant')
            fis_init.output.mf(r).params = mean(D_train(:,6));
        else
            fis_init.output.mf(r).params = zeros(1, 6); % 5 inputs + 1 bias
        end
    end

    %% --- Εκπαίδευση με ANFIS (υβριδική μέθοδος) ---
    anfis_opt = anfisOptions(...
        'InitialFIS',        fis_init, ...
        'EpochNumber',       num_epochs, ...
        'ValidationData',    D_val, ...
        'OptimizationMethod', 1);   % 1 = υβριδική μέθοδος

    [fis_trained, train_err, ~, fis_best, val_err] = ...
        anfis(D_train, anfis_opt);

    trained_fis{m}  = fis_trained;
    best_fis{m}     = fis_best;
    train_errors{m} = train_err;
    val_errors{m}   = val_err;

    fprintf('Ελάχιστο validation error: %.6f (epoch %d)\n', ...
        min(val_err), find(val_err == min(val_err), 1));
end

%% --- Αποθήκευση ---
save('tsk_models.mat', 'trained_fis', 'best_fis', 'train_errors', 'val_errors', ...
     'model_names', 'models_config', 'D_train', 'D_val', 'D_test');

fprintf('\nΌλα τα μοντέλα εκπαιδεύτηκαν και αποθηκεύτηκαν στο tsk_models.mat\n');