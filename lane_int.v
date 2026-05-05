module lane_int (
    input clk,
    input rst,
    output reg [1:0] dir
);

reg [3:0] timer;

parameter N = 2'd0,
          E = 2'd1,
          S = 2'd2,
          W = 2'd3;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dir   <= N;
        timer <= 0;
    end
    else begin
        if (timer == 9) begin
            timer <= 0;
            dir   <= dir + 1;
        end
        else begin
            timer <= timer + 1;
        end
    end
end

endmodule