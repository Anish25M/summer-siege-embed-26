function outputs = ds_run_modulators(vin, cfg)
%DS_RUN_MODULATORS Simulate each candidate modulator architecture.

rng(cfg.modulator.random_seed);
N = numel(vin);
dither_amplitude = cfg.modulator.dither_amplitude;

dither_first = dither_amplitude*(rand(1,N)-0.5);
outputs.first_order = run_first_order(vin, dither_first);

dither_second = dither_amplitude*(rand(1,N)-0.5);
outputs.second_order = run_second_order(vin, dither_second);

dither_mash_stage1 = dither_amplitude*(rand(1,N)-0.5);
dither_mash_stage2 = dither_amplitude*(rand(1,N)-0.5);
[outputs.mash_2_1, outputs.mash_details] = ds_run_mash_2_1( ...
    vin, dither_mash_stage1, dither_mash_stage2, ...
    cfg.modulator.mash_interstage_gain);

dither_third = dither_amplitude*(rand(1,N)-0.5);
[outputs.third_order_single_loop, outputs.third_details] = ...
    ds_run_third_order_single_loop( ...
    vin, dither_third, cfg.modulator.third_order_ntf_pole);

outputs.architecture_names = { ...
    'first_order', ...
    'second_order', ...
    'third_order_single_loop', ...
    'mash_2_1'};
outputs.architecture_labels = { ...
    '1st-order single loop', ...
    '2nd-order single loop', ...
    '3rd-order single loop', ...
    'MASH 2-1'};
end

function y = run_first_order(x, dither)
N = numel(x);
integrator1 = 0;
y = zeros(1,N);

for n = 1:N
    if n == 1
        feedback = 0;
    else
        feedback = y(n-1);
    end
    integrator1 = integrator1 + x(n) - feedback;
    y(n) = bipolar_quantizer(integrator1 + dither(n));
end
end

function y = run_second_order(x, dither)
N = numel(x);
integrator1 = 0;
integrator2 = 0;
y = zeros(1,N);

for n = 1:N
    if n == 1
        feedback = 0;
    else
        feedback = y(n-1);
    end
    integrator1 = integrator1 + x(n) - feedback;
    integrator2 = integrator2 + integrator1 - feedback;
    y(n) = bipolar_quantizer(integrator2 + dither(n));
end
end

function y = bipolar_quantizer(value)
y = 2*double(value >= 0) - 1;
end
