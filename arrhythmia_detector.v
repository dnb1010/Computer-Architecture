module arrhythmia_detector (
    input clk, 
    input rst,
    input [7:0] bpm,
    input ready_strobe,
    output reg abnormal,
    output reg [1:0] type // Phân loại: 01 (chậm), 10 (nhanh), 00 (BT)
);
    // Ngưỡng chuẩn đoán
    parameter BRADYCARDIA_LIMIT  = 8'd60;
    parameter TACHYCARDIA_LIMIT  = 8'd100;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            abnormal <= 0;
            type <= 2'b00;
        end else if (ready_strobe) begin
            if (bpm > 0 && bpm < BRADYCARDIA_LIMIT) begin
                abnormal <= 1;
                type <= 2'b01;
            end else if (bpm > TACHYCARDIA_LIMIT) begin
                abnormal <= 1;
                type <= 2'b10; 
            end else begin
                abnormal <= 0;
                type <= 2'b00;
            end
        end
    end  
endmodule
