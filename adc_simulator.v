module adc_simulator (
    input  wire clk,        // Xung nhịp hệ thống (Ví dụ: 50 MHz)
    input  wire rst_n,      // Nút Reset (tích cực thấp - bấm để reset)
    output reg  [9:0] ecg_out // Dữ liệu nhịp tim 10-bit xuất ra
);

    // =======================================================
    // 1. KHỞI TẠO BỘ NHỚ ROM VÀ NẠP DỮ LIỆU
    // =======================================================
    reg [9:0] rom_memory [0:1023]; // Khai báo bộ nhớ 1024 ô, mỗi ô 10-bit
    
    initial begin
        // Nạp file Hex. Lưu ý: File ecg_rom.mem phải để cùng thư mục dự án
        $readmemh("ecg_rom.mem", rom_memory); 
    end

    // =======================================================
    // 2. BỘ CHIA TẦN SỐ (CLOCK DIVIDER) - Tạo xung 360Hz
    // =======================================================
    // Tính toán: 50,000,000 / 360 - 1 = 138888
    reg [17:0] clk_div_cnt; // 18-bit đủ chứa số 138888
    wire tick_360Hz = (clk_div_cnt == 138887); // Báo hiệu đến lúc xuất mẫu mới

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= 0;
        end else if (tick_360Hz) begin
            clk_div_cnt <= 0; // Đếm đến đỉnh thì reset về 0
        end else begin
            clk_div_cnt <= clk_div_cnt + 1; // Tăng dần bộ đếm
        end
    end

    // =======================================================
    // 3. BỘ ĐẾM ĐỊA CHỈ (ADDRESS COUNTER) - Quét qua 1024 mẫu
    // =======================================================
    reg [9:0] address; // 10-bit đếm được từ 0 đến 1023

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address <= 0; // Khởi động lại từ đầu sóng khi reset
        end else if (tick_360Hz) begin
            // Vì address là 10-bit, khi cộng 1 vào 1023 (1111111111) 
            // nó sẽ tự động tràn về 0 (0000000000), tạo thành vòng lặp liên tục.
            address <= address + 1; 
        end
    end

    // =======================================================
    // 4. XUẤT DỮ LIỆU TỪ ROM
    // =======================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ecg_out <= 0;
        end else begin
            ecg_out <= rom_memory[address]; // Đọc giá trị tại địa chỉ hiện tại
        end
    end

endmodule