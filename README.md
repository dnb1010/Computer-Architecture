# 🫀 ECG Heart Monitor — FPGA System

> Hệ thống theo dõi nhịp tim thời gian thực trên FPGA, phát hiện loạn nhịp và cảnh báo khẩn cấp bằng tín hiệu Morse SOS.

---

## 📌 Tổng quan

Dự án mô phỏng một thiết bị y tế đơn giản có khả năng:

- Đọc tín hiệu ECG từ ROM mô phỏng (thay thế cho ADC vật lý)
- Lọc nhiễu tín hiệu qua hai tầng bộ lọc số
- Phát hiện đỉnh R-wave và tính toán nhịp tim (BPM)
- Phân loại loạn nhịp và đánh giá mức rủi ro
- Kích hoạt cảnh báo thông qua LED, còi buzzer, và tín hiệu SOS Morse
- Hiển thị BPM trên LED 7 đoạn và giao tiếp UART với máy tính
- Ghi lịch sử dữ liệu vào RAM nội bộ

Toàn bộ được viết bằng **Verilog HDL**, mô phỏng bằng **Icarus Verilog** và xem sóng bằng **GTKWave**.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    heart_monitor_top.v                      │
│                                                             │
│  ┌──────────────┐    ┌───────────────────────────────────┐  │
│  │  PIPELINE 1  │    │          PIPELINE 2               │  │
│  │  (Người 1)   │    │          (Người 2)                │  │
│  │              │    │                                   │  │
│  │ adc_simulator│───►│ peak_detector                     │  │
│  │      │       │    │      │                            │  │
│  │ signal_norm  │    │ rr_interval_counter               │  │
│  │      │       │    │      │                            │  │
│  │ moving_avg   │    │ bpm_calculator                    │  │
│  │      │       │    │      │                            │  │
│  │ lowpass_filt ├────► arrhythmia_detector               │  │
│  └──────────────┘    └────────────┬──────────────────────┘  │
│                                   │                         │
│                      ┌────────────▼──────────────────────┐  │
│                      │        PIPELINE 3                 │  │
│                      │        (Người 3)                  │  │
│                      │                                   │  │
│                      │  risk_classifier                  │  │
│                      │        │                          │  │
│                      │  emergency_fsm                    │  │
│                      │  (6 states: IDLE→MEASURING→       │  │
│                      │   ANALYZING→COUNTING→             │  │
│                      │   COMPARE→DISPLAY)                │  │
│                      │        │                          │  │
│                      │  alarm_controller                 │  │
│                      │        │                          │  │
│                      │  sos_signal_generator             │  │
│                      └────────┬──────────────────────────┘  │
│                               │                             │
│              ┌────────────────▼──────────────────────────┐  │
│              │              OUTPUT                       │  │
│              │  LED 7-seg │ UART │ LCD │ LED Matrix      │  │
│              │  Buzzer    │ SOS  │ RAM Logger            │  │
│              └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### FSM Emergency — 6 trạng thái

```
  IDLE ──► MEASURING ──► ANALYZING ──► COUNTING ──► COMPARE
                ▲              │ (normal)     │           │
                │              ▼              │    (cnt<3)│
                └──────── MEASURING ◄─────────┘           │
                               ▲                   (cnt≥3)│
                               └─────── DISPLAY ◄─────────┘
```

| Trạng thái  | Mô tả |
|-------------|-------|
| `IDLE`      | Khởi động, reset bộ đếm |
| `MEASURING` | Đợi `ready_strobe` từ Pipeline 2 |
| `ANALYZING` | Đọc `risk_in`, nếu bình thường quay về MEASURING |
| `COUNTING`  | Tăng `error_count` |
| `COMPARE`   | Nếu ≥ 3 lần bất thường → DISPLAY |
| `DISPLAY`   | Phát `risk_out` và `alarm_trigger`, reset bộ đếm |

---

## 🧰 Technology Stack

|   Thành phần    |                                        Chi tiết                                 |
|-----------------|---------------------------------------------------------------------------------|
|  Ngôn ngữ HDL   |                                      Verilog 2001                               |
| Trình biên dịch |          [Icarus Verilog](http://iverilog.icarus.com/) (iverilog) ≥ v10         |
|  Xem dạng sóng  |                     [GTKWave](https://gtkwave.sourceforge.net/)                 |
|  Clock hệ thống |                                         50 MHz                                  |
|      Reset      | Tích cực thấp (`rst_n`) cho Pipeline 1; tích cực cao (`rst`) cho Pipeline 2 & 3 |
|   Dữ liệu ECG   |                           ROM 1024 mẫu × 10-bit (`ecg_rom.mem`)                 |
|  UART Baudrate  |                                        9600 bps                                 |


## ✨ Features

### 🔬 Xử lý tín hiệu
- **ADC Simulator**: Phát lại sóng ECG thực từ file ROM với tần số lấy mẫu 360 Hz
- **Signal Normalizer**: Loại bỏ đường nền (DC offset) bằng cách trừ `OFFSET` (mặc định = 100)
- **Moving Average Filter**: Cửa sổ trượt 8 mẫu, dùng tổng đệ quy để tối ưu tài nguyên
- **Lowpass Filter**: IIR bậc 1 — `Y[n] = (X[n] + 3·Y[n-1]) / 4`

### 💓 Phân tích nhịp tim
- **Peak Detector**: Cửa sổ 3 điểm + deadzone 72 mẫu (0.2 giây) chống đa đỉnh giả
- **RR Counter**: Đếm số xung clock 50 MHz giữa 2 đỉnh liên tiếp (độ phân giải 20 ns)
- **BPM Calculator**: `BPM = 3,000,000 / (rr_interval / 1000)` — một phép chia duy nhất
- **Arrhythmia Detector**: Phân loại nhịp chậm (<60 BPM), nhịp nhanh (>100 BPM)

### 🚨 Cảnh báo khẩn cấp

| Mức rủi ro | BPM | LED | Còi | SOS |
|------------|-----|-----|-----|-----|
| `NORMAL` (00) | 60–100 | Tắt | Tắt | Tắt |
| `WARNING` (01) | 50–60 hoặc 100–120 | Vàng chớp chậm ~1.5 Hz | Tắt | Tắt |
| `DANGER` (10) | 40–50 hoặc 120–180 | Đỏ chớp nhanh ~6 Hz | 200 Hz | Bật |
| `CRITICAL` (11) | 0, <40, hoặc >180 | Đỏ sáng liên tục | 200 Hz | Bật |

### 📡 Đầu ra
- **LED 7 đoạn**: Hiển thị BPM 3 chữ số, quét multiplexing 4 vị trí
- **UART 9600**: Gửi giá trị BPM mỗi khi có nhịp mới
- **LCD 16×2**: Hiển thị ký tự N/W/D/C theo mức rủi ro
- **LED Matrix 8×8**: Vẽ sóng ECG cuộn theo thời gian thực
- **RAM Logger**: Circular buffer 256 ô, lưu lịch sử BPM + risk level
- **SOS Morse**: Phát chuỗi `... --- ...` (27 bit) với bước thời gian 0.2 giây

---

## 📁 Project Structure

```
Computer-Architecture/
│
├── a_h_n/                        # Người 1 — Xử lý tín hiệu ADC
│   ├── adc_simulator.v           # Giả lập ADC từ ROM, xuất sample_tick 360 Hz
│   ├── signal_normalizer.v       # Loại bỏ DC offset
│   ├── moving_average_filter.v   # Bộ lọc trung bình trượt 8 mẫu
│   ├── lowpass_filter.v          # Bộ lọc IIR thông thấp
│   ├── ecg_rom.mem               # Dữ liệu ECG thực (hex, 1024 mẫu)
│   └── tb_adc.v                  # Testbench Pipeline 1
│
├── d_n_b/                        # Người 2 — Phân tích nhịp tim
│   ├── peak_detector.v           # Phát hiện đỉnh R-wave
│   ├── rr_interval_counter.v     # Đếm khoảng RR
│   ├── bpm_calculator.v          # Tính BPM từ RR interval
│   ├── arrhythmia_detector.v     # Phân loại loạn nhịp
│   └── tb_bpm_core.v             # Testbench Pipeline 2
│
├── n_m_d/                        # Người 3 — Hệ thống cảnh báo
│   ├── risk_classifier.v         # Đánh giá mức rủi ro 4 cấp
│   ├── emergency_fsm.v           # FSM 6 trạng thái quản lý cảnh báo
│   ├── alarm_controller.v        # Điều khiển LED + Buzzer
│   └── sos_signal_generator.v    # Phát tín hiệu Morse SOS
│
└── d_t_l_a/                      # Người 4 — Tích hợp & Hiển thị
    ├── heart_monitor_top.v       # Module top-level, nối toàn bộ pipeline
    ├── seven_segment_driver.v    # Hiển thị BPM lên LED 7 đoạn
    ├── uart_transmitter.v        # Giao tiếp UART 9600 bps
    ├── lcd_controller.v          # Điều khiển LCD 16×2
    ├── led_matrix_waveform.v     # Hiển thị sóng ECG trên LED Matrix 8×8
    ├── ram_logger.v              # Lưu lịch sử BPM + risk vào RAM
    ├── tb_emergency_system.v     # Testbench 4 kịch bản cảnh báo
    └── tb_top.v                  # Testbench top-level tích hợp
```

---

## 🛠️ Hướng dẫn cài đặt & Sử dụng

### 1. Cài đặt công cụ

#### 🍎 macOS
```bash
# Cài Homebrew nếu chưa có
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Cài Icarus Verilog và GTKWave
brew install icarus-verilog
brew install --cask gtkwave
```

#### 🐧 Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y iverilog gtkwave
```

#### 🐧 Linux (Fedora/RHEL)
```bash
sudo dnf install iverilog gtkwave
```

#### 🪟 Windows
1. Tải **Icarus Verilog** tại: https://bleyer.org/icarus/  
   → Chọn bản `iverilog-v12-20220611-x64_setup.exe`  
   → Trong lúc cài, tick chọn **GTKWave** để cài cùng lúc

2. Sau khi cài, mở **Start Menu** → gõ `GTKWave` để kiểm tra

3. Mở **Command Prompt** hoặc **PowerShell**, kiểm tra:
   ```cmd
   iverilog -v
   vvp -v
   ```

---

### 2. Tải dự án

```bash
git clone <repository-url>
cd Computer-Architecture
```

Hoặc tải ZIP → giải nén → mở terminal trong thư mục dự án.

---

### 3. Chạy mô phỏng

> **Lưu ý**: Tất cả lệnh dưới đây chạy từ **thư mục gốc** của dự án.  
> File `ecg_rom.mem` phải nằm cùng thư mục với file biên dịch hoặc truyền đường dẫn tuyệt đối.

---

#### 🅰️ Testbench Pipeline 1 — Kiểm tra ADC & Bộ lọc tín hiệu

```bash
# Biên dịch
iverilog -o sim_adc \
  a_h_n/tb_adc.v \
  a_h_n/adc_simulator.v \
  a_h_n/signal_normalizer.v \
  a_h_n/moving_average_filter.v \
  a_h_n/lowpass_filter.v

# Chạy
vvp sim_adc

# Xem sóng
gtkwave wave.vcd
```

**Kỳ vọng**: Xem được 4 tín hiệu `ecg_raw → ecg_norm → ecg_filtered → ecg_final` ngày càng mượt hơn trong GTKWave.

---

#### 🅱️ Testbench Pipeline 2 — Kiểm tra BPM Calculator

```bash
# Biên dịch
iverilog -o sim_bpm \
  d_n_b/tb_bpm_core.v \
  d_n_b/peak_detector.v \
  d_n_b/rr_interval_counter.v \
  d_n_b/bpm_calculator.v \
  d_n_b/arrhythmia_detector.v

# Chạy
vvp sim_bpm
```

**Kỳ vọng** (in ra terminal):
```
==== TEST 1: NHIP BINH THUONG (Ky vong: ~75 BPM) ====
>> [KET QUA] Time: ... | Nhip tim tinh duoc:  75 BPM | Abnormal: 0

==== TEST 2: NHIP TIM NHANH (Ky vong: ~150 BPM) ====
>> [KET QUA] Time: ... | Nhip tim tinh duoc: 150 BPM | Abnormal: 1

==== TEST 3: NHIP TIM CHAM (Ky vong: ~40 BPM) ====
>> [KET QUA] Time: ... | Nhip tim tinh duoc:  40 BPM | Abnormal: 1
```

---

#### 🆘 Testbench Pipeline 3 — Kiểm tra 4 kịch bản cảnh báo

```bash
# Biên dịch
iverilog -o sim_emergency \
  d_t_l_a/tb_emergency_system.v \
  n_m_d/risk_classifier.v \
  n_m_d/emergency_fsm.v \
  n_m_d/alarm_controller.v \
  n_m_d/sos_signal_generator.v

# Chạy
vvp sim_emergency

# Xem sóng
gtkwave wave.vcd
```

**Kỳ vọng** (in ra terminal):
```
======================================================
UNIT TEST: EMERGENCY FSM + ALARM CONTROLLER
======================================================

--- KICH BAN 1: BINH THUONG (75 BPM) ---
>> T=216000  | BPM= 75 | arr=00 | risk_in=00 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=1256000 | BPM= 75 | arr=00 | risk_in=00 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=2296000 | BPM= 75 | arr=00 | risk_in=00 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=3336000 | BPM= 75 | arr=00 | risk_in=00 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=4376000 | BPM= 75 | arr=00 | risk_in=00 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=5416000 | BPM= 75 | arr=00 | risk_in=00 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
Ket qua sau 6 nhip binh thuong:
[PASS] out = NORMAL(00) | got=0 (exp=0)
[PASS] rm_trigger = OFF | got=0 (exp=0)
[PASS] sos_enable = OFF | got=0 (exp=0)
[PASS] buzzer = OFF | got=0 (exp=0)

--- KICH BAN 2: NHIP NHANH (130 BPM) -> DANGER ---
>> T=6856000 | BPM=130 | arr=10 | risk_in=10 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=7896000 | BPM=130 | arr=10 | risk_in=10 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=8936000 | BPM=130 | arr=10 | risk_in=10 | risk_out=00 | alarm=0 | LED=00 | buzzer=0 | sos_en=0
>> T=9976000 | BPM=130 | arr=10 | risk_in=10 | risk_out=10 | alarm=1 | LED=00 | buzzer=0 | sos_en=1
Ket qua sau 4 nhip nhanh (130 BPM):
[PASS] 0) tu classifier | got=2 (exp=2)
[PASS] (10) sau 3+ nhip | got=2 (exp=2)
[PASS] = ON khi DANGER | got=1 (exp=1)
[PASS] er/SOS kich hoat | got=1 (exp=1)
...
KET QUA: 18/18 test PASS | 0 FAIL
>> TAT CA TEST DA QUA! <<
```

---

#### 🔝 Testbench Top-level — Tích hợp toàn hệ thống

```bash
# Biên dịch toàn bộ
iverilog -o sim_top -s tb_emergency_system */*.v

# Chạy
vvp sim_top

# Xem sóng
gtkwave wave.vcd
```

---

### 4. Xem biểu đồ sóng trong GTKWave

Sau khi chạy `gtkwave wave.vcd`:

#### Bước 1 — Chọn module muốn xem
Trong panel **SST** (Signal Search Tree) bên trái:
- Bấm vào tên module (ví dụ `tb_emergency_system`)
- Các tín hiệu của module đó sẽ hiện ra ở panel **Signals** bên dưới

#### Bước 2 — Thêm tín hiệu vào biểu đồ
- **Double-click** vào tên tín hiệu để thêm vào cửa sổ sóng
- Hoặc **kéo thả** tín hiệu từ panel Signals vào vùng sóng

#### Bước 3 — Tín hiệu nên xem theo từng testbench

| Testbench | Tín hiệu gợi ý |
|-----------|----------------|
| `tb_adc` | `ecg_raw`, `ecg_norm`, `ecg_filtered`, `ecg_final`, `sample_tick` |
| `tb_bpm_core` | `signal_in`, `peak`, `rr_interval`, `bpm`, `abnormal` |
| `tb_emergency_system` | `bpm_stim`, `risk_in_wire`, `risk_out_wire`, `alarm_trigger`, `led_pins`, `buzzer_pwm`, `sos_enable`, `sos_out` |
| `tb_top` | `led_warn`, `buzzer`, `sos_out`, `uart_tx`, `seg` |

#### Bước 4 — Điều hướng thời gian
| Phím tắt | Chức năng |
|----------|-----------|
| `Ctrl + Scroll` | Zoom in/out |
| `Shift + Scroll` | Cuộn ngang |
| `F` | Fit toàn bộ sóng vào màn hình |
| `Ctrl + F` | Tìm kiếm tín hiệu |
| Click giữa vùng sóng | Đặt marker thời gian |

#### Bước 5 — Đổi màu và định dạng tín hiệu
- **Right-click** vào tên tín hiệu → **Data Format** → chọn `Decimal`, `Hex`, hoặc `Binary`
- **Right-click** → **Color** → chọn màu cho dễ phân biệt

---

### 5. Thay đổi tham số mô phỏng

#### Thay đổi ngưỡng cảnh báo trong `risk_classifier.v`
```verilog
// Chỉnh ngưỡng BPM theo yêu cầu
if (bpm > 8'd180 ...)   // Ngưỡng CRITICAL trên
if (bpm < 8'd40  ...)   // Ngưỡng CRITICAL dưới
if (bpm > 8'd120 ...)   // Ngưỡng DANGER trên
```

#### Thay đổi offset tín hiệu ECG trong `signal_normalizer.v`
```verilog
// Nếu đường nền sóng ECG trên GTKWave nằm ở giá trị khác 100
signal_normalizer #(.OFFSET(10'd150)) u_norm ( ... );
```

#### Thay đổi ngưỡng phát hiện đỉnh trong `tb_top.v` / `heart_monitor_top.v`
```verilog
peak_detector u_peak (
    ...
    .threshold(10'd500),  // Điều chỉnh nếu bỏ lỡ hoặc phát hiện sai đỉnh
    ...
);
```

#### Thay đổi số lần bất thường trước khi cảnh báo trong `emergency_fsm.v`
```verilog
// Mặc định: 3 lần liên tiếp mới kích hoạt cảnh báo
if (error_count >= 3'd3)   // Đổi thành 3'd1 để cảnh báo ngay lần đầu
```

---

## ⚠️ Lưu ý quan trọng

- File `ecg_rom.mem` **bắt buộc** phải nằm cùng thư mục với nơi chạy lệnh `vvp`, vì `$readmemh` dùng đường dẫn tương đối
- Trên **Windows**, dùng dấu `/` thay vì `\` trong lệnh `iverilog`, hoặc dùng Git Bash thay PowerShell
- Pipeline 1 dùng reset **tích cực thấp** (`rst_n`), trong khi Pipeline 2 & 3 dùng reset **tích cực cao** (`rst`). Module top-level đã chuyển đổi tự động: `wire rst = ~rst_n`
- `bpm_calculator.v` yêu cầu `rr_interval` nằm trong khoảng `12,000,000` đến `100,000,000` clock cycles để tính hợp lệ (~30–250 BPM). Ngoài vùng này `bpm` sẽ về 0

---

## 👥 Thành viên

| Người | Module phụ trách |
|-------|-----------------|
| **a_h_n** | ADC Simulator, Signal Normalizer, Moving Average Filter, Lowpass Filter |
| **d_n_b** | Peak Detector, RR Interval Counter, BPM Calculator, Arrhythmia Detector |
| **n_m_d** | Risk Classifier, Emergency FSM, Alarm Controller, SOS Generator |
| **d_t_l_a** | Heart Monitor Top, Seven Segment Driver, UART, LCD, LED Matrix, RAM Logger, Testbenches |
