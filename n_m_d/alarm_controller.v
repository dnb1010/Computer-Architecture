module alarm_controller (
    input clk,          // 50 MHz
    input rst,          // Tín hiệu reset
    input [1:0] risk_level,
    output reg [1:0] led_pins, // [1]: Red, [0]: Yellow
    output reg buzzer_pwm,
    output reg sos_enable
);

    // Bộ đếm chia tần cho còi (200 Hz từ 50 MHz)
    // Giới hạn đếm = 50,000,000 / 200 / 2 (để toggle) = 125,000
    reg [17:0] pwm_counter;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buzzer_pwm <= 0;
            pwm_counter <= 0;
            sos_enable <= 0;
        end else if (risk_level >= 2'b10) begin // Nguy hiểm hoặc Khẩn cấp (Critical)
            sos_enable <= 1;
            if (pwm_counter >= 18'd125_000) begin
                buzzer_pwm <= ~buzzer_pwm;
                pwm_counter <= 0;
            end else begin
                pwm_counter <= pwm_counter + 1;
            end
        end else begin
            buzzer_pwm <= 0;
            pwm_counter <= 0;
            sos_enable <= 0;
        end
    end

    // Tạo xung chớp cho LED
    reg [24:0] blink_counter;
    always @(posedge clk or posedge rst) begin
        if (rst) blink_counter <= 0;
        else blink_counter <= blink_counter + 1;
    end

    wire slow_blink = blink_counter[24]; // Khoảng 1.5Hz
    wire fast_blink = blink_counter[22]; // Khoảng 6Hz

    always @(*) begin
        led_pins = 2'b00;
        case (risk_level)
            2'b01: led_pins[0] = slow_blink; // Vàng chớp chậm (Warning)
            2'b10: led_pins[1] = fast_blink; // Đỏ chớp nhanh (Danger)
            2'b11: led_pins[1] = 1'b1;       // Đỏ sáng liên tục (Critical)
            default: led_pins = 2'b00;
        endcase
    end

endmodule
