module heart_monitor_top (
    input  wire       clk,        // Xung nhịp hệ thống 50MHz
    input  wire       rst_n,      // Reset từ nút bấm (tích cực thấp)
    
    // Đầu ra hiển thị
    output wire [1:0] led_warn,   // LED báo động (Đỏ/Vàng)
    output wire       buzzer,     // Còi báo động
    output wire       uart_tx,    // Truyền dữ liệu lên PC
    output wire       sos_out,    // Tín hiệu Morse SOS
    output wire [6:0] seg,        // LED 7 đoạn (đoạn a-g)
    output wire [3:0] an,          // LED 7 đoạn (chọn vị trí led)

    output wire       lcd_rs,     // LCD Register Select
    output wire       lcd_rw,     // LCD Read/Write
    output wire       lcd_en,     // LCD Enable
    output wire [7:0] lcd_data,   // LCD Data Bus
    output wire [7:0] matrix_row, // LED Matrix Rows
    output wire [7:0] matrix_col  // LED Matrix Columns
);

    // =======================================================
    // 1. CÁC DÂY NỐI TRUNG GIAN (WIRES)
    // =======================================================
    // Tín hiệu đồng bộ Reset
    wire rst = ~rst_n; // Chuyển đổi rst_n sang rst cho Người 2 & 3

    // Pipeline 1 -> 2
    wire [9:0] raw_ecg;
    wire [9:0] norm_ecg;
    wire [9:0] filtered_ecg;
    wire [9:0] final_ecg;
    wire       sample_tick; // Xung 360Hz để đồng bộ lấy mẫu

    // Pipeline 2 -> 3
    wire        peak_detected;
    wire [31:0] rr_interval;
    wire        ready_strobe;
    wire [7:0]  bpm_value;
    wire [15:0] rr_ms;
    wire        abnormal;
    wire [1:0]  arrhythmia_type;

    // Pipeline 3 -> Đầu ra
    wire [1:0] risk_level;
    wire       sos_enable;
    wire       alarm_trigger_w; // Dây nối mới cho alarm_trigger

    // =======================================================
    // 2. KẾT NỐI PIPELINE 1
    // =======================================================
    
    // Giả lập ADC
    adc_simulator u_adc (
        .clk(clk), 
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .ecg_out(raw_ecg)
    );
 
    signal_normalizer u_norm (
        .clk(clk), 
        .rst_n(rst_n),
        .data_in(raw_ecg), 
        .data_out(norm_ecg)
    );

    moving_average_filter u_maf (
        .clk(clk), 
        .rst_n(rst_n),
        .data_in(norm_ecg), 
        .data_out(filtered_ecg)
    );

    lowpass_filter u_lpf (
        .clk(clk), .rst_n(rst_n),
        .data_en(sample_tick), 
        .data_in(filtered_ecg), 
        .data_out(final_ecg)
    );

    // =======================================================
    // 3. KẾT NỐI PIPELINE 2
    // =======================================================
    
    // Dây nối cho xung đồng bộ trễ
    reg ready_strobe_d1;
    
    peak_detector u_peak (
        .clk(clk), .rst(rst),
        .sample_tick(sample_tick),
        .threshold(10'd500), // Ngưỡng có thể tinh chỉnh
        .signal_in(final_ecg),
        .peak(peak_detected)
    );

    rr_interval_counter u_rr (
        .clk(clk), .rst(rst),
        .peak(peak_detected),
        .rr_interval(rr_interval),
        .ready_strobe(ready_strobe)
    );

    bpm_calculator u_bpm (
        .clk(clk), .rst(rst),
        .start_calc(ready_strobe), // Sửa lỗi theo README
        .rr_interval(rr_interval),
        .rr_ms(rr_ms),
        .bpm(bpm_value)
    );

    // Tạo delay 1 chu kỳ clock cho ready_strobe
    // Đợi bpm_value ổn định từ thanh ghi của u_bpm
    always @(posedge clk or posedge rst) begin
        if (rst) ready_strobe_d1 <= 1'b0;
        else     ready_strobe_d1 <= ready_strobe;
    end
    
    // =======================================================
    // 4. KẾT NỐI PIPELINE 3
    // =======================================================

    arrhythmia_detector u_arr (
        .clk(clk), .rst(rst),
        .bpm(bpm_value),
        .ready_strobe(ready_strobe_d1), // DÙNG XUNG ĐÃ DELAY
        .abnormal(abnormal),
        .type(arrhythmia_type)
    );

    // Khối đánh giá rủi ro
    wire [1:0] current_risk;
    risk_classifier u_class (
        .bpm(bpm_value),
        .arrhythmia_type(arrhythmia_type),
        .risk_level(current_risk)
    );

    emergency_fsm u_fsm (
        .clk(clk), .rst(rst),
        .ready_strobe(ready_strobe_d1), // DÙNG XUNG ĐÃ DELAY
        .risk_in(current_risk),
        .risk_out(risk_level),
        .alarm_trigger(alarm_trigger_w) // Kết nối chân alarm_trigger
    );

    alarm_controller u_alarm (
        .clk(clk), .rst(rst),
        .risk_level(risk_level),
        .alarm_trigger(alarm_trigger_w), // Truyền tín hiệu chốt vào bộ điều khiển
        .led_pins(led_warn),
        .buzzer_pwm(buzzer),
        .sos_enable(sos_enable)
    );

    sos_signal_generator u_sos (
        .clk(clk), .rst(rst),
        .enable(sos_enable),
        .sos_out(sos_out)
    );

    // =======================================================
    // 5. MODULES 4
    // =======================================================

    // Hiển thị BPM lên LED 7 đoạn
    seven_segment_driver u_display (
        .clk(clk), .rst(rst),
        .value(bpm_value),
        .seg(seg), .an(an)
    );

    // Truyền dữ liệu lên UART (Gửi số BPM dưới dạng text)
    uart_transmitter u_uart (
        .clk(clk), .rst(rst),
        .data_in(bpm_value),
        .start_tx(ready_strobe_d1),
        .tx_out(uart_tx)
    );

    // Khởi tạo RAM Logger (Lưu lịch sử dữ liệu)
    ram_logger u_logger (
        .clk(clk), .rst(rst),
        .write_en(ready_strobe_d1),
        .bpm_in(bpm_value),
        .risk_in(risk_level)
    );

    // Khởi tạo LCD Controller
    lcd_controller u_lcd (
        .clk(clk), .rst(rst),
        .risk_level(risk_level),
        .lcd_rs(lcd_rs), 
        .lcd_rw(lcd_rw), 
        .lcd_en(lcd_en), 
        .lcd_data(lcd_data)
    );

    // Khởi tạo LED Matrix Waveform (Vẽ biểu đồ nhịp tim)
    led_matrix_waveform u_matrix (
        .clk(clk), .rst(rst),
        .sample_tick(sample_tick),
        .ecg_signal(final_ecg),
        .row_pins(matrix_row),
        .col_pins(matrix_col)
    );
endmodule
