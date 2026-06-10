module seven_segment_driver (
    input  wire       clk,        // 50 MHz
    input  wire       rst,        // Tích cực cao
    input  wire [7:0] value,      // Giá trị BPM (0-255)
    output reg  [6:0] seg,        // Các đoạn a-g (tích cực thấp cho đa số board)
    output reg  [3:0] an          // Chọn vị trí LED (Anode - tích cực thấp)
);

    // 1. Tách số BPM thành các chữ số Hàng trăm, Hàng chục, Hàng đơn vị
    wire [3:0] hundreds = (value / 100) % 10;
    wire [3:0] tens     = (value / 10) % 10;
    wire [3:0] units    = value % 10;

    // 2. Bộ chia tần số để quét LED (Tạo xung quét khoảng 1ms)
    reg [16:0] scan_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) scan_cnt <= 0;
        else     scan_cnt <= scan_cnt + 1;
    end

    wire [1:0] scan_state = scan_cnt[16:15]; // Dùng 2 bit cao để chọn 1 trong 4 LED

    // 3. Bộ giải mã BCD sang 7 đoạn (a-g) - Tích cực thấp (0 là sáng)
    function [6:0] bcd_to_7seg;
        input [3:0] bcd;
        case (bcd)
            4'h0: bcd_to_7seg = 7'b1000000; // 0
            4'h1: bcd_to_7seg = 7'b1111001; // 1
            4'h2: bcd_to_7seg = 7'b0100100; // 2
            4'h3: bcd_to_7seg = 7'b0110000; // 3
            4'h4: bcd_to_7seg = 7'b0011001; // 4
            4'h5: bcd_to_7seg = 7'b0010010; // 5
            4'h6: bcd_to_7seg = 7'b0000010; // 6
            4'h7: bcd_to_7seg = 7'b1111000; // 7
            4'h8: bcd_to_7seg = 7'b0000000; // 8
            4'h9: bcd_to_7seg = 7'b0010000; // 9
            default: bcd_to_7seg = 7'b1111111; // Tắt
        endcase
    endfunction

    // 4. Quét qua 4 vị trí LED (Multiplexing)
    always @(*) begin
        case (scan_state)
            2'b00: begin // LED Hàng đơn vị
                an = 4'b1110; 
                seg = bcd_to_7seg(units);
            end
            2'b01: begin // LED Hàng chục
                an = 4'b1101;
                seg = bcd_to_7seg(tens);
            end
            2'b10: begin // LED Hàng trăm
                an = 4'b1011;
                seg = bcd_to_7seg(hundreds);
            end
            2'b11: begin // LED thứ 4 (Tắt hoặc dùng hiển thị ký hiệu)
                an = 4'b0111;
                seg = 7'b1111111; // Tắt LED này
            end
        endcase
    end

endmodule
