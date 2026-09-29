%% -----------------------------------------------------------
%  Σενάριο 2 – Απόκριση FLC σε δύο διαφορετικά σήματα αναφοράς
%
%  Σχ.3: Βηματικό προφίλ  20 → 50 → 40 rad/s
%  Σχ.4: Ράμπα            0.4 → 50 → 0.4 rad/s
%
%  Απαιτούμενα αρχεία:
%    - flc_corrected_params.mat   (από design_FLC_FZPI.m)
%    - scenario1_results.mat      (για τα κέρδη Ke, alpha, K1)
%% -----------------------------------------------------------

clear; clc; close all;

%% -----------------------------------------------------------
%  1.  ΦΟΡΤΩΣΗ ΠΑΡΑΜΕΤΡΩΝ
%% -----------------------------------------------------------

load('flc_corrected_params.mat', 'FLC');
load('scenario1_results.mat',    'Ke', 'alpha', 'K1');

fis = FLC.fis;

T = 0.01;    % δειγματοληψία (sec)

% State-space φυτού (ΔΙΟΡΘΩΣΗ: ορίζονται εδώ, όχι από Σενάριο 1)
Ac = [0,    1;
     -1, -10.1];
Bc = [0; 25];
Cc = [1, 0];

fprintf('=== Παράμετροι Σεναρίου 2 ===\n');
fprintf('  Ke    = %.4f\n', Ke);
fprintf('  alpha = %.4f\n', alpha);
fprintf('  K1    = %.4f\n', K1);
fprintf('  T     = %.3f s\n', T);

%% -----------------------------------------------------------
%  2.  ΣΕΝΑΡΙΟ 2.1 – ΒΗΜΑΤΙΚΟ ΠΡΟΦΙΛ (Σχ.3)
%
%  Εκφώνηση Σχ.3:
%    t = 0  – 5  s : r = 20 rad/s
%    t = 5  – 10 s : r = 50 rad/s  (βηματική άνοδος)
%    t = 10 – 20 s : r = 40 rad/s  (βηματική μείωση)
%% -----------------------------------------------------------

Tsim = 20;
t    = 0 : T : Tsim;
N    = length(t);

% Σήμα αναφοράς Σχ.3
r1 = zeros(1, N);
for k = 1:N
    if t(k) < 5
        r1(k) = 20;       % ΔΙΟΡΘΩΣΗ: ξεκινά από 20 (όχι 50)
    elseif t(k) < 10
        r1(k) = 50;
    else
        r1(k) = 40;
    end
end

% Προσομοίωση FZ-PI
x      = zeros(2,1);
u_k    = 0;
y1     = zeros(1, N);
e_prev = 0;              % ΔΙΟΡΘΩΣΗ: ρητή αρχικοποίηση

for k = 1:N

    % Σφάλμα
    e_k  = r1(k) - x(1);

    % Μεταβολή σφάλματος (απλή διαφορά — συνεπής με Σχ.2 εκφώνησης)
    if k == 1
        de_k = 0;
    else
        de_k = (e_k - e_prev) / T;   % ΔΙΟΡΘΩΣΗ: /T για συνέπεια με Σεν.1
    end

    % Κανονικοποίηση
    e_n  = max(-1, min(1,  Ke    * e_k  ));
    de_n = max(-1, min(1,  alpha * de_k ));

    % FLC
    du_n = evalfis(fis, [e_n, de_n]);
    u_k  = u_k + K1 * du_n;

    % Anti-windup (ΔΙΟΡΘΩΣΗ: [-50,50] συνεπές με Σεν.1)
    u_k = max(-50, min(50, u_k));

    % Φυτό (Euler forward)
    xdot = Ac * x + Bc * u_k;
    x    = x + T * xdot;
    y1(k) = x(1);

    e_prev = e_k;
end

% Μετρικά για κάθε βηματική μεταβολή
fprintf('\n=== Σενάριο 2.1 – Βηματικό προφίλ ===\n');

% Βήμα 1: t=0→5, r=20
idx1 = 1 : round(5/T)+1;
info1 = stepinfo(y1(idx1), t(idx1), 20, 'SettlingTimeThreshold', 0.02);
fprintf('  Βήμα r=20: OS=%.2f%%  tr=%.3fs\n', info1.Overshoot, info1.RiseTime);

% Βήμα 2: t=5→10, r=50
idx2 = round(5/T)+1 : round(10/T)+1;
y2_seg = y1(idx2);  t2_seg = t(idx2) - t(idx2(1));
info2 = stepinfo(y2_seg, t2_seg, 50, 'SettlingTimeThreshold', 0.02);
fprintf('  Βήμα r=50: OS=%.2f%%  tr=%.3fs\n', info2.Overshoot, info2.RiseTime);

% Βήμα 3: t=10→20, r=40
% ΣΗΜΕΙΩΣΗ: Το σύστημα κατεβαίνει από 50→40 (αρνητικό βήμα).
% Το stepinfo δίνει ψεύτικη OS/tr γιατί y_start > r_final.
% Χρησιμοποιούμε χειροκίνητη μέτρηση settling time.
idx3    = round(10/T)+1 : N;
y3_seg  = y1(idx3);
t3_seg  = t(idx3) - t(idx3(1));
r_final = 40;
tol     = 0.02 * r_final;   % ±2% του στόχου

% Settling time: πρώτη στιγμή που y μπαίνει και μένει εντός ±2%
in_band = abs(y3_seg - r_final) <= tol;
settled = find(~in_band, 1, 'last');   % τελευταία έξοδος από band
if isempty(settled)
    t_settle3 = 0;
else
    t_settle3 = t3_seg(min(settled+1, length(t3_seg)));
end
ss_err3 = abs(r_final - y3_seg(end));
fprintf('  Βήμα r=40 (κατάβαση 50→40): Ts=%.3fs  SS_err=%.4f rad/s\n', ...
    t_settle3, ss_err3);

% Γραφική απεικόνιση
figure('Name','Σενάριο 2.1 – Βηματικό Προφίλ','Color','w');

subplot(2,1,1);
plot(t, r1, 'k--', 'LineWidth', 1.5); hold on;
plot(t, y1, 'r-',  'LineWidth', 2.0);
grid on;
xlabel('Χρόνος (s)');
ylabel('Ταχύτητα (rad/s)');
title('Σενάριο 2.1 – Βηματικό σήμα αναφοράς (20→50→40 rad/s)');
legend('Αναφορά r(t)', 'Απόκριση FZ-PI', 'Location','east');
xlim([0 Tsim]); ylim([0 60]);

subplot(2,1,2);
e_plot = r1 - y1;
plot(t, e_plot, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Χρόνος (s)');
ylabel('Σφάλμα e(t) (rad/s)');
title('Σφάλμα παρακολούθησης');
xlim([0 Tsim]);
yline(0, '--k');

%% -----------------------------------------------------------
%  3.  ΣΕΝΑΡΙΟ 2.2 – ΡΑΜΠΑ (Σχ.4)
%
%  Εκφώνηση Σχ.4:
%    t = 0  – 10 s : ράμπα από 0.4 → 50 rad/s
%    t = 10 – 20 s : ράμπα από 50  → 0.4 rad/s
%
%  Κλίση: (50 - 0.4) / 10 = 4.96 rad/s per sec
%% -----------------------------------------------------------

slope = (50 - 0.4) / 10;    % = 4.96 rad/s²

% Σήμα αναφοράς Σχ.4
r2 = zeros(1, N);
for k = 1:N
    if t(k) <= 10
        r2(k) = 0.4 + slope * t(k);          % άνοδος: 0.4 → 50
    else
        r2(k) = 50  - slope * (t(k) - 10);   % κατάβαση: 50 → 0.4
    end
    % κορεσμός για ακρίβεια
    r2(k) = max(0.4, min(50, r2(k)));
end

% Προσομοίωση FZ-PI
x      = zeros(2,1);
u_k    = 0;
y2     = zeros(1, N);
e_prev = 0;              % αρχικοποίηση

for k = 1:N

    e_k = r2(k) - x(1);

    if k == 1
        de_k = 0;
    else
        de_k = (e_k - e_prev) / T;
    end

    e_n  = max(-1, min(1,  Ke    * e_k  ));
    de_n = max(-1, min(1,  alpha * de_k ));

    du_n = evalfis(fis, [e_n, de_n]);
    u_k  = u_k + K1 * du_n;
    u_k  = max(-50, min(50, u_k));

    xdot = Ac * x + Bc * u_k;
    x    = x + T * xdot;
    y2(k) = x(1);

    e_prev = e_k;
end

% Μετρικά
e_ramp    = r2 - y2;
rms_error = sqrt(mean(e_ramp.^2));
max_error = max(abs(e_ramp));

fprintf('\n=== Σενάριο 2.2 – Ράμπα ===\n');
fprintf('  RMS σφάλμα παρακολούθησης : %.4f rad/s\n', rms_error);
fprintf('  Μέγιστο σφάλμα            : %.4f rad/s\n', max_error);
fprintf('  Τελική τιμή y(end)         : %.4f rad/s\n', y2(end));
fprintf('  Τελική τιμή r(end)         : %.4f rad/s\n', r2(end));

% Γραφική απεικόνιση
figure('Name','Σενάριο 2.2 – Ράμπα','Color','w');

subplot(2,1,1);
plot(t, r2, 'k--', 'LineWidth', 1.5); hold on;
plot(t, y2, 'b-',  'LineWidth', 2.0);
grid on;
xlabel('Χρόνος (s)');
ylabel('Ταχύτητα (rad/s)');
title('Σενάριο 2.2 – Σήμα αναφοράς ράμπας (0.4→50→0.4 rad/s)');
legend('Αναφορά r(t)', 'Απόκριση FZ-PI', 'Location','north');
xlim([0 Tsim]); ylim([0 60]);

subplot(2,1,2);
plot(t, e_ramp, 'b-', 'LineWidth', 1.2);
grid on;
xlabel('Χρόνος (s)');
ylabel('Σφάλμα e(t) (rad/s)');
title(sprintf('Σφάλμα παρακολούθησης ράμπας  (RMS=%.3f, max=%.3f)', ...
    rms_error, max_error));
xlim([0 Tsim]);
yline(0, '--k');

%% -----------------------------------------------------------
%  4.  ΣΥΓΚΡΙΤΙΚΟ ΔΙΑΓΡΑΜΜΑ
%% -----------------------------------------------------------

figure('Name','Σενάριο 2 – Σύγκριση','Color','w');
plot(t, r1, 'k--',  'LineWidth', 1.2); hold on;
plot(t, y1, 'r-',   'LineWidth', 1.8);
plot(t, r2, 'k:',   'LineWidth', 1.2);
plot(t, y2, 'b-',   'LineWidth', 1.8);
grid on;
xlabel('Χρόνος (s)');
ylabel('Ταχύτητα (rad/s)');
title('Σενάριο 2 – Σύγκριση βηματικής και ράμπας');
legend('r(t) βηματικό', 'y(t) FLC – βηματικό', ...
       'r(t) ράμπα',    'y(t) FLC – ράμπα', ...
       'Location','east');
xlim([0 Tsim]); ylim([0 65]);

%% -----------------------------------------------------------
%  5.  ΣΧΟΛΙΑΣΜΟΣ ΙΚΑΝΟΤΗΤΑΣ ΠΑΡΑΚΟΛΟΥΘΗΣΗΣ ΡΑΜΠΑΣ
%% -----------------------------------------------------------

fprintf('\n=== Σχολιασμός ικανότητας παρακολούθησης ράμπας ===\n');
fprintf('  Ο FZ-PI ελεγκτής παρακολουθεί ράμπες με σταθερό σφάλμα.\n');
fprintf('  Αυτό οφείλεται στην ολοκληρωτική δομή (incremental PI):\n');
fprintf('    u(k) = u(k-1) + K1*du_n → συσσωρεύει σήμα ελέγχου\n');
fprintf('  Το σφάλμα μόνιμης κατάστασης για ράμπα εξαρτάται\n');
fprintf('  από την κλίση και την ταχύτητα απόκρισης του φυτού.\n');
fprintf('  Μεγαλύτερο K1 ή alpha → μικρότερο σφάλμα παρακολούθησης.\n');

%% -----------------------------------------------------------
%  6.  ΑΠΟΘΗΚΕΥΣΗ
%% -----------------------------------------------------------

save('scenario2_results.mat', 't', 'y1', 'y2', 'r1', 'r2', ...
     'e_ramp', 'rms_error', 'max_error');

fprintf('\n=== Αποθήκευση → scenario2_results.mat ✓ ===\n');