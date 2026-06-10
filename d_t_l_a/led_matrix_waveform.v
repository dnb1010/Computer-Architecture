module led_matrix_waveform (
    input wire clk,
    input wire rst,
    input wire sample_tick,        // Lấy mẫu theo nhịp ADC
    input wire [9:0] ecg_signal,   // Nối với final_ecg
    
    output reg [7:0] row_pins,     // Quét hàng (Tích cực cao)
    output reg [7:0] col_pins      // Quét cột (Tích cực thấp)
);

    // Thanh ghi dịch lưu trữ 8 cột giá trị ECG trên màn hình
    reg [2:0] display_buffer [0:7]; 
    
    // 1. Cập nhật dữ liệu sóng nhịp tim vào Buffer
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) display_buffer[i] <= 3'd0;
        end else if (sample_tick) begin
            // Dịch dữ liệu sang trái
            for (i = 7; i > 0; i = i - 1) begin
                display_buffer[i] <= display_buffer[i-1];
            end
            // Đưa dữ liệu mới vào (scale 10-bit xuống 3-bit: 0-7)
            display_buffer[0] <= ecg_signal[9:7]; 
        end
    end

    // 2. Quét hiển thị LED Matrix (Multiplexing)
    reg [15:0] scan_cnt;
    reg [2:0]  col_idx;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_cnt <= 0;
            col_idx <= 0;
            col_pins <= 8'b11111111;
            row_pins <= 8'b00000000;
        end else begin
            scan_cnt <= scan_cnt + 1'b1;
            if (scan_cnt == 16'd20_000) begin // Quét tốc độ ~300Hz
                scan_cnt <= 0;
                col_idx <= col_idx + 1'b1;
                
                // Bật cột tương ứng (tích cực thấp)
                col_pins <= ~(8'b00000001 << col_idx);
                
                // Bật 1 điểm sáng trên cột dựa vào giá trị ECG trong Buffer
                row_pins <= (8'b00000001 << display_buffer[col_idx]);
            end
        end
    end

endmodule
