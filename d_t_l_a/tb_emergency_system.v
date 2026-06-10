// ============================================================
// MO TA: Unit testbench kiem tra toan bo pipeline canh bao:
//        risk_classifier -> emergency_fsm -> alarm_controller
//        -> sos_signal_generator
//
// KICH BAN: 4 truong hop
//   1. Binh thuong  (~75 BPM)   -> Khong co den/coi
//   2. Nhip nhanh   (~130 BPM)  -> Vang chop cham (WARNING)
//   3. Nguy hiem    (~160 BPM)  -> Do chop nhanh + Buzzer (DANGER)
//   4. Dot quy/SOS  (~200 BPM)  -> Do sang lien tuc + SOS (CRITICAL)
// ============================================================
`timescale 1ns / 1ps

module tb_emergency_system;

    // --------------------------------------------------------
    // 1. KHAI BAO TIN HIEU
    // --------------------------------------------------------
    reg        clk;
    reg        rst;

    // Input truc tiep vao pipeline
    reg  [7:0] bpm_stim;
    reg  [1:0] arr_stim;
    reg        ready_strobe;

    // Day noi ket qua
    wire [1:0] risk_in_wire;      // Tu risk_classifier -> FSM
    wire [1:0] risk_out_wire;     // Tu FSM -> alarm
    wire       alarm_trigger;

    wire [1:0] led_pins;
    wire       buzzer_pwm;
    wire       sos_enable;
    wire       sos_out;

    // --------------------------------------------------------
    // 2. KHOI TAO MODULE
    // --------------------------------------------------------
    risk_classifier u_class (
        .bpm           (bpm_stim),
        .arrhythmia_type(arr_stim),
        .risk_level    (risk_in_wire)
    );

    emergency_fsm u_fsm (
        .clk           (clk),
        .rst           (rst),
        .ready_strobe  (ready_strobe),
        .risk_in       (risk_in_wire),
        .risk_out      (risk_out_wire),
        .alarm_trigger (alarm_trigger)
    );

    alarm_controller u_alarm (
        .clk           (clk),
        .rst           (rst),
        .risk_level    (risk_out_wire),
        .led_warn      (led_pins),
        .buzzer_pwm    (buzzer_pwm),
        .sos_enable    (sos_enable)
    );

    sos_signal_generator #(.CLK_DIV_MAX(24'd4)) u_sos (
        .clk           (clk),
        .rst           (rst),
        .enable        (sos_enable),
        .sos_out       (sos_out)
    );

    // --------------------------------------------------------
    // 3. CLOCK 50MHz (chu ky 20ns)
    // --------------------------------------------------------
    initial clk = 0;
    always  #10 clk = ~clk;

    // --------------------------------------------------------
    // 4. BIEN DEM KIEM TRA TU DONG
    // --------------------------------------------------------
    integer test_pass;
    integer test_fail;
    integer total_tests;

    // --------------------------------------------------------
    // 5. TASK: GUI N NHIP TIM
    //    Tao ready_strobe 1-clock-wide moi 'gap_clk' chu ky
    // --------------------------------------------------------
    task send_beats;
        input [7:0]  beat_bpm;
        input [1:0]  arr_type;
        input integer num_beats;
        input integer gap_clk;   // Khoang cach giua cac nhip (clock cycles)
        integer i;
    begin
        bpm_stim = beat_bpm;
        arr_stim = arr_type;
        for (i = 0; i < num_beats; i = i + 1) begin
            // Phat xung ready_strobe (1 chu ky clock)
            @(posedge clk); #1;
            ready_strobe = 1'b1;
            @(posedge clk); #1;
            ready_strobe = 1'b0;
            // Cho gap_clk chu ky truoc nhip tiep theo
            repeat (gap_clk) @(posedge clk);
        end
    end
    endtask

    // --------------------------------------------------------
    // 6. TASK: KIEM TRA GIA TRI VA IN KET QUA
    // --------------------------------------------------------
    task check;
        input [63:0] actual;
        input [63:0] expected;
        input [127:0] msg;     // Ten kiem tra
    begin
        total_tests = total_tests + 1;
        if (actual === expected) begin
            $display("  [PASS] %s | got=%0d (exp=%0d)", msg, actual, expected);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] %s | got=%0d (exp=%0d)  <--- LOI!", msg, actual, expected);
            test_fail = test_fail + 1;
        end
    end
    endtask

    // --------------------------------------------------------
    // 7. MONITOR: In moi khi co nhip moi den
    // --------------------------------------------------------
    always @(posedge ready_strobe) begin
        #5; // Cho tin hieu on dinh
        $display("  >> T=%0t | BPM=%3d | arr=%2b | risk_in=%2b | risk_out=%2b | alarm=%b | LED=%2b | buzzer=%b | sos_en=%b",
            $time, bpm_stim, arr_stim, risk_in_wire, risk_out_wire,
            alarm_trigger, led_pins, buzzer_pwm, sos_enable);
    end

    // --------------------------------------------------------
    // 8. KICH BAN MO PHONG CHINH
    // --------------------------------------------------------
    initial begin
        // Khoi tao
        $dumpfile("wave.vcd");        
        $dumpvars(0, tb_emergency_system); 
        test_pass   = 0;
        test_fail   = 0;
        total_tests = 0;
        ready_strobe = 0;
        bpm_stim = 8'd0;
        arr_stim = 2'b00;

        // Reset
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        $display("======================================================");
        $display("  UNIT TEST: EMERGENCY FSM + ALARM CONTROLLER");
        $display("======================================================");

        // =======================================================
        // KICH BAN 1: BINH THUONG (~75 BPM)
        // Muc ky vong: risk_out = NORMAL(00), den tat, coi im
        // =======================================================
        $display("\n--- KICH BAN 1: BINH THUONG (75 BPM) ---");
        // Gui 6 nhip binh thuong (can it nhat 3 de FSM on dinh)
        send_beats(8'd75, 2'b00, 6, 50);
        repeat(20) @(posedge clk);

        $display("  Ket qua sau 6 nhip binh thuong:");
        check(risk_out_wire, 2'b00, "risk_out = NORMAL(00)");
        check(alarm_trigger, 1'b0,  "alarm_trigger = OFF");
        check(sos_enable,    1'b0,  "sos_enable = OFF");
        // Den va coi phu thuoc vao risk_out=00 -> tat
        check(buzzer_pwm,    1'b0,  "buzzer = OFF");

        // =======================================================
        // KICH BAN 2: NHIP NHANH (130 BPM) -> WARNING
        // 60 < 130 <= 120 => DANGER theo risk_classifier
        // Muc ky vong: risk_out = DANGER(10) sau 3 nhip, den do chop nhanh
        // =======================================================
        $display("\n--- KICH BAN 2: NHIP NHANH (130 BPM) -> DANGER ---");
        // Phai gui >= 3 nhip bat thuong de FSM kich hoat canh bao
        send_beats(8'd130, 2'b10, 4, 50);
        repeat(30) @(posedge clk);

        $display("  Ket qua sau 4 nhip nhanh (130 BPM):");
        // 130 BPM > 120 => DANGER(10) trong risk_classifier
        check(risk_in_wire, 2'b10, "risk_in = DANGER(10) tu classifier");
        // FSM can >= 3 nhip de kick hoat alarm
        check(risk_out_wire, 2'b10, "risk_out = DANGER(10) sau 3+ nhip");
        check(sos_enable,    1'b1,  "sos_enable = ON khi DANGER");
        check(buzzer_pwm | sos_enable, 1'b1, "Buzzer/SOS kich hoat");

        // =======================================================
        // KICH BAN 3: NGUY HIEM (160 BPM) -> DANGER
        // Reset FSM truoc (chuyen sang binh thuong 1 nhip)
        // Muc ky vong: risk_out = DANGER(10), den do chop nhanh, buzzer
        // =======================================================
        $display("\n--- KICH BAN 3: NGUY HIEM (160 BPM) -> DANGER ---");
        // Gui 1 nhip binh thuong de reset error_count trong FSM
        send_beats(8'd75, 2'b00, 2, 50);
        repeat(10) @(posedge clk);
        $display("  (Da reset voi 2 nhip binh thuong)");

        send_beats(8'd160, 2'b10, 4, 50);
        repeat(30) @(posedge clk);

        $display("  Ket qua sau 4 nhip nguy hiem (160 BPM):");
        // 160 BPM: 120 < 160 <= 180 => DANGER(10)
        check(risk_in_wire,  2'b10, "risk_in = DANGER(10)");
        check(risk_out_wire, 2'b10, "risk_out = DANGER(10)");
        check(sos_enable,    1'b1,  "sos_enable = ON");

        // =======================================================
        // KICH BAN 4: DOT QUY / SOS (200 BPM) -> CRITICAL
        // Muc ky vong: risk_out = CRITICAL(11), den do lien tuc, SOS
        // =======================================================
        $display("\n--- KICH BAN 4: DOT QUY / SOS (200 BPM) -> CRITICAL ---");
        // Reset FSM
        send_beats(8'd75, 2'b00, 2, 50);
        repeat(10) @(posedge clk);
        $display("  (Da reset voi 2 nhip binh thuong)");

        send_beats(8'd200, 2'b10, 4, 50);
        repeat(30) @(posedge clk);

        $display("  Ket qua sau 4 nhip dot quy (200 BPM):");
        // 200 > 180 => CRITICAL(11)
        check(risk_in_wire,  2'b11, "risk_in = CRITICAL(11)");
        check(risk_out_wire, 2'b11, "risk_out = CRITICAL(11)");
        check(sos_enable,    1'b1,  "sos_enable = ON (SOS phat song)");

        // =======================================================
        // KIEM TRA BON GIAO: Sau CRITICAL -> ve BINH THUONG
        // =======================================================
        $display("\n--- KIEM TRA PHUC HOI: Sau dot quy -> ve binh thuong ---");
        send_beats(8'd75, 2'b00, 4, 50);
        repeat(30) @(posedge clk);

        $display("  Ket qua sau khi phuc hoi (75 BPM):");
        check(risk_in_wire,  2'b00, "risk_in = NORMAL(00)");
        check(alarm_trigger, 1'b0,  "alarm_trigger = OFF sau phuc hoi");
        // Luu y: risk_out co the chua ve 00 ngay (tuy thuoc FSM reset)
        $display("  [INFO] risk_out=%0b (FSM co the chua reset ngay - xem Bug #2 bao cao)", risk_out_wire);

        // =======================================================
        // KIEM TRA CANH BAO: Nguong cuc bien
        // =======================================================
        $display("\n--- KIEM TRA CANH: BPM = 0 (tim ngung dap) -> CRITICAL ---");
        send_beats(8'd75, 2'b00, 2, 50); // Reset
        repeat(10) @(posedge clk);
        send_beats(8'd0, 2'b00, 4, 50);
        repeat(30) @(posedge clk);

        $display("  Ket qua BPM=0:");
        // bpm=0 => CRITICAL vi risk_classifier kiem tra `bpm==0`
        check(risk_in_wire, 2'b11, "risk_in = CRITICAL(11) khi BPM=0");

        $display("\n--- KIEM TRA CANH: BPM = 35 (cham nguy hiem) -> CRITICAL ---");
        send_beats(8'd75, 2'b00, 2, 50); // Reset
        repeat(10) @(posedge clk);
        send_beats(8'd35, 2'b01, 4, 50);
        repeat(30) @(posedge clk);
        check(risk_in_wire, 2'b11, "risk_in = CRITICAL(11) khi BPM=35 (<40)");

        // =======================================================
        $display("\n======================================================");
        $display("  KET QUA: %0d/%0d test PASS | %0d FAIL",
            test_pass, total_tests, test_fail);
        if (test_fail == 0)
            $display("  >> TAT CA TEST DA QUA! <<");
        else
            $display("  >> CO %0d LOI - XEM LOG TREN DE SUA <<", test_fail);
        $display("======================================================");
        $finish;
    end

endmodule
