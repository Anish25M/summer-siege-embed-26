function metrics = plot_matlab_verilog_outputs(output_filename)
%PLOT_MATLAB_VERILOG_OUTPUTS Align and compare MATLAB and Verilog outputs.
%   Run the Verilog simulation first from the verilog directory so that
%   verilog_output_codes.csv exists.

matlab_directory = fileparts(mfilename('fullpath'));
repository_directory = fullfile(matlab_directory, '..');
golden_filename = fullfile(repository_directory, 'rtl_vectors', ...
    'output_codes_20bit_twos_complement.mem');
verilog_filename = fullfile(repository_directory, 'verilog', ...
    'verilog_output_codes.csv');

if nargin < 1 || isempty(output_filename)
    output_filename = fullfile(repository_directory, 'verilog', ...
        'matlab_verilog_comparison.png');
end
if ~isfile(golden_filename)
    error('MATLAB golden output is missing: %s', golden_filename);
end
if ~isfile(verilog_filename)
    error(['Verilog output is missing: %s\nRun "vvp sim.out" from the ' ...
        'verilog directory first.'], verilog_filename);
end

word_length = 20;
matlab_output = decode_signed_hex(readlines(golden_filename), word_length);

verilog_lines = strip(readlines(verilog_filename));
verilog_lines = verilog_lines(strlength(verilog_lines) > 0);
verilog_rows = split(verilog_lines, ',');
if size(verilog_rows, 2) ~= 2
    error('Expected index,hex rows in %s.', verilog_filename);
end
verilog_output = decode_signed_hex(verilog_rows(:, 2), word_length);

sample_count = min(numel(matlab_output), numel(verilog_output));
matlab_output = matlab_output(1:sample_count);
verilog_output = verilog_output(1:sample_count);

maximum_lag = min(256, floor(sample_count/4));
lag = estimate_integer_lag(matlab_output, verilog_output, maximum_lag);
[matlab_aligned, verilog_aligned, matlab_indices] = ...
    align_by_lag(matlab_output, verilog_output, lag);

valid = isfinite(matlab_aligned) & isfinite(verilog_aligned);
error_codes = verilog_aligned(valid)-matlab_aligned(valid);
correlation_matrix = corrcoef( ...
    matlab_aligned(valid), verilog_aligned(valid));

metrics.lag_output_samples = lag;
metrics.compared_sample_count = nnz(valid);
metrics.correlation = correlation_matrix(1, 2);
metrics.rmse_codes = sqrt(mean(error_codes.^2));
metrics.maximum_absolute_error_codes = max(abs(error_codes));
metrics.exact_match_percent = 100*mean(error_codes == 0);
metrics.gain_ratio = dot(matlab_aligned(valid), verilog_aligned(valid))/ ...
    dot(matlab_aligned(valid), matlab_aligned(valid));
metrics.gain_error_percent = 100*(metrics.gain_ratio-1);

figure_handle = figure('Color', 'w', 'Position', [100 100 1200 720]);
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
layout_title = title(layout, sprintf( ...
    'MATLAB versus Verilog: aligned by %+d output samples', lag));
layout_title.Color = 'k';

zoom_start = min(1024, max(matlab_indices));
zoom = valid & matlab_indices >= zoom_start & ...
    matlab_indices < zoom_start+256;

overlay_axes = nexttile;
plot(matlab_indices(zoom), matlab_aligned(zoom), 'LineWidth', 1.3);
hold on;
plot(matlab_indices(zoom), verilog_aligned(zoom), '--', 'LineWidth', 1.2);
grid on;
xlabel('MATLAB output sample index');
ylabel('Signed 20-bit code');
overlay_legend = legend('MATLAB golden', 'Verilog aligned', ...
    'Location', 'best');
title('Aligned output waveforms (256-sample detail)');
style_axes(overlay_axes);
set(overlay_legend, 'Color', 'w', 'TextColor', 'k', 'EdgeColor', [0.7 0.7 0.7]);

error_axes = nexttile;
plot(matlab_indices(valid), error_codes, 'LineWidth', 0.9);
grid on;
xlabel('MATLAB output sample index');
ylabel('Verilog - MATLAB (codes)');
title(sprintf(['Error: correlation %.8f, RMSE %.1f codes, gain error ' ...
    '%+.3f%%'], metrics.correlation, metrics.rmse_codes, ...
    metrics.gain_error_percent));
style_axes(error_axes);

exportgraphics(figure_handle, output_filename, 'Resolution', 160);
fprintf('Estimated Verilog lag: %+d output samples\n', lag);
fprintf('Correlation: %.10f\n', metrics.correlation);
fprintf('RMSE: %.6f codes\n', metrics.rmse_codes);
fprintf('Maximum absolute error: %.0f codes\n', ...
    metrics.maximum_absolute_error_codes);
fprintf('Exact matches after alignment: %.4f%%\n', ...
    metrics.exact_match_percent);
fprintf('Best-fit gain ratio: %.10f (%+.6f%%)\n', ...
    metrics.gain_ratio, metrics.gain_error_percent);
fprintf('Comparison graph written to %s\n', output_filename);
end

function values = decode_signed_hex(hexadecimal, word_length)
hexadecimal = strip(string(hexadecimal));
values = nan(size(hexadecimal));
valid = strlength(hexadecimal) > 0 & ...
    ~contains(lower(hexadecimal), 'x') & ...
    ~contains(lower(hexadecimal), 'z');
unsigned = hex2dec(hexadecimal(valid));
signed_values = unsigned;
negative = unsigned >= 2^(word_length-1);
signed_values(negative) = signed_values(negative)-2^word_length;
values(valid) = signed_values;
end

function best_lag = estimate_integer_lag(reference, candidate, maximum_lag)
best_lag = 0;
best_correlation = -Inf;
best_rmse = Inf;

for trial_lag = -maximum_lag:maximum_lag
    [reference_aligned, candidate_aligned] = ...
        align_by_lag(reference, candidate, trial_lag);
    valid = isfinite(reference_aligned) & isfinite(candidate_aligned);
    if nnz(valid) < 2
        continue;
    end

    correlation_matrix = corrcoef( ...
        reference_aligned(valid), candidate_aligned(valid));
    trial_correlation = correlation_matrix(1, 2);
    trial_rmse = sqrt(mean((candidate_aligned(valid)- ...
        reference_aligned(valid)).^2));

    if trial_correlation > best_correlation || ...
            (trial_correlation == best_correlation && trial_rmse < best_rmse)
        best_correlation = trial_correlation;
        best_rmse = trial_rmse;
        best_lag = trial_lag;
    end
end
end

function [reference_aligned, candidate_aligned, reference_indices] = ...
    align_by_lag(reference, candidate, lag)
if lag >= 0
    reference_aligned = reference(1:end-lag);
    candidate_aligned = candidate(1+lag:end);
    reference_indices = (0:numel(reference_aligned)-1)';
else
    reference_aligned = reference(1-lag:end);
    candidate_aligned = candidate(1:end+lag);
    reference_indices = (-lag:numel(reference)-1)';
end
end

function style_axes(axes_handle)
set(axes_handle, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'GridColor', [0.75 0.75 0.75], 'MinorGridColor', [0.85 0.85 0.85]);
axes_handle.Title.Color = 'k';
axes_handle.XLabel.Color = 'k';
axes_handle.YLabel.Color = 'k';
end
