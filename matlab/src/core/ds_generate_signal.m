function signal = ds_generate_signal(cfg)
%DS_GENERATE_SIGNAL Build a settled record coherent at the ADC output rate.

total_output_samples = cfg.simulation.measurement_output_samples + ...
    cfg.simulation.settling_output_samples;
N = total_output_samples*cfg.derived.total_decimation;
Fs = cfg.derived.sample_rate_Hz;

signal.sample_count = N;
signal.time_s = (0:N-1)/Fs;
signal.ideal_vin = cfg.signal.amplitude * ...
    sin(2*pi*cfg.signal.tone_Hz*signal.time_s);

if cfg.analog.enable_input_noise
    rng(cfg.analog.input_noise_seed);
    noise_standard_deviation = ...
        cfg.analog.input_noise_density_FS_per_sqrt_Hz * sqrt(Fs/2);
    signal.input_noise = noise_standard_deviation*randn(1,N);
else
    noise_standard_deviation = 0;
    signal.input_noise = zeros(1,N);
end

signal.input_noise_standard_deviation = noise_standard_deviation;
signal.vin = signal.ideal_vin+signal.input_noise;
end
