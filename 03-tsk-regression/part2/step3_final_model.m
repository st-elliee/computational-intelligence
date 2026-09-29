%% =========================================================
%  ΜΕΡΟΣ 2 - Βήμα 3: Εκπαίδευση Τελικού TSK Μοντέλου
%             + Όλα τα Διαγράμματα + Πίνακας Μετρικών
%% =========================================================

clear; clc; close all;

%% --- Φόρτωση ---
load('supercon_split.mat');
load('gridsearch_results.mat');

fprintf('=== Τελικό Μοντέλο ===\n');
fprintf('  Features  : %d (indices: ', best_num_features);
fprintf('%d ', best_features_idx); fprintf(')\n');
fprintf('  Radius rα : %.1f\n\n', best_ra);

%% --- Προετοιμασία δεδομένων με βέλτιστα features ---
X_train = D_train(:, best_features_idx);
y_train = D_train(:, 82);

X_val   = D_val(:, best_features_idx);
y_val   = D_val(:, 82);

X_test  = D_test(:, best_features_idx);
y_test  = D_test(:, 82);

train_data = [X_train, y_train];
val_data   = [X_val,   y_val];

%% =========================================================
%  ΕΚΠΑΙΔΕΥΣΗ ΤΕΛΙΚΟΥ ΜΟΝΤΕΛΟΥ
%% =========================================================

% Δημιουργία FIS με Subtractive Clustering
fprintf('Δημιουργία FIS με Subtractive Clustering...\n');
fis_init = genfis(X_train, y_train, ...
    genfisOptions('SubtractiveClustering', ...
    'ClusterInfluenceRange', best_ra));

fprintf('Αριθμός IF-THEN κανόνων: %d\n', length(fis_init.Rules));

% Εκπαίδευση
fprintf('Εκπαίδευση ANFIS...\n');
opt = anfisOptions(...
    'InitialFIS',         fis_init, ...
    'EpochNumber',        100, ...
    'ValidationData',     val_data, ...
    'OptimizationMethod', 1, ...
    'DisplayANFISInformation', 1, ...
    'DisplayErrorValues',      1, ...
    'DisplayFinalResults',     1);

[fis_trained, train_err, ~, fis_best, val_err] = anfis(train_data, opt);

fprintf('\nΕκπαίδευση ολοκληρώθηκε ✓\n');
fprintf('Best epoch: %d | Min val RMSE: %.4f\n', ...
    find(val_err == min(val_err), 1), min(val_err));

%% =========================================================
%  ΑΞΙΟΛΟΓΗΣΗ ΣΤΟ TEST SET
%% =========================================================
y_pred = evalfis(fis_best, X_test);

e      = y_test - y_pred;
SSres  = sum(e.^2);
SStot  = sum((y_test - mean(y_test)).^2);

RMSE = sqrt(mean(e.^2));
NMSE = SSres / SStot;
NDEI = sqrt(NMSE);
R2   = 1 - SSres / SStot;

fprintf('\n╔══════════════════════════════════╗\n');
fprintf('║   ΑΠΟΤΕΛΕΣΜΑΤΑ ΤΕΛΙΚΟΥ ΜΟΝΤΕΛΟΥ  ║\n');
fprintf('╠══════════╦═══════╦═══════╦═══════╣\n');
fprintf('║   RMSE   ║  NMSE ║  NDEI ║   R²  ║\n');
fprintf('╠══════════╬═══════╬═══════╬═══════╣\n');
fprintf('║  %7.4f ║%6.4f ║%6.4f ║%6.4f ║\n', RMSE, NMSE, NDEI, R2);
fprintf('╚══════════╩═══════╩═══════╩═══════╝\n');

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 1: Learning Curve
%% =========================================================
fig1 = figure('Position', [100 100 900 450]);
epochs = 1:length(train_err);
plot(epochs, train_err, 'b-',  'LineWidth', 1.5, 'DisplayName', 'Train Error');
hold on;
plot(epochs, val_err,   'r--', 'LineWidth', 1.5, 'DisplayName', 'Validation Error');
[mv, me] = min(val_err);
plot(me, mv, 'rv', 'MarkerSize', 12, 'MarkerFaceColor','r', 'DisplayName', 'Best Epoch');
xlabel('Επαναλήψεις (Epochs)'); ylabel('RMSE');
title('Learning Curve — Τελικό Μοντέλο');
legend('Location','best'); grid on;
saveas(fig1, 'final_learning_curve.png');

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 2: Πραγματικές τιμές vs Προβλέψεις
%% =========================================================
fig2 = figure('Position', [100 100 1000 450]);

subplot(1,2,1);
n_show = min(500, length(y_test));  % δείξε max 500 δείγματα
plot(y_test(1:n_show),  'b-',  'LineWidth',1, 'DisplayName','Πραγματική');
hold on;
plot(y_pred(1:n_show), 'r--', 'LineWidth',1, 'DisplayName','Πρόβλεψη');
xlabel('Δείγματα'); ylabel('Critical Temp (normalized)');
title('Πραγματική vs Πρόβλεψη'); legend('Location','best'); grid on;

subplot(1,2,2);
scatter(y_test, y_pred, 10, 'filled', 'MarkerFaceAlpha', 0.3);
hold on;
lims = [min(y_test) max(y_test)];
plot(lims, lims, 'r-', 'LineWidth', 2);   % ιδανική ευθεία y=x
xlabel('Πραγματική Τιμή'); ylabel('Προβλεπόμενη Τιμή');
title(sprintf('Scatter Plot (R²=%.4f)', R2));
grid on;

sgtitle('Τελικό Μοντέλο — Αποτελέσματα Test Set', 'FontSize',13,'FontWeight','bold');
saveas(fig2, 'final_predictions.png');

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 3: Ασαφή Σύνολα (αρχική & τελική μορφή)
%  Δείχνουμε τις MFs για τις 3 πρώτες εισόδους
%% =========================================================
n_show_inputs = min(3, best_num_features);

fig3 = figure('Position', [100 100 1200 400]);
for inp = 1:n_show_inputs
    % Αρχικές MFs
    subplot(2, n_show_inputs, inp);
    x_range = linspace(0, 1, 300);
    hold on;
    colors = lines(length(fis_init.Inputs(inp).MembershipFunctions));
    for k = 1:length(fis_init.Inputs(inp).MembershipFunctions)
        mf = fis_init.Inputs(inp).MembershipFunctions(k);
        plot(x_range, evalmf(x_range, mf.Parameters, mf.Type), ...
            'LineWidth', 2, 'Color', colors(k,:));
    end
    title(sprintf('Input %d — Αρχική', inp)); ylim([0 1.1]); grid on;

    % Τελικές MFs
    subplot(2, n_show_inputs, n_show_inputs + inp);
    hold on;
    for k = 1:length(fis_best.Inputs(inp).MembershipFunctions)
        mf = fis_best.Inputs(inp).MembershipFunctions(k);
        plot(x_range, evalmf(x_range, mf.Parameters, mf.Type), ...
            'LineWidth', 2, 'Color', colors(k,:));
    end
    title(sprintf('Input %d — Τελική', inp)); ylim([0 1.1]); grid on;
end
sgtitle('Συναρτήσεις Συμμετοχής — Αρχική & Τελική Μορφή', ...
    'FontSize',13,'FontWeight','bold');
saveas(fig3, 'final_membership_functions.png');

%% =========================================================
%  ΣΥΓΚΡΙΣΗ: SC vs Grid Partitioning
%% =========================================================
fprintf('\n=== Σύγκριση Αριθμού Κανόνων ===\n');
sc_rules = length(fis_best.Rules);
gp_2mf   = 2^best_num_features;
gp_3mf   = 3^best_num_features;

fprintf('Subtractive Clustering     : %d κανόνες\n', sc_rules);
fprintf('Grid Partitioning (2 MFs)  : 2^%d = %d κανόνες\n', best_num_features, gp_2mf);
fprintf('Grid Partitioning (3 MFs)  : 3^%d = %d κανόνες\n', best_num_features, gp_3mf);

%% --- Αποθήκευση ---
save('final_model.mat', 'fis_best', 'fis_trained', ...
    'train_err', 'val_err', 'RMSE', 'NMSE', 'NDEI', 'R2', ...
    'best_num_features', 'best_ra', 'best_features_idx');

fprintf('\nΤελικό μοντέλο αποθηκεύτηκε στο final_model.mat ✓\n');