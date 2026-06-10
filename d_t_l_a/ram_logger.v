module ram_logger (
    input wire clk,
    input wire rst,
    input wire write_en,       // Nối với ready_strobe_d1
    input wire [7:0] bpm_in,   // Nối với bpm_value
    input wire [1:0] risk_in   // Nối với risk_level
);

    // Tạo bộ nhớ RAM có 256 ô, mỗi ô 10-bit (2 bit rủi ro + 8 bit BPM)
    reg [9:0] history_ram [0:255];
    reg [7:0] addr_ptr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addr_ptr <= 8'd0;
        end else if (write_en) begin
            // Ghi dữ liệu vào RAM tại địa chỉ hiện tại
            history_ram[addr_ptr] <= {risk_in, bpm_in};
            // Tăng con trỏ địa chỉ (ghi vòng lặp tròn - Circular Buffer)
            addr_ptr <= addr_ptr + 1'b1;
        end
    end

endmodule
