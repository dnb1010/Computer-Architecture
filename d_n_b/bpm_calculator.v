module bpm_calculator (
    input clk,
    input rst,
    input start_calc,
    input [31:0] rr_interval, // số clock giữ 2 nhịp (có thể lớn -> dùng 32 bit)
    output reg [15:0] rr_ms,  // khoảng cách rr (ms)
    output reg [7:0] bpm // nhịp tim (BPM)
);
    // Hằng số cho Clock 50MHz: 50,000 pulses = 1ms
    parameter CLK_PER_MS = 32'd50_000; // Hz
    
    // Hằng số 1 phút = 60,000ms
    parameter FACTOR_REDUCED = 32'd3_000_000;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rr_ms <= 0;
            bpm <= 0;
        end else if (start_calc) begin
            // 1. Chuyển đổi sang mili giây
            // rr_ms = raw_count / 50,000
            rr_ms <= rr_interval / CLK_PER_MS;

            // 2. Tính BPM = 60,000 / rr_ms
            // Kiểm tra tránh chia cho 0 hoặc nhịp tim phi thực tế (<30 BPM hoặc >250 BPM)
            if (rr_interval > 32'd12_000_000 && rr_interval < 32'd100_000_000) begin // RR > 240ms (~250 BPM)
                bpm <= FACTOR_REDUCED / (rr_interval / 10'd1000);
            end else begin
                bpm <= 8'd0; // Tín hiệu nhiễu hoặc không hợp lệ
            end
        end
    end
endmodule
