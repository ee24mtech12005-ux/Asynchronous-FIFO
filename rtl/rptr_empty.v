// Read-pointer & EMPTY generation (read clock domain)
module rptr_empty #(parameter ADDR_WIDTH = 4) (
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,
    input  wire [ADDR_WIDTH:0]   wptr_gray_sync,   // write pointer synced into rclk
    output reg                   rempty,
    output wire [ADDR_WIDTH-1:0] raddr,
    output reg  [ADDR_WIDTH:0]   rptr_gray
);
    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next, rgray_next;
    wire                rempty_val;

    assign raddr      = rbin[ADDR_WIDTH-1:0];
    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    // EMPTY: next read Gray ptr equals synced write Gray ptr
    assign rempty_val = (rgray_next == wptr_gray_sync);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin      <= 0;
            rptr_gray <= 0;
            rempty    <= 1'b1;
        end else begin
            rbin      <= rbin_next;
            rptr_gray <= rgray_next;
            rempty    <= rempty_val;
        end
    end
endmodule
