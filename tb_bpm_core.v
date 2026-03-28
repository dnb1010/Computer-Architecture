

`timescale 1ns / 1ps

module tb_bpm_core;

    // Các tín hiệu kích thích (Stimulus)
    reg clk;
    reg rst;
    reg [9:0] signal_in; // Đã sửa lỗi viết sai singal_in

    // Các dây nối giữa các module (Internal Wires)
    wire peak;
    wire [31:0] rr_interval;
    wire [15:0] bpm;
    wire abnormal;

    // 1. Khối phát hiện đỉnh
    // Giả sử ngưỡng threshold bạn để cố định bên trong hoặc truyền vào
    // Ở đây tôi giả định module peak_detector của bạn nhận (clk, rst, in, out)
    peak_detector u1 (
        .clk(clk),
        .rst(rst),
        .signal_in(signal_in),
        .threshold(10'd800), // Thêm ngưỡng để lọc đỉnh 2000
        .peak(peak)
    );

    // 2. Khối đếm khoảng cách RR (Module tách thứ 1)
    rr_counter u2 (
        .clk(clk),
        .rst(rst),
        .peak(peak),
        .raw_count(rr_interval)
    );

    // 3. Khối tính toán BPM (Module tách thứ 2)
    // Lưu ý: bpm_calculator cần chân clk/rst để thực hiện phép chia
    bpm_calculator u3 (
        .clk(clk),
        .rst(rst),
        .raw_count(rr_interval),
        .start_calc(peak), // Dùng ngay xung peak để kích hoạt tính toán
        .bpm(bpm)
    );

    // 4. Khối cảnh báo loạn nhịp (Cái đầu tiên bạn viết - Logic tổ hợp)
    // Module này chỉ có input [15:0] bpm và output reg abnormal
    arrhythmia_detector u4 (
        .bpm(bpm),
        .abnormal(abnormal)
    );

    // Tạo xung nhịp hệ thống (Giả sử 100MHz cho dễ tính toán trong TB)
    always #5 clk = ~clk;

    // Task mô phỏng tín hiệu ECG sạch
    task generate_clean_ecg;
        input integer interval; // Số chu kỳ clk giữa các đỉnh
        input integer beats;    // Số nhịp muốn tạo
        integer i, j;           // Khai báo biến vòng lặp bên trong task
    begin
        for (i = 0; i < beats; i = i + 1) begin
            for (j = 0; j < interval; j = j + 1) begin
                if (j == 0)
                    signal_in = 10'd950; // Giá trị đỉnh (phải lớn hơn threshold)
                else
                    signal_in = 10'd300; // Baseline
                
                @(posedge clk); // Đợi 1 chu kỳ clock cho mỗi mẫu
            end
        end
    end
    endtask

    // Quá trình chạy Test
    initial begin
        // Khởi tạo
        clk = 0;
        rst = 1;
        signal_in = 0;

        // Giải phóng Reset
        #20 rst = 0;
        $display("--- Bat dau mo phong he thong ECG ---");

        // TEST 1: Nhịp tim bình thường (~75 BPM)
        // Với clk 100MHz, 1s = 100,000,000 cycles. 
        // Trong TB này ta giả lập số nhỏ hơn để thấy kết quả nhanh
        $display("==== TEST NHIP BINH THUONG ====");
        generate_clean_ecg(1000, 5); 
        $display("BPM hien tai: %d | Abnormal: %b", bpm, abnormal);

        // TEST 2: Nhịp tim nhanh (Tachycardia)
        $display("==== TEST NHIP TIM NHANH ====");
        generate_clean_ecg(400, 5); 
        $display("BPM hien tai: %d | Abnormal: %b", bpm, abnormal);

        // TEST 3: Nhịp tim cham (Bradycardia)
        $display("==== TEST NHIP TIM CHAM ====");
        generate_clean_ecg(2500, 5);
        $display("BPM hien tai: %d | Abnormal: %b", bpm, abnormal);

        #100;
        $display("--- Ket thuc mo phong ---");
        $finish;
    end

endmodule
