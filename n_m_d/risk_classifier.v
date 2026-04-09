module risk_classifier (
    input [7:0] bpm,
    input [1:0] arrhythmia_type, // 01: bradycardia, 10: tachycardia, 00: normal
    input [7:0] spo2,           // Giả định từ cảm biến khác
    input [7:0] temperature,    // Giả định từ cảm biến khác
    output reg [1:0] risk_level
);

    // Định nghĩa các mức rủi ro
    parameter NORMAL   = 2'b00;
    parameter WARNING  = 2'b01;
    parameter DANGER   = 2'b10;
    parameter CRITICAL = 2'b11;

    always @(*) begin
        // Mặc định là bình thường
        risk_level = NORMAL;

        // 1. Kiểm tra mức NGUY HIỂM CAO (CRITICAL)
        // Nhịp tim quá thấp/cao nghiêm trọng hoặc SpO2 cực thấp
        if (bpm > 8'd180 || bpm < 8'd40 || (spo2 > 0 && spo2 < 8'd85)) begin
            risk_level = CRITICAL;
        end
        // 2. Kiểm tra mức NGUY HIỂM (DANGER)
        // Có rối loạn nhịp tim hoặc các chỉ số ngoài ngưỡng an toàn
        else if (arrhythmia_type != 2'b00 || bpm > 8'd120 || bpm < 8'd50 || (spo2 > 0 && spo2 < 8'd92)) begin
            risk_level = DANGER;
        end
        // 3. Kiểm tra mức CẢNH BÁO (WARNING)
        // Nhịp tim hơi cao/thấp hoặc sốt nhẹ
        else if (bpm > 8'd100 || bpm < 8'd60 || temperature > 8'd38) begin
            risk_level = WARNING;
        end
        else begin
            risk_level = NORMAL;
        end
    end

endmodule
