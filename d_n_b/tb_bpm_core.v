// `timescale 1ns / 1ps

// module tb_bpm_core;

//     // 1. Khai bao cac tin hieu Stimulus (Kich thich)
//     reg clk;
//     reg rst;
//     reg [9:0] signal_in; 

//     // 2. Khai bao cac day noi (Wires)
//     wire peak;
//     wire [31:0] rr_interval;
//     wire [15:0] rr_ms_out;
//     wire [7:0] bpm;
//     wire abnormal;
//     wire [1:0] arrhythmia_type; 
    
//     // Day noi cho sample_tick
//     wire sample_tick_out;
//     wire ready_strobe_u2;

//     // =======================================================
//     // BO CHIA TAN SO: Tao xung sample_tick 360Hz tu clk 50MHz
//     // =======================================================
//     // Cong thuc: 50,000,000 / 360 = ~138,888 chu ky clock
//     reg [17:0] tick_div;
//     reg sample_tick_reg;
//     assign sample_tick_out = sample_tick_reg;

//     always @(posedge clk or posedge rst) begin
//         if (rst) begin
//             tick_div <= 0;
//             sample_tick_reg <= 0;
//         end else begin
//             if (tick_div >= 18'd138887) begin
//                 tick_div <= 0;
//                 sample_tick_reg <= 1;
//             end else begin
//                 tick_div <= tick_div + 1;
//                 sample_tick_reg <= 0;
//             end
//         end
//     end

//     // 3. Khoi phat hien dinh (u1)
//     peak_detector u1 (
//         .clk(clk),
//         .rst(rst),
//         .signal_in(signal_in),
//         .threshold(10'd800), 
//         .sample_tick(sample_tick_out), // Cap nguon xung 360Hz
//         .peak(peak)
//     );

//     // 4. Khoi dem khoang cach RR (u2)
//     rr_interval_counter u2 (
//         .clk(clk),
//         .rst(rst),
//         .peak(peak),
//         .rr_interval(rr_interval),
//         .ready_strobe(ready_strobe_u2)
//     );

//     // 5. Khoi tinh toan BPM (u3)
//     bpm_calculator u3 (
//         .clk(clk),
//         .rst(rst),
//         .start_calc(peak),
//         .rr_interval(rr_interval), 
//         .rr_ms(rr_ms_out),             
//         .bpm(bpm)
//     );

//     // 6. Khoi canh bao loan nhip (u4)
// // Thêm đoạn này để tạo trễ 1 clock cho tín hiệu báo đỉnh
//     reg peak_delayed;
//     always @(posedge clk) begin
//         peak_delayed <= peak;
//     end

//     // 6. Khối cảnh báo loạn nhịp (u4)
//     arrhythmia_detector u4 (
//         .clk(clk),
//         .rst(rst),
//         .bpm(bpm),
//         .ready_strobe(peak_delayed), // SỬA CHỖ NÀY: Dùng peak_delayed thay vì peak
//         .abnormal(abnormal),
//         .type(arrhythmia_type) 
//     );

//     // =======================================================
//     // CAU HINH CLOCK & MO PHONG
//     // =======================================================
    
//     // Tao xung clock 50MHz (Chu ky = 20ns)
//     always #10 clk = ~clk;

//     // Task mo phong tin hieu ECG (Da dong bo voi sample_tick 360Hz)
//     task generate_clean_ecg;
//         input integer interval_ticks; // Tinh bang so tick thay vi so clock
//         input integer beats;    
//         integer i, j;           
//     begin
//         for (i = 0; i < beats; i = i + 1) begin
//             for (j = 0; j < interval_ticks; j = j + 1) begin
//                 // QUAN TRONG: Doi dung thoi diem khoi detector lay mau
//                 @(posedge sample_tick_out); 
                
//                 // Tao hinh dang "ngon nui" de thoa man dieu kien (p2 > p1) && (p2 > p3)
//                 if (j == 0)      signal_in = 10'd600; // Suon len
//                 else if (j == 1) signal_in = 10'd950; // DINH (Peak)
//                 else if (j == 2) signal_in = 10'd600; // Suon xuong
//                 else             signal_in = 10'd300; // Muc nen (Baseline)
//             end
//         end
//     end
//     endtask

//     // Tu dong in ra Transcript moi khi BPM thay doi
//     always @(bpm) begin
//         if (bpm > 0) begin
//             #20;
//             $display(">> [KET QUA] Time: %0t | Nhap tim tinh duoc: %d BPM | Abnormal: %b", $time, bpm, abnormal);
//         end
//     end

//     // Qua trinh chay Test
//     initial begin
//         // Khoi tao
//         clk = 0;
//         rst = 1;
//         signal_in = 0;

//         // Giai phong Reset
//         #40 rst = 0;
//         $display("-------------------------------------------");
//         $display("--- BAT DAU MO PHONG HE THONG ECG ---");
//         $display("-------------------------------------------"); 
        
//         // TEST 1: Nhip tim binh thuong (~75 BPM)
//         // 75 BPM -> RR = 800ms. Voi tan so 360Hz, 800ms tuong duong khoang 288 ticks
//         $display("\n==== TEST 1: NHIP BINH THUONG (Ky vong: ~75 BPM) ====");
//         generate_clean_ecg(288, 4); 

//         // TEST 2: Nhip tim nhanh (~150 BPM)
//         // 150 BPM -> RR = 400ms. Tuong duong 144 ticks
//         $display("\n==== TEST 2: NHIP TIM NHANH (Ky vong: ~150 BPM) ====");
//         generate_clean_ecg(144, 4); 

//         // TEST 3: Nhip tim cham (~40 BPM)
//         // 40 BPM -> RR = 1500ms. Tuong duong 540 ticks
//         $display("\n==== TEST 3: NHIP TIM CHAM (Ky vong: ~40 BPM) ====");
//         generate_clean_ecg(540, 4); 

//         #1000;
//         $display("\n--- KET THUC MO PHONG ---");
//         $finish;
//     end

// endmodule

`timescale 1ns / 1ps

module tb_bpm_core;

    // 1. Khai bao cac tin hieu Stimulus (Kich thich)
    reg clk;
    reg rst;
    reg [9:0] signal_in; 

    // 2. Khai bao cac day noi (Wires)
    wire peak;
    wire [31:0] rr_interval;
    wire [15:0] rr_ms_out;
    wire [7:0] bpm;
    wire abnormal;
    wire [1:0] arrhythmia_type; 
    
    // Day noi cho sample_tick va pipeline
    wire sample_tick_out;
    wire ready_strobe_u2;
    reg ready_strobe_u3; // The hien u3 da tinh toan xong

    // =======================================================
    // BO CHIA TAN SO: Tao xung sample_tick 360Hz tu clk 50MHz
    // =======================================================
    reg [17:0] tick_div;
    reg sample_tick_reg;
    assign sample_tick_out = sample_tick_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_div <= 0;
            sample_tick_reg <= 0;
        end else begin
            if (tick_div >= 18'd138887) begin
                tick_div <= 0;
                sample_tick_reg <= 1;
            end else begin
                tick_div <= tick_div + 1;
                sample_tick_reg <= 0;
            end
        end
    end

    // 3. Khoi phat hien dinh (u1)
    peak_detector u1 (
        .clk(clk),
        .rst(rst),
        .signal_in(signal_in),
        .threshold(10'd800), 
        .sample_tick(sample_tick_out), 
        .peak(peak) // Nguoi 1: Phat hien dinh
    );

    // 4. Khoi dem khoang cach RR (u2)
    rr_interval_counter u2 (
        .clk(clk),
        .rst(rst),
        .peak(peak),
        .rr_interval(rr_interval),
        .ready_strobe(ready_strobe_u2) // Nguoi 2: Dem xong thi bao ready_strobe_u2
    );

    // =======================================================
    // PIPELINE: Tao do tre de u4 doi u3
    // =======================================================
    always @(posedge clk or posedge rst) begin
        if (rst) ready_strobe_u3 <= 0;
        else     ready_strobe_u3 <= ready_strobe_u2; // u3 tre 1 nhip so voi u2
    end

    // 5. Khoi tinh toan BPM (u3)
    bpm_calculator u3 (
        .clk(clk),
        .rst(rst),
        .start_calc(ready_strobe_u2), // SUA O DAY: u3 doi u2 lam xong moi tinh
        .rr_interval(rr_interval), 
        .rr_ms(rr_ms_out),             
        .bpm(bpm)
    );

    // 6. Khoi canh bao loan nhip (u4)
    arrhythmia_detector u4 (
        .clk(clk),
        .rst(rst),
        .bpm(bpm),
        .ready_strobe(ready_strobe_u3), // SUA O DAY: u4 doi u3 lam xong moi xet duyet
        .abnormal(abnormal),
        .type(arrhythmia_type) 
    );

    // =======================================================
    // CAU HINH CLOCK & MO PHONG
    // =======================================================
    always #10 clk = ~clk;

    task generate_clean_ecg;
        input integer interval_ticks; 
        input integer beats;    
        integer i, j;           
    begin
        for (i = 0; i < beats; i = i + 1) begin
            for (j = 0; j < interval_ticks; j = j + 1) begin
                @(posedge sample_tick_out); 
                
                if (j == 0)      signal_in = 10'd600; 
                else if (j == 1) signal_in = 10'd950; 
                else if (j == 2) signal_in = 10'd600; 
                else             signal_in = 10'd300; 
            end
        end
    end
    endtask

    // Tu dong in ra Transcript moi khi BPM thay doi
    always @(bpm) begin
        if (bpm > 0) begin
            #40; // SUA O DAY: Doi them 2 nhip clock (40ns) de du lieu chay den u4 vung vang nhat
            $display(">> [KET QUA] Time: %0t | Nhip tim tinh duoc: %d BPM | Abnormal: %b", $time, bpm, abnormal);
        end
    end

    // Qua trinh chay Test
    initial begin
        clk = 0;
        rst = 1;
        signal_in = 0;

        #40 rst = 0;
        $display("-------------------------------------------");
        $display("--- BAT DAU MO PHONG HE THONG ECG ---");
        $display("-------------------------------------------"); 
        
        $display("\n==== TEST 1: NHIP BINH THUONG (Ky vong: ~75 BPM) ====");
        generate_clean_ecg(288, 4); 

        $display("\n==== TEST 2: NHIP TIM NHANH (Ky vong: ~150 BPM) ====");
        generate_clean_ecg(144, 4); 

        $display("\n==== TEST 3: NHIP TIM CHAM (Ky vong: ~40 BPM) ====");
        generate_clean_ecg(540, 4); 

        #1000;
        $display("\n--- KET THUC MO PHONG ---");
        $finish;
    end

endmodule