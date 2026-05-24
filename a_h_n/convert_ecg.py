import wfdb
import numpy as np

# 1. Đọc dữ liệu từ file 100 (.dat và .hea)
# sampto=1024 nghĩa là mình lấy 1024 mẫu đầu tiên (khoảng 3-4 nhịp tim)
record = wfdb.rdrecord('100', sampto=1024)

# 2. Lấy tín hiệu từ kênh đầu tiên (thường là MLII - rất rõ đỉnh R)
signal = record.p_signal[:, 0]

# 3. Chuẩn hóa dữ liệu về dải 10-bit (0 đến 1023) để nạp vào FPGA
s_min = np.min(signal)
s_max = np.max(signal)
# Công thức chuẩn hóa: (x - min) / (max - min) * 1023
v_norm = ((signal - s_min) / (s_max - s_min)) * 1023
v_int = v_norm.astype(int)

# 4. Ghi ra file ecg_rom.mem dưới dạng HEX
with open('ecg_rom.mem', 'w') as f:
    for value in v_int:
        # Ghi định dạng Hex 3 chữ số (ví dụ: 0A1, 3FF)
        f.write(f"{value:03X}\n")

print("Xong! Bạn đã có file ecg_rom.mem để nạp vào Verilog.")