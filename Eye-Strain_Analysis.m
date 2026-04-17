%% Arduino setup
port = "COM3";
baudRate = 9600;
% Note: nSamples / secDelay = samples per second.
% More samples are recommended for accurate insights
nSamples = 60;
secDelay = 1;

arduinoObj = serialport(port, baudRate);
configureTerminator(arduinoObj, "LF");
flush(arduinoObj);

disp("Collecting data...");
pause(2);

%% Preallocate arrays
distanceData = NaN(nSamples,1);
lightData = NaN(nSamples,1);
motionData = NaN(nSamples,1);

%% Read serial data and close serial connection
for k = 1:nSamples
    line = readline(arduinoObj);
    disp(line);

% Expect values in format "distance,light,motion" via circuit

values = split(strtrim(line), ",");

if numel(values) == 3
    distanceData(k) = str2double(values(1));
    lightData(k) = str2double(values(2));
     motionData(k) = str2double(values(3));
end
end

clear arduinoObj

%% Define time vector (denotes time in seconds)
t = (0:nSamples-1)' * secDelay;

%% Data filtering ("smoothing data") -- validation, interpolation, etc
% Clean noisy sensor readings prior to eye strain metric computations
distanceData(distanceData < 0) = NaN;
distanceSmooth = fillmissing(distanceData, 'linear');
distanceSmooth = movmean(distanceSmooth, 3);
lightSmooth = movmean(lightData, 3);

%% Determine active-use periods via PIR
% If motion is detected, assume the user remains active for 5 secs
holdSeconds = 5;
activeUse = false(nSamples,1);

for k = 1:nSamples
startIndex = max(1, k - holdSeconds + 1);

    if any(motionData(startIndex:k) == 1)
activeUse(k) = true;
    end
end

%% Exclude movement-based inactivity from analysis
%  Distance and light readings from potentinal breaks may be outliers and
%  thus, should not be counted in the filtered data
distanceActive = distanceSmooth;
lightActive = lightSmooth;

distanceActive(~activeUse) = NaN;
lightActive(~activeUse) = NaN;

%% Calculate metrics during active use
avgDistance = mean(distanceActive, 'omitnan');
avgLight = mean(lightActive, 'omitnan');
activeUsePercent = 100 * mean(activeUse);
rawMotionPercent = 100 * mean(motionData, 'omitnan');

validDistanceCount = sum(~isnan(distanceActive));

if validDistanceCount > 0
percentTooClose = 100 * sum(distanceActive < 50, 'omitnan') / validDistanceCount;
else
percentTooClose = NaN;
end

%% Distance trend during active use
validIdx = ~isnan(distanceActive);

if sum(validIdx) >= 2
p = polyfit(t(validIdx), distanceActive(validIdx), 1);
distanceSlope = p(1);
else
distanceSlope = NaN;
end

%% Evaluate risk score based on weigted system
riskScore = 0;

% Weigh distance as a means to evaluate eye strain risk
if ~isnan(avgDistance)
    if avgDistance < 40
        riskScore = riskScore + 2;
    elseif avgDistance < 50
        riskScore = riskScore + 1;
    end
end

% Weigh statistically significant distance-based closeness (in cm) as a 
% key metric in computing risk score
if ~isnan(percentTooClose)
    if percentTooClose > 60
        riskScore = riskScore + 2;
    elseif percentTooClose > 30
        riskScore = riskScore + 1;
    end
end

% Account for the fact that closer over time may indicate worsening posture 
if ~isnan(distanceSlope) && distanceSlope < -0.2
    riskScore = riskScore + 1;
end

% Low light weighs greater when the user is also sitting too close
if ~isnan(avgLight)
    if avgLight < 200 && ~isnan(avgDistance) && avgDistance < 50
        riskScore = riskScore + 2;
    elseif avgLight < 300
        riskScore = riskScore + 1;
    end
end

% Provide risk level assessment based on weighted risk score
if riskScore <= 1
    riskLevel = "Low";
elseif riskScore <= 3
    riskLevel = "Moderate";
elseif riskScore <= 5
    riskLevel = "High";
else
    riskLevel = "Very High";
end

%% Display summary
fprintf("\n===== SESSION SUMMARY =====\n");
fprintf("Average Distance During Active Use: %.2f cm\n", avgDistance);
fprintf("Percent Too Close During Active Use (<50 cm): %.2f%%\n", percentTooClose);
fprintf("Average Light During Active Use: %.2f\n", avgLight);
fprintf("Raw Motion Detection Percentage: %.2f%%\n", rawMotionPercent);
fprintf("Active Use Percentage: %.2f%%\n", activeUsePercent);
fprintf("Distance Trend Slope During Active Use: %.4f cm/s\n", distanceSlope);
fprintf("Risk Level: %s\n", riskLevel);

%% Plots of raw and filtered data
figure;
plot(t, distanceData, 'o-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Distance (cm)');
title('Raw Screen Distance Over Time');
grid on;

figure;
plot(t, distanceActive, 'o-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Distance (cm)');
title('Screen Distance During Active Use');
grid on;

figure;
plot(t, lightData, 'o-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Light Sensor Value');
title('Raw Ambient Light Over Time');
grid on;

figure;
plot(t, lightActive, 'o-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Light Sensor Value');
title('Ambient Light During Active Use');
grid on;

figure;
stairs(t, motionData, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Motion');
title('Raw PIR Motion Signal');
ylim([-0.2 1.2]);
grid on;

figure;
stairs(t, activeUse, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Active Use');
title('Estimated Active Use from PIR');
ylim([-0.2 1.2]);
grid on;

%% Save data to files
resultsTable = table( ...
t, distanceData, distanceActive, lightData, lightActive, motionData, activeUse, ...
'VariableNames', {'Time_s','DistanceRaw_cm','DistanceActive_cm','LightRaw','LightActive','Motion','ActiveUse'});

writetable(resultsTable, 'session_data.csv');

save('session_data.mat', ...
    't', 'distanceData', 'distanceActive', ...
    'lightData', 'lightActive', ...
    'motionData', 'activeUse', ...
    'avgDistance', 'percentTooClose', 'avgLight', ...
    'rawMotionPercent', 'activeUsePercent', ...
    'distanceSlope', 'riskScore', 'riskLevel');

disp("Session data saved to session_data.csv and session_data.mat");
