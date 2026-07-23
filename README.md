# 20-Bit Delta-Sigma ADC Study and RTL Decimation Filter

This project studies, simulates, and implements the digital filtering path for a
20-bit delta-sigma ADC. The work compares delta-sigma modulator choices across
Nyquist sampling rates from 0.5 ksps to 2 ksps, targets 16-19 ENOB, and provides
a Verilog RTL implementation of the selected digital decimation filter.

The final selected signal chain is:

```text
Analog input model
  -> discrete-time MASH 2-1 delta-sigma modulator
  -> signed 6-bit digitally-cancelled modulator stream
  -> fourth-order CIC decimator by 16
  -> 64-tap FIR decimator by 4
  -> signed 20-bit ADC output code
```

The MATLAB model is the system-level and bit-true reference. The Verilog module
implements the CIC/FIR decimation filter and is checked against MATLAB-generated
golden vectors.

## Project Aims

- Model and simulate a 20-bit delta-sigma ADC.
- Study the trade-off between Nyquist sampling rate and ENOB using a common
  signal set from 0.5 ksps to 2 ksps.
- Compare candidate delta-sigma modulator and decimation-filter choices.
- Design a digital decimation filter equivalent to the MATLAB model.
- Implement and simulate the decimation filter at RTL using Verilog.

## Repository Layout

```text
matlab/
  delta_sigma_adc.m                 Main MATLAB entry point for simulations
  delta_sigma_adc_setup.m           Adds MATLAB source folders to the path
  export_rtl_test_vectors.m         Writes Verilog stimulus, coefficients, and golden outputs
  plot_matlab_verilog_outputs.m     Compares Verilog output against MATLAB reference
  src/
    core/                           Configuration, signal generation, modulators, metrics
    filters/                        CIC/FIR design, integer filter model, output quantization
    analysis/                       ENOB sweeps, plots, summaries, design studies

rtl_vectors/
  coeffs.hex                        FIR coefficient ROM contents for Verilog
  mash_combined_twos_complement.mem Signed 6-bit RTL input stimulus
  output_codes_20bit_twos_complement.mem
                                    Golden signed 20-bit MATLAB output codes

verilog/
  digital_filter_5bit.v             Verilog CIC + FIR decimation filter
  testbench.v                       Testbench using MATLAB-generated vectors

README.md                           Project overview and run instructions
```

Generated simulator files such as `sim.out`, `dump.vcd`, `sim_console.log`, and
`verilog_output_codes.csv` are intentionally not kept in the repository. They
are recreated when the Verilog simulation is run.

## MATLAB Model

Run MATLAB from the `matlab/` folder.

```matlab
results = delta_sigma_adc;
```

With no arguments, `delta_sigma_adc` runs the final 2 ksps design and the
required 0.5-2 ksps ENOB sweep. The main steps are:

1. `ds_default_config` defines ADC, modulator, signal, and decimator settings.
2. `ds_generate_signal` creates the coherent input sine wave and optional input
   noise.
3. `ds_run_modulators` evaluates candidate delta-sigma modulators.
4. `ds_design_filters` builds the CIC/FIR decimation filter coefficients.
5. `ds_filter_and_decimate` runs the floating-point reference filter path.
6. `ds_filter_and_decimate_integer` runs the bit-true integer reference used for
   RTL comparison.
7. `ds_measure_performance` computes SINAD and ENOB.

To run only the required rate sweep without plots:

```matlab
study = delta_sigma_adc(500:250:2000, false);
```

To compare the noise-budgeted and ideal cases:

```matlab
budgeted = delta_sigma_adc(500:250:2000, false, true);
ideal = delta_sigma_adc(500:250:2000, false, false);
```

## Selected Design

| Item | Value |
| --- | --- |
| ADC target resolution | 20-bit signed output |
| Modulator | Discrete-time MASH 2-1 |
| Modulator stages | Two 1-bit stages |
| MASH interstage gain | 0.25 |
| Modulator clock | 256 kHz |
| Input tone | 125 Hz coherent sine |
| Input level | -6 dBFS |
| Decimator | CIC by 16 followed by FIR by 4 |
| CIC order | 4 |
| FIR length | 64 taps |
| Output sample rate | 4 ksps for the 2 ksps Nyquist case |
| FIR coefficient format | Signed 24-bit Q1.23 |

The MASH 2-1 architecture was selected because it stayed within the target
16-19 ENOB range over the required Nyquist-rate sweep, while also matching the
fixed digital filter structure used for RTL implementation.

## RTL Vector Export

The Verilog simulation uses deterministic vectors exported from MATLAB.

```matlab
manifest = export_rtl_test_vectors;
```

This writes the files in `rtl_vectors/`:

- `mash_combined_twos_complement.mem`: signed 6-bit filter input samples.
- `coeffs.hex`: 64 signed 24-bit FIR coefficients.
- `output_codes_20bit_twos_complement.mem`: golden signed 20-bit final outputs.

These files are kept because they are the source stimulus and reference outputs
for the RTL testbench.

## Verilog RTL

The RTL is in `verilog/digital_filter_5bit.v`. The top-level module is
`digital_filter`, with these ports:

```verilog
module digital_filter(
    input fastclk,
    input signed [5:0] bitstream,
    input rst_n,
    output signed [19:0] digital_out,
    output data_valid,
    output overflow
);
```

Internally, the filter contains:

- `CIC_filter`: four integrator stages, decimation by 16, and four comb stages.
- `FIR_filter`: 64-tap multiply-accumulate FIR stage with decimation by 4.
- Output scaling, rounding, and saturation to signed 20-bit ADC codes.

The testbench in `verilog/testbench.v` reads
`../rtl_vectors/mash_combined_twos_complement.mem`, applies the samples at the
256 kHz modulator clock rate, and prints valid 20-bit output samples.

## Run RTL Simulation

From the `verilog/` folder:

```powershell
iverilog -g2012 -o sim.out digital_filter_5bit.v testbench.v
vvp sim.out
```

The simulation may generate:

- `sim.out`: compiled Icarus Verilog simulation executable.
- `dump.vcd`: waveform dump for GTKWave or another waveform viewer.
- console output containing the produced output codes.

If the console output is redirected to `sim_console.log` or converted into
`verilog_output_codes.csv`, those files are generated analysis artifacts and can
be deleted after comparison.

## MATLAB-Verilog Comparison

After running the Verilog testbench and saving the RTL output codes, run:

```matlab
cd matlab
metrics = plot_matlab_verilog_outputs;
```

The script aligns the MATLAB and Verilog output sequences, estimates latency,
computes error metrics, and can create a comparison plot. The expected result is
that the Verilog decimation output matches the MATLAB bit-true reference after
pipeline latency alignment.

## Requirements

- MATLAB R2025a or compatible version
- Signal Processing Toolbox
- Icarus Verilog for RTL simulation
- Optional: GTKWave for viewing `dump.vcd`

## Notes

This repository is organized as a finished project handoff. MATLAB files define
the reference model and design studies, `rtl_vectors/` contains the reusable
test vectors, and `verilog/` contains the RTL implementation plus testbench.
Generated logs, waveforms, compiled simulator outputs, and temporary comparison
exports are not part of the permanent source.
