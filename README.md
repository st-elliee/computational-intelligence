# Computational Intelligence – Fuzzy Systems

Coursework for **Computational Intelligence (Υπολογιστική Νοημοσύνη)**, Department of Electrical and Computer Engineering, Aristotle University of Thessaloniki. Spring semester 2024–25, instructor: I. Theocharis.

Four individual assignments on fuzzy control and neuro-fuzzy (TSK) modelling, all implemented in MATLAB.

| # | Assignment | Topics | Key result |
|---|------------|--------|------------|
| 1 | [Fuzzy PI speed control of a work-table mechanism](01-fuzzy-pi-speed-control) | Root-locus PI design, FZ-PI controller, 49-rule base, reference tracking | Overshoot 2.49% → 0.05%, settling time −41% vs. linear PI |
| 2 | [Fuzzy car control with obstacle avoidance](02-fuzzy-car-obstacle-avoidance) | Mamdani FLC, 27 rules, trajectory simulation | Obstacle avoided and goal reached from all 3 initial headings |
| 3 | [Regression with TSK models](03-tsk-regression) | ANFIS hybrid training, grid partitioning vs. subtractive clustering, ReliefF, grid search + 5-fold CV | R² = 0.81 on Superconductivity (81 → 12 features, 16 rules) |
| 4 | [Classification with TSK models](04-tsk-classification) | Class-dependent vs. class-independent clustering, Relief, grid search + stratified 5-fold CV | 73.8% OA on Haberman; 73.7% seizure recall on Epileptic Seizure |

Each folder contains the MATLAB code, the assignment brief (`assignment.pdf`, in Greek), the full report (`report.pdf`, in Greek) and the generated figures.

## Requirements

- MATLAB (developed on R2023b)
- Fuzzy Logic Toolbox
- Control System Toolbox (assignment 1)
- Statistics and Machine Learning Toolbox (assignments 3–4: `relieff`, `cvpartition`)

## Datasets

All from the UCI Machine Learning Repository: [Airfoil Self-Noise](https://archive.ics.uci.edu/dataset/291/airfoil+self+noise), [Superconductivity](https://archive.ics.uci.edu/dataset/464/superconductivty+data), [Haberman's Survival](https://archive.ics.uci.edu/dataset/43/haberman+s+survival), [Epileptic Seizure Recognition](https://archive.ics.uci.edu/dataset/388/epileptic+seizure+recognition).

## Author

Elisavet Stougiannou
