//instantiates memory to be used for async fifo
module async_fifo_mem # (
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 32,
    parameter PTR_WIDTH = $clog2(FIFO_DEPTH)

) (
    input logic s_axis_aclk,
    input logic [DATA_WIDTH-1:0]  d_in,
    input logic [PTR_WIDTH-1:0]   wr_ptr,
    input logic [PTR_WIDTH-1:0]   rd_ptr,
    input logic                   s_axis_tvalid,
    input logic                   s_axis_tready,
    output logic [DATA_WIDTH-1:0] dout
);

logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];

assign dout = mem[rd_ptr];

always_ff @(posedge s_axis_aclk) begin
    if(s_axis_tvalid && s_axis_tready)
        mem[wr_ptr] <= d_in;
end


endmodule
