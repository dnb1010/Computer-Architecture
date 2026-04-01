`timescale 1ns / 1ps

module tb_adc_simulator();
    // Khai báo các tín hiệu điều khiển chung
    reg clk;
    reg rst_n;

    // Khai báo các đường dây (wire) để truyền tín hiệu giữa các block
    wire [9:0] ecg_raw;       // Tín hiệu thô từ ADC
    wire [9:0] ecg_norm;      // Tín hiệu sau khi loại bỏ offset
    wire [9:0] ecg_filtered;  // Tín hiệu đã qua bộ lọc trung bình trượt

    // ---------------------------------------------------------
    // GHÉP NỐI CÁC MODULE (PIPELINE)
    // ---------------------------------------------------------

    // Block 1: Giả lập ADC
    adc_simulator u_adc (
        .clk(clk),
        .rst_n(rst_n),
        .ecg_out(ecg_raw)
    );

    // Block 2: Chuẩn hóa tín hiệu (Loại bỏ nhiễu đường nền)
    signal_normalizer #(
        .OFFSET(10'd100) // Tham số này có thể tinh chỉnh lại khi xem sóng thực tế
    ) u_norm (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(ecg_raw),
        .data_out(ecg_norm)
    );

    // Block 3: Bộ lọc trung bình trượt đệ quy
    moving_average_filter u_maf (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(ecg_norm),
        .data_out(ecg_filtered)
    );

    // Block 4: Bộ lọc thông thấp
    lowpass_filter u_lpf (
        .clk(clk),
        .rst_n(rst_n),
        .data_en(data_en),
        .data_in(ecg_filtered),
        .data_out(ecg_final)
    );


    // ---------------------------------------------------------
    // KHỞI TẠO CLOCK VÀ KỊCH BẢN MÔ PHỎNG
    // ---------------------------------------------------------

    // Tạo xung Clock 50MHz (Chu kỳ 20ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Kịch bản chạy mô phỏng
    initial begin
        // Yêu cầu phần mềm xuất dữ liệu ra file sóng
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_adc_simulator);

        // Đặt trạng thái Reset ban đầu
        rst_n = 0;
        #100;
        
        // Nhả Reset, bắt đầu cho hệ thống chạy
        rst_n = 1; 

        // Chạy mô phỏng trong 3 giây (3,000,000,000 ns)
        #3000000000;

        $stop; // Dừng mô phỏng
    end

endmodule