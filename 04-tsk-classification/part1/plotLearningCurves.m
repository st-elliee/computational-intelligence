function plotLearningCurves(trnErrors, valErrors, modelNames)
%PLOTLEARNINGCURVES  Σχεδιάζει τις καμπύλες μάθησης για όλα τα μοντέλα.
%
%  Εμφανίζει train error και validation error συναρτήσει των epochs.

nModels = length(trnErrors);
colors  = {'b', 'r', 'g', 'm'};

figure('Name', 'Learning Curves - All Models', ...
       'NumberTitle', 'off', ...
       'Position', [100, 100, 1200, 800]);

for i = 1:nModels
    subplot(2, 2, i);
    hold on;

    epochs = 1:length(trnErrors{i});

    plot(epochs, trnErrors{i}, [colors{i}, '-'], ...
         'LineWidth', 1.5, 'DisplayName', 'Training Error');
    plot(1:length(valErrors{i}), valErrors{i}, [colors{i}, '--'], ...
         'LineWidth', 1.5, 'DisplayName', 'Validation Error');

    xlabel('Epochs');
    ylabel('RMSE');
    title(sprintf('Learning Curve - Model %d: %s', i, modelNames{i}));
    legend('Location', 'best');
    grid on;
    hold off;
end

sgtitle('Learning Curves - TSK Models (Μέρος 1)', 'FontSize', 14);
saveas(gcf, 'learning_curves.png');
fprintf('\nΑποθηκεύτηκε: learning_curves.png\n');

end