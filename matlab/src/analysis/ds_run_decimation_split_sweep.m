function comparison = ds_run_decimation_split_sweep(nyquist_rate_Hz, make_plot)
%DS_RUN_DECIMATION_SPLIT_SWEEP Compare factor pairs with total decimation 64.

if nargin < 1
    nyquist_rate_Hz = 2000;
end
if nargin < 2
    make_plot = true;
end

decimation_pairs = [2 32; 4 16; 8 8; 16 4; 32 2];
cfg_base = ds_default_config(nyquist_rate_Hz);
signal = ds_generate_signal(cfg_base);
all_modulators = ds_run_modulators(signal.vin, cfg_base);

modulators.mash_2_1 = all_modulators.mash_2_1;
modulators.architecture_names = {'mash_2_1'};
modulators.architecture_labels = {'MASH 2-1'};

candidate_count = size(decimation_pairs,1);
enob = zeros(candidate_count,1);
fir_order = zeros(candidate_count,1);
coefficient_count = zeros(candidate_count,1);
fir_input_rate_Hz = zeros(candidate_count,1);
cic_bit_growth = zeros(candidate_count,1);
passband_droop_dB = zeros(candidate_count,1);
quantized_passband_droop_dB = zeros(candidate_count,1);
quantized_attenuation_dB = zeros(candidate_count,1);
float_combined_attenuation_dB = zeros(candidate_count,1);
direct_form_multiplications_per_second = zeros(candidate_count,1);
polyphase_multiplications_per_second = zeros(candidate_count,1);

for index = 1:candidate_count
    cfg = cfg_base;
    cic_decimation = decimation_pairs(index,1);
    fir_decimation = decimation_pairs(index,2);
    cfg.filter.B.cic_decimation = cic_decimation;
    cfg.filter.B.fir_decimation = fir_decimation;
    cfg.filter.B.use_kaiser_estimated_order = true;

    filters = ds_design_filters(cfg);
    filtered = ds_filter_and_decimate(modulators, filters, cfg);
    results = ds_measure_performance(filtered, filters, cfg);

    enob(index) = results.by_architecture.mash_2_1.filter_B.enob;
    fir_order(index) = results.FIR_order;
    coefficient_count(index) = numel(results.FIR_coefficients);
    fir_input_rate_Hz(index) = results.Fs/cic_decimation;
    cic_bit_growth(index) = cfg.filter.cic_order * ...
        log2(cic_decimation*cfg.filter.differential_delay);
    passband_droop_dB(index) = results.passband_droop_dB(2);
    quantized_passband_droop_dB(index) = ...
        results.quantized_passband_droop_dB;
    quantized_attenuation_dB(index) = ...
        results.quantized_atten_at_Fstop_dB;
    float_combined_attenuation_dB(index) = ...
        results.combined_atten_dB;
    direct_form_multiplications_per_second(index) = ...
        coefficient_count(index)*fir_input_rate_Hz(index);
    polyphase_multiplications_per_second(index) = ...
        coefficient_count(index)*(results.Fs/filters.B.total_decimation);
end

comparison = table( ...
    decimation_pairs(:,1), decimation_pairs(:,2), enob, ...
    fir_order, coefficient_count, fir_input_rate_Hz, cic_bit_growth, ...
    passband_droop_dB, quantized_passband_droop_dB, ...
    quantized_attenuation_dB, float_combined_attenuation_dB, ...
    direct_form_multiplications_per_second, ...
    polyphase_multiplications_per_second, ...
    'VariableNames', { ...
        'CIC_Decimation', 'FIR_Decimation', 'MASH_Measured_ENOB', ...
        'FIR_Order', 'Coefficient_Count', 'FIR_Input_Rate_Hz', ...
        'CIC_Bit_Growth', 'Passband_Droop_dB', ...
        'Quantized_Passband_Droop_dB', ...
        'Quantized_Attenuation_dB', 'Float_Combined_Attenuation_dB', ...
        'Direct_Form_Multiplies_Per_Second', ...
        'Polyphase_Multiplies_Per_Second'});

disp(comparison);

if make_plot
    split_labels = string(decimation_pairs(:,1)) + " x " + ...
        string(decimation_pairs(:,2));
    figure('Name', sprintf( ...
        'MASH 2-1 decimation splits, Nyquist rate %.0f Hz', ...
        nyquist_rate_Hz));

    subplot(2,2,1);
    bar(categorical(split_labels), enob);
    grid on;
    ylabel('Measured ENOB (bits)');
    title('MASH 2-1 output performance');

    subplot(2,2,2);
    bar(categorical(split_labels), coefficient_count);
    grid on;
    ylabel('FIR coefficients');
    title('FIR size');

    subplot(2,2,3);
    bar(categorical(split_labels), passband_droop_dB);
    grid on;
    ylabel('Droop (dB)');
    title('Combined passband droop');

    subplot(2,2,4);
    yyaxis left;
    bar(categorical(split_labels), ...
        polyphase_multiplications_per_second/1e6);
    ylabel('Polyphase MMAC/s');
    yyaxis right;
    plot(categorical(split_labels), cic_bit_growth, 'o-', ...
        'LineWidth', 1.5);
    ylabel('CIC bit growth');
    grid on;
    title('Hardware cost indicators');
    drawnow;
end
end
