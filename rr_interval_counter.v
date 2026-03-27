module rr_interval_counter (
    input clk,
    input rst,
    input peak,
    output reg [31:0] rr_interval
);
reg [31:0] counter;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter <= 0;
        rr_interval <= 0;
    end else begin
        counter <= counter + 1;

        if (peak) begin
            rr_interval <= counter;
            counter <= 0;
        end
    end
end
endmodule