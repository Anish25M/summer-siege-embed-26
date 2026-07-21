function sweep = ds_run_mash_gain_amplitude_sweep( ...
    interstage_gains, input_levels_dBFS, nyquist_rate_Hz, make_plot)
%DS_RUN_MASH_GAIN_AMPLITUDE_SWEEP Map MASH performance and stage-2 state.
%   Each point uses the configured input-noise and modulator-dither seeds,
%   so the returned matrices and table are repeatable across calls.

if nargin < 1
    interstage_gains = [0.125 0.25 0.5 1];
end
if nargin < 2
    input_levels_dBFS = [-12 -9 -6 -3 -2 -1 -0.5];
end
if nargin < 3
    nyquist_rate_Hz = 2000;
end
if nargin < 4
    make_plot = true;
end

validateattributes(interstage_gains, {'numeric'}, ...
    {'real', 'finite', 'vector', 'positive'}, mfilename, ...
    'interstage_gains');
validateattributes(input_levels_dBFS, {'numeric'}, ...
    {'real', 'finite', 'vector', 'nonempty'}, mfilename, ...
    'input_levels_dBFS');
interstage_gains = interstage_gains(:)';
input_levels_dBFS = input_levels_dBFS(:);

cfg_base = ds_default_config(nyquist_rate_Hz);
filters = ds_design_filters(cfg_base);
amplitude_count = numel(input_levels_dBFS);
gain_count = numel(interstage_gains);
matrix_size = [amplitude_count gain_count];

measured_enob = zeros(matrix_size);
inband_sinad_dB = zeros(matrix_size);
stage2_input_rms = zeros(matrix_size);
stage2_input_peak = zeros(matrix_size);
stage2_integrator_rms = zeros(matrix_size);
stage2_integrator_peak = zeros(matrix_size);
stage2_integrator_minimum = zeros(matrix_size);
stage2_integrator_maximum = zeros(matrix_size);
numerically_stable = false(matrix_size);

for amplitude_index = 1:amplitude_count
    cfg_amplitude = cfg_base;
    cfg_amplitude.signal.input_level_dBFS = ...
        input_levels_dBFS(amplitude_index);
    cfg_amplitude.signal.amplitude = ...
        cfg_amplitude.signal.full_scale_peak * ...
        10^(cfg_amplitude.signal.input_level_dBFS/20);
    signal = ds_generate_signal(cfg_amplitude);

    for gain_index = 1:gain_count
        cfg = cfg_amplitude;
        cfg.modulator.mash_interstage_gain = ...
            interstage_gains(gain_index);
        all_modulators = ds_run_modulators(signal.vin, cfg);

        mash_only.mash_2_1 = all_modulators.mash_2_1;
        mash_only.architecture_names = {'mash_2_1'};
        mash_only.architecture_labels = {'MASH 2-1'};
        filtered = ds_filter_and_decimate(mash_only, filters, cfg);
        results = ds_measure_performance(filtered, filters, cfg);
        performance = results.by_architecture.mash_2_1.filter_B;
        diagnostics = all_modulators.mash_details.diagnostics;

        measured_enob(amplitude_index,gain_index) = ...
            performance.measured_enob;
        inband_sinad_dB(amplitude_index,gain_index) = ...
            performance.inband_sinad_dB;
        stage2_input_rms(amplitude_index,gain_index) = ...
            diagnostics.stage2_input_rms;
        stage2_input_peak(amplitude_index,gain_index) = ...
            diagnostics.stage2_input_peak;
        stage2_integrator_rms(amplitude_index,gain_index) = ...
            diagnostics.stage2_integrator_rms;
        stage2_integrator_peak(amplitude_index,gain_index) = ...
            diagnostics.stage2_integrator_peak;
        stage2_integrator_minimum(amplitude_index,gain_index) = ...
            diagnostics.stage2_integrator_minimum;
        stage2_integrator_maximum(amplitude_index,gain_index) = ...
            diagnostics.stage2_integrator_maximum;
        numerically_stable(amplitude_index,gain_index) = ...
            all(isfinite(all_modulators.mash_2_1)) && ...
            all(isfinite(all_modulators.mash_details.stage2_integrator1));
    end
end

[peak_sinad_by_gain_dB, best_amplitude_index] = ...
    max(inband_sinad_dB, [], 1);
best_input_level_dBFS = reshape( ...
    input_levels_dBFS(best_amplitude_index), 1, []);
peak_measured_enob = zeros(1,gain_count);
for gain_index = 1:gain_count
    peak_measured_enob(gain_index) = ...
        measured_enob(best_amplitude_index(gain_index),gain_index);
end
within_3dB_of_peak = numerically_stable & ...
    inband_sinad_dB >= peak_sinad_by_gain_dB-3;
operational_msa_dBFS = nan(1,gain_count);
for gain_index = 1:gain_count
    acceptable_levels = input_levels_dBFS( ...
        within_3dB_of_peak(:,gain_index));
    if ~isempty(acceptable_levels)
        operational_msa_dBFS(gain_index) = max(acceptable_levels);
    end
end

[input_grid_dBFS, gain_grid] = ndgrid( ...
    input_levels_dBFS, interstage_gains);
sweep = struct();
sweep.interstage_gains = interstage_gains;
sweep.input_levels_dBFS = input_levels_dBFS;
sweep.nyquist_rate_Hz = nyquist_rate_Hz;
sweep.measured_enob = measured_enob;
sweep.inband_sinad_dB = inband_sinad_dB;
sweep.stage2_input_rms = stage2_input_rms;
sweep.stage2_input_peak = stage2_input_peak;
sweep.stage2_integrator_rms = stage2_integrator_rms;
sweep.stage2_integrator_peak = stage2_integrator_peak;
sweep.stage2_integrator_minimum = stage2_integrator_minimum;
sweep.stage2_integrator_maximum = stage2_integrator_maximum;
sweep.numerically_stable = numerically_stable;
sweep.within_3dB_of_peak = within_3dB_of_peak;
sweep.best_input_level_dBFS = best_input_level_dBFS;
sweep.peak_sinad_by_gain_dB = peak_sinad_by_gain_dB;
sweep.peak_measured_enob = peak_measured_enob;
sweep.operational_msa_dBFS = operational_msa_dBFS;
sweep.table = table(gain_grid(:), input_grid_dBFS(:), ...
    measured_enob(:), inband_sinad_dB(:), stage2_input_rms(:), ...
    stage2_input_peak(:), stage2_integrator_rms(:), ...
    stage2_integrator_peak(:), stage2_integrator_minimum(:), ...
    stage2_integrator_maximum(:), numerically_stable(:), ...
    within_3dB_of_peak(:), ...
    'VariableNames', {'Interstage_Gain', 'Input_Level_dBFS', ...
    'Measured_ENOB', 'Inband_SINAD_dB', 'Stage2_Input_RMS', ...
    'Stage2_Input_Peak', 'Stage2_Integrator_RMS', ...
    'Stage2_Integrator_Peak', 'Stage2_Integrator_Minimum', ...
    'Stage2_Integrator_Maximum', 'Numerically_Stable', ...
    'Within_3dB_Of_Peak'});
sweep.summary_by_gain = table(interstage_gains(:), ...
    best_input_level_dBFS(:), peak_sinad_by_gain_dB(:), ...
    peak_measured_enob(:), operational_msa_dBFS(:), ...
    'VariableNames', {'Interstage_Gain', 'Best_Input_Level_dBFS', ...
    'Peak_Inband_SINAD_dB', 'Peak_Measured_ENOB', ...
    'Operational_MSA_dBFS'});
disp(sweep.table);
disp(sweep.summary_by_gain);

if make_plot
    figure('Name', 'MASH gain-amplitude sweep');
    tiledlayout(1,2);
    nexttile;
    surf(interstage_gains, input_levels_dBFS, measured_enob, ...
        'EdgeColor', 'none');
    view(2);
    set(gca, 'XScale', 'log', 'YDir', 'normal');
    colorbar;
    xlabel('MASH interstage gain');
    ylabel('Input level (dBFS)');
    title('Measured ENOB (bits)');

    nexttile;
    surf(interstage_gains, input_levels_dBFS, ...
        stage2_integrator_peak, 'EdgeColor', 'none');
    view(2);
    set(gca, 'XScale', 'log', 'YDir', 'normal');
    colorbar;
    xlabel('MASH interstage gain');
    ylabel('Input level (dBFS)');
    title('Stage-2 integrator peak');
    sgtitle(sprintf('MASH 2-1 at %.1f ksps', nyquist_rate_Hz/1000));
    drawnow;
end
end
