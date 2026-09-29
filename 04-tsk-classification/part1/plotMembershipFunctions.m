function plotMembershipFunctions(models, modelNames)
%PLOTMEMBERSHIPFUNCTIONS  Σχεδιάζει τα ασαφή σύνολα (MFs) για κάθε μοντέλο.
%
%  Εμφανίζει τις membership functions για κάθε input variable
%  μετά την εκπαίδευση.
%
%  Input names για το Haberman dataset:
%    x1 = Age of patient
%    x2 = Year of operation
%    x3 = Number of positive axillary nodes

inputNames = {'Age', 'Year of Operation', 'Positive Axillary Nodes'};
nInputs    = 3;

for modelIdx = 1:length(models)
    fis = models{modelIdx};

    figure('Name', sprintf('MFs - Model %d: %s', modelIdx, modelNames{modelIdx}), ...
           'NumberTitle', 'off', ...
           'Position', [100, 100, 1200, 400]);

    for inp = 1:nInputs
        subplot(1, nInputs, inp);
        hold on;

        mfs = fis.Inputs(inp).MembershipFunctions;
        range = fis.Inputs(inp).Range;
        x_vals = linspace(range(1), range(2), 300);

        colors = lines(length(mfs));
        for mfIdx = 1:length(mfs)
            mf = mfs(mfIdx);
            y_vals = evalmf(x_vals, mf.Parameters, mf.Type);
            plot(x_vals, y_vals, 'Color', colors(mfIdx,:), ...
                 'LineWidth', 1.5, 'DisplayName', mf.Name);
        end

        xlabel(inputNames{inp});
        ylabel('Membership Degree');
        title(sprintf('Input %d: %s', inp, inputNames{inp}));
        ylim([0, 1.1]);
        grid on;
        legend('Location', 'best', 'FontSize', 7);
        hold off;
    end

    sgtitle(sprintf('Membership Functions - Model %d: %s', ...
            modelIdx, modelNames{modelIdx}), 'FontSize', 12);
    saveas(gcf, sprintf('mfs_model%d.png', modelIdx));
end

fprintf('Αποθηκεύτηκαν διαγράμματα MFs για %d μοντέλα.\n', length(models));

end