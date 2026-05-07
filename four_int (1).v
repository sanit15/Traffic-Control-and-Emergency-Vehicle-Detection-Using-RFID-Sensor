`timescale 1ns/1ps

module four_int (
    input        clk,
    input        rst,

    input rx,

    output  [1:0] l0_dir,
    output  [1:0] l1_dir,
    output  [1:0] l2_dir,
    output  [1:0] l3_dir,

    output reg emg_active,
    output reg  [3:0] sensor   // sensor[i] = emergency detected at intersection i

);

parameter N=2'd0, E=2'd1, S=2'd2, W=2'd3;

wire [7:0] rx_data;
wire rx_ready;

uart_rx uart (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .data(rx_data),
    .ready(rx_ready)
);

wire [31:0] uid;
wire valid;

rfid_parser parser (
    .clk(clk),
    .rst(rst),
    .data_in(rx_data),
    .ready(rx_ready),
    .uid(uid),
    .valid(valid)
);

reg [31:0] timer;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        emg_active <= 0;
        sensor <= 4'd0;
        timer <= 0;
    end
    else begin

        // countdown timer
        if (timer != 0)
            timer <= timer - 1;
        else begin
            emg_active <= 0;
            sensor <= 4'd0;
        end

        // RFID emergency detection
        if (valid) begin
            if (uid == 32'h0100A354) begin
                emg_active <= 1;
                sensor[0] <= 1;
                timer <= 50000000*4;
            end
        end

    end
end

//////////////////////////////////////////////////
// L0 — wraps lane FSM; emergency overrides to East
//////////////////////////////////////////////////

wire [1:0] l0_dir_normal;

lane_int L0 (
    .clk(clk),
    .rst(rst),
    .dir(l0_dir_normal)
);

assign l0_dir = 
	(timer == 0) ? l0_dir_normal :
	sensor[0] ? W :
	l0_dir_normal;

//////////////////////////////////////////////////
// L1
//////////////////////////////////////////////////

reg [25:0] timer_l1;
reg [1:0] l1_state;

reg [25:0] delay1, travel1;
reg forcing1, force1;
reg [1:0] prev_l0;

// L1 normal FSM — paused during emergency or inter-lane force
always @(posedge clk or posedge rst) begin
    if (rst) begin
        l1_state <= N;
        timer_l1 <= 0;
    end
    else begin
        if (!forcing1 && !sensor[1]) begin
            if (timer_l1 == 50000000) begin
                timer_l1 <= 0;
                case (l1_state)
                    N: l1_state <= E;
                    E: l1_state <= S;
                    S: l1_state <= N;
                endcase
            end else timer_l1 <= timer_l1 + 1;
        end
    end
end

// L1 inter-lane force logic (triggered when L0 exits West)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        delay1<=0; travel1<=0;
        forcing1<=0; force1<=0;
        prev_l0<=N;
    end
    else begin
        prev_l0 <= l0_dir;

        if (prev_l0 == W && l0_dir != W && !forcing1 && !sensor[1])
            force1 <= 1;
        else if (forcing1) begin
            if (delay1 == 50000000) begin
                forcing1 <= 0; force1 <= 0;
                delay1 <= 0; travel1 <= 0;
            end else delay1 <= delay1 + 1;
        end

        if (force1) begin
            if (travel1 == 50000000) begin
                forcing1 <= 1;
                force1   <= 0;
            end else travel1 <= travel1 + 1;
        end
    end
end

// L1 output: emergency → East, inter-lane → West, else normal
assign l1_dir =
    (sensor[0] || sensor[1]) ? W :
    (forcing1) ? W :
    l1_state;

//////////////////////////////////////////////////
// L2
//////////////////////////////////////////////////

reg [25:0] timer_l2;
reg [1:0] l2_state;

reg [25:0] delay2, travel2;
reg forcing2, force2;
reg [1:0] prev_l0_n;

// L2 normal FSM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        l2_state <= E;
        timer_l2 <= 0;
    end
    else if (!forcing2 && !sensor[2]) begin
        if (timer_l2 == 50000000) begin
            timer_l2 <= 0;
            case (l2_state)
                E: l2_state <= S;
                S: l2_state <= W;
                W: l2_state <= E;
            endcase
        end else timer_l2 <= timer_l2 + 1;
    end
end

// L2 inter-lane force logic (triggered when L0 exits North)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        delay2<=0; travel2<=0;
        forcing2<=0; force2<=0;
        prev_l0_n<=N;
    end
    else begin
        prev_l0_n <= l0_dir;

        if (prev_l0_n == N && l0_dir != N && !forcing2 && !sensor[2])
            force2 <= 1;
        else if (forcing2) begin
            if (delay2 == 50000000) begin
                forcing2 <= 0; force2 <= 0;
                delay2 <= 0; travel2 <= 0;
            end else delay2 <= delay2 + 1;
        end

        if (force2) begin
            if (travel2 == 50000000) begin
                forcing2 <= 1;
                force2   <= 0;
            end else travel2 <= travel2 + 1;
        end
    end
end

// L2 output: emergency → East, inter-lane → North, else normal
assign l2_dir =
    (sensor[2]) ? W :
    (forcing2) ? N :
    l2_state;

//////////////////////////////////////////////////
// L3
//////////////////////////////////////////////////

reg [25:0] timer_l3;
reg [1:0] l3_state;

reg [25:0] delay3, travel3;
reg forcing3, force3;
reg [1:0] prev_l1_n, prev_l2;

// L3 normal FSM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        l3_state <= E;
        timer_l3 <= 0;
    end
    else if (!forcing3 && !sensor[3]) begin
        if (timer_l3 == 50000000) begin
            timer_l3 <= 0;
            case (l3_state)
                E: l3_state <= S;
                S: l3_state <= E;
            endcase
        end else timer_l3 <= timer_l3 + 1;
    end
end

// L3 inter-lane force logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        delay3<=0; travel3<=0;
        forcing3<=0; force3<=0;
        prev_l1_n<=N; prev_l2<=N;
    end
    else begin
        prev_l1_n <= l1_dir;
        prev_l2   <= l2_dir;

        if (((prev_l1_n == N && l1_dir != N) ||
             (prev_l2 != l2_dir)) && !forcing3 && !sensor[3])
            force3 <= 1;
        else if (forcing3) begin
            if (delay3 == 50000000) begin
                forcing3 <= 0; force3 <= 0;
                delay3 <= 0; travel3 <= 0;
            end else delay3 <= delay3 + 1;
        end

        if (force3) begin
            if (travel3 == 50000000) begin
                forcing3 <= 1;
                force3   <= 0;
            end else travel3 <= travel3 + 1;
        end
    end
end

// L3 output: emergency → East, inter-lane conditional, else normal
assign l3_dir =
    (sensor[2] || sensor[3]) ? W :
    (forcing3) ?
        ((l3_state == E) ? N : W)
    :
    l3_state;

endmodule