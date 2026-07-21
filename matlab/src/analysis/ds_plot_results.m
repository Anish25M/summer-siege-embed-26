function ds_plot_results(modulators, filtered, filters, results, cfg)
%DS_PLOT_RESULTS Plot settled spectra and decimation-filter responses.

Fs = cfg.derived.sample_rate_Hz;
f_tone = cfg.signal.tone_Hz;
f_band = cfg.signal.bandwidth_Hz;
names = modulators.architecture_names;
labels = modulators.architecture_labels;
architecture_count = numel(names);

raw_count = cfg.simulation.measurement_output_samples * ...
    cfg.derived.total_decimation;
n_meas_A = results.measurement_sample_count_A;
n_meas_B = results.measurement_sample_count_B;

figure('Position', [50 50 1400 1050], ...
    'Name', sprintf('Delta-Sigma Pipeline, Nyquist rate %.0f Hz', ...
    cfg.spec.nyquist_rate_Hz));

for row = 1:architecture_count
    name = names{row};
    raw = modulators.(name);
    raw = raw(end-raw_count+1:end);
    signal_A = filtered.A.(name);
    signal_A = signal_A(end-n_meas_A+1:end);
    signal_B = filtered.B.(name);
    signal_B = signal_B(end-n_meas_B+1:end);

    [frequency_raw, power_raw] = display_spectrum(raw, Fs);
    [frequency_A, power_A] = display_spectrum(signal_A, results.Fout_A);
    [frequency_B, power_B] = display_spectrum(signal_B, results.Fout_B);
    spectra = { ...
        {frequency_raw, power_raw}, ...
        {frequency_A, power_A}, ...
        {frequency_B, power_B}};

    panel_titles = { ...
        [labels{row} ': raw output'], ...
        [labels{row} ': Filter A'], ...
        [labels{row} ': Filter B']};

    for column = 1:3
        subplot(architecture_count, 3, (row-1)*3+column);
        plot(spectra{column}{1}, spectra{column}{2}, 'LineWidth', 1);
        grid on;
        set(gca, 'XScale', 'log');
        xlim([20 max(spectra{column}{1})]);
        ylim([-180 10]);
        title(panel_titles{column});
        ylabel('Power (dB)');

        if column == 1
            xlabel('Frequency (Hz)');
        else
            if column == 2
                performance = results.by_architecture.(name).filter_A;
            else
                performance = results.by_architecture.(name).filter_B;
            end
            xlabel(sprintf('Measured ENOB %.2f bits', ...
                performance.measured_enob), ...
                'FontWeight', 'bold');
            xline(f_band, '--k');
        end
    end
end
drawnow;

frequency_Hz = filters.response.frequency_Hz;
response_A_dB = filters.response.A_dB;
response_B_dB = filters.response.B_dB;
response_B_quantized_dB = filters.response.B_quantized_dB;
alias_stop_start = results.Fout_A-f_band;
response_limit = min(Fs/2, max(4*f_band, 1.15*alias_stop_start));

figure('Position', [120 120 1200 760], ...
    'Name', sprintf('Decimation filters, Nyquist rate %.0f Hz', ...
    cfg.spec.nyquist_rate_Hz));

subplot(2,1,1);
plot(frequency_Hz, response_A_dB, 'LineWidth', 1.5);
hold on;
plot(frequency_Hz, response_B_dB, 'LineWidth', 1.5);
plot(frequency_Hz, response_B_quantized_dB, '-.', 'LineWidth', 1.1);
plot(frequency_Hz, filters.response.B_cic_dB, '--', 'LineWidth', 1.0);
plot(frequency_Hz, filters.response.B_fir_dB, ':', 'LineWidth', 1.2);
xline(f_tone, '-.k', sprintf('tone = %.0f Hz', f_tone));
xline(f_band, '--k', sprintf('band edge = %.0f Hz', f_band));
hold off;
grid on;
xlim([0 1.25*f_band]);
passband_display = frequency_Hz <= 1.25*f_band;
minimum_passband_response = min([ ...
    response_A_dB(passband_display); ...
    response_B_dB(passband_display)]);
ylim([min(-1, floor(minimum_passband_response)-1) 0.5]);
ylabel('Magnitude (dB)');
title(sprintf(['Passband detail: tone gains A %.2f dB, B %.2f dB; ' ...
               'band droop A %.2f dB, B %.2f dB'], ...
    results.gain_at_tone_dB(1), results.gain_at_tone_dB(2), ...
    results.passband_droop_dB(1), results.passband_droop_dB(2)));
quantized_filter_label = sprintf('B: CIC + FIR (Q1.%d)', ...
    results.FIR_coefficient_fractional_bits);
legend('A: CIC', 'B: CIC + FIR (float)', ...
    quantized_filter_label, 'B: CIC stage', 'B: FIR stage', ...
    'Location', 'southwest');

subplot(2,1,2);
plot(frequency_Hz, response_A_dB, 'LineWidth', 1.3);
hold on;
plot(frequency_Hz, response_B_dB, 'LineWidth', 1.3);
plot(frequency_Hz, response_B_quantized_dB, '-.', 'LineWidth', 1.1);
xline(f_band, '--k', 'passband edge');
xline(alias_stop_start, '-.r', 'alias stopband begins');
hold off;
grid on;
xlim([0 response_limit]);
ylim([-180 5]);
xlabel('Input-referred frequency (Hz)');
ylabel('Magnitude (dB)');
title(sprintf('Overall anti-alias response before decimation by %d', ...
    filters.B.total_decimation));
legend('A: CIC', 'B: CIC + FIR (float)', ...
    quantized_filter_label, 'Location', 'southwest');
drawnow;
end

function [frequency_Hz, power_dB] = display_spectrum(x, sample_rate)
N = numel(x);
window = hann(N)';
X = fft(x.*window)/(sum(window)/2);
power = abs(X(1:floor(N/2)+1)).^2/2;
frequency_Hz = (0:floor(N/2))*sample_rate/N;
power_dB = 10*log10(power+1e-18);
end
