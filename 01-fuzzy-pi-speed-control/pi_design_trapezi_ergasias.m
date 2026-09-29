%% -----------------------------------------------------------
%  PI σχεδίαση για έλεγχο ταχύτητας τραπεζιού εργασίας
%  Φυτό:      Gp(s) = 25 / ((s+0.1)(s+10))
%  Ελεγκτής:  Gc(s) = K * (s + c) / s   -> Kp = K,  Ki = K*c
%  Προδιαγραφές (για μονάδα βήματος):
%       Overshoot < 8%
%       Rise time < 0.6 s
%% -----------------------------------------------------------

    clear; clc; close all;
    s = tf('s');

    %% ΡΥΘΜΙΣΕΙΣ
    w_step    = 50;                      % μέγιστη ταχύτητα στόχος (rad/s)
    c         = 0.2;                     % θέση μηδενικού του PI (κοντά στον πόλο -0.1)
    K_range   = logspace(-3, 3, 400);    % εύρος αναζήτησης κέρδους K (log-scale)
    OS_max    = 8;                       % μέγιστη υπερύψωση (%)
    tr_max    = 0.6;                     % μέγιστος χρόνος ανόδου (sec)

    %% ΦΥΤΟ
    Gp = 25 / ((s+0.1)*(s+10));

    %% ΕΛΕΓΚΤΗΣ ΧΩΡΙΣ ΚΕΡΔΟΣ
    Gc0 = (s + c)/s;

    %% ΑΝΟΙΚΤΟΣ ΒΡΟΧΟΣ & ROOT LOCUS
    L = Gc0 * Gp;

    fig1 = figure('Name','Root Locus','Color','w');
    rlocus(L);
    title(sprintf('Root Locus L(s) = ((s+%.3g)/s) G_p(s)', c));
    grid on;
    try saveas(fig1, 'pi_root_locus.png'); end

    %% ΣΑΡΩΣΗ ΣΤΟ K ΓΙΑ ΙΚΑΝΟΠΟΙΗΣΗ ΠΡΟΔΙΑΓΡΑΦΩΝ
    best = struct('K', NaN, 'info', [], 'meets', false);

    for K = K_range
        sys_cl = feedback(K*L, 1);      % κλειστός βρόχος με μοναδιαία ανάδραση
        info   = stepinfo(sys_cl);      % μετρικά για είσοδο 0→1
        if ~isnan(info.Overshoot) && ~isnan(info.RiseTime)
            meets = (info.Overshoot <= OS_max) && (info.RiseTime <= tr_max);
            if meets
                best.K    = K;
                best.info = info;
                best.meets = true;
                break;                  % πρώτο K που ικανοποιεί τις προδιαγραφές
            end
        end
    end

    % Αν δεν βρεθεί K που να ικανοποιεί πλήρως, βρες το "καλύτερο" με ελάχιστη ποινή
    if ~best.meets
        penalty = inf; K_best = NaN; info_best = [];
        for K = K_range
            sys_cl = feedback(K*L, 1);
            info   = stepinfo(sys_cl);
            if isnan(info.Overshoot) || isnan(info.RiseTime), continue; end
            p = max(0, info.Overshoot-OS_max)/OS_max + ...
                max(0, info.RiseTime-tr_max)/tr_max;
            if p < penalty
                penalty   = p;
                K_best    = K;
                info_best = info;
            end
        end
        best.K    = K_best;
        best.info = info_best;
        best.meets = false;
    end

    %% ΤΕΛΙΚΟΣ ΕΛΕΓΚΤΗΣ & ΚΛΕΙΣΤΟΣ ΒΡΟΧΟΣ
    K  = best.K;
    Kp = K;
    Ki = K * c;

    Gc     = K * Gc0;
    sys_cl = feedback(Gc*Gp, 1);

    %% ΠΟΛΟΙ ΚΛΕΙΣΤΟΥ ΒΡΟΧΟΥ (ΓΙΑ ΣΧΟΛΙΑΣΜΟ)
    poles_cl = pole(sys_cl);

    %% ΒΗΜΑΤΙΚΗ ΑΠΟΚΡΙΣΗ ΓΙΑ ΑΝΑΦΟΡΑ 50 rad/s
    t = 0:0.001:5;
    [y,t] = step(w_step*sys_cl, t);

    fig2 = figure('Name','Step Response (50 rad/s)','Color','w');
    plot(t, y, 'LineWidth', 1.25); grid on;
    xlabel('Χρόνος (s)');
    ylabel('Ταχύτητα (rad/s)');
    title(sprintf('Βηματική απόκριση σε αναφορά %g rad/s (PI)', w_step));
    yline(w_step, '--', 'w_{ref}');
    xlim([0, max(t)]);
    try saveas(fig2, 'pi_step_response_50rad.png'); end

    %% ΜΕΤΡΙΚΑ ΓΙΑ ΜΟΝΑΔΙΑΙΟ ΒΗΜΑ (ΣΥΜΦΩΝΑ ΜΕ ΠΡΟΔΙΑΓΡΑΦΕΣ)
    infoW = stepinfo(sys_cl);   % 0→1 βάση

    %% ΕΚΤΥΠΩΣΗ ΑΠΟΤΕΛΕΣΜΑΤΩΝ
    fprintf('\n--- ΑΠΟΤΕΛΕΣΜΑΤΑ PI ΕΛΕΓΚΤΗ ---\n');
    fprintf('Μηδενικό PI (c)        = %.4f\n', c);
    fprintf('Κέρδος K (συνολικό)    = %.6f\n', K);
    fprintf('Kp                     = %.6f\n', Kp);
    fprintf('Ki                     = %.6f\n', Ki);
    fprintf('\n--- Μετρικά για μονάδα βήματος ---\n');
    fprintf('Overshoot (%%)          = %.3f\n', infoW.Overshoot);
    fprintf('Rise time (s)          = %.3f\n', infoW.RiseTime);
    fprintf('Settling time (s)      = %.3f\n', infoW.SettlingTime);
    fprintf('\nΠόλοι κλειστού βρόχου:\n');
    disp(poles_cl);

    if best.meets
        fprintf('>>> ΙΚΑΝΟΠΟΙΕΙ τις προδιαγραφές (OS <= %g%%, tr <= %.2f s)\n', OS_max, tr_max);
    else
        fprintf('>>> ΔΕΝ ικανοποιεί πλήρως τις προδιαγραφές – προσαρμόστε c ή εύρος K\n');
    end

    %% ΑΠΟΘΗΚΕΥΣΗ ΠΑΡΑΜΕΤΡΩΝ ΓΙΑ ΜΕΤΕΠΕΞΕΡΓΑΣΙΑ (π.χ. FLC)
    save('pi_tuned_params.mat', 'K', 'Kp', 'Ki', 'c', ...
         'OS_max', 'tr_max', 'w_step', 'poles_cl');

    %% ΕΠΙΣΤΡΟΦΗ ΑΠΟΤΕΛΕΣΜΑΤΩΝ ΩΣ STRUCT
    PI.K       = K;
    PI.Kp      = Kp;
    PI.Ki      = Ki;
    PI.c       = c;
    PI.Gp      = Gp;
    PI.Gc      = Gc;
    PI.sys_cl  = sys_cl;
    PI.info    = infoW;
    PI.poles   = poles_cl;
    PI.w_step  = w_step;
    PI.meets   = best.meets;

