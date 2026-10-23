// Write-pointer & FULL generation (write clock domain)
// Pointer is ADDR_WIDTH+1 bits: extra MSB distinguishes full from empty.
module wptr_full #(parameter ADDR_WIDTH = 4) (
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,
    input  wire [ADDR_WIDTH:0]   rptr_gray_sync,   // read pointer synced into wclk
    output reg                   wfull,
    output wire [ADDR_WIDTH-1:0] waddr,
    output reg  [ADDR_WIDTH:0]   wptr_gray
);
    reg  [ADDR_WIDTH:0] wbin;
    wire [ADDR_WIDTH:0] wbin_next, wgray_next;
    wire                wfull_val;

    assign waddr      = wbin[ADDR_WIDTH-1:0];
    assign wbin_next  = wbin + (winc & ~wfull);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;   // binary -> Gray

    // FULL: next write Gray ptr equals synced read Gray ptr with the top TWO bits inverted
    assign wfull_val = (wgray_next == {~rptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
                                        rptr_gray_sync[ADDR_WIDTH-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin      <= 0;
            wptr_gray <= 0;
            wfull     <= 1'b0;
        end else begin
            wbin      <= wbin_next;
            wptr_gray <= wgray_next;
            wfull     <= wfull_val;
        end
    end
endmodule
