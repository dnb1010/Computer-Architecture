`timescale 1ns / 1ps

module tb_top();
    reg clk;
    reg rst_n;
    wire [1:0] led_warn;
    wire       buzzer;
    wire       uart_tx;
    wire       sos_out;
    wire [6:0] seg;
    wire [3:0] an;
    wire       lcd_rs, lcd_rw, lcd_en;
    wire [7:0] lcd_data;
    wire [7:0] matrix_row, matrix_col;

    integer test_pass  = 0;
    integer test_fail  = 0;
    integer total_tests = 0;

    heart_monitor_top uut (
        .clk(clk), .rst_n(rst_n),
        .led_warn(led_warn), .buzzer(buzzer),
        .uart_tx(uart_tx), .sos_out(sos_out),
        .seg(seg), .an(an),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw),
        .lcd_en(lcd_en), .lcd_data(lcd_data),
        .matrix_row(matrix_row), .matrix_col(matrix_col)
    );

    // Clock 50 MHz
    initial clk = 0;
    always #10 clk = ~clk;

    // Monitor
    always @(posedge uut.ready_strobe_d1) begin
        #5;
        $display(" >> T=%0t | BPM=%0d | Risk_in=%b | Risk_out=%b | SOS_en=%b | Alarm=%b",
            $time, uut.bpm_value, uut.u_class.risk_level,
            uut.u_fsm.risk_out, uut.sos_enable, uut.u_fsm.alarm_trigger);
    end

    task check;
        input [63:0] actual;
        input [63:0] expected;
        input [127:0] msg;
    begin
        total_tests = total_tests + 1;
        if (actual === expected) begin
            $display("  [PASS] %s | got=%0d (exp=%0d)", msg, actual, expected);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] %s | got=%0d (exp=%0d)", msg, actual, expected);
            test_fail = test_fail + 1;
        end
    end
    endtask

    // -------------------------------------------------------
    // Task mới: đồng bộ với sample_tick, tạo dạng sóng đỉnh đúng
    // interval_ticks: số tick 360Hz giữa 2 đỉnh
    // num_beats: số nhịp cần tạo
    // -------------------------------------------------------
    task simulate_heartbeat;
        input [7:0]   bpm_display;
        input integer interval_ticks;
        input integer num_beats;
        integer i, j;
    begin
        $display(">>> Dang kich ban: %0d BPM", bpm_display);
        for (i = 0; i < num_beats; i = i + 1) begin
            for (j = 0; j < interval_ticks; j = j + 1) begin
                // Đợi đúng thời điểm sample_tick để peak_detector lấy mẫu
                @(posedge uut.sample_tick);
                if      (j == 0) force uut.final_ecg = 10'd400;
                else if (j == 1) force uut.final_ecg = 10'd900; // Đỉnh > threshold 500
                else if (j == 2) force uut.final_ecg = 10'd400;
                else             force uut.final_ecg = 10'd150;
            end
        end
        release uut.final_ecg;
    end
    endtask

    initial begin
        rst_n = 0; #200; rst_n = 1;
        // Đợi hệ thống ổn định
        repeat(500) @(posedge clk);

        $display("======================================================");
        $display("  UNIT TEST: HEART MONITOR TOP LEVEL INTEGRATION");
        $display("======================================================");

        // Kịch bản 1: Bình thường (75 BPM)
        // 75 BPM -> RR = 800ms -> 288 ticks @360Hz
        $display("\n--- Kich ban 1: Binh thuong (75 BPM) ---");
        simulate_heartbeat(75, 288, 6);
        // Đợi FSM xử lý xong (cần ít nhất 3 nhịp, thêm buffer)
        repeat(500000) @(posedge clk);
        check(uut.u_fsm.risk_out, 2'b00, "Kich ban 1 (75BPM): Risk=NORMAL");
        check(uut.u_fsm.alarm_trigger, 1'b0, "Kich ban 1: Alarm=OFF");
        $display("");

        // Kịch bản 2: Nhịp nhanh -> DANGER (130 BPM)
        // 130 BPM -> RR = 461ms -> 166 ticks @360Hz
        $display("\n--- Kich ban 2: Nhip nhanh (130 BPM) -> DANGER ---");
        simulate_heartbeat(130, 166, 6); // 6 nhịp để FSM đếm đủ 3 lần bất thường
        repeat(500000) @(posedge clk);
        check(uut.u_fsm.risk_out, 2'b10, "Kich ban 2 (130BPM): Risk=DANGER");
        check(uut.sos_enable,     1'b1,  "Kich ban 2: SOS Active");
        $display("");

        // Kịch bản 3: Nguy hiểm (160 BPM) -> DANGER
        // 160 BPM -> RR = 375ms -> 135 ticks @360Hz
        // Reset FSM trước bằng 3 nhịp bình thường
        $display("\n--- Reset FSM bang 3 nhip binh thuong ---");
        simulate_heartbeat(75, 288, 4);
        repeat(200000) @(posedge clk);
        $display("\n--- Kich ban 3: Nguy hiem (160 BPM) -> DANGER ---");
        simulate_heartbeat(160, 135, 6);
        repeat(500000) @(posedge clk);
        check(uut.u_fsm.risk_out, 2'b10, "Kich ban 3 (160BPM): Risk=DANGER");
        $display("");

        // Kịch bản 4: Đột quỵ (200 BPM) -> CRITICAL
        // 200 BPM -> RR = 300ms -> 108 ticks @360Hz
        $display("\n--- Reset FSM bang 3 nhip binh thuong ---");
        simulate_heartbeat(75, 288, 4);
        repeat(200000) @(posedge clk);
        $display("\n--- Kich ban 4: Dot quy (200 BPM) -> CRITICAL ---");
        simulate_heartbeat(200, 108, 6);
        repeat(500000) @(posedge clk);
        check(uut.u_fsm.risk_out, 2'b11, "Kich ban 4 (200BPM): Risk=CRITICAL");
        $display("");

        $display("\n======================================================");
        $display("  KET QUA: %0d/%0d test PASS | %0d FAIL",
            test_pass, total_tests, test_fail);
        if (test_fail == 0)
            $display("  >> TAT CA TEST DA QUA! <<");
        $display("======================================================");
        $stop;
    end
endmodule
