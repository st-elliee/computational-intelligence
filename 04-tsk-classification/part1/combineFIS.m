function combinedFIS = combineFIS(fisArray, X_train, Y_train)
%COMBINEFIS  Συνδυάζει FIS που δημιουργήθηκαν ανά κλάση σε ένα ενιαίο FIS.
%
%  Κτίζουμε το combined FIS από μηδέν (sugfis) προσθέτοντας
%  μία-μία τις MFs με μοναδικά ονόματα, αποφεύγοντας name conflicts.

classes  = unique(Y_train);
nInputs  = size(X_train, 2);

%% --- Δημιουργία κενού Sugeno FIS ---
combinedFIS = sugfis('Name', 'combined_TSK');

% Προσθήκη inputs με range από τα training data
for inp = 1:nInputs
    combinedFIS = addInput(combinedFIS, ...
        [min(X_train(:,inp)), max(X_train(:,inp))], ...
        'Name', sprintf('in%d', inp));
end

% Προσθήκη output
combinedFIS = addOutput(combinedFIS, ...
    [min(Y_train)-0.5, max(Y_train)+0.5], ...
    'Name', 'out1');

%% --- Προσθήκη MFs και κανόνων από κάθε κλάση ---
mfCountPerInput = zeros(1, nInputs);  % πλήθος MFs ανά input (running total)
outMFcount      = 0;                  % πλήθος output MFs (running total)
allRuleAnt      = [];                 % antecedents όλων των κανόνων
allRuleCon      = [];                 % consequents

for c = 1:length(classes)
    fis_c   = fisArray{c};
    nRules_c = numel(fis_c.Rules);

    % --- Input MFs ---
    for inp = 1:nInputs
        mfs_c = fis_c.Inputs(inp).MembershipFunctions;
        for mfIdx = 1:numel(mfs_c)
            newName = sprintf('in%d_c%d_mf%d', inp, c, mfIdx);
            combinedFIS = addMF(combinedFIS, sprintf('in%d',inp), ...
                mfs_c(mfIdx).Type, mfs_c(mfIdx).Parameters, ...
                'Name', newName);
        end
    end

    % --- Output MFs (constant = singleton) ---
    % Consequent value = η κλάση που αντιστοιχεί
    for rIdx = 1:nRules_c
        newOutName = sprintf('out_c%d_r%d', c, rIdx);
        combinedFIS = addMF(combinedFIS, 'out1', 'constant', ...
            classes(c), 'Name', newOutName);
        outMFcount = outMFcount + 1;
    end

    % --- Κανόνες ---
    % Χτίζουμε antecedent matrix με offset από προηγούμενες κλάσεις
    for rIdx = 1:nRules_c
        ant = fis_c.Rules(rIdx).Antecedent;   % [mf_idx_in1, mf_idx_in2, ...]
        % Offset: προσθέτουμε πλήθος MFs που έχουν ήδη μπει
        ant_shifted = ant + mfCountPerInput;
        % Μηδενικά antecedents (don't care) παραμένουν 0
        ant_shifted(ant == 0) = 0;

        allRuleAnt = [allRuleAnt; ant_shifted];          %#ok<AGROW>
        allRuleCon = [allRuleCon; outMFcount - nRules_c + rIdx]; %#ok<AGROW>
    end

    % Ενημέρωση offset counters
    for inp = 1:nInputs
        mfCountPerInput(inp) = mfCountPerInput(inp) + ...
            numel(fis_c.Inputs(inp).MembershipFunctions);
    end
end

%% --- Προσθήκη κανόνων στο combined FIS ---
% Format: [ant(1..nInputs), con(1..nOutputs), weight, connection(1=AND,2=OR)]
nTotalRules = size(allRuleAnt, 1);
ruleList    = [allRuleAnt, allRuleCon, ones(nTotalRules,1), ones(nTotalRules,1)];

combinedFIS = addRule(combinedFIS, ruleList);

fprintf('  Combined FIS: %d inputs, %d rules\n', ...
    nInputs, numel(combinedFIS.Rules));

end