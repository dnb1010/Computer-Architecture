module lcd_controller (
    input wire clk,
    input wire rst,
    input wire [1:0] risk_level,
    
    // Giao tiếp phần cứng LCD 16x2
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_en,
    output reg [7:0] lcd_data
);

    // Bộ chia tần để tạo độ trễ gửi dữ liệu cho LCD (~1ms)
    reg [15:0] delay_cnt;
    wire tick = (delay_cnt == 16'd50_000);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delay_cnt <= 0;
            lcd_en <= 0;
            lcd_rs <= 1; // 1 = Ghi Data, 0 = Ghi Lệnh
            lcd_rw <= 0; // Luôn ghi
            lcd_data <= 8'h20; // Ký tự khoảng trắng (Space)
        end else begin
            if (delay_cnt < 16'd50_000) begin
                delay_cnt <= delay_cnt + 1'b1;
                lcd_en <= 0;
            end else begin
                delay_cnt <= 0;
                lcd_en <= 1; // Tạo xung chốt dữ liệu
                
                // Cập nhật ký tự tùy theo trạng thái
                case (risk_level)
                    2'b00: lcd_data <= 8'h4E; // Chữ 'N' (Normal)
                    2'b01: lcd_data <= 8'h57; // Chữ 'W' (Warning)
                    2'b10: lcd_data <= 8'h44; // Chữ 'D' (Danger)
                    2'b11: lcd_data <= 8'h43; // Chữ 'C' (Critical/Stroke)
                    default: lcd_data <= 8'h2D; // Dấu '-'
                endcase
            end
        end
    end

endmodule
