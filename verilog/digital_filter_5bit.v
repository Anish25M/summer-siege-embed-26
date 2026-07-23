// ==========================================
// delta sigma digital filter
// ==========================================

module digital_filter(input fastclk, 
                      input signed [5:0] bitstream, 
                      input rst_n,
                      output signed [19:0] digital_out,
                      output data_valid,overflow);
  wire signed [21:0] out_cic;
  wire signed [51:0] out_fir;
  wire signed [51:0] scaled_out;
  wire enable_cic;
 
  CIC_filter dec_16 (.fastclk(fastclk), 
                     .bitstream(bitstream),
                     .rst_n(rst_n), 
                     .out(out_cic), 
                     .enable_cic(enable_cic));
  
  FIR_filter dec_4 (.fastclk(fastclk),
    				.rst_n(rst_n),
  			   	    .enable_cic(enable_cic),  
  				    .in(out_cic),         
                    .out(out_fir),
                    .data_valid(data_valid));
  
  assign scaled_out= ($signed(out_fir)+(out_fir[51] ? 52'sd524287 : 52'sd524288)) >>> 20;
  assign digital_out= (scaled_out>52'sd524287) ? 20'h7FFFF :
                      (scaled_out<(-52'sd524288)) ? 20'h80000 :
                      scaled_out[19:0];
  assign overflow = (scaled_out > 52'sd524287) || (scaled_out < -52'sd524288);
 
endmodule







// ==========================================
//CIC filter
// ==========================================


module CIC_filter (input fastclk, input signed [5:0] bitstream, input rst_n,
                   output signed [21:0] out,
                   output enable_cic);
  
  wire signed [21:0] w0,w1,w2,w3,w4;
  assign w0= {{16{bitstream[5]}}, bitstream};
  
  integrator i1 (.fastclk(fastclk), .rst_n(rst_n), .in(w0), .out(w1));
  integrator i2 (.fastclk(fastclk), .rst_n(rst_n), .in(w1), .out(w2));
  integrator i3 (.fastclk(fastclk), .rst_n(rst_n), .in(w2), .out(w3));
  integrator i4 (.fastclk(fastclk), .rst_n(rst_n), .in(w3), .out(w4));
  
  wire [5:0] count;
  
  counter counting (.fastclk (fastclk),.rst_n(rst_n),.count(count));
  
  assign enable_cic= (count[3:0]==4'd15);
  
  wire signed [21:0] w5,w6,w7,w8;
  
  comb c1 (.enable(enable_cic), .rst_n(rst_n), .fastclk(fastclk), .in(w4), .out(w5));
  comb c2 (.enable(enable_cic), .rst_n(rst_n), .fastclk(fastclk), .in(w5), .out(w6));
  comb c3 (.enable(enable_cic), .rst_n(rst_n), .fastclk(fastclk), .in(w6), .out(w7));
  comb c4 (.enable(enable_cic), .rst_n(rst_n), .fastclk(fastclk), .in(w7), .out(w8));
  
  assign out=w8;
  
endmodule

module integrator (input fastclk,rst_n,
                   input signed [21:0] in,
                   output reg signed [21:0] out);
  
  always @(posedge fastclk or negedge rst_n) begin
    if (!rst_n) begin
      out<=22'sd0;
    end else begin
      out<=out+in;
    end
  end
endmodule

module comb (input enable,rst_n,fastclk,
             input signed [21:0] in,
             output reg signed [21:0] out);
  reg signed [21:0] r1;
  always @(posedge fastclk or negedge rst_n) begin
    if (!rst_n) begin
      r1<=22'sd0;
      out<=22'sd0;
    end else if (enable) begin
      r1<=in;
      out<=in-r1;
    end
  end
endmodule


module counter (input fastclk,rst_n,
                output reg [5:0] count);
  
  always @(posedge fastclk or negedge rst_n) begin
    if (!rst_n) begin
      count<=6'd0;
    end else begin
      count<=count+6'd1;
    end
  end
 
endmodule

// ==========================================
// FIR filter
// ==========================================

module FIR_filter (input fastclk,
                   input rst_n,
                   input enable_cic,
                   input signed [21:0] in,           
                   output reg signed [51:0] out,
                   output data_valid);

  // ------------------------------------------
  // Memory_Unit
  // ------------------------------------------
  reg signed [21:0] ram [0:63];
  reg signed [23:0] rom [0:63];

  initial begin
    $readmemh("../rtl_vectors/coeffs.hex", rom); 
  end

  // Write Pointer
  reg [5:0] write_pointer;
  
  always @(posedge fastclk or negedge rst_n) begin
    if (!rst_n) begin
      write_pointer<=6'd0;
    end else if (enable_cic) begin
      ram[write_pointer]<=in;
      write_pointer<=write_pointer+6'd1;
    end
  end
  
  // ------------------------------------------
  //Control_Unit
  // ------------------------------------------
  wire [5:0] mac_count;
  counter counting_mac (.fastclk (fastclk),.rst_n(rst_n),.count(mac_count));
  
  wire enable_fir;
  assign enable_fir= (mac_count==6'd0);
    
  reg [5:0] base_pointer;
  wire [5:0] read_pointer;
  
  always @(posedge fastclk) begin
    if(enable_fir) begin
      base_pointer<= write_pointer;
    end
  end
  
  assign read_pointer=base_pointer+mac_count;
  
  reg signed [23:0] coeff;
  reg signed [21:0] in_mul;
  
  always @(posedge fastclk) begin
    coeff<=rom[6'd63-mac_count];
    in_mul<=ram[read_pointer];
  end

  // ------------------------------------------
  //MAC_Unit
  // ------------------------------------------


  reg signed [51:0] mac_result;
  reg dat_valid;
  
  always @(posedge fastclk or negedge rst_n) begin
    if (!rst_n) begin
      mac_result<=52'd0;
      out<=52'd0;
      dat_valid<=1'b0;
    end else begin
      dat_valid<=enable_fir;
      if (enable_fir) begin
        out<= mac_result;
        mac_result<=52'd0;
      end else begin
        mac_result<=mac_result+coeff*in_mul;
      end
    end
  end

  assign data_valid=dat_valid;
  
endmodule
