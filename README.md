# Tóm Tắt Chi Tiết Dự Án: ECG Heart Rate Monitor

**Repository:** `Computer-Architecture-main`  
**Ngôn ngữ:** Verilog HDL  
**Mục tiêu:** Thiết kế hệ thống phần cứng số xử lý tín hiệu điện tâm đồ (ECG), phát hiện nhịp tim và cảnh báo loạn nhịp.

---

## 1. Tổng Quan Kiến Trúc

Dự án được chia làm **2 pipeline độc lập** nhưng liên kết với nhau:

```
┌─────────────────────────────────────────────────────────┐
│              PIPELINE 1 — Xử lý tín hiệu ADC            │
│                                                         │
│  [ADC Simulator] → [Signal Normalizer] →                │
│  [Moving Average Filter] → [Low-Pass Filter]            │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ tín hiệu ECG đã lọc
┌─────────────────────────────────────────────────────────┐
│              PIPELINE 2 — Đo nhịp tim & Cảnh báo        │
│                                                         │
│  [Peak Detector] → [RR Interval Counter] →              │
│  [BPM Calculator] → [Arrhythmia Detector]               │
└─────────────────────────────────────────────────────────┘
```

**Clock hệ thống:** 50 MHz  
**Tần số lấy mẫu ECG:** 360 Hz (tạo bằng bộ chia tần từ 50 MHz)  
**Độ phân giải ADC:** 10-bit (giá trị 0–1023)

---

## 2. Cấu Trúc Thư Mục

```
Computer-Architecture-main/
│
├── a_h_n/                          # Pipeline 1 — Xử lý ADC
│   ├── adc_simulator.v             # Giả lập ADC đọc dữ liệu ECG từ ROM
│   ├── ecg_rom.mem                 # Dữ liệu sóng ECG (1024 mẫu hex)
│   ├── signal_normalizer.v         # Loại bỏ offset đường nền
│   ├── moving_average_filter.v     # Bộ lọc trung bình trượt 8 điểm
│   ├── lowpass_filter.v            # Bộ lọc thông thấp IIR
│   ├── tb_adc.v                    # Testbench cho Pipeline 1
│   └── task1                       # (file rỗng)
│
├── peak_detector.v                 # Pipeline 2 — Phát hiện đỉnh R
├── rr_interval_counter.v           # Đếm khoảng cách giữa 2 đỉnh
├── bpm_calculator.v                # Tính nhịp tim (BPM)
├── arrhythmia_detector.v           # Phân loại loạn nhịp
└── tb_bpm_core.v                   # Testbench cho Pipeline 2
```

---

## 3. Mô Tả Chi Tiết Từng Module

### 3.1 `adc_simulator.v` — Giả lập bộ chuyển đổi ADC

**Chức năng:** Đọc tuần tự 1024 mẫu ECG từ bộ nhớ ROM và phát ra tín hiệu 10-bit với tần số 360 Hz, mô phỏng đầu ra của một ADC thực tế.

**Thông số:**
- Clock vào: 50 MHz
- Tần số output: 360 Hz
- Độ phân giải: 10-bit
- Số mẫu: 1024 (tự động lặp vòng nhờ tràn số 10-bit)

**Cơ chế hoạt động:**

| Khối con | Mô tả |
|----------|-------|
| ROM (1024 × 10-bit) | Lưu dạng sóng ECG, nạp từ file `ecg_rom.mem` bằng `$readmemh` |
| Clock Divider 18-bit | Đếm đến 138.887, tạo xung `tick_360Hz` mỗi 1/360 giây |
| Address Counter 10-bit | Tăng địa chỉ ROM mỗi tick; tự wrap-around 1023→0 |
| Output Register | Đọc `rom_memory[address]` và latch ra `ecg_out` |

**Reset:** Tích cực thấp (`rst_n = 0`).

---

### 3.2 `ecg_rom.mem` — Dữ liệu sóng ECG

**Định dạng:** 1024 dòng, mỗi dòng là 1 giá trị hex 10-bit (ví dụ: `13E`, `2FF`, `3FF`...).

**Phân tích dữ liệu mẫu:**
- Các giá trị đầu xấp xỉ `0x13E` = 318 (decimal) → đây là mức đường nền (baseline) của sóng ECG
- Dữ liệu biểu diễn 1 chu kỳ tim hoàn chỉnh, lặp lại liên tục khi phát ở 360 Hz → tương đương ~2,84 giây/chu kỳ (~21 BPM nếu chỉ 1 đỉnh/chu kỳ)

---

### 3.3 `signal_normalizer.v` — Chuẩn hóa tín hiệu

**Chức năng:** Loại bỏ offset DC của đường nền để các bộ lọc và detector phía sau làm việc chính xác hơn.

**Tham số:**
- `OFFSET = 100` (mặc định, có thể chỉnh)

**Logic:**
```
if (data_in > OFFSET)   → data_out = data_in - OFFSET
else                    → data_out = 0   (clamp, tránh underflow)
```

**Lưu ý thiết kế:** Việc clamp về 0 thay vì cho phép giá trị âm là hợp lý vì tín hiệu ECG sau ADC luôn dương. Tham số `OFFSET` nên được hiệu chỉnh dựa trên dữ liệu thực tế quan sát trên GTKWave.

---

### 3.4 `moving_average_filter.v` — Bộ lọc trung bình trượt đệ quy

**Chức năng:** Làm mượt tín hiệu ECG bằng cách tính trung bình của 8 mẫu gần nhất, loại bỏ nhiễu tần số cao.

**Thông số:**
- Cửa sổ: 8 mẫu
- Độ rộng sum: 13-bit (để chứa tối đa 8 × 1023 = 8184 < 2^13 = 8192)

**Thuật toán đệ quy (tối ưu phần cứng):**
```
sum_mới = sum_cũ + mẫu_mới - mẫu_cũ_nhất
data_out = sum[12:3]   // tương đương chia 8 (dịch phải 3 bit)
```

> Ưu điểm: Chỉ cần 1 bộ cộng và 1 bộ trừ thay vì 7 bộ cộng nối tiếp, tiết kiệm tài nguyên phần cứng đáng kể.

**Cấu trúc nội bộ:** Shift register 8 phần tử × 10-bit.

---

### 3.5 `lowpass_filter.v` — Bộ lọc thông thấp IIR

**Chức năng:** Lọc thêm một lần nữa để loại bỏ các dao động còn sót lại sau bộ lọc trung bình trượt, cho ra tín hiệu rất mượt.

**Phương trình bộ lọc IIR bậc 1:**
```
Y[n] = (X[n] + 3 × Y[n-1]) / 4
```

**Hiện thực phần cứng (tránh nhân thực sự):**
```verilog
calc_sum = data_in + data_out + (data_out << 1)
         = X[n] + Y[n-1] + 2×Y[n-1]
         = X[n] + 3×Y[n-1]
data_out = calc_sum[11:2]   // chia 4 bằng dịch phải 2 bit
```

**Cổng điều khiển:** `data_en` — chỉ cập nhật output khi có xung kích hoạt từ tầng trước.

**Đặc tính:** Hệ số α = 0.75 cho tần số cắt thấp, phù hợp làm mượt sóng ECG trước khi phát hiện đỉnh.

---

### 3.6 `peak_detector.v` — Phát hiện đỉnh R

**Chức năng:** Phát hiện các đỉnh R trong sóng ECG (điểm cao nhất của mỗi nhịp tim) và xuất xung `peak` mỗi khi tìm thấy.

**Thuật toán cửa sổ trượt 3 điểm:**
```
Đỉnh được xác nhận khi:
  p2 > p1   (điểm giữa lớn hơn điểm sau)
  p2 > p3   (điểm giữa lớn hơn điểm trước)
  p2 > threshold  (lớn hơn ngưỡng, lọc nhiễu)
```

**Cơ chế deadzone (Refractory Period):**
- Sau mỗi đỉnh được phát hiện, bộ đếm `deadzone_cnt` được set = 72
- Trong 72 mẫu tiếp theo (~0,2 giây ở 360 Hz), mọi đỉnh tiếp theo đều bị bỏ qua
- Ngăn chặn phát hiện đa đỉnh cho một nhịp tim

**Lưu ý:** `sample_tick` phải được kết nối — module chỉ xử lý khi có xung 360 Hz.

---

### 3.7 `rr_interval_counter.v` — Đếm khoảng RR

**Chức năng:** Đo khoảng cách (tính theo số chu kỳ clock 50 MHz) giữa hai đỉnh R liên tiếp.

**Cơ chế:**
```
- counter tăng liên tục mỗi clock
- Khi nhận peak:
    → latch counter vào rr_interval
    → reset counter về 0
    → phát ready_strobe = 1 (1 chu kỳ)
```

**Output:**
- `rr_interval [31:0]`: số clock giữa 2 đỉnh (32-bit để chứa nhịp tim rất chậm)
- `ready_strobe`: xung báo hiệu dữ liệu mới sẵn sàng

---

### 3.8 `bpm_calculator.v` — Tính nhịp tim BPM

**Chức năng:** Chuyển đổi khoảng RR (đơn vị clock) thành nhịp tim BPM.

**Công thức:**
```
rr_ms  = rr_interval / 50.000        (đổi sang millisecond)
BPM    = 60.000 / rr_ms              (đổi sang nhịp/phút)
       = 60.000 × 50.000 / rr_interval
```

**Tham số hằng số:**
- `CLK_PER_MS = 50.000` (chu kỳ clock trong 1ms ở 50 MHz)
- `MS_PER_MIN = 60.000` (ms trong 1 phút)

**Lọc nhiễu:** BPM chỉ được tính khi RR > 240ms (tương đương < 250 BPM), loại bỏ các xung nhiễu cực ngắn.

**⚠️ Lưu ý quan trọng:** Module có 2 lỗi cần sửa — xem mục Danh sách lỗi.

---

### 3.9 `arrhythmia_detector.v` — Phát hiện loạn nhịp

**Chức năng:** Phân loại nhịp tim thành 3 trạng thái dựa trên BPM và đưa ra cảnh báo.

**Bảng phân loại:**

| Điều kiện | Chẩn đoán | `type` | `abnormal` |
|-----------|-----------|--------|-----------|
| 0 < BPM < 60 | Nhịp chậm (Bradycardia) | `2'b01` | `1` |
| BPM > 100 | Nhịp nhanh (Tachycardia) | `2'b10` | `1` |
| 60 ≤ BPM ≤ 100 | Bình thường | `2'b00` | `0` |

**Ngưỡng chuẩn đoán:**
- `BRADYCARDIA_LIMIT = 60 BPM`
- `TACHYCARDIA_LIMIT = 100 BPM`

**Cơ chế:** Đồng bộ clock, chỉ cập nhật khi nhận `ready_strobe = 1` từ `rr_interval_counter`.

---

## 4. Testbench

### 4.1 `tb_adc.v` — Kiểm thử Pipeline 1

Ghép nối toàn bộ 4 module của pipeline xử lý ADC thành chuỗi:

```
adc_simulator → signal_normalizer → moving_average_filter → lowpass_filter
```

**Kịch bản mô phỏng:**
- Clock 50 MHz (chu kỳ 20 ns)
- Reset 100 ns ban đầu
- Chạy mô phỏng 3 giây (3.000.000.000 ns)
- Xuất file `wave.vcd` để xem trên GTKWave

### 4.2 `tb_bpm_core.v` — Kiểm thử Pipeline 2

Sử dụng task `generate_clean_ecg` để tạo tín hiệu ECG nhân tạo với các kịch bản:

| Test case | Interval (cycles) | Nhịp tim dự kiến | Kết quả mong đợi |
|-----------|:-----------------:|:----------------:|:----------------:|
| Nhịp bình thường | 1.000 | ~75 BPM | `abnormal = 0` |
| Nhịp nhanh (Tachycardia) | 400 | ~187 BPM | `abnormal = 1, type = 10` |
| Nhịp chậm (Bradycardia) | 2.500 | ~30 BPM | `abnormal = 1, type = 01` |

> **Lưu ý:** Testbench dùng clock 100 MHz (khác với thiết kế thực dùng 50 MHz) để rút ngắn thời gian mô phỏng.

---

## 5. Luồng Dữ Liệu Tổng Thể

```
ecg_rom.mem (1024 mẫu hex)
      │
      ▼
[adc_simulator]          50 MHz → 360 Hz, output 10-bit ECG raw
      │ ecg_raw [9:0]
      ▼
[signal_normalizer]      Trừ OFFSET=100, clamp ≥ 0
      │ ecg_norm [9:0]
      ▼
[moving_average_filter]  Trung bình 8 mẫu đệ quy, sum 13-bit
      │ ecg_filtered [9:0]
      ▼
[lowpass_filter]         IIR: Y = (X + 3Y_prev) / 4
      │ ecg_final [9:0]
      ▼
[peak_detector]          Cửa sổ 3 điểm + threshold + deadzone 72 mẫu
      │ peak (1-bit pulse)
      ▼
[rr_interval_counter]    Đếm clock giữa 2 đỉnh, 32-bit
      │ rr_interval [31:0] + ready_strobe
      ▼
[bpm_calculator]         BPM = 60000ms / (rr_interval / 50000)
      │ bpm [7:0] + rr_ms [15:0]
      ▼
[arrhythmia_detector]    So sánh BPM với ngưỡng 60 / 100
      │
      ▼
  abnormal (1-bit) + type [1:0]
  → Đưa ra cảnh báo loạn nhịp tim
```

---

## 6. Danh Sách Lỗi

| # | File | Loại | Mô tả ngắn |
|---|------|:----:|-----------|
| 1 | `peak_detector.v` | 🔴 E | `DEADZONE_LIMIT` chưa khai báo (phải là `DEADZONE_VAL`) |
| 2 | `bpm_calculator.v` | 🔴 E | Port `start_calc` chưa khai báo trong module |
| 3 | `bpm_calculator.v` | 🔴 E | Signal `raw_count` chưa khai báo (phải là `rr_interval`) |
| 4 | `bpm_calculator.v` | 🟡 W | Điều kiện lọc BPM bị ngược logic |
| 5 | `tb_adc.v` | 🔴 E | `data_en` chưa khai báo trong testbench |
| 6 | `tb_adc.v` | 🔴 E | `ecg_final` chưa khai báo trong testbench |
| 7 | `tb_bpm_core.v` | 🔴 E | Instantiate `rr_counter` thay vì `rr_interval_counter` |
| 8 | `tb_bpm_core.v` | 🔴 E | Port `.raw_count` không tồn tại trong `bpm_calculator` |
| 9 | `tb_bpm_core.v` | 🔴 E | Thiếu kết nối port `sample_tick` cho `peak_detector` |
| 10 | `tb_bpm_core.v` | 🟡 W | Width mismatch: `bpm` khai báo `[15:0]` thay vì `[7:0]` |
| 11 | `tb_bpm_core.v` | 🟡 W | `arrhythmia_detector` thiếu `clk`, `rst`, `ready_strobe`, `type` |

**Tổng:** 8 lỗi biên dịch (🔴 E) · 3 cảnh báo logic (🟡 W)

---

## 7. Nhận Xét Thiết Kế

### Điểm mạnh

- **Pipeline rõ ràng:** Mỗi module đảm nhận đúng một chức năng, dễ kiểm thử độc lập.
- **Tối ưu phần cứng:** Moving average dùng thuật toán đệ quy (cộng/trừ thay vì 7 phép cộng nối tiếp), lowpass filter dùng dịch bit thay vì phép chia thực sự.
- **Deadzone hợp lý:** 72 mẫu ở 360 Hz = 200ms, phù hợp với thực tế sinh lý tim người (khoảng bất hoạt sau đỉnh R).
- **Tham số hóa:** `signal_normalizer` dùng `parameter OFFSET` dễ chỉnh theo dữ liệu thực.
- **Reset đồng bộ/bất đồng bộ:** Pipeline 1 dùng reset tích cực thấp (`rst_n`), Pipeline 2 dùng reset tích cực cao (`rst`) — nhất quán trong từng pipeline.

### Điểm cần cải thiện

- **Thiếu nhất quán tên tín hiệu** giữa module definition và nơi instantiate — nguyên nhân chính gây ra 5/8 lỗi biên dịch.
- **`bpm_calculator` thiếu port:** `start_calc` và `raw_count` cần được thêm vào port list hoặc thống nhất tên với testbench.
- **Hai pipeline chưa được tích hợp:** Chưa có top-level module kết nối đầu ra của pipeline 1 vào đầu vào của pipeline 2.
- **Testbench Pipeline 2 dùng clock khác (100 MHz):** Các hằng số `CLK_PER_MS` trong `bpm_calculator` được tính cho 50 MHz — kết quả BPM trong testbench sẽ sai gấp đôi.
- **Không có top-level testbench tích hợp:** Hai pipeline chỉ được test riêng lẻ, chưa có kịch bản test end-to-end từ ROM đến cảnh báo loạn nhịp.

---

*Báo cáo được tạo tự động · Computer-Architecture-main · ECG Verilog Project*
