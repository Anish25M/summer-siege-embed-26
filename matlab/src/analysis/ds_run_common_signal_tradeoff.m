function study = ds_run_common_signal_tradeoff( ...
    nyquist_rates_Hz, input_level_dBFS, make_plot)
%DS_RUN_COMMON_SIGNAL_TRADEOFF Compare architectures with one test policy.

if nargin < 1
    nyquist_rates_Hz = 500:250:2000;
end
if nargin < 2
    input_level_dBFS = -6;
end
if nargin < 3
    make_plot = true;
end

nyquist_rates_Hz = nyquist_rates_Hz(:);
architecture_names = {'first_order', 'second_order', ...
    'third_order_single_loop', 'mash_2_1'};
architecture_labels = {'1st-order single loop', ...
    '2nd-order single loop', '3rd-order single loop', 'MASH 2-1'};
architecture_count = numel(architecture_names);
measured_enob = zeros(numel(nyquist_rates_Hz),architecture_count);
tone_Hz = zeros(numel(nyquist_rates_Hz),1);
osr = zeros(numel(nyquist_rates_Hz),1);

for rate_index = 1:numel(nyquist_rates_Hz)
    cfg = ds_default_config(nyquist_rates_Hz(rate_index));
    cfg.signal.input_level_dBFS = input_level_dBFS;
    cfg.signal.amplitude = cfg.signal.full_scale_peak * ...
        10^(input_level_dBFS/20);
    signal = ds_generate_signal(cfg);
    modulators = ds_run_modulators(signal.vin,cfg);
    filters = ds_design_filters(cfg);
    filtered = ds_filter_and_decimate(modulators,filters,cfg);
    results = ds_measure_performance(filtered,filters,cfg);

    for architecture_index = 1:architecture_count
        name = architecture_names{architecture_index};
        performance = results.by_architecture.(name).filter_B;
        measured_enob(rate_index,architecture_index) = ...
            performance.measured_enob;
    end
    tone_Hz(rate_index) = cfg.signal.tone_Hz;
    osr(rate_index) = cfg.derived.osr;
end

study.nyquist_rates_Hz = nyquist_rates_Hz;
study.input_level_dBFS = input_level_dBFS;
study.architecture_names = architecture_names;
study.architecture_labels = architecture_labels;
study.measured_enob = measured_enob;
study.test_conditions = table(nyquist_rates_Hz,osr,tone_Hz, ...
    'VariableNames', {'Nyquist_Rate_Hz','OSR','Coherent_Tone_Hz'});
study.measured_table = array2table([nyquist_rates_Hz measured_enob], ...
    'VariableNames', {'Nyquist_Rate_Hz','First_Order_ENOB', ...
    'Second_Order_ENOB','Third_Order_ENOB','MASH_2_1_ENOB'});

mash_index = find(strcmp(architecture_names,'mash_2_1'),1);
mash_enob = measured_enob(:,mash_index);
study.mash_is_strictly_monotonic = all(diff(mash_enob)<0);
cfg_reference = ds_default_config(nyquist_rates_Hz(1));
tolerance_bits = 0.1;
study.mash_meets_target_range = all( ...
    mash_enob >= cfg_reference.spec.minimum_target_enob-tolerance_bits & ...
    mash_enob <= cfg_reference.spec.maximum_target_enob+tolerance_bits);

disp(study.test_conditions);
disp(study.measured_table);
fprintf('MASH monotonic: %s; measured ENOB within %.1f to %.1f bits: %s\n', ...
    string(study.mash_is_strictly_monotonic), ...
    cfg_reference.spec.minimum_target_enob, ...
    cfg_reference.spec.maximum_target_enob, ...
    string(study.mash_meets_target_range));

if make_plot
    figure('Name','Common-stimulus architecture trade-off');
    plot(nyquist_rates_Hz/1000,measured_enob,'o-','LineWidth',1.4);
    yline(cfg_reference.spec.minimum_target_enob,'--k','16-bit minimum');
    yline(cfg_reference.spec.maximum_target_enob,'--k','19-bit maximum');
    grid on;
    xlabel('Nyquist rate (ksps)');
    ylabel('Measured ENOB (bits)');
    title(sprintf('Common %.1f dBFS, %.1f Hz coherent tone', ...
        input_level_dBFS, tone_Hz(1)));
    legend(architecture_labels,'Location','best');
    drawnow;
end
end
