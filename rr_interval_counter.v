module rr_interval_counter (
    input clk,          // 50 MHz
    input rst,
    input peak,         // Xung từ khối peak_detector
    output reg [31:0] rr_interval, // Số chu kỳ clk giữa 2 đỉnh
    output reg ready_strobe // Xung báo hiệu đã đo xong 1 chu kỳ
);
    reg [31:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            rr_interval <= 0;
            ready_strobe <= 0;
        end else begin
            counter <= counter + 1;
            ready_strobe <= 0;
            if (peak) begin
                rr_interval <= counter;
                counter <= 0;
                ready_strobe <= 1;
            end
        end
    end
endmodule
