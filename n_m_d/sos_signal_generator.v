module sos_signal_generator (
    input clk,          // 50 MHz
    input rst,          // Reset signal
    input enable,       // Kích hoạt phát tín hiệu SOS
    output reg sos_out
);

    // -------------------------------------------------------
    // Bộ chia tần: toggle slow_clk mỗi 5,000,000 chu kỳ
    // → chu kỳ slow_clk = 10,000,000 chu kỳ clk = 0.2s
    // -------------------------------------------------------
    reg [23:0] clk_div;
    reg        slow_clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div  <= 24'd0;
            slow_clk <= 1'b0;
        end else begin
            if (clk_div >= 24'd4_999_999) begin
                clk_div  <= 24'd0;
                slow_clk <= ~slow_clk;
            end else begin
                clk_div <= clk_div + 1'b1;
            end
        end
    end

    // -------------------------------------------------------
    // Edge detector: tạo xung 1 chu kỳ clk tại rising slow_clk
    // Toàn bộ logic FSM chạy trên clk chính → đơn clock domain
    // -------------------------------------------------------
    reg slow_clk_prev;
    wire slow_pulse = slow_clk & ~slow_clk_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) slow_clk_prev <= 1'b0;
        else     slow_clk_prev <= slow_clk;
    end

    // -------------------------------------------------------
    // Mã Morse SOS: ... --- ...
    //   S = 1 0 1 0 1          (5  bits)
    //   gap chữ = 0 0 0        (3  bits)
    //   O = 111 0 111 0 111    (11 bits)
    //   gap chữ = 0 0 0        (3  bits)
    //   S = 1 0 1 0 1          (5  bits)
    //   Tổng = 27 bits
    // -------------------------------------------------------
    localparam [26:0] MORSE_SOS = 27'b101_01_000_11101110111_000_10101;
    //                                  S       gap    O          gap  S
    // Viết rõ hơn (MSB → LSB):
    //   10101 000 11101110111 000 10101

    reg [4:0] bit_count;   // 0..26

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_count <= 5'd0;
            sos_out   <= 1'b0;
        end else begin
            if (!enable) begin
                // Khi không kích hoạt: reset về đầu, tắt output
                bit_count <= 5'd0;
                sos_out   <= 1'b0;
            end else if (slow_pulse) begin
                // Phát bit hiện tại (MSB trước)
                sos_out <= MORSE_SOS[26 - bit_count];
                // Tăng hoặc wrap bit_count
                if (bit_count >= 5'd26)
                    bit_count <= 5'd0;
                else
                    bit_count <= bit_count + 1'b1;
            end
            // Nếu enable=1 nhưng chưa có pulse: giữ nguyên output
        end
    end

endmodule