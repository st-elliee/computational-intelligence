%% =========================================================
%  ΜΕΡΟΣ 1 - Βήμα 4: Διαγράμματα
%  1. Ασαφή σύνολα (membership functions)
%  2. Learning curves
%  3. Διαγράμματα σφαλμάτων πρόβλεψης
%% =========================================================

clear; clc; close all;

%% --- Φόρτωση ---
load('tsk_models.mat');

X_test = D_test(:, 1:5);
y_test = D_test(:, 6);

input_names = {'Frequency', 'Angle of Attack', 'Chord Length', ...
               'Free Stream Velocity', 'Displacement Thickness'};

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 1: Ασαφή Σύνολα (τελική μορφή)
%% =========================================================
for m = 1:4
    fis = best_fis{m};
    num_inputs = length(fis.Inputs);
    
    fig = figure('Name', sprintf('MFs - Model %d', m), ...
                 'Position', [100 100 1400 600]);
    
    for i = 1:num_inputs
        subplot(1, num_inputs, i);
        
        % Εύρος εισόδου
        x_range = linspace(fis.Inputs(i).Range(1), fis.Inputs(i).Range(2), 300);
        
        hold on;
        colors = lines(length(fis.Inputs(i).MembershipFunctions));
        
        for j = 1:length(fis.Inputs(i).MembershipFunctions)
            mf = fis.Inputs(i).MembershipFunctions(j);
            y_mf = evalmf(x_range, mf.Parameters, mf.Type);
            plot(x_range, y_mf, 'LineWidth', 2, 'Color', colors(j,:));
        end
        
        xlabel(input_names{i}, 'FontSize', 9);
        ylabel('Βαθμός Συμμετοχής');
        title(sprintf('x_%d', i));
        ylim([0 1.1]);
        grid on;
        hold off;
    end
    
    sgtitle(sprintf('%s — Τελικές Συναρτήσεις Συμμετοχής', ...
            strrep(model_names{m}, '\', '')), 'FontSize', 13, 'FontWeight', 'bold');
    
    saveas(fig, sprintf('mf_plot_model%d.png', m));
end

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 2: Learning Curves
%% =========================================================
fig2 = figure('Name', 'Learning Curves', 'Position', [100 100 1200 800]);

for m = 1:4
    subplot(2, 2, m);
    
    epochs = 1:length(train_errors{m});
    plot(epochs, train_errors{m}, 'b-', 'LineWidth', 1.5); hold on;
    plot(epochs, val_errors{m},   'r--','LineWidth', 1.5);
    
    % Σημείο ελάχιστου validation error
    [min_val, min_ep] = min(val_errors{m});
    plot(min_ep, min_val, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    
    xlabel('Επαναλήψεις (Epochs)');
    ylabel('RMSE');
    title(strrep(model_names{m}, '\', ''));
    legend('Train Error', 'Validation Error', 'Best Epoch', 'Location', 'best');
    grid on;
    hold off;
end

sgtitle('Learning Curves — Σφάλμα συναρτήσει Επαναλήψεων', ...
        'FontSize', 13, 'FontWeight', 'bold');
saveas(fig2, 'learning_curves.png');

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 3: Σφάλματα Πρόβλεψης (Prediction Error Plots)
%% =========================================================
fig3 = figure('Name', 'Prediction Errors', 'Position', [100 100 1200 800]);

for m = 1:4
    y_pred = evalfis(best_fis{m}, X_test);
    errors = y_test - y_pred;
    
    subplot(2, 2, m);
    
    % Real vs Predicted
    plot(y_test,  'b-',  'LineWidth', 1,   'DisplayName', 'Πραγματική Έξοδος'); hold on;
    plot(y_pred,  'r--', 'LineWidth', 1,   'DisplayName', 'Πρόβλεψη Μοντέλου');
    
    xlabel('Δείγματα');
    ylabel('Scaled SPL (dB)');
    title(strrep(model_names{m}, '\', ''));
    legend('Location', 'best');
    grid on;
    hold off;
end

sgtitle('Σύγκριση Πραγματικής Εξόδου και Πρόβλεψης (Test Set)', ...
        'FontSize', 13, 'FontWeight', 'bold');
saveas(fig3, 'predictions.png');

%% =========================================================
%  ΔΙΑΓΡΑΜΜΑ 3β: Histogram σφαλμάτων
%% =========================================================
fig4 = figure('Name', 'Error Histograms', 'Position', [100 100 1200 800]);

for m = 1:4
    y_pred = evalfis(best_fis{m}, X_test);
    errors = y_test - y_pred;
    
    subplot(2, 2, m);
    histogram(errors, 30, 'FaceColor', [0.2 0.5 0.8], 'EdgeColor', 'white');
    xlabel('Σφάλμα Πρόβλεψης');
    ylabel('Συχνότητα');
    title(strrep(model_names{m}, '\', ''));
    grid on;
end

sgtitle('Κατανομή Σφαλμάτων Πρόβλεψης (Test Set)', ...
        'FontSize', 13, 'FontWeight', 'bold');
saveas(fig4, 'error_histograms.png');

%% =========================================================
%  ΠΙΝΑΚΑΣ ΑΠΟΤΕΛΕΣΜΑΤΩΝ
%% =========================================================
load('tsk_results.mat');

fprintf('\n╔══════════════════╦══════════╦══════════╦══════════╦══════════╗\n');
fprintf('║ %-16s ║ %8s ║ %8s ║ %8s ║ %8s ║\n', 'Model', 'RMSE', 'NMSE', 'NDEI', 'R²');
fprintf('╠══════════════════╬══════════╬══════════╬══════════╬══════════╣\n');
for m = 1:4
    fprintf('║ %-16s ║ %8.4f ║ %8.4f ║ %8.4f ║ %8.4f ║\n', ...
        strrep(model_names{m}, '\', ''), results(m,1), results(m,2), results(m,3), results(m,4));
end
fprintf('╚══════════════════╩══════════╩══════════╩══════════╩══════════╝\n');

fprintf('\nΌλα τα διαγράμματα αποθηκεύτηκαν ως .png\n');