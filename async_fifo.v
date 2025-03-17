//configurable async FIFO for AXI Stream interface
//if inputs or outputs are not used, the inputs can be driven to 0 and the outputs left unconnected
module async_fifo # (
    parameter DATA_WIDTH   = 32,
    parameter FIFO_DEPTH   = 32,
    parameter TUSER_WIDTH  = 1,
    parameter HAS_TID      = 0,
    parameter HAS_TDEST    = 0,
    parameter HAS_TUSER    = 0
) (
    input logic                   s_axis_aclk,
    input logic                   s_axis_resetn,
    input logic                   s_axis_tvalid,
    input logic [DATA_WIDTH-1:0]  s_axis_tdata,
    input logic [TKEEP_WIDTH-1:0] s_axis_tkeep,
    input logic                   s_axis_tlast,
    input logic [2:0]             s_axis_tid,
    input logic [TUSER_WIDTH-1:0] s_axis_tuser,
    input logic                   s_axis_tdest,
    output logic                  s_axis_tready,


    input logic                    m_axis_aclk,
    input logic                    m_axis_resetn,
    output logic                   m_axis_tvalid,
    output logic [DATA_WIDTH-1:0]  m_axis_tdata,
    output logic [TKEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                   m_axis_tlast,
    output logic [2:0]             m_axis_tid,
    output logic [TUSER_WIDTH-1:0] m_axis_tuser,
    output logic                   m_axis_tdest,
    input  logic                   m_axis_tready
);

localparam PTR_WIDTH      = $clog2(FIFO_DEPTH);
localparam TKEEP_WIDTH    = DATA_WIDTH >> 3;
localparam ACC_DATA_WIDTH = DATA_WIDTH + TKEEP_WIDTH + 1;


logic  [PTR_WIDTH:0] rd_ptr;
logic  [PTR_WIDTH:0] rd_ptr_dv;
logic  [PTR_WIDTH:0] g_rd_ptr;
logic  [PTR_WIDTH:0] g_rd_ptr_r1;
logic  [PTR_WIDTH:0] g_rd_ptr_r2;
logic  [PTR_WIDTH:0] g_rd_ptr_dv;
logic  [PTR_WIDTH:0] wr_ptr;
logic  [PTR_WIDTH:0] wr_ptr_dv;
logic  [PTR_WIDTH:0] g_wr_ptr;
logic  [PTR_WIDTH:0] g_wr_ptr_r1;
logic  [PTR_WIDTH:0] g_wr_ptr_r2;
logic  [PTR_WIDTH:0] g_wr_ptr_dv;
logic                m_axis_resetn_r1;
logic                m_axis_resetn_r2;
logic                s_axis_resetn_r1;
logic                s_axis_resetn_r2;

logic full;
logic empty;

async_fifo_mem #(
    .DATA_WIDTH(ACC_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) async_fifo_mem_i0 (
    .s_axis_aclk  (s_axis_aclk),
    .d_in         (s_axis_tdata),
    .wr_ptr       (wr_ptr),
    .rd_ptr       (rd_ptr),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .dout         (m_axis_tdata)
);


generate
if(HAS_TID) begin
    async_fifo_mem #(
        .DATA_WIDTH(3),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) async_fifo_mem_i2 (
        .s_axis_aclk  (s_axis_aclk),
        .d_in         (s_axis_tid),
        .wr_ptr       (wr_ptr),
        .rd_ptr       (rd_ptr),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .dout         (m_axis_tid)
    );
end
else assign m_axis_tid = 3'd0;
if(HAS_TDEST) begin
    async_fifo_mem #(
        .DATA_WIDTH(1),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) async_fifo_mem_i3 (
        .s_axis_aclk  (s_axis_aclk),
        .d_in         (s_axis_tdest),
        .wr_ptr       (wr_ptr),
        .rd_ptr       (rd_ptr),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .dout         (m_axis_tdest)
    );
end
else assign m_axis_tdest = 1'b0;
if(HAS_TUSER) begin
    async_fifo_mem #(
        .DATA_WIDTH(TUSER_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) async_fifo_mem_i4 (
        .s_axis_aclk  (s_axis_aclk),
        .d_in         (s_axis_tuser),
        .wr_ptr       (wr_ptr),
        .rd_ptr       (rd_ptr),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .dout         (m_axis_tuser)
    );
end
else assign m_axis_tuser = 'd0;
endgenerate

assign s_axis_tlast  = m_axis_tdata[ACC_DATA_WIDTH-1];
assign s_axis_tkeep  = m_axis_tdata[ACC_DATA_WIDTH-2:ACC_DATA_WIDTH-TKEEP_WIDTH-1];

always_comb begin
    rd_ptr_dv   = rd_ptr + (m_axis_tvalid & m_axis_tready);
    wr_ptr_dv   = wr_ptr + (s_axis_tvalid & s_axis_tready);
    g_rd_ptr_dv = rd_ptr_dv^(rd_ptr_dv >> 1);
    g_wr_ptr_dv = wr_ptr_dv^(wr_ptr_dv >> 1);
end

//m_axis_tvalid is not registered to reduce latency
always_comb begin
    empty = g_rd_ptr == g_wr_ptr_r2;
    m_axis_tvalid = !empty;
end

// s_axis_tready is registered so that its reset value will show not ready at startup
always_comb
    full  = g_rd_ptr_r2 == {~g_wr_ptr_dv[PTR_WIDTH:PTR_WIDTH-1], g_wr_ptr_dv[PTR_WIDTH-2:0]};

//s_axis_resetn is used as async reset in case tx clock is not active
//m_axis_resetn is synchronized so that both sides are reset
always_ff @(posedge s_axis_aclk or negedge s_axis_resetn) begin
    if(!s_axis_resetn) begin
        m_axis_resetn_r1 <= '0;
        m_axis_resetn_r2 <= '0;
    end
    if(!s_axis_resetn || !m_axis_resetn_r2) begin
        wr_ptr         <= 'd0;
        g_wr_ptr       <= 'd0;
        g_rd_ptr_r1    <= 'd0;
        g_rd_ptr_r2    <= 'd0;
        s_axis_tready  <= 'd0;
    end
    else begin
        g_wr_ptr         <= g_wr_ptr_dv;
        wr_ptr           <= wr_ptr_dv;
        g_rd_ptr_r1      <= g_rd_ptr;
        g_rd_ptr_r2      <= g_rd_ptr_r1;
        s_axis_tready    <= !full;
        m_axis_resetn_r1 <= m_axis_resetn;
        m_axis_resetn_r2 <= m_axis_resetn_r1;
    end
end

//m_axis_resetn is used as async reset in case tx clock is not active
//s_axis_resetn is synchronized so that both sides are reset
always_ff @(posedge m_axis_aclk or negedge m_axis_resetn) begin
    //reset value of 1 instead of 0 because it doesn't matter on TX side
    if(!m_axis_resetn) begin
        s_axis_resetn_r1 <= '1;
        s_axis_resetn_r2 <= '1;
    end
    if(!m_axis_resetn || !s_axis_resetn_r2) begin
        rd_ptr      <= 'd0;
        g_rd_ptr    <= 'd0;
        g_wr_ptr_r1 <= 'd0;
        g_wr_ptr_r2 <= 'd0;
    end
    else begin
        rd_ptr           <= rd_ptr_dv;
        g_rd_ptr         <= g_rd_ptr_dv;
        g_wr_ptr_r1      <= g_wr_ptr;
        g_wr_ptr_r2      <= g_wr_ptr_r1;
        s_axis_resetn_r1 <= s_axis_resetn;
        s_axis_resetn_r2 <= s_axis_resetn_r1;
    end
    
end

endmodule
