// Khai báo model
module  peak_detector (
    input clk, // clock hệ thống
    input rst, // reset
    input sample_tick, // Xung tích 360Hz từ bộ chia tần số
    input [9:0] threshold, // tín hiệu 10 - bit từ ADC hoặc bộ lọc
    input [9:0] signal_in, // tín hiệu egc đầu vào (dữ liệu từ adc_simulator)
    output reg peak // output 1 khi có đỉnh
);
    // Các thanh ghi trễ để tạo cửa sổ 3 điểm
    reg [9:0] p1, p2, p3;

    // Bộ đém khoảng trễ để tránh đa đỉnh (Refractory Counter)
    reg [7:0] deadzone_cnt; // 8 bit là đủ đếm đến 72
    // Tham số chặn 0.2s một nhịp đập với 360Hz
    parameter DEADZONE_VAL = 8'd72;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {p1, p2, p3} <= 0;
            peak <= 0;
            deadzone_cnt <= 0;
        end else if (sample_tick) begin // Chỉ xử lý khi có mẫu mới từ ADC
            // Dịch mẫu
            p1 <= signal_in;
            p2 <= p1;
            p3 <= p2;

            // Logic đếm lùi deadzone
            if (deadzone_cnt > 0) begin
                deadzone_cnt <= deadzone_cnt - 1'b1;
                peak <= 0;
            end 
            // Điều kiện tìm đỉnh
            else if ((p2 > p1) && (p2 > p3) && (p2 > threshold)) begin
                peak <= 1'b1;
                deadzone_cnt <= DEADZONE_LIMIT; // Khóa 72 mẫu tiếp theo
            end else begin
                peak <= 0;
            end
        end else begin
            // Giữ nguyên trạng thái peak chỉ cao trong 1 chu kỳ clock sample_tick
            // hoặc reset về 0 tùy vào khối nhận tín hiệu phía sau
            peak <= 0; 
        end
    end

endmodule

