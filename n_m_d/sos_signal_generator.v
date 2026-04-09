module sos_signal_generator (
    input clk,          // 50 MHz
    input rst,          // Reset signal
    input enable,       // Kích hoạt phát tín hiệu SOS
    output reg sos_out
);

    // Bộ chia tần tạo xung slow_clk (0.2s cho mỗi đơn vị Morse)
    // 50,000,000 * 0.2 = 10,000,000
    reg [23:0] clk_div;
    reg slow_clk;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div <= 0;
            slow_clk <= 0;
        end else begin
            if (clk_div >= 24'd10_000_000) begin
                clk_div <= 0;
                slow_clk <= ~slow_clk;
            end else begin
                clk_div <= clk_div + 1'b1;
            end
        end
    end

    // Mã hóa S.O.S: ... --- ... 
    // S: 10101, Space: 000, O: 11101110111, Space: 000, S: 10101
    // Tổng cộng 27 bits
    wire [26:0] morse_pattern = 27'b10101_000_11101110111_000_10101;
    reg [4:0] bit_count; // Đủ để đếm đến 27

    always @(posedge slow_clk or posedge rst) begin
        if (rst) begin
            bit_count <= 0;
            sos_out <= 0;
        end else if (enable) begin
            sos_out <= morse_pattern[26 - bit_count];
            if (bit_count >= 5'd26) begin
                bit_count <= 0;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end else begin
            bit_count <= 0;
            sos_out <= 0;
        end
    end

endmodule
