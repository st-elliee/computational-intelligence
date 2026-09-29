%% =========================================================
%  ΜΕΡΟΣ 2 - Βήμα 2: Feature Selection (ReliefF) +
%             Grid Search με 5-fold Cross Validation
%  Παράμετροι: num_features × cluster_radius (rα)
%% =========================================================

clear; clc; close all;

%% --- Φόρτωση ---
load('supercon_split.mat');

%% =========================================================
%  ΒΗΜΑ Α: Feature Selection με ReliefF
%  Εκτελείται μία φορά στο training set
%% =========================================================
fprintf('=== Feature Selection με ReliefF ===\n');

X_train_full = D_train(:, 1:81);
y_train_full = D_train(:, 82);

% ReliefF: επιστρέφει τα features ταξινομημένα κατά βαρύτητα
[feat_idx_sorted, feat_weights] = relieff(X_train_full, y_train_full, 10);

fprintf('Feature ranking ολοκληρώθηκε ✓\n');
fprintf('Top 10 features (indices): ');
fprintf('%d ', feat_idx_sorted(1:10));
fprintf('\n\n');

%% =========================================================
%  ΒΗΜΑ Β: Grid Search + 5-fold Cross Validation
%  Παράμετροι:
%    - num_features: πλήθος κορυφαίων features
%    - ra: ακτίνα cluster για Subtractive Clustering
%% =========================================================

% --- Πλέγμα παραμέτρων ---
num_features_grid = [4, 6, 8, 10, 12];   % αριθμός features
ra_grid           = [0.3, 0.5, 0.7, 0.9]; % ακτίνα cluster

n_folds = 5;

% Αποθήκευση αποτελεσμάτων
n_nf = length(num_features_grid);
n_ra = length(ra_grid);
cv_rmse_mean = zeros(n_nf, n_ra);  % μέσο RMSE ανά συνδυασμό
num_rules    = zeros(n_nf, n_ra);  % αριθμός κανόνων

fprintf('=== Grid Search: %d x %d = %d συνδυασμοί ===\n', ...
    n_nf, n_ra, n_nf * n_ra);
fprintf('5-fold CV ανά συνδυασμό\n\n');

% Δημιουργία fold indices για το training set
N_train = size(D_train, 1);
fold_size = floor(N_train / n_folds);
fold_idx = crossvalind('Kfold', N_train, n_folds);

total_combos = n_nf * n_ra;
combo = 0;

for i = 1:n_nf
    nf = num_features_grid(i);
    % Επιλογή top-nf features (από ReliefF ranking)
    sel_features = feat_idx_sorted(1:nf);

    for j = 1:n_ra
        ra = ra_grid(j);
        combo = combo + 1;

        fprintf('[%2d/%2d] Features=%2d | ra=%.1f ... ', ...
            combo, total_combos, nf, ra);

        fold_rmse = zeros(n_folds, 1);
        fold_rules = zeros(n_folds, 1);

        for f = 1:n_folds
            % Split training set σε train/val για CV
            val_mask   = (fold_idx == f);
            train_mask = ~val_mask;

            X_cv_train = D_train(train_mask, sel_features);
            y_cv_train = D_train(train_mask, 82);
            X_cv_val   = D_train(val_mask,   sel_features);
            y_cv_val   = D_train(val_mask,   82);

            cv_train_data = [X_cv_train, y_cv_train];
            cv_val_data   = [X_cv_val,   y_cv_val];

            % Δημιουργία FIS με Subtractive Clustering
            try
                fis_sc = genfis(X_cv_train, y_cv_train, ...
                    genfisOptions('SubtractiveClustering', ...
                    'ClusterInfluenceRange', ra));

                % Εκπαίδευση με ANFIS
                opt = anfisOptions(...
                    'InitialFIS',        fis_sc, ...
                    'EpochNumber',       50, ...
                    'ValidationData',    cv_val_data, ...
                    'OptimizationMethod', 1, ...
                    'DisplayANFISInformation', 0, ...
                    'DisplayErrorValues',      0, ...
                    'DisplayStepSize',         0, ...
                    'DisplayFinalResults',     0);

                [~, ~, ~, fis_best_cv, ~] = anfis(cv_train_data, opt);

                % Αξιολόγηση στο validation fold
                y_pred_cv = evalfis(fis_best_cv, X_cv_val);
                fold_rmse(f)  = sqrt(mean((y_cv_val - y_pred_cv).^2));
                fold_rules(f) = length(fis_sc.Rules);

            catch ME
                % Αν αποτύχει (π.χ. πολύ μικρό ra → πάρα πολλοί κανόνες)
                fold_rmse(f)  = NaN;
                fold_rules(f) = NaN;
                fprintf('[Fold %d σφάλμα: %s] ', f, ME.message(1:min(30,end)));
            end
        end

        cv_rmse_mean(i,j) = mean(fold_rmse, 'omitnan');
        num_rules(i,j)    = round(mean(fold_rules, 'omitnan'));

        fprintf('Mean RMSE=%.4f | Rules≈%d\n', cv_rmse_mean(i,j), num_rules(i,j));
    end
end

%% =========================================================
%  ΒΗΜΑ Γ: Εύρεση βέλτιστων παραμέτρων
%% =========================================================
[min_val, min_idx] = min(cv_rmse_mean(:));
[best_i, best_j]   = ind2sub(size(cv_rmse_mean), min_idx);

best_num_features = num_features_grid(best_i);
best_ra           = ra_grid(best_j);
best_features_idx = feat_idx_sorted(1:best_num_features);

fprintf('\n========================================\n');
fprintf(' ΒΕΛΤΙΣΤΕΣ ΠΑΡΑΜΕΤΡΟΙ\n');
fprintf('   Αριθμός features : %d\n', best_num_features);
fprintf('   Cluster radius rα: %.1f\n', best_ra);
fprintf('   Min CV RMSE      : %.4f\n', min_val);
fprintf('   Approx. # Rules  : %d\n', num_rules(best_i, best_j));
fprintf('========================================\n');

%% =========================================================
%  ΒΗΜΑ Δ: Διαγράμματα Grid Search
%% =========================================================

% 1. RMSE vs αριθμός features (για κάθε ra)
fig1 = figure('Position', [100 100 900 500]);
hold on;
colors = lines(n_ra);
for j = 1:n_ra
    plot(num_features_grid, cv_rmse_mean(:,j), '-o', ...
        'LineWidth', 2, 'Color', colors(j,:), ...
        'DisplayName', sprintf('r_a=%.1f', ra_grid(j)));
end
xlabel('Αριθμός Features');
ylabel('Mean CV RMSE');
title('Grid Search: RMSE vs Αριθμός Features');
legend('Location', 'best');
grid on;
saveas(fig1, 'gridsearch_rmse_vs_features.png');

% 2. RMSE vs αριθμός κανόνων
fig2 = figure('Position', [100 100 900 500]);
hold on;
for j = 1:n_ra
    plot(num_rules(:,j), cv_rmse_mean(:,j), '-s', ...
        'LineWidth', 2, 'Color', colors(j,:), ...
        'DisplayName', sprintf('r_a=%.1f', ra_grid(j)));
end
xlabel('Αριθμός IF-THEN Κανόνων');
ylabel('Mean CV RMSE');
title('Grid Search: RMSE vs Αριθμός Κανόνων');
legend('Location', 'best');
grid on;
saveas(fig2, 'gridsearch_rmse_vs_rules.png');

% 3. Heatmap RMSE
fig3 = figure('Position', [100 100 700 500]);
heatmap(string(ra_grid), string(num_features_grid), cv_rmse_mean, ...
    'Title', 'CV RMSE — Grid Search', ...
    'XLabel', 'Cluster Radius r_a', ...
    'YLabel', 'Αριθμός Features', ...
    'Colormap', parula);
saveas(fig3, 'gridsearch_heatmap.png');

%% --- Αποθήκευση ---
save('gridsearch_results.mat', ...
    'cv_rmse_mean', 'num_rules', ...
    'num_features_grid', 'ra_grid', ...
    'best_num_features', 'best_ra', 'best_features_idx', ...
    'feat_idx_sorted', 'feat_weights');

fprintf('\nΑποτελέσματα Grid Search αποθηκεύτηκαν ✓\n');