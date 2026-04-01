module lowpass_filter (
    input  wire clk,
    input  wire rst_n,
    input  wire data_en,        // Xung kích hoạt từ module trước
    input  wire [9:0] data_in,  // Tín hiệu đầu vào (từ moving_average)
    output reg  [9:0] data_out  // Tín hiệu đầu ra siêu mượt
);

    // Dây nối nội bộ để tính toán tổng (cần 12-bit để tránh tràn số)
    wire [11:0] calc_sum;
    
    // Tính toán tổ hợp: (X_vào + 3 * Y_cũ)
    // Lưu ý: (data_out << 1) chính là 2 * data_out. 
    // Do đó: data_out + (data_out << 1) = 3 * data_out.
    assign calc_sum = data_in + data_out + (data_out << 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0;
        end else if (data_en) begin
            // Dịch bit sang phải 2 lần (tương đương chia 4) để lấy kết quả
            data_out <= calc_sum[11:2]; 
        end
    end

endmodule