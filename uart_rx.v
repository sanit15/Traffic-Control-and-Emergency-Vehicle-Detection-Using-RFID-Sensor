module uart_rx (
    input clk,          // 50 MHz
    input rst,
    input rx,           // from Arduino
    output reg [7:0] data,
    output reg ready
);

    parameter BAUD_DIV = 5208;

    reg [12:0] baud_cnt = 0;
    reg baud_tick = 0;

    reg [3:0] bit_cnt = 0;
    reg [9:0] shift = 0;

    reg rx_sync1, rx_sync2;

    // Synchronizer (avoid metastability)
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    // Baud generator
    always @(posedge clk) begin
        if (baud_cnt == BAUD_DIV-1) begin
            baud_cnt <= 0;
            baud_tick <= 1;
        end else begin
            baud_cnt <= baud_cnt + 1;
            baud_tick <= 0;
        end
    end

    reg receiving = 0;

    always @(posedge clk) begin
        if (rst) begin
            receiving <= 0;
            bit_cnt <= 0;
            ready <= 0;
        end else begin
            ready <= 0;

            if (!receiving) begin
                // Detect start bit (falling edge)
                if (rx_sync2 == 0) begin
                    receiving <= 1;
                    bit_cnt <= 0;
                end
            end else if (baud_tick) begin
                shift <= {rx_sync2, shift[9:1]};
                bit_cnt <= bit_cnt + 1;

                if (bit_cnt == 9) begin
                    receiving <= 0;
                    data <= shift[9:2]; // extract 8 bits
                    ready <= 1;
                end
            end
        end
    end

endmodule