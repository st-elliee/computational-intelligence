%% -----------------------------------------------------------
%  Σχεδίαση Ασαφούς Ελεγκτή FZ-PI για το τραπέζι εργασίας
%
%  Είσοδοι:  e(k)  -> κανονικοποιημένο σφάλμα E
%            de(k) -> κανονικοποιημένη μεταβολή σφάλματος dE
%  Έξοδος:   du(k) -> μεταβολή σήματος ελέγχου
%
%  Κλιμακοποίηση:
%       E_n  = Ke    * e(k)         Ke    = 1/w_max = 1/50
%       dE_n = alpha * de(k)        alpha = 1/100   (max|Δe|=100)
%       du   = K1   * dU_n          K1    = Ki (από γραμμικό PI)
%
%  Μεταβλητές ασάφειας:
%       E, dE : 7 MF τριγωνικές (NL, NM, NS, ZR, PS, PM, PL)
%       dU    : 9 MF τριγωνικές (NV, NL, NM, NS, ZR, PS, PM, PL, PV)
%
%  Χαρακτηριστικά FIS:
%       - Mamdani
%       - AND  = min
%       - OR   = max
%       - Implication  = min  (Mamdani)
%       - Aggregation  = max
%       - Defuzzification = centroid (COA)
%% -----------------------------------------------------------

clear; clc; close all;

%% -----------------------------------------------------------
%  1.  ΦΟΡΤΩΣΗ PI ΚΕΡΔΩΝ (από pi_tuned_params.mat)
%% -----------------------------------------------------------

load('pi_tuned_params.mat', 'Kp', 'Ki', 'w_step');

fprintf('\n=== Φόρτωση PI κερδών ===\n');
fprintf('  Kp     = %.4f\n', Kp);
fprintf('  Ki     = %.4f\n', Ki);
fprintf('  w_step = %.1f rad/s\n', w_step);

%% -----------------------------------------------------------
%  2.  ΚΕΡΔΗ ΚΛΙΜΑΚΟΠΟΙΗΣΗΣ
%
%  Ke    : e ∈ [-w_max, w_max] → [-1, 1]
%           Ke = 1/w_max = 1/50 = 0.02
%
%  alpha : Δe = e(k) - e(k-1), max |Δe| = 2*w_max = 100
%           alpha = 1/100 = 0.01  (ώστε Δe_n ∈ [-1,1])
%
%  K1    : κλιμακοποίηση εξόδου FLC
%           K1 = Ki (αντιστοιχεί στον ολοκληρωτικό όρο του PI)
%% -----------------------------------------------------------

Ke    = 1 / w_step;    % = 0.0200
alpha = 1 / 100;       % = 0.0100  ← ΔΙΟΡΘΩΣΗ (ήταν 1/500)
K1    = Ki;            % = Ki από PI σχεδιασμό

fprintf('\n=== Κέρδη κλιμακοποίησης ===\n');
fprintf('  Ke    = %.4f   (e ∈ [-%g,%g] → [-1,1])\n', Ke, w_step, w_step);
fprintf('  alpha = %.4f   (Δe ∈ [-100,100] → [-1,1])\n', alpha);
fprintf('  K1    = %.4f   (= Ki)\n', K1);

%% -----------------------------------------------------------
%  3.  ΔΗΜΙΟΥΡΓΙΑ FIS  (Mamdani)
%% -----------------------------------------------------------

fis = mamfis( ...
    "Name",                  "FZ_PI_Controller", ...
    "AndMethod",             "min",    ...
    "OrMethod",              "max",    ...
    "ImplicationMethod",     "min",    ...
    "AggregationMethod",     "max",    ...
    "DefuzzificationMethod", "centroid");

%% -----------------------------------------------------------
%  4.  ΕΙΣΟΔΟΣ 1 : E  (κανονικοποιημένο σφάλμα)
%      7 τριγωνικές MF στο [-1, 1]
%      Κέντρα: -1, -2/3, -1/3, 0, 1/3, 2/3, 1
%      Πλάτος βάσης: 2/3  (επικαλύψεις 50%)
%% -----------------------------------------------------------

fis = addInput(fis, [-1 1], "Name", "E");

names7   = ["NL","NM","NS","ZR","PS","PM","PL"];
centers7 = [-1, -2/3, -1/3, 0, 1/3, 2/3, 1];

for i = 1:7
    if i == 1                          % αριστερή άκρη (flat left)
        params = [-1, -1, -2/3];
    elseif i == 7                      % δεξιά άκρη (flat right)
        params = [2/3, 1, 1];
    else
        params = [centers7(i)-1/3, centers7(i), centers7(i)+1/3];
    end
    fis = addMF(fis, "E", "trimf", params, "Name", names7(i));
end

%% -----------------------------------------------------------
%  5.  ΕΙΣΟΔΟΣ 2 : dE  (κανονικοποιημένη μεταβολή σφάλματος)
%      Ίδια δομή με E
%% -----------------------------------------------------------

fis = addInput(fis, [-1 1], "Name", "dE");

for i = 1:7
    if i == 1
        params = [-1, -1, -2/3];
    elseif i == 7
        params = [2/3, 1, 1];
    else
        params = [centers7(i)-1/3, centers7(i), centers7(i)+1/3];
    end
    fis = addMF(fis, "dE", "trimf", params, "Name", names7(i));
end

%% -----------------------------------------------------------
%  6.  ΕΞΟΔΟΣ : dU  (κανονικοποιημένη μεταβολή ελέγχου)
%      9 τριγωνικές MF στο [-1, 1]
%      Κέντρα: linspace(-1,1,9) → βήμα 0.25
%      Πλάτος βάσης: 0.5  (επικαλύψεις 50%)
%% -----------------------------------------------------------

fis = addOutput(fis, [-1 1], "Name", "dU");

names9   = ["NV","NL","NM","NS","ZR","PS","PM","PL","PV"];
centers9 = linspace(-1, 1, 9);   % [-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1]

for i = 1:9
    if i == 1
        params = [-1, -1, -0.75];
    elseif i == 9
        params = [0.75, 1, 1];
    else
        params = [centers9(i)-0.25, centers9(i), centers9(i)+0.25];
    end
    fis = addMF(fis, "dU", "trimf", params, "Name", names9(i));
end

%% -----------------------------------------------------------
%  7.  ΒΑΣΗ ΚΑΝΟΝΩΝ  (49 κανόνες, πλήρως αντισυμμετρική)
%
%  Μορφή κάθε γραμμής: [E_idx  dE_idx  dU_idx  weight  AND/OR]
%     E_idx  : 1=NL ... 7=PL
%     dE_idx : 1=NL ... 7=PL
%     dU_idx : 1=NV ... 9=PV
%     weight : 1 (ισοβαρείς)
%     conn   : 1 = AND (min)
%
%  Ιδιότητες:
%     - ZR, ZR → ZR  (μηδενικό σφάλμα = μηδενική μεταβολή ελέγχου)
%     - Αντισυμμετρία: rule(E_i,dE_j) + rule(E_{8-i},dE_{8-j}) = 10
%     - Μονοτονία: αύξηση E ή dE → αύξηση dU
%
%  Πίνακας (γραμμή=E, στήλη=dE):
%
%          NL   NM   NS   ZR   PS   PM   PL
%    NL  [ NV   NV   NM   NL   NM   NS   ZR ]
%    NM  [ NV   NL   NL   NM   NS   ZR   PS ]
%    NS  [ NM   NL   NM   NS   ZR   PS   PM ]
%    ZR  [ NL   NM   NS   ZR   PS   PM   PL ]
%    PS  [ NM   NS   ZR   PS   PM   PL   PM ]
%    PM  [ NS   ZR   PS   PM   PL   PL   PV ]
%    PL  [ ZR   PS   PM   PL   PM   PV   PV ]
%% -----------------------------------------------------------

ruleMatrix = [
 1 1 1;  1 2 1;  1 3 3;  1 4 2;  1 5 3;  1 6 4;  1 7 5;
 2 1 1;  2 2 2;  2 3 2;  2 4 3;  2 5 4;  2 6 5;  2 7 6;
 3 1 3;  3 2 2;  3 3 3;  3 4 4;  3 5 5;  3 6 6;  3 7 7;
 4 1 2;  4 2 3;  4 3 4;  4 4 5;  4 5 6;  4 6 7;  4 7 8;
 5 1 3;  5 2 4;  5 3 5;  5 4 6;  5 5 7;  5 6 8;  5 7 7;
 6 1 4;  6 2 5;  6 3 6;  6 4 7;  6 5 8;  6 6 8;  6 7 9;
 7 1 5;  7 2 6;  7 3 7;  7 4 8;  7 5 7;  7 6 9;  7 7 9
];

% Προσθήκη weight=1 και AND connector=1
rules = [ruleMatrix, ones(49,1), ones(49,1)];

fis = addRule(fis, rules);

fprintf('\n=== Βάση κανόνων ===\n');
fprintf('  Συνολικοί κανόνες: %d\n', numel(fis.Rules));

%% -----------------------------------------------------------
%  8.  ΑΠΕΙΚΟΝΙΣΗ ΣΥΝΑΡΤΗΣΕΩΝ ΜΕΛΟΥΣ
%% -----------------------------------------------------------

figure('Name','MF Εισόδου E', 'Color','w');
plotmf(fis, 'input', 1);
title('Συναρτήσεις μέλους εισόδου E (σφάλμα)');
xlabel('Κανονικοποιημένο σφάλμα E_n');

figure('Name','MF Εισόδου dE', 'Color','w');
plotmf(fis, 'input', 2);
title('Συναρτήσεις μέλους εισόδου dE (μεταβολή σφάλματος)');
xlabel('Κανονικοποιημένη μεταβολή dE_n');

figure('Name','MF Εξόδου dU', 'Color','w');
plotmf(fis, 'output', 1);
title('Συναρτήσεις μέλους εξόδου dU (μεταβολή ελέγχου)');
xlabel('Κανονικοποιημένη μεταβολή dU_n');

%% -----------------------------------------------------------
%  9.  ΑΠΟΘΗΚΕΥΣΗ FIS και ΠΑΡΑΜΕΤΡΩΝ
%% -----------------------------------------------------------

writeFIS(fis, 'FZ_PI_Controller');

FLC.fis    = fis;
FLC.Ke     = Ke;
FLC.alpha  = alpha;
FLC.K1     = K1;
FLC.Kp     = Kp;
FLC.Ki     = Ki;
FLC.w_step = w_step;

save('flc_corrected_params.mat', 'FLC');

fprintf('\n=== Αποθήκευση ===\n');
fprintf('  FIS αποθηκεύτηκε → FZ_PI_Controller.fis\n');
fprintf('  Παράμετροι       → flc_corrected_params.mat\n');
fprintf('\n=== Σύνοψη παραμέτρων FLC ===\n');
fprintf('  Ke    = %.4f\n', Ke);
fprintf('  alpha = %.4f\n', alpha);
fprintf('  K1    = %.4f\n', K1);
fprintf('  MF E/dE: 7 τριγωνικές στο [-1,1]\n');
fprintf('  MF dU:   9 τριγωνικές στο [-1,1]\n');
fprintf('  Κανόνες: 49 (7x7), πλήρως αντισυμμετρικοί\n');