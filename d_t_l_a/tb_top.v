`timescale 1ns / 1ps

module tb_top();
    // 1. Tín hiệu kết nối
    reg clk;
    reg rst_n;
    wire [1:0] led_warn;
    wire       buzzer;
    wire       uart_tx;
    wire       sos_out;
    wire [6:0] seg;
    wire [3:0] an;
    wire       lcd_rs;
    wire       lcd_rw;
    wire       lcd_en;
    wire [7:0] lcd_data;
    wire [7:0] matrix_row;
    wire [7:0] matrix_col;

    // Biến thống kê
    integer test_pass = 0;
    integer test_fail = 0;
    integer total_tests = 0;

    // 2. Module Top-level
    heart_monitor_top uut (
        .clk(clk), .rst_n(rst_n), .led_warn(led_warn), .buzzer(buzzer),
        .uart_tx(uart_tx), .sos_out(sos_out), .seg(seg), .an(an),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_en(lcd_en), .lcd_data(lcd_data),
        .matrix_row(matrix_row), .matrix_col(matrix_col)
    );

    // 3. Monitor: Tự động in log mỗi khi có nhịp tim mới
    // Truy cập trực tiếp vào bên trong uut để lấy dữ liệu
    always @(posedge uut.ready_strobe_d1) begin
        #5; 
        $display(" >> T=%0t | BPM=%0d | Risk_in=%b | Risk_out=%b | SOS_en=%b | Alarm=%b",
         $time, uut.bpm_value, uut.u_class.risk_level, uut.u_fsm.risk_out, uut.u_sos.enable, uut.u_fsm.alarm_trigger);
    end

    // Task kiểm tra
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

    // 4. Clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

// ... (các phần khai báo giữ nguyên)

    // 4. Task giả lập nhịp tim (Đã thêm biến bpm để in log)
    task simulate_heartbeat;
        input [7:0] bpm;            // Thêm tham số BPM
        input integer interval_ticks;
        input integer num_beats;
        integer i;
    begin
        $display(">>> Dang kich ban: %0d BPM", bpm); // In ra log ngay khi bắt đầu kịch bản
        for (i = 0; i < num_beats; i = i + 1) begin
            @(posedge clk);
            force uut.final_ecg = 10'd800;
            @(posedge clk);
            release uut.final_ecg;
            #(interval_ticks * 2777777 - 20);
        end
    end
    endtask

    // 5. Kịch bản mô phỏng 4 trạng thái
    initial begin
        rst_n = 0; #100; rst_n = 1;
        $display("======================================================");
        $display("  UNIT TEST: HEART MONITOR TOP LEVEL INTEGRATION");
        $display("======================================================");

        // Kịch bản 1: Bình thường (75 BPM)
        simulate_heartbeat(75, 288, 6);
        #1000000;
        check(uut.u_fsm.risk_out, 2'b00, "Kich ban 1 (75BPM): Risk=NORMAL");
        check(uut.u_fsm.alarm_trigger, 1'b0, "Kich ban 1: Alarm=OFF");
        $display("");

        // Kịch bản 2: Nhịp nhanh (130 BPM)
        simulate_heartbeat(130, 166, 4);
        #1000000;
        check(uut.u_fsm.risk_out, 2'b10, "Kich ban 2 (130BPM): Risk=DANGER");
        check(uut.u_sos.enable, 1'b1, "Kich ban 2: SOS Active");
        $display("");

        // Kịch bản 3: Nguy hiểm (160 BPM)
        simulate_heartbeat(160, 135, 4);
        #1000000;
        check(uut.u_fsm.risk_out, 2'b10, "Kich ban 3 (160BPM): Risk=DANGER");
        $display("");

        // Kịch bản 4: Đột quỵ (200 BPM)
        simulate_heartbeat(200, 50, 4);
        #1000000;
        check(uut.u_fsm.risk_out, 2'b11, "Kich ban 4 (200BPM): Risk=CRITICAL");

        $display("\n======================================================");
        $display("  KET QUA: %0d/%0d test PASS | %0d FAIL", test_pass, total_tests, test_fail);
        $display("======================================================");
        $stop;
    end
endmodule
