function sweep = ds_run_third_order_pole_sweep( ...
    ntf_poles, nyquist_rate_Hz, input_level_dBFS, make_plot)
%DS_RUN_THIRD_ORDER_POLE_SWEEP Compare third-order NTF pole choices.

if nargin < 1
    ntf_poles = 0.5:0.05:0.9;
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

ntf_poles = ntf_poles(:);
cfg = ds_default_config(nyquist_rate_Hz);
cfg.analog.enable_input_noise = false;
cfg.signal.input_level_dBFS = input_level_dBFS;
cfg.signal.amplitude = cfg.signal.full_scale_peak * ...
    10^(input_level_dBFS/20);
signal = ds_generate_signal(cfg);
filters = ds_design_filters(cfg);

point_count = numel(ntf_poles);
measured_enob = zeros(point_count,1);
ntf_peak = zeros(point_count,1);
quantizer_input_peak = zeros(point_count,1);
feedback_output_peak = zeros(point_count,1);
numerically_stable = false(point_count,1);

rng(cfg.modulator.random_seed);
dither = cfg.modulator.dither_amplitude * ...
    (rand(1,signal.sample_count)-0.5);

for index = 1:point_count
    [output, details] = ds_run_third_order_single_loop( ...
        signal.vin, dither, ntf_poles(index));

    third_only.third_order_single_loop = output;
    third_only.architecture_names = {'third_order_single_loop'};
    third_only.architecture_labels = {'3rd-order single loop'};
    filtered = ds_filter_and_decimate(third_only, filters, cfg);
    results = ds_measure_performance(filtered, filters, cfg);
    performance = results.by_architecture.third_order_single_loop.filter_B;

    measured_enob(index) = performance.measured_enob;
    [response, ~] = freqz(details.ntf_numerator, ...
        details.ntf_denominator, 65536);
    ntf_peak(index) = max(abs(response));
    quantizer_input_peak(index) = max(abs(details.quantizer_input));
    feedback_output_peak(index) = max(abs(details.feedback_output));
    numerically_stable(index) = all(isfinite(details.feedback_output)) ...
        && feedback_output_peak(index) < 1e6;
end

sweep = table(ntf_poles, measured_enob, ...
    ntf_peak, quantizer_input_peak, feedback_output_peak, ...
    numerically_stable, ...
    'VariableNames', {'NTF_Pole', 'Measured_ENOB', 'NTF_Peak', ...
    'Quantizer_Input_Peak', 'Feedback_Output_Peak', ...
    'Numerically_Stable'});
disp(sweep);

if make_plot
    figure('Name', 'Third-order NTF pole sweep');
    yyaxis left;
    plot(ntf_poles, measured_enob, 'o-', 'LineWidth', 1.4);
    ylabel('Measured ENOB (bits)');
    yyaxis right;
    plot(ntf_poles, ntf_peak, 's-', 'LineWidth', 1.4);
    yline(1.5, '--', 'Lee guideline');
    ylabel('Peak NTF magnitude');
    grid on;
    xlabel('Repeated real NTF pole');
    title(sprintf('Third-order loop at %.1f ksps, %.1f dBFS', ...
        nyquist_rate_Hz/1000, input_level_dBFS));
    drawnow;
end
end
