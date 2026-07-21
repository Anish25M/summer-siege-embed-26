function results = delta_sigma_adc(nyquist_rate_Hz, make_plots)
%DELTA_SIGMA_ADC Run the delta-sigma ADC architecture comparison.
%   RESULTS = DELTA_SIGMA_ADC(NYQUIST_RATE_HZ, MAKE_PLOTS) evaluates one
%   Nyquist-rate point or a vector of points. Calling DELTA_SIGMA_ADC with
%   no inputs runs the selected 2 ksps point and the required rate sweep.

delta_sigma_adc_setup();

if nargin == 0
    results = struct();
    results.selected_2ksps = delta_sigma_adc(2000, true);
    results.required_tradeoff = ds_run_common_signal_tradeoff( ...
        500:250:2000, -6, true);
    return;
end

if nargin < 2
    make_plots = true;
end

if ~isscalar(nyquist_rate_Hz)
    results = ds_run_common_signal_tradeoff( ...
        nyquist_rate_Hz, -6, make_plots);
    return;
end

cfg = ds_default_config(nyquist_rate_Hz);
signal = ds_generate_signal(cfg);
modulators = ds_run_modulators(signal.vin, cfg);
filters = ds_design_filters(cfg);
filtered = ds_filter_and_decimate(modulators, filters, cfg);
results = ds_measure_performance(filtered, filters, cfg);
integer_filter = ds_filter_and_decimate_integer( ...
    modulators.mash_2_1, filters, cfg);
integer_performance = ds_coherent_inband_performance( ...
    integer_filter.output_normalized, ...
    cfg.simulation.measurement_output_samples, ...
    cfg.derived.output_rate_Hz, cfg.signal.tone_Hz, ...
    cfg.signal.bandwidth_Hz);
results.integer_filter = integer_filter;
results.by_architecture.mash_2_1.filter_B_integer = integer_performance;

if make_plots
    ds_print_summary(results, filters, cfg, false);
    ds_plot_results(modulators, filtered, filters, results, cfg);
end
end
