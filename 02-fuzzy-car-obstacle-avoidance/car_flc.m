%% ============================================================
%%  Εργασία: Car Control με Fuzzy Logic Controller (FLC)
%%  Μάθημα : Υπολογιστική Νοημοσύνη - Ασαφή Συστήματα
%% ============================================================
%  Τελεστές:
%   - Implication : Larsen (prod)
%   - ALSO        : max
%   - Σύνθεση     : max-min
%   - Defuzz      : COA (centroid)
%
%  Παράμετροι:
%   - u = 0.05 m/sec  |  Εμπόδιο x∈[5,7], y∈[1,3]
%   - Αρχή (4, 0.4)   |  Στόχος (10, 3.2)
%   - θ₁=0°, θ₂=-45°, θ₃=-90°
%% ============================================================

clear; clc; close all;

%% ============================================================
%% ΜΕΡΟΣ Α  –  ΔΗΜΙΟΥΡΓΙΑ FIS
%% ============================================================

fis = mamfis('Name','CarFLC');
fis.AndMethod             = 'min';
fis.ImplicationMethod     = 'prod';      % Larsen
fis.AggregationMethod     = 'max';       % ALSO = max
fis.DefuzzificationMethod = 'centroid';  % COA

% ── dV ∈ [0,1]  (Σχ.2) ──────────────────────────────────────
fis = addInput(fis,[0 1],'Name','dV');
fis = addMF(fis,'dV','trimf',[0    0    0.5],'Name','S');
fis = addMF(fis,'dV','trimf',[0    0.5  1  ],'Name','M');
fis = addMF(fis,'dV','trimf',[0.5  1    1  ],'Name','L');

% ── dH ∈ [0,1]  (Σχ.2) ──────────────────────────────────────
fis = addInput(fis,[0 1],'Name','dH');
fis = addMF(fis,'dH','trimf',[0    0    0.5],'Name','S');
fis = addMF(fis,'dH','trimf',[0    0.5  1  ],'Name','M');
fis = addMF(fis,'dH','trimf',[0.5  1    1  ],'Name','L');

% ── θ ∈ [-180°,+180°]  (Σχ.3) ───────────────────────────────
fis = addInput(fis,[-180 180],'Name','theta');
fis = addMF(fis,'theta','trimf',[-180  -180    0],'Name','N');
fis = addMF(fis,'theta','trimf',[-180     0  180],'Name','ZE');
fis = addMF(fis,'theta','trimf',[   0   180  180],'Name','P');

% ── Δθ ∈ [-130°,+130°]  (Σχ.4) ──────────────────────────────
fis = addOutput(fis,[-130 130],'Name','dtheta');
fis = addMF(fis,'dtheta','trimf',[-130  -130    0],'Name','N');
fis = addMF(fis,'dtheta','trimf',[-130     0  130],'Name','ZE');
fis = addMF(fis,'dtheta','trimf',[   0   130  130],'Name','P');

%% ── Membership Functions Plot ─────────────────────────────────
figure('Name','Membership Functions','NumberTitle','off','Position',[50 50 1100 700]);
subplot(2,2,1); plotmf(fis,'input',1);
title('dV – Κάθετη απόσταση [0,1]'); xlabel('dV (m)');
subplot(2,2,2); plotmf(fis,'input',2);
title('dH – Οριζόντια απόσταση [0,1]'); xlabel('dH (m)');
subplot(2,2,3); plotmf(fis,'input',3);
title('\theta – Διεύθυνση ταχύτητας [-180°,+180°]'); xlabel('\theta (°)');
subplot(2,2,4); plotmf(fis,'output',1);
title('\Delta\theta – Μεταβολή διεύθυνσης [-130°,+130°]'); xlabel('\Delta\theta (°)');
sgtitle('Fuzzy Membership Functions – Car FLC','FontSize',13,'FontWeight','bold');


%% ============================================================
%% ΜΕΡΟΣ Β  –  ΒΑΣΗ ΚΑΝΟΝΩΝ  (27 κανόνες: 3×3×3)
%% ============================================================
%
%  ΑΡΧΗ ΣΧΕΔΙΑΣΜΟΥ:
%  
%   • θ=ZE (≈0°) = η «σωστή» κατεύθυνση (προς τα δεξιά/στόχο)
%   • θ=N (<0°)  = πηγαίνει προς τα κάτω/αριστερά            
%   • θ=P (>0°)  = πηγαίνει προς τα πάνω                     
%                                                            
%   ΚΟΝΤΑ ΣΕ ΕΜΠΟΔΙΟ (dH=S ή dV=S):                          
%     θ=N ή ZE → Δθ=P  (στρίψε ΠΑΝΩ να αποφύγεις)            
%     θ=P      → Δθ=ZE (ήδη πηγαίνεις πάνω, διατήρησε)       
%                                                            
%   ΕΛΕΥΘΕΡΟΣ ΔΡΟΜΟΣ (dH=L και dV=L ή M):                    
%     θ=P → Δθ=N  (διόρθωσε πίσω προς στόχο, μην πας πολύ πάνω)
%     θ=ZE→ Δθ=ZE (συνέχισε ευθεία)                           
%     θ=N → Δθ=ZE (μην πας χαμηλότερα, ευθεία)                
%  
%
%  Δείκτες: S=1 M=2 L=3 | N=1 ZE=2 P=3
%
%        dV  dH   θ   Δθ   w   c
ruleList = [
%  ── dV=S (κοντά κάθετα) ────────────────────────────────────
  1   1   1   3   1   1 ;  % S S N  → P  : εμπόδιο κοντά, κατεύθυνση κάτω → ΠΑΝΩ
  1   1   2   3   1   1 ;  % S S ZE → P  : εμπόδιο κοντά, ευθεία → ΠΑΝΩ
  1   1   3   2   1   1 ;  % S S P  → ZE : ήδη πάνω → διατήρηση
  1   2   1   3   1   1 ;  % S M N  → P  : κοντά κάθετα, μέτρια οριζόντια → ΠΑΝΩ
  1   2   2   3   1   1 ;  % S M ZE → P
  1   2   3   2   1   1 ;  % S M P  → ZE : ήδη πάνω → διατήρηση
  1   3   1   2   1   1 ;  % S L N  → ZE : κοντά κάθετα, μακριά οριζ. → ευθεία
  1   3   2   2   1   1 ;  % S L ZE → ZE
  1   3   3   1   1   1 ;  % S L P  → N  : κοντά κάθετα, μακριά οριζ., ήδη πάνω → διόρθωση

%  ── dV=M (μέτρια κάθετη απόσταση) ──────────────────────────
  2   1   1   3   1   1 ;  % M S N  → P  : κοντά οριζόντια → ΠΑΝΩ
  2   1   2   3   1   1 ;  % M S ZE → P
  2   1   3   2   1   1 ;  % M S P  → ZE : ήδη πάνω → διατήρηση
  2   2   1   2   1   1 ;  % M M N  → ZE : μέτριο παντού → ευθεία
  2   2   2   2   1   1 ;  % M M ZE → ZE
  2   2   3   1   1   1 ;  % M M P  → N  : μέτριο, υπερβολικά πάνω → διόρθωση δεξιά
  2   3   1   2   1   1 ;  % M L N  → ZE : ελεύθερο οριζ. → ευθεία
  2   3   2   2   1   1 ;  % M L ZE → ZE
  2   3   3   1   1   1 ;  % M L P  → N  : ελεύθερο, υπερβολικά πάνω → διόρθωση

%  ── dV=L (μακριά κάθετα) ────────────────────────────────────
  3   1   1   3   1   1 ;  % L S N  → P  : κοντά οριζόντια μόνο → ΠΑΝΩ
  3   1   2   3   1   1 ;  % L S ZE → P
  3   1   3   2   1   1 ;  % L S P  → ZE : ήδη πάνω → διατήρηση
  3   2   1   2   1   1 ;  % L M N  → ZE : ελεύθερο κάθετα → ευθεία
  3   2   2   2   1   1 ;  % L M ZE → ZE
  3   2   3   1   1   1 ;  % L M P  → N  : ελεύθερο, πάνω → διόρθωση
  3   3   1   2   1   1 ;  % L L N  → ZE : ελεύθερος δρόμος, κάτω → ευθεία (μην χάσεις ύψος)
  3   3   2   2   1   1 ;  % L L ZE → ZE : ελεύθερος δρόμος → συνέχισε
  3   3   3   1   1   1 ;  % L L P  → N  : ελεύθερος δρόμος, πάνω → διόρθωση προς στόχο
];

fis = addRule(fis, ruleList);
writeFIS(fis,'car_flc');
fprintf('FIS αποθηκεύτηκε ως car_flc.fis\n');


%% ============================================================
%% ΜΕΡΟΣ Γ  –  ΠΡΟΣΟΜΟΙΩΣΗ
%% ============================================================

x_init = 4;   y_init = 0.4;
x_dest = 10;  y_dest = 3.2;
obs_x  = [5, 7];
obs_y  = [1, 3];

u        = 0.05;  % m/sec 
dt       = 1;     % sec/βήμα
sf       = 0.4;   % scale factor: μέγιστη στροφή/βήμα = 130*0.4 = 52°
max_iter = 3000;
d_stop   = 0.20;

% ── ΠΑΡΑΜΕΤΡΟΣ ΕΛΞΗΣ ΠΡΟΣ ΣΤΟΧΟ ─────────────────────────────
% Όταν είμαστε μακριά από το εμπόδιο, προσθέτουμε μικρή
% διόρθωση προς τη γωνία-στόχου. Αυτό εξασφαλίζει ότι το
% όχημα δεν χάνει την κατεύθυνσή του μετά την αποφυγή.
goal_gain = 0.3;  % ισχύς έλξης (0=καμία, 1=πλήρης)

theta0_list = [0, -45, -90];
colors      = {'b','r',[0 0.6 0]};
lstyles     = {'-','--','-.'};

figure('Name','Τροχιές Οχήματος – FLC','NumberTitle','off','Position',[200 100 850 620]);
hold on; grid on;

% Εμπόδιο
fill([obs_x(1) obs_x(2) obs_x(2) obs_x(1)], ...
     [obs_y(1) obs_y(1) obs_y(2) obs_y(2)], ...
     [0.75 0.75 0.75],'EdgeColor','k','LineWidth',2,'DisplayName','Εμπόδιο');
text(mean(obs_x),mean(obs_y),'ΕΜΠΟΔΙΟ', ...
    'HorizontalAlignment','center','FontWeight','bold','FontSize',11);
plot(x_init,y_init,'ko','MarkerSize',10,'MarkerFaceColor','k','DisplayName','Αρχή (4, 0.4)');
plot(x_dest,y_dest,'p','MarkerSize',18,'MarkerFaceColor','y', ...
     'MarkerEdgeColor','k','LineWidth',1.5,'DisplayName','Στόχος (10, 3.2)');

for i = 1:3
    theta_deg = theta0_list(i);
    x = x_init;  y = y_init;
    traj_x = x;  traj_y = y;
    reached = false;

    for k = 1:max_iter
        if norm([x-x_dest, y-y_dest]) < d_stop
            reached = true; break;
        end

        % ── Αποστάσεις από εμπόδιο (κορεσμένες στο 1m) ──────
        if     y < obs_y(1), dV = min(obs_y(1)-y, 1);
        elseif y > obs_y(2), dV = min(y-obs_y(2), 1);
        else,                dV = 0;
        end
        if     x < obs_x(1), dH = min(obs_x(1)-x, 1);
        elseif x > obs_x(2), dH = min(x-obs_x(2), 1);
        else,                dH = 0;
        end

        % ── FLC: αποφυγή εμποδίου ────────────────────────────
        dtheta_flc = sf * evalfis(fis,[dV, dH, theta_deg]);

        % ── Έλξη προς στόχο (ενεργή μόνο όταν είμαστε μακριά) ──
        % Υπολογίζουμε τη γωνία προς τον στόχο
        theta_goal = atan2d(y_dest-y, x_dest-x);
        theta_err  = mod(theta_goal - theta_deg + 180, 360) - 180;
        % Βάρος: 0 κοντά στο εμπόδιο, 1 μακριά
        free = min(dV + dH, 1);   % 0=εμπόδιο κοντά, 1=ελεύθερο
        dtheta_goal = goal_gain * free * theta_err;

        % ── Συνολική μεταβολή γωνίας ─────────────────────────
        delta_theta = dtheta_flc + dtheta_goal;

        % ── Ενημέρωση γωνίας (wrap στο [-180°,+180°]) ────────
        theta_deg = mod(theta_deg + delta_theta + 180, 360) - 180;

        % ── Κινηματική ───────────────────────────────────────
        x = x + u*dt*cosd(theta_deg);
        y = y + u*dt*sind(theta_deg);

        traj_x(end+1) = x; %#ok<AGROW>
        traj_y(end+1) = y; %#ok<AGROW>
    end

    plot(traj_x, traj_y, 'Color',colors{i},'LineStyle',lstyles{i}, ...
         'LineWidth',2.2,'DisplayName',sprintf('\\theta_0 = %d°',theta0_list(i)));

    if reached
        fprintf('theta0 = %4d deg  ->  Στόχος σε %d βήματα | Τελ.θέση: (%.2f, %.2f)\n', ...
                theta0_list(i),k,x,y);
    else
        fprintf('theta0 = %4d deg  ->  Δεν επιτεύχθηκε | Τελ.θέση: (%.2f, %.2f)\n', ...
                theta0_list(i),x,y);
    end
end

xlabel('x (m)','FontSize',12); ylabel('y (m)','FontSize',12);
title('Τροχιές Οχήματος – Fuzzy Logic Controller','FontSize',13,'FontWeight','bold');
legend('Location','northwest','FontSize',10);
xlim([2 11]); ylim([-2 6]);
xticks(0:1:11); yticks(-2:1:6);
set(gca,'FontSize',11);


%% ============================================================
%% ΜΕΡΟΣ Δ  –  SURFACE VIEWS
%% ============================================================
figure('Name','Surface Views','NumberTitle','off','Position',[50 400 1000 380]);
subplot(1,2,1); gensurf(fis,[1 3]);
xlabel('dV'); ylabel('\theta (°)'); zlabel('\Delta\theta (°)');
title('Surface: dV & \theta \rightarrow \Delta\theta');
subplot(1,2,2); gensurf(fis,[2 3]);
xlabel('dH'); ylabel('\theta (°)'); zlabel('\Delta\theta (°)');
title('Surface: dH & \theta \rightarrow \Delta\theta');
sgtitle('FIS Surface Views','FontSize',12,'FontWeight','bold');

fprintf('\nΠροσομοίωση ολοκληρώθηκε.\n');