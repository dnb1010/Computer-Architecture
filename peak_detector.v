// Khai báo model
module  peak_detector (
    input clk, // clock hệ thống
    input rst, // reset
    input [9:0] signal_in, // tín hiệu egc đầu vào
    output reg peak // output 1 khi có đỉnh
);

reg [9:0] prev, curr;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        prev <= 0;
        curr <= 0;
        peak <= 0;
    end else begin
        prev <= curr;
        curr <= signal_in;

        if (curr > prev && curr > signal_in)
            peak <= 1;
        else
            peak <= 0;
    end
    
end

endmodule