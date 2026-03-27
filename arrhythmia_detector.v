module arrhythmia_detector (
    input [15:0] bpm,
    output reg abnormal
);

always @(*) begin
    if (bpm < 60 || bpm > 100)
        abnormal = 1;
    else
        abnormal = 0;
end  
endmodule