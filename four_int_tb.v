`timescale 1ns/1ps

module four_int_tb;

reg clk;
reg rst;

wire [1:0] l0_dir, l1_dir, l2_dir, l3_dir;

reg rx;
wire emg_active;

four_int uut (
    .clk   (clk),
    .rst   (rst),
    .l0_dir(l0_dir),
    .l1_dir(l1_dir),
    .l2_dir(l2_dir),
    .l3_dir(l3_dir),
    .rx(rx),
    .emg_active(emg_active)
);

always #10 clk = ~clk;

// Direction decode for readability
function [39:0] dir_name;
    input [1:0] d;
    case (d)
        2'd0: dir_name = "N    ";
        2'd1: dir_name = "E    ";
        2'd2: dir_name = "S    ";
        2'd3: dir_name = "W    ";
    endcase
endfunction

task send_byte;
    input [7:0] byte;
    integer i;
    begin
        rx = 0; // start bit
        #(5208*20);
        
        for (i = 0; i < 8; i = i + 1) begin
            rx = byte[i];
            #(5208*20);
        end

        rx = 1; // stop bit
        #(5208*20);
    end
endtask

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, four_int_tb);

    clk    = 0;
    rst    = 1;
    rx = 1;

    #20;
    rst = 0;

    // ── Normal operation for a while ─────────────────────────────────────
    #200;

    // ── EMG at intersection 0 (L0) ───────────────────────────────────────
     #100 rst = 0;

    // Send <3A7F2C91>
    send_byte("<");
    send_byte("0");
    send_byte("1");
    send_byte("0");
    send_byte("0");
    send_byte("A");
    send_byte("3");
    send_byte("5");
    send_byte("4");
    send_byte(">");

    // wait to observe LED
    
    // ── Resume normal, finish ─────────────────────────────────────────────
    #(20000*10);
    $finish;
end

endmodule