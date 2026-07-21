function [y, details] = ds_run_mash_2_1( ...
    x, dither_stage1, dither_stage2, interstage_gain)
%DS_RUN_MASH_2_1 Simulate a 2-1 MASH with matched digital cancellation.

N = numel(x);
stage1_integrator1 = zeros(1,N);
stage1_integrator2 = zeros(1,N);
stage2_integrator1 = zeros(1,N);
stage1_output = zeros(1,N);
stage2_output = zeros(1,N);
stage1_error = zeros(1,N);
stage2_input = zeros(1,N);

for n = 1:N
    if n == 1
        previous_output = 0;
        previous_integrator1 = 0;
        previous_integrator2 = 0;
    else
        previous_output = stage1_output(n-1);
        previous_integrator1 = stage1_integrator1(n-1);
        previous_integrator2 = stage1_integrator2(n-1);
    end

    stage1_integrator1(n) = previous_integrator1 + x(n) - previous_output;
    stage1_integrator2(n) = previous_integrator2 + ...
        stage1_integrator1(n) - previous_output;
    stage1_output(n) = bipolar_quantizer( ...
        stage1_integrator2(n)+dither_stage1(n));
    stage1_error(n) = stage1_output(n)-stage1_integrator2(n);
    stage2_input(n) = interstage_gain*stage1_error(n);
end

for n = 1:N
    if n == 1
        previous_output = 0;
        previous_integrator = 0;
    else
        previous_output = stage2_output(n-1);
        previous_integrator = stage2_integrator1(n-1);
    end

    stage2_integrator1(n) = previous_integrator + ...
        stage2_input(n) - previous_output;
    stage2_output(n) = bipolar_quantizer( ...
        stage2_integrator1(n)+dither_stage2(n));
end

y = zeros(1,N);
for n = 3:N
    second_difference = stage2_output(n) ...
        - 2*stage2_output(n-1) + stage2_output(n-2);
    y(n) = stage1_output(n)-second_difference/interstage_gain;
end

details.stage1_output = stage1_output;
details.stage2_output = stage2_output;
details.stage1_quantization_error = stage1_error;
details.stage2_input = stage2_input;
details.stage1_integrator1 = stage1_integrator1;
details.stage1_integrator2 = stage1_integrator2;
details.stage2_integrator1 = stage2_integrator1;
details.interstage_gain = interstage_gain;
end

function y = bipolar_quantizer(value)
y = 2*double(value >= 0)-1;
end
