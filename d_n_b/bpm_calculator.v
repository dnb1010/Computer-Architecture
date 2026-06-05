module bpm_calculator (
    input clk,
    input rst,
    input start_calc,
    input [31:0] rr_interval, 
    output reg [15:0] rr_ms,  
    output reg [7:0] bpm 
);
    // 50,000 pulses = 1ms
    parameter CLK_PER_MS = 32'd50_000; 

    // Các biến tạm thời phục vụ tính toán pipeline hoặc tuần tự
    wire [15:0] calculated_rr_ms;
    
    // Rút gọn phép chia 1: Tính rr_ms trước
    // Nếu thiết kế tối ưu, nên thay phép "/" này bằng một Module Divider IP Core có sẵn của Xilinx/Altera
    assign calculated_rr_ms = rr_interval / CLK_PER_MS;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rr_ms <= 0;
            bpm <= 0;
        end else if (start_calc) begin
            rr_ms <= calculated_rr_ms;

            // Kiểm tra điều kiện bằng rr_ms (nhẹ hơn kiểm tra bằng rr_interval rất nhiều)
            // 240ms tương đương ~250 BPM, 2000ms tương đương 30 BPM
            if (calculated_rr_ms > 16'd240 && calculated_rr_ms < 16'd2000) begin 
                // Chỉ sử dụng duy nhất 1 phép chia cho toàn bộ module
                bpm <= 16'd60_000 / calculated_rr_ms; 
            end else begin
                bpm <= 8'd0; // Sóng nhiễu hoặc không hợp lệ
            end
        end
    end
endmodule
