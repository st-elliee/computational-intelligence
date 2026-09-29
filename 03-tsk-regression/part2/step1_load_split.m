%% =========================================================
%  ΜΕΡΟΣ 2 - Βήμα 1: Φόρτωση, Προεπεξεργασία & Διαχωρισμός
%  Dataset: Superconductivity (UCI Repository)
%  Split: 60% Train | 20% Validation | 20% Test
%% =========================================================

clear; clc; close all;

%% --- 1. Φόρτωση Dataset ---
% Το αρχείο train.csv έχει 82 στήλες:
% Στήλες 1-81: features | Στήλη 82: target (critical_temp)

if ~isfile('train.csv'), unzip('train.zip'); end   % το dataset είναι συμπιεσμένο στο repo
data = readmatrix('train.csv');

X = data(:, 1:81);   % Features
y = data(:, 82);     % Target: critical temperature

N = size(data, 1);   % = 21263

fprintf('Dataset φορτώθηκε επιτυχώς.\n');
fprintf('Σύνολο δειγμάτων : %d\n', N);
fprintf('Αριθμός features  : %d\n', size(X, 2));
fprintf('Target range      : [%.2f, %.2f]\n', min(y), max(y));

%% --- 2. Έλεγχος για NaN / Inf ---
nan_count = sum(sum(isnan(data)));
inf_count = sum(sum(isinf(data)));
fprintf('\nNaN values : %d\n', nan_count);
fprintf('Inf values : %d\n', inf_count);

% Αν υπάρχουν NaN, αντικατάστασε με median κάθε στήλης
if nan_count > 0
    for col = 1:size(data,2)
        col_median = median(data(:,col), 'omitnan');
        data(isnan(data(:,col)), col) = col_median;
    end
    fprintf('NaN values αντικαταστάθηκαν με median.\n');
end

%% --- 3. Κανονικοποίηση (Normalization) στο [0, 1] ---
% Σημαντικό για το Subtractive Clustering και το ANFIS
X_norm = normalize(X, 'range');  % min-max normalization ανά feature
y_norm = normalize(y, 'range');

fprintf('\nΚανονικοποίηση δεδομένων: [0,1] ✓\n');

%% --- 4. Τυχαία Ανακατάταξη (Shuffle) ---
rng(42);
idx = randperm(N);
X_norm = X_norm(idx, :);
y_norm = y_norm(idx);
y_orig = y(idx);  % Κρατάμε και τις αρχικές τιμές για αξιολόγηση

%% --- 5. Διαχωρισμός 60 / 20 / 20 ---
n_train = round(0.60 * N);        % 12757
n_val   = round(0.20 * N);        % 4252
n_test  = N - n_train - n_val;    % 4254

D_train = [X_norm(1:n_train, :),             y_norm(1:n_train)];
D_val   = [X_norm(n_train+1:n_train+n_val,:), y_norm(n_train+1:n_train+n_val)];
D_test  = [X_norm(n_train+n_val+1:end, :),   y_norm(n_train+n_val+1:end)];

y_test_orig = y_orig(n_train+n_val+1:end);  % για inverse-transform αξιολόγηση

fprintf('\nΔιαχωρισμός δεδομένων:\n');
fprintf('  Εκπαίδευσης (Dtrn): %d δείγματα\n', size(D_train,1));
fprintf('  Επικύρωσης  (Dval): %d δείγματα\n', size(D_val,1));
fprintf('  Ελέγχου     (Dchk): %d δείγματα\n', size(D_test,1));

%% --- 6. Αποθήκευση ---
% Αποθηκεύουμε και τα X_norm ολόκληρα για το feature selection
save('supercon_split.mat', ...
    'D_train', 'D_val', 'D_test', ...
    'X_norm', 'y_norm', 'y_orig', 'y_test_orig', ...
    'n_train', 'n_val', 'n_test', 'N');

fprintf('\nΑποθηκεύτηκε στο supercon_split.mat ✓\n');