function comparison = ds_run_input_level_sweep( ...
    input_levels_dBFS, nyquist_rate_Hz, make_plot)
%DS_RUN_INPUT_LEVEL_SWEEP Check nonlinear performance versus input level.

if nargin < 1
    input_levels_dBFS = (-12:0.5:-0.5)';
end
if nargin < 2
    nyquist_rate_Hz = 2000;
end
if nargin < 3
    make_plot = true;
end

input_levels_dBFS = input_levels_dBFS(:);
cfg_base = ds_default_config(nyquist_rate_Hz);
architecture_names = {'first_order', 'second_order', ...
    'third_order_single_loop', 'mash_2_1'};
architecture_labels = {'1st-order single loop', ...
    '2nd-order single loop', '3rd-order single loop', 'MASH 2-1'};
architecture_count = numel(architecture_names);
measured_enob = zeros(numel(input_levels_dBFS), architecture_count);
sinad_dB = zeros(numel(input_levels_dBFS), architecture_count);

for level_index = 1:numel(input_levels_dBFS)
    cfg = cfg_base;
    cfg.signal.input_level_dBFS = input_levels_dBFS(level_index);
    cfg.signal.amplitude = cfg.signal.full_scale_peak * ...
        10^(cfg.signal.input_level_dBFS/20);

    signal = ds_generate_signal(cfg);
    modulators = ds_run_modulators(signal.vin, cfg);
    filters = ds_design_filters(cfg);
    filtered = ds_filter_and_decimate(modulators, filters, cfg);
    results = ds_measure_performance(filtered, filters, cfg);

    for architecture_index = 1:architecture_count
        name = architecture_names{architecture_index};
        performance = results.by_architecture.(name).filter_B;
        measured_enob(level_index,architecture_index) = ...
            performance.measured_enob;
        sinad_dB(level_index,architecture_index) = ...
            performance.inband_sinad_dB;
    end
end

comparison = struct();
comparison.input_levels_dBFS = input_levels_dBFS;
comparison.architecture_names = architecture_names;
comparison.architecture_labels = architecture_labels;
comparison.measured_enob = measured_enob;
comparison.inband_sinad_dB = sinad_dB;
comparison.table = array2table( ...
    [input_levels_dBFS measured_enob], ...
    'VariableNames', {'Input_Level_dBFS', ...
    'First_Measured_ENOB', 'Second_Measured_ENOB', ...
    'Third_Measured_ENOB', 'MASH_Measured_ENOB'});
disp(comparison.table);

best_level_dBFS = zeros(architecture_count,1);
best_sinad_dB = zeros(architecture_count,1);
best_measured_enob = zeros(architecture_count,1);
operational_msa_dBFS = zeros(architecture_count,1);

for architecture_index = 1:architecture_count
    [best_sinad_dB(architecture_index), best_index] = ...
        max(sinad_dB(:,architecture_index));
    best_level_dBFS(architecture_index) = input_levels_dBFS(best_index);
    best_measured_enob(architecture_index) = ...
        measured_enob(best_index,architecture_index);
    acceptable = sinad_dB(:,architecture_index) >= ...
        best_sinad_dB(architecture_index)-3;
    operational_msa_dBFS(architecture_index) = ...
        max(input_levels_dBFS(acceptable));
end

comparison.best_by_architecture = table( ...
    string(architecture_labels(:)), best_level_dBFS, best_sinad_dB, ...
    best_measured_enob, operational_msa_dBFS, ...
    'VariableNames', {'Architecture', 'Best_Input_Level_dBFS', ...
    'Peak_Inband_SINAD_dB', 'Peak_Measured_ENOB', ...
    'Operational_MSA_dBFS'});
disp(comparison.best_by_architecture);

if make_plot
    figure('Name', sprintf( ...
        'Input-level sweep, Nyquist rate %.0f Hz', nyquist_rate_Hz));
    plot(input_levels_dBFS, measured_enob, 'o-', 'LineWidth', 1.3);
    grid on;
    xlabel('Input level (dBFS)');
    ylabel('Measured ENOB (bits)');
    title(sprintf('Filter B at %.0f ksps Nyquist rate', ...
        nyquist_rate_Hz/1000));
    legend(architecture_labels, 'Location', 'best');
    drawnow;
end
end
