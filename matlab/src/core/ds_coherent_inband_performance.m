function performance = ds_coherent_inband_performance( ...
    signal, measurement_count, sample_rate, tone_Hz, bandwidth_Hz)
%DS_COHERENT_INBAND_PERFORMANCE Measure one coherent in-band record.

x = signal(end-measurement_count+1:end);
x = x-mean(x);
N = numel(x);
X = fft(x)/N;
power = abs(X(1:floor(N/2)+1)).^2;
if N > 2
    power(2:end-1) = 2*power(2:end-1);
end
frequency_Hz = (0:floor(N/2))*sample_rate/N;

[~, tone_bin] = min(abs(frequency_Hz-tone_Hz));
band_bins = find(frequency_Hz <= bandwidth_Hz + 10*eps(bandwidth_Hz));
unwanted_bins = setdiff(band_bins, [1 tone_bin]);
signal_power = power(tone_bin);
unwanted_power = sum(power(unwanted_bins));
sinad_dB = 10*log10(signal_power/unwanted_power);

performance.inband_sinad_dB = sinad_dB;
performance.measured_enob = (sinad_dB-1.76)/6.02;
performance.signal_power = signal_power;
performance.unwanted_power = unwanted_power;
performance.tone_bin = tone_bin;
end
