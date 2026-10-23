// Asynchronous FIFO (Cummings-style, Gray-code pointers + 2-FF synchronizers)
// Depth = 2**ADDR_WIDTH. Independent write and read clocks.
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4          // depth = 16
)(
    // write domain
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire                  wfull,
    // read domain
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  rempty
);
    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH:0]   wptr_gray, rptr_gray;
    wire [ADDR_WIDTH:0]   rptr_gray_sync, wptr_gray_sync;

    // read pointer -> write clock domain
    sync_2ff #(ADDR_WIDTH+1) u_sync_r2w (
        .clk(wclk), .rst_n(wrst_n), .d_in(rptr_gray), .d_out(rptr_gray_sync));

    // write pointer -> read clock domain
    sync_2ff #(ADDR_WIDTH+1) u_sync_w2r (
        .clk(rclk), .rst_n(rrst_n), .d_in(wptr_gray), .d_out(wptr_gray_sync));

    fifo_mem #(DATA_WIDTH, ADDR_WIDTH) u_mem (
        .wclk(wclk), .wen(winc), .full(wfull),
        .waddr(waddr), .raddr(raddr), .wdata(wdata), .rdata(rdata));

    wptr_full #(ADDR_WIDTH) u_wptr_full (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc),
        .rptr_gray_sync(rptr_gray_sync),
        .wfull(wfull), .waddr(waddr), .wptr_gray(wptr_gray));

    rptr_empty #(ADDR_WIDTH) u_rptr_empty (
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc),
        .wptr_gray_sync(wptr_gray_sync),
        .rempty(rempty), .raddr(raddr), .rptr_gray(rptr_gray));
endmodule
