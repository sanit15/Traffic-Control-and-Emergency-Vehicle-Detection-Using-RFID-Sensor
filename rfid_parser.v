module rfid_parser (
    input clk,
    input rst,
    input [7:0] data_in,
    input ready,

    output reg [31:0] uid,
    output reg valid
);

    reg [2:0] state;
    reg [2:0] count;
    reg [3:0] nibble;
    reg [31:0] temp_uid;

    parameter IDLE = 0,
              READ = 1;

    // ASCII → HEX function
    function [3:0] ascii_to_hex;
        input [7:0] char;
        begin
            if (char >= "0" && char <= "9")
                ascii_to_hex = char - "0";
            else if (char >= "A" && char <= "F")
                ascii_to_hex = char - "A" + 10;
            else
                ascii_to_hex = 0;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            count <= 0;
            valid <= 0;
        end else begin
            valid <= 0;

            if (ready) begin
                case (state)

                IDLE: begin
                    if (data_in == "<") begin
                        count <= 0;
                        temp_uid <= 0;
                        state <= READ;
                    end
                end

                READ: begin
                    if (data_in == ">") begin
                        uid <= temp_uid;
                        valid <= 1;
                        state <= IDLE;
                    end else begin
                        nibble = ascii_to_hex(data_in);

                        temp_uid <= (temp_uid << 4) | nibble;
                        count <= count + 1;
                    end
                end

                endcase
            end
        end
    end

endmodule