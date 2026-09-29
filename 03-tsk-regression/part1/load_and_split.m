%% =========================================================
%  ΜΕΡΟΣ 1 - Βήμα 1: Φόρτωση & Διαχωρισμός Δεδομένων
%  Dataset: Airfoil Self-Noise (UCI Repository)
%  Split: 60% Train | 20% Validation | 20% Test
%% =========================================================

clear; clc; close all;

%% --- 1. Φόρτωση Dataset ---
% Το αρχείο είναι tab-separated, χωρίς header
% Στήλες: Frequency, AngleOfAttack, ChordLength, FreeStreamVelocity,
%          SuctionSideDisplacementThickness, ScaledSoundPressureLevel (target)

data = readmatrix('airfoil_self_noise.dat');  % αλλαγή σε .csv αν χρειαστεί

X = data(:, 1:5);   % Features (5 μεταβλητές εισόδου)
y = data(:, 6);     % Target (Scaled Sound Pressure Level)

N = size(data, 1);  % = 1503

fprintf('Dataset φορτώθηκε επιτυχώς.\n');
fprintf('Σύνολο δειγμάτων: %d\n', N);
fprintf('Αριθμός features: %d\n', size(X, 2));

%% --- 2. Τυχαία Ανακατάταξη (shuffle) ---
rng(42);  % για αναπαραγωγιμότητα
idx = randperm(N);
data_shuffled = data(idx, :);

%% --- 3. Διαχωρισμός 60 / 20 / 20 ---
n_train = round(0.60 * N);   % 901
n_val   = round(0.20 * N);   % 300
n_test  = N - n_train - n_val; % 302

idx_train = 1 : n_train;
idx_val   = n_train+1 : n_train+n_val;
idx_test  = n_train+n_val+1 : N;

D_train = data_shuffled(idx_train, :);
D_val   = data_shuffled(idx_val,   :);
D_test  = data_shuffled(idx_test,  :);

fprintf('\nΔιαχωρισμός δεδομένων:\n');
fprintf('  Εκπαίδευσης (Dtrn): %d δείγματα\n', size(D_train, 1));
fprintf('  Επικύρωσης  (Dval): %d δείγματα\n', size(D_val,   1));
fprintf('  Ελέγχου     (Dchk): %d δείγματα\n', size(D_test,  1));

%% --- 4. Αποθήκευση ---
save('airfoil_split.mat', 'D_train', 'D_val', 'D_test');
fprintf('\nΑποθηκεύτηκε στο airfoil_split.mat\n');