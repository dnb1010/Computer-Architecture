module heart_monitor_top (
    input  wire       clk,        // Xung nhịp hệ thống 50MHz
    input  wire       rst_n,      // Reset từ nút bấm (tích cực thấp)
    
    // Đầu ra hiển thị
    output wire [1:0] led_warn,   // LED báo động (Đỏ/Vàng)
    output wire       buzzer,     // Còi báo động
    output wire       uart_tx,    // Truyền dữ liệu lên PC
    output wire       sos_out,    // Tín hiệu Morse SOS
    output wire [6:0] seg,        // LED 7 đoạn (đoạn a-g)
    output wire [3:0] an          // LED 7 đoạn (chọn vị trí led)
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

    // =======================================================
    // 2. KẾT NỐI PIPELINE 1
    // =======================================================
    
    // Giả lập ADC
    adc_simulator u_adc (
        .clk(clk), .rst_n(rst_n),
        .ecg_out(raw_ecg)
        // Lưu ý: Cần thêm output tick_360Hz vào module gốc của Người 1
    );
    
    // Tạm thời tạo sample_tick nếu module Người 1 chưa có output này
    reg [17:0] tick_cnt;
    assign sample_tick = (tick_cnt == 18'd138887);
    always @(posedge clk) tick_cnt <= (sample_tick || !rst_n) ? 0 : tick_cnt + 1;

    signal_normalizer u_norm (
        .clk(clk), .rst_n(rst_n),
        .data_in(raw_ecg), .data_out(norm_ecg)
    );

    moving_average_filter u_maf (
        .clk(clk), .rst_n(rst_n),
        .data_in(norm_ecg), .data_out(filtered_ecg)
    );

    lowpass_filter u_lpf (
        .clk(clk), .rst_n(rst_n),
        .data_en(sample_tick), .data_in(filtered_ecg), .data_out(final_ecg)
    );

    // =======================================================
    // 3. KẾT NỐI PIPELINE 2
    // =======================================================

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

    // =======================================================
    // 4. KẾT NỐI PIPELINE 3
    // =======================================================

    arrhythmia_detector u_arr (
        .clk(clk), .rst(rst),
        .bpm(bpm_value),
        .ready_strobe(ready_strobe),
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
        .ready_strobe(ready_strobe),
        .risk_in(current_risk),
        .risk_out(risk_level)
    );

    alarm_controller u_alarm (
        .clk(clk), .rst(rst),
        .risk_level(risk_level),
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
        .tx_out(uart_tx)
    );

endmodule
