function sweep = ds_run_mash_interstage_gain_sweep( ...
    interstage_gains, nyquist_rate_Hz, input_level_dBFS, make_plot)
%DS_RUN_MASH_INTERSTAGE_GAIN_SWEEP Compare MASH gain and stage-2 drive.
%   The stimulus and random seeds are held constant at every point, making
%   repeated calls and point-to-point comparisons deterministic.

if nargin < 1
    interstage_gains = [0.125 0.25 0.5 1];
end
if nargin < 2
    nyquist_rate_Hz = 2000;
end
if nargin < 3
    input_level_dBFS = -6;
end
if nargin < 4
    make_plot = true;
end

validateattributes(interstage_gains, {'numeric'}, ...
    {'real', 'finite', 'vector', 'positive'}, mfilename, ...
    'interstage_gains');
interstage_gains = interstage_gains(:);

cfg_base = ds_default_config(nyquist_rate_Hz);
cfg_base.signal.input_level_dBFS = input_level_dBFS;
cfg_base.signal.amplitude = cfg_base.signal.full_scale_peak * ...
    10^(input_level_dBFS/20);
signal = ds_generate_signal(cfg_base);
filters = ds_design_filters(cfg_base);

point_count = numel(interstage_gains);
measured_enob = zeros(point_count,1);
inband_sinad_dB = zeros(point_count,1);
stage2_input_rms = zeros(point_count,1);
stage2_input_peak = zeros(point_count,1);
stage2_integrator_rms = zeros(point_count,1);
stage2_integrator_peak = zeros(point_count,1);
stage2_integrator_minimum = zeros(point_count,1);
stage2_integrator_maximum = zeros(point_count,1);

for index = 1:point_count
    cfg = cfg_base;
    cfg.modulator.mash_interstage_gain = interstage_gains(index);
    all_modulators = ds_run_modulators(signal.vin, cfg);

    mash_only.mash_2_1 = all_modulators.mash_2_1;
    mash_only.architecture_names = {'mash_2_1'};
    mash_only.architecture_labels = {'MASH 2-1'};
    filtered = ds_filter_and_decimate(mash_only, filters, cfg);
    results = ds_measure_performance(filtered, filters, cfg);
    performance = results.by_architecture.mash_2_1.filter_B;
    diagnostics = all_modulators.mash_details.diagnostics;

    measured_enob(index) = performance.measured_enob;
    inband_sinad_dB(index) = performance.inband_sinad_dB;
    stage2_input_rms(index) = diagnostics.stage2_input_rms;
    stage2_input_peak(index) = diagnostics.stage2_input_peak;
    stage2_integrator_rms(index) = diagnostics.stage2_integrator_rms;
    stage2_integrator_peak(index) = diagnostics.stage2_integrator_peak;
    stage2_integrator_minimum(index) = ...
        diagnostics.stage2_integrator_minimum;
    stage2_integrator_maximum(index) = ...
        diagnostics.stage2_integrator_maximum;
end

digital_cancellation_gain = 1./interstage_gains;
sweep = table(interstage_gains, digital_cancellation_gain, ...
    measured_enob, inband_sinad_dB, stage2_input_rms, ...
    stage2_input_peak, stage2_integrator_rms, stage2_integrator_peak, ...
    stage2_integrator_minimum, stage2_integrator_maximum, ...
    'VariableNames', {'Interstage_Gain', 'Digital_Cancellation_Gain', ...
    'Measured_ENOB', 'Inband_SINAD_dB', 'Stage2_Input_RMS', ...
    'Stage2_Input_Peak', 'Stage2_Integrator_RMS', ...
    'Stage2_Integrator_Peak', 'Stage2_Integrator_Minimum', ...
    'Stage2_Integrator_Maximum'});
disp(sweep);

if make_plot
    figure('Name', 'MASH 2-1 interstage-gain sweep');
    yyaxis left;
    semilogx(interstage_gains, measured_enob, 'o-', ...
        'LineWidth', 1.4);
    ylabel('Measured ENOB (bits)');
    yyaxis right;
    semilogx(interstage_gains, stage2_input_rms, 's-', ...
        interstage_gains, stage2_integrator_peak, 'd-', ...
        'LineWidth', 1.4);
    ylabel('Stage-2 state (full-scale units)');
    grid on;
    xlabel('MASH interstage gain');
    title(sprintf('MASH 2-1 at %.1f ksps, %.1f dBFS', ...
        nyquist_rate_Hz/1000, input_level_dBFS));
    legend('Measured ENOB', 'Stage-2 input RMS', ...
        'Stage-2 integrator peak', 'Location', 'best');
    drawnow;
end
end
