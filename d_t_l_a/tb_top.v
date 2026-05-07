`timescale 1ns / 1ps

module tb_top();
    // 1. Khai báo các tín hiệu kết nối với Top-level
    reg clk;
    reg rst_n;
    wire [1:0] led_warn;
    wire       buzzer;
    wire       uart_tx;
    wire       sos_out;
    wire [6:0] seg;
    wire [3:0] an;

    // 2. Gọi module Top-level
    heart_monitor_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .led_warn(led_warn),
        .buzzer(buzzer),
        .uart_tx(uart_tx),
        .sos_out(sos_out),
        .seg(seg),
        .an(an)
    );

    // 3. Tạo xung Clock 50MHz (Chu kỳ 20ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 4. Task giả lập nhịp tim
    // interval_ticks: Khoảng cách giữa các đỉnh (tính bằng tick 360Hz)
    task simulate_heartbeat;
        input integer interval_ticks;
        input integer num_beats;
        integer i, j;
    begin
        for (i = 0; i < num_beats; i = i + 1) begin
            // Đợi đến cạnh lên của clock để force, đảm bảo không miss cạnh 
            @(posedge clk); 
            force uut.u_peak.peak = 1; 
            @(posedge clk); // Giữ trong đúng 1 chu kỳ clock
            release uut.u_peak.peak;
            
            // Đợi khoảng cách nhịp
            #(interval_ticks * 2777777);
        end
    end
    endtask

    // 5. Kịch bản mô phỏng 4 trạng thái
    initial begin
        // Khởi tạo
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("--- BAT DAU KIEM TRA 4 KICH BAN ---");

        // TH1: BÌNH THƯỜNG (~75 BPM)
        // 75 BPM -> RR = 800ms -> ~288 ticks
        $display("Kich ban 1: Binh thuong (75 BPM)");
        simulate_heartbeat(288, 5);
        #1000000;

        // TH2: NHỊP NHANH (>120 BPM)
        // 130 BPM -> RR = 461ms -> ~166 ticks
        $display("Kich ban 2: Nhip nhanh (130 BPM)");
        simulate_heartbeat(166, 5);
        #1000000;

        // TH3: NGUY HIỂM (>150 BPM)
        // 160 BPM -> RR = 375ms -> ~135 ticks
        $display("Kich ban 3: Nguy hiem (160 BPM)");
        simulate_heartbeat(135, 5);
        #1000000;

        // TH4: ĐỘT QUỴ (Nhịp hỗn loạn/SOS)
        // Giả lập nhịp cực nhanh hoặc mất nhịp liên tục
        $display("Kich ban 4: Dot quy (SOS)");
        simulate_heartbeat(50, 5); 

        #5000000;
        $display("--- KET THUC MO PHONG ---");
        $finish;
    end
endmodule
