// Two-flop synchronizer: moves a multi-bit GRAY-CODED pointer across clock domains
module sync_2ff #(parameter WIDTH = 5) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] d_in,
    output reg  [WIDTH-1:0] d_out
);
    reg [WIDTH-1:0] q1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1    <= {WIDTH{1'b0}};
            d_out <= {WIDTH{1'b0}};
        end else begin
            q1    <= d_in;
            d_out <= q1;
        end
    end
endmodule
