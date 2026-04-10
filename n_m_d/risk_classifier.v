module risk_classifier (
    input [7:0] bpm,
    input [1:0] arrhythmia_type, // Từ d_n_b: 01 (chậm), 10 (nhanh), 00 (BT)
    output reg [1:0] risk_level
);

    // Định nghĩa các mức rủi ro
    parameter NORMAL   = 2'b00;
    parameter WARNING  = 2'b01;
    parameter DANGER   = 2'b10;
    parameter CRITICAL = 2'b11;

    always @(*) begin
        // 1. Kiểm tra trạng thái Bình thường từ d_n_b
        if (arrhythmia_type == 2'b00 && bpm >= 8'd60 && bpm <= 8'd100) begin
            risk_level = NORMAL;
        end
        // 2. Nếu có bất thường, đánh giá mức độ nghiêm trọng dựa trên số BPM
        else begin
            // Mức KHẨN CẤP (Ngừng tim hoặc nhịp cực đoan)
            if (bpm == 8'd0 || bpm > 8'd180 || bpm < 8'd40) begin
                risk_level = CRITICAL;
            end
            // Mức NGUY HIỂM (Nhịp rất nhanh hoặc rất chậm)
            else if (bpm > 8'd120 || bpm < 8'd50) begin
                risk_level = DANGER;
            end
            // Mức CẢNH BÁO (Các trường hợp rối loạn nhẹ còn lại)
            else begin
                risk_level = WARNING;
            end
        end
    end

endmodule
