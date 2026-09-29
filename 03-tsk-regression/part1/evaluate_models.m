%% =========================================================
%  ΜΕΡΟΣ 1 - Βήμα 3: Αξιολόγηση Μοντέλων
%  Μετρικές: RMSE, NMSE, NDEI, R²
%% =========================================================

clear; clc; close all;

%% --- Φόρτωση ---
load('tsk_models.mat');

X_test = D_test(:, 1:5);
y_test = D_test(:, 6);
y_mean = mean(y_test);

%% --- Υπολογισμός μετρικών για κάθε μοντέλο ---
results = zeros(4, 4);  % [RMSE, NMSE, NDEI, R²]

fprintf('\n%-15s %10s %10s %10s %10s\n', 'Model', 'RMSE', 'NMSE', 'NDEI', 'R²');
fprintf('%s\n', repmat('-', 1, 60));

for m = 1:4
    % Πρόβλεψη με το βέλτιστο FIS (από validation)
    y_pred = evalfis(best_fis{m}, X_test);

    % Υπολογισμός σφαλμάτων
    e = y_test - y_pred;

    SSres = sum(e.^2);
    SStot = sum((y_test - y_mean).^2);

    RMSE = sqrt(mean(e.^2));
    NMSE = SSres / SStot;
    NDEI = sqrt(NMSE);
    R2   = 1 - SSres / SStot;

    results(m, :) = [RMSE, NMSE, NDEI, R2];

    fprintf('%-15s %10.4f %10.4f %10.4f %10.4f\n', ...
        strrep(model_names{m}, '\', ''), RMSE, NMSE, NDEI, R2);
end

%% --- Αποθήκευση ---
save('tsk_results.mat', 'results', 'model_names');
fprintf('\nΑποτελέσματα αποθηκεύτηκαν στο tsk_results.mat\n');