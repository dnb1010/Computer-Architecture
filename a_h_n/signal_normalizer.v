module signal_normalizer #(
    // Khai báo tham số OFFSET để dễ dàng thay đổi tùy theo dữ liệu thực tế
    // Ví dụ: Nếu đường nền của sóng ECG trên GTKWave đang nằm ở khoảng 100, ta set OFFSET = 100
    parameter OFFSET = 10'd100 
)(
    input wire clk,
    input wire rst_n,
    input wire [9:0] data_in,     // Tín hiệu thô từ ADC (10-bit)
    output reg [9:0] data_out     // Tín hiệu đã được chuẩn hóa
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 10'd0;
        end else begin
            // Kiểm tra để tránh tràn số (Underflow) khi trừ
            // Nếu data_in nhỏ hơn mức offset, gán output = 0 để cắt bỏ nhiễu âm
            if (data_in > OFFSET) begin
                data_out <= data_in - OFFSET;
            end else begin
                data_out <= 10'd0; 
            end
        end
    end

endmodule