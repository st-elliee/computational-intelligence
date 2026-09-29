function computeMetrics(Y_true, Y_pred, modelIdx, modelName)
%COMPUTEMETRICS  Υπολογίζει και εκτυπώνει μετρικές ταξινόμησης.
%
%  Υπολογίζει:
%   - Error Matrix (Confusion Matrix)
%   - Overall Accuracy (OA)
%   - Producer's Accuracy (PA) ανά κλάση
%   - User's Accuracy (UA) ανά κλάση
%   - Kappa statistic (κ̂)
%
%  Σύμβολα από εκφώνηση:
%   xii  = σωστά ταξινομημένα δείγματα κλάσης i
%   xir  = σύνολο προβλεπόμενων ως Ci (row sum)
%   xjc  = σύνολο πραγματικών Cj (column sum)

classes = unique([Y_true; Y_pred]);
k = length(classes);
N = length(Y_true);

%% --- Error Matrix ---
errMat = zeros(k, k);
for i = 1:k
    for j = 1:k
        errMat(i,j) = sum(Y_pred == classes(i) & Y_true == classes(j));
    end
end

fprintf('Error Matrix (Predicted \\ Actual):\n');
fprintf('         ');
for j = 1:k
    fprintf('  C%d ', classes(j));
end
fprintf('\n');
for i = 1:k
    fprintf('Pred C%d: ', classes(i));
    for j = 1:k
        fprintf('%4d  ', errMat(i,j));
    end
    fprintf('\n');
end

%% --- Overall Accuracy ---
OA = sum(diag(errMat)) / N;
fprintf('\nOverall Accuracy (OA): %.4f (%.2f%%)\n', OA, OA*100);

%% --- Producer's & User's Accuracy ---
xir = sum(errMat, 2);   % row sums    (predicted per class)
xjc = sum(errMat, 1);   % column sums (actual per class)

fprintf('\nPer-class Metrics:\n');
fprintf('%-8s | PA (Producer) | UA (User)\n', 'Κλάση');
fprintf('---------|---------------|----------\n');
for i = 1:k
    PA = errMat(i,i) / xjc(i);   % TP / actual positives
    UA = errMat(i,i) / xir(i);   % TP / predicted positives
    if isnan(PA), PA = 0; end
    if isnan(UA), UA = 0; end
    fprintf('C%d       |    %.4f     |   %.4f\n', classes(i), PA, UA);
end

%% --- Kappa Statistic ---
% κ̂ = (N*Σxii - Σ(xic*xir)) / (N^2 - Σ(xic*xir))
sum_diag  = sum(diag(errMat));
sum_rowcol = sum(xir .* xjc');
kappa = (N * sum_diag - sum_rowcol) / (N^2 - sum_rowcol);

fprintf('\nKappa (κ̂): %.4f\n', kappa);

%% --- Αποθήκευση σχήματος Error Matrix ---
figure('Name', sprintf('Model %d - %s', modelIdx, modelName), ...
       'NumberTitle', 'off');
confusionchart(Y_true, Y_pred, ...
    'Title', sprintf('Confusion Matrix - %s', modelName), ...
    'RowSummary', 'row-normalized', ...
    'ColumnSummary', 'column-normalized');
saveas(gcf, sprintf('confusion_model%d.png', modelIdx));

end