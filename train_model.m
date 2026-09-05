%% Train Landslide Machine Learning Classifier
clear; clc;
rng(42); % For reproducibility

% Synthesize representative geotechnical dataset (1000 observations)
N = 1000;
FoS = 0.5 + 2.0 * rand(N,1);             % Factor of safety (0.5 to 2.5)
moisture = 0.1 + 0.45 * rand(N,1);       % Soil moisture (10% to 55%)
rain = 100 * rand(N,1);                  % Rain intensity (0 to 100 mm/h)
tilt_rate = 10 * rand(N,1);              % Tilt rate (0 to 10 deg/h)

% Labeling based on geotechnical domain rules:
% 0 = Safe, 1 = Advisory, 2 = Critical/Evacuate
labels = zeros(N,1);
for i = 1:N
    if FoS(i) < 1.0 || (FoS(i) < 1.2 && tilt_rate(i) > 3.0) || (moisture(i) > 0.45 && tilt_rate(i) > 4.0)
        labels(i) = 2; % Critical
    elseif FoS(i) < 1.4 || rain(i) > 50 || tilt_rate(i) > 1.5 || moisture(i) > 0.38
        labels(i) = 1; % Advisory
    else
        labels(i) = 0; % Safe
    end
end

X = [FoS, moisture, rain, tilt_rate];
Y = labels;

% Train Decision Tree Classifier
mdl = fitctree(X, Y, 'PredictorNames', {'FoS','Moisture','Rain','TiltRate'}, ...
    'ClassNames', [0; 1; 2], 'MaxNumSplits', 15);

% Save trained model for Simulink
save('landslide_model.mat', 'mdl');
fprintf('Success: Trained ML model saved as landslide_model.mat\n');
