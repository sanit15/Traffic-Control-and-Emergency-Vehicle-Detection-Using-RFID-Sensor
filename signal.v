`timescale 1ns/1ps
module signal(
    input        clk,
    input        rst,
    input        force_green,
    input  [1:0] forced_lane,
    output reg   [1:0]  current_lane,
    output wire  [11:0] light_flat    // wire, not reg — no latch risk
);

localparam RED    = 3'b100;
localparam YELLOW = 3'b010;
localparam GREEN  = 3'b001;

localparam T_GREEN  = 4'd7;
localparam T_YELLOW = 4'd2;
localparam T_TOTAL  = T_GREEN + T_YELLOW; // 10

reg [3:0] count;

// ── sequential: counter + lane advance ───────────────────────────────────────
always @(posedge clk or posedge rst) begin
    if (rst) begin
        current_lane <= 2'd0;
        count        <= 4'd0;
    end else if (force_green) begin
        // FIX 2: snap current_lane to forced_lane so FSM is consistent
        // on release; counter held at 0 for a clean full phase on exit.
        current_lane <= forced_lane;
        //count        <= 4'd0;
    end else begin
        if (count >= T_TOTAL - 4'd1) begin
            count        <= 4'd0;
            current_lane <= current_lane + 2'd1;
        end else begin
            count <= count + 4'd1;
        end
    end
end

// ── combinational: per-lane light output ─────────────────────────────────────
wire [2:0] l0, l1, l2, l3;

assign l0 = (force_green && forced_lane == 2'd0)                           ? GREEN  :
            (!force_green && current_lane == 2'd0 && count < T_GREEN)      ? GREEN  :
            (!force_green && current_lane == 2'd0 && count < T_TOTAL)      ? YELLOW :
            RED;

assign l1 = (force_green && forced_lane == 2'd1)                           ? GREEN  :
            (!force_green && current_lane == 2'd1 && count < T_GREEN)      ? GREEN  :
            (!force_green && current_lane == 2'd1 && count < T_TOTAL)      ? YELLOW :
            RED;

assign l2 = (force_green && forced_lane == 2'd2)                           ? GREEN  :
            (!force_green && current_lane == 2'd2 && count < T_GREEN)      ? GREEN  :
            (!force_green && current_lane == 2'd2 && count < T_TOTAL)      ? YELLOW :
            RED;

assign l3 = (force_green && forced_lane == 2'd3)                           ? GREEN  :
            (!force_green && current_lane == 2'd3 && count < T_GREEN)      ? GREEN  :
            (!force_green && current_lane == 2'd3 && count < T_TOTAL)      ? YELLOW :
            RED;

assign light_flat = {l3, l2, l1, l0};

endmodule
