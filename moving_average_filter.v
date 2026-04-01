module moving_average_filter (
    input wire clk,
    input wire rst_n,
    input wire [9:0] data_in,     // Tín hiệu đầu vào (10-bit)
    output reg [9:0] data_out     // Tín hiệu đã lọc (10-bit)
);

    // Khai báo mảng thanh ghi dịch (Shift Register) gồm 8 phần tử, mỗi phần tử 10-bit
    reg [9:0] shift_reg [0:7];
    
    // Biến lưu tổng: Cần 13 bit để chống tràn khi cộng tối đa 8 số 10-bit (10 + log2(8) = 13)
    reg [12:0] sum; 
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Khởi tạo lại toàn bộ hệ thống khi Reset
            sum <= 13'd0;
            data_out <= 10'd0;
            for (i = 0; i < 8; i = i + 1) begin
                shift_reg[i] <= 10'd0;
            end
        end else begin
            // 1. Dịch dữ liệu trong mảng (Cập nhật cửa sổ trượt)
            shift_reg[0] <= data_in; // Đưa mẫu mới nhất vào vị trí đầu
            for (i = 1; i < 8; i = i + 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end

            // 2. Cập nhật tổng đệ quy: Tổng mới = Tổng cũ + Mẫu mới nhất - Mẫu cũ nhất
            // Đây là bước tối ưu phần cứng quan trọng thay vì dùng 7 bộ cộng nối tiếp
            sum <= sum + data_in - shift_reg[7];

            // 3. Tính trung bình (Chia cho 8 bằng cách lấy từ bit thứ 3 trở đi)
            // Tương đương phép toán: data_out = sum / 8
            data_out <= sum[12:3];
        end
    end

endmodule