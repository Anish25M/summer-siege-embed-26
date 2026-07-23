`timescale 1ns / 1ps

module tb_digital_filter();
  
  reg fastclk;
  reg rst_n;
  reg signed [5:0] bitstream;
  wire signed [19:0] digital_out;
  wire data_valid;
  wire overflow;

  digital_filter DUT (
    .fastclk(fastclk),
    .bitstream(bitstream),
    .rst_n(rst_n),
    .digital_out(digital_out),
    .data_valid(data_valid),
    .overflow(overflow)
  );

 // for generating sampling clk frequency of 256KHz
  initial begin
    fastclk= 0;
    forever #1953.125 fastclk= ~fastclk; 
  end

  // IMPORTANT: Ensure this perfectly matches your .mem file line count
  parameter NUM_SAMPLES= 327680; 
  reg signed [5:0] input_mem [0:NUM_SAMPLES-1];
  integer i;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(1, tb_digital_filter);

    $readmemh("../rtl_vectors/mash_combined_twos_complement.mem", input_mem);

    rst_n= 0;
    bitstream= 6'd0;
    
    // Hold reset low for a few clock cycles
    #25; 
    rst_n= 1;
    
    $display("Starting MATLAB Vector Simulation...");
    
    for (i= 0; i<NUM_SAMPLES; i= i+1) begin
      @(posedge fastclk);
      bitstream= input_mem[i];
    end

    // wait for final calculations to flush through pipeline
    repeat(150) @(posedge fastclk);
    
    $display("Simulation Complete.");
    $finish;
  end

  // Print to console only when data_valid is strictly high
  always @(posedge fastclk) begin
    if (data_valid === 1'b1) begin
      $display("%h", digital_out);
    end
  end

endmodule
