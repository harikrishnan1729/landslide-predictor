%% Train Geotechnically-Calibrated Landslide Machine Learning Classifier
clear; clc;
rng(42); % For strict reproducibility

fprintf('Generating physically-coupled geotechnical training data...\n');
N_scenarios = 1200;
steps_per_scenario = 10;
total_samples = N_scenarios * steps_per_scenario;

X_data = zeros(total_samples, 4); % [FoS, Moisture (%), Rain (mm/h), TiltRate (deg/h)]
Y_data = zeros(total_samples, 1); % [0=Safe, 1=Advisory, 2=Evacuate]

idx = 1;
for s = 1:N_scenarios
    % Sample environmental boundary conditions
    beta = 20 + 30 * rand();         % Slope angle (20 to 50 deg)
    c_prime = 8 + 8 * rand();        % Cohesion (8 to 16 kPa)
    moist = 0.15 + 0.15 * rand();    % Initial antecedent moisture (15% to 30%)
    cum_r = 0;
    
    % Random storm scenario
    rain_peak = 120 * rand()^1.5;   % Rain peak (0 to 120 mm/h)
    tremor = (rand() < 0.25) * (12 * rand()^2); % Occasional seismic events (0 to 12 deg/h)
    
    for st = 1:steps_per_scenario
        % Rain follows bell or pulse curve
        r = rain_peak * sin(pi * st / steps_per_scenario);
        
        % Hydrological step (physical 15-minute advance: 900s)
        dt_sim = 900;
        hyd = lews_physics('hydrology_step', moist, r, dt_sim, cum_r);
        moist = hyd.moist;
        cum_r = hyd.cum_rain;
        
        % Pore pressure & FoS
        u = lews_physics('pore_pressure', moist, 0.34, 9.81, 1.5, beta);
        fos = lews_physics('fos', beta, c_prime, 30, 18, 1.5, u, tremor);
        
        % Kinematic tilt velocity
        tilt = lews_physics('kinematics', fos, tremor);
        
        % Ground truth classification based on geotechnical limits
        if fos <= 1.05 || (fos <= 1.20 && tilt >= 2.2) || (moist >= 0.45 && fos <= 1.25)
            lbl = 2; % Critical Evacuate
        elseif fos <= 1.40 || moist >= 0.28 || r >= 35 || tilt >= 0.8
            lbl = 1; % Advisory Warning
        else
            lbl = 0; % Safe
        end
        
        X_data(idx, :) = [fos, moist * 100, r, tilt];
        Y_data(idx)    = lbl;
        idx = idx + 1;
    end
end

% Partition into 80% Train, 20% Test
cv = cvpartition(Y_data, 'HoldOut', 0.20);
X_train = X_data(training(cv), :);
Y_train = Y_data(training(cv));
X_test  = X_data(test(cv), :);
Y_test  = Y_data(test(cv));

fprintf('Dataset distribution: Safe=%.1f%%, Advisory=%.1f%%, Critical=%.1f%%\n', ...
    100*mean(Y_data==0), 100*mean(Y_data==1), 100*mean(Y_data==2));

% Train Decision Tree Classifier with optimized splits and class priors
mdl = fitctree(X_train, Y_train, ...
    'PredictorNames', {'FoS', 'MoisturePct', 'RainRate', 'TiltRate'}, ...
    'ClassNames', [0; 1; 2], ...
    'MaxNumSplits', 25, ...
    'Prune', 'on');

% Evaluate on unseen holdout test set
[Y_pred, scores] = predict(mdl, X_test);
accuracy = mean(Y_pred == Y_test);
conf_mat = confusionmat(Y_test, Y_pred);

fprintf('Holdout Test Accuracy: %.2f%%\n', accuracy * 100);
fprintf('Confusion Matrix:\n');
disp(conf_mat);

% Save model and metrics for dashboard and verification
model = mdl;
save('landslide_model.mat', 'model', 'mdl', 'accuracy', 'conf_mat');
fprintf('Success: Trained ML model saved as landslide_model.mat\n');
