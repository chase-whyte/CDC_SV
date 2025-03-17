//counts up to 2^(GC_CNTR_WIDTH)-1 single-cycle input pulses per output clock cycle
//dout is high for as many output clock cycles as there are single-cycle input pulses
//good for bursts of events in input clock domain
module pulse_sync_gc # (
    parameter CNTR_WIDTH = 2
    ) (
    input logic clk_in,
    input logic resetn,
    input logic din,
    input logic clk_out,
    output logic dout
);

logic [CNTR_WIDTH-1:0]      input_pulse_cntr;
logic [CNTR_WIDTH-1:0]      input_pulse_cntr_dv;
logic [CNTR_WIDTH-1:0]      input_pulse_cntr_gc;
logic [1:0][CNTR_WIDTH-1:0] input_pulse_cntr_gc_sync;
logic [CNTR_WIDTH-1:0]      input_pulse_cntr_sync_bin;
logic [CNTR_WIDTH-1:0]      input_pulse_cntr_sync_bin_prev;
logic [15:0]                output_pulse_cntr;


always_comb
    input_pulse_cntr_dv = input_pulse_cntr + din;

always_ff @(posdge clk_in or negedge resetn) begin
    if(!resetn) begin
        input_pulse_cntr <= '0;
        input_pulse_cntr_gc <= '0;
    end
    else begin
        input_pulse_cntr <= input_pulse_cntr_dv;
        input_pulse_cntr_gc <= input_pulse_cntr_dv ^ (input_pulse_cntr_dv >> 1);
    end
end

always_comb begin
    for(int i = 0; i < CNTR_WIDTH; i++)
        input_pulse_cntr_sync_bin[i] = ^(input_pulse_cntr_gc_sync[1] >> i);
end

always_comb
    dout = !(output_pulse_cntr == '0);

always_ff @(posdge clk_out or negedge resetn) begin
    if(!resetn) begin
        input_pulse_cntr_gc_sync       <= '0;
        output_pulse_cntr              <= '0;
        input_pulse_cntr_sync_bin_prev <= '0;
    end
    else begin
        input_pulse_cntr_gc_sync <= {input_pulse_cntr_gc_sync[1:0], input_pulse_cntr_gc};
        input_pulse_cntr_sync_bin_prev <= input_pulse_cntr_sync_bin;
        output_pulse_cntr <= output_pulse_cntr + input_pulse_cntr_sync_bin - input_pulse_cntr_sync_bin_prev - dout;
    end
end

endmodule