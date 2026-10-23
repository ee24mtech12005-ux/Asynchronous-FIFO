// Dual-port memory: write on wclk, asynchronous (combinational) read
module fifo_mem #(parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 4) (
    input  wire                  wclk,
    input  wire                  wen,
    input  wire                  full,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [ADDR_WIDTH-1:0] raddr,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire [DATA_WIDTH-1:0] rdata
);
    localparam DEPTH = 1 << ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    assign rdata = mem[raddr];

    always @(posedge wclk)
        if (wen && !full)
            mem[waddr] <= wdata;
endmodule
