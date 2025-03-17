//This only works if the distance between the two input pulses is guaranteed to be at least 1.5X the receiving clock period
//If the distance between two input pulses is less, or a pulse is longer than a clock cycle, this won't work
module pulse_sync (
    input logic clk_in,
    input logic resetn,
    input logic din,
    input logic clk_out,
    output logic dout
);
logic       din_toggle;
logic [2:0] din_toggle_sync;

assign dout = din_toggle_sync[2] ^ din_toggle_sync[1];

always_ff @(posedge clk_in or negedge resetn) begin
    if(!resetn)
        din_toggle <= '0;
    else
        din_toggle <= din_toggle ^ din;
end
always_ff @(posdge clk_out or negedge resetn) begin
    if(!resetn)
        din_toggle_sync <= '0;
    else
        din_toggle_sync <= {din_toggle_sync[1:0], din_toggle};
end

endmodule