# train_badminton_model.py
import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras import layers, models, regularizers
from tensorflow.keras.utils import to_categorical
import tensorflow as tf

# 資料路徑
data_dir = r"D:\AIOT\project\modle\self_made\data"
df = pd.read_excel(os.path.join(data_dir, "output_label_all.xlsx"))

# 檢查原始類別分布
print("原始類別分布：")
print(df['label'].value_counts())

# 切成 40 筆 frame
def create_frames(df, label):
    frames = []
    labels = []
    for i in range(0, len(df) - 40 + 1, 40):
        chunk = df.iloc[i:i+40]
        if len(chunk) < 40:
            continue
        frame_data = chunk[['aX', 'aY', 'aZ', 'gX', 'gY', 'gZ']].to_numpy()
        frames.append(frame_data)
        labels.append(label)
    return frames, labels

# 針對三類別資料分別切 frame
frames_smash, labels_smash = create_frames(df[df['label'] == 'smash'], 'smash')
frames_drive, labels_drive = create_frames(df[df['label'] == 'drive'], 'drive')
frames_other, labels_other = create_frames(df[df['label'] == 'other'], 'other')

print(f"原始 frame 數量：")
print(f"  smash: {len(frames_smash)}")
print(f"  drive: {len(frames_drive)}")
print(f"  other: {len(frames_other)}")

# 目標: 每類別都補到 2000 frame
target_frames = 2000

def balance_frames(frames, labels, target_count):
    frames = np.array(frames)
    labels = np.array(labels)
    if len(frames) >= target_count:
        idx = np.random.choice(len(frames), target_count, replace=False)
    else:
        idx = np.random.choice(len(frames), target_count, replace=True)
    balanced_frames = frames[idx]
    balanced_labels = labels[idx]
    return balanced_frames, balanced_labels

frames_smash_balanced, labels_smash_balanced = balance_frames(frames_smash, labels_smash, target_frames)
frames_drive_balanced, labels_drive_balanced = balance_frames(frames_drive, labels_drive, target_frames)
frames_other_balanced, labels_other_balanced = balance_frames(frames_other, labels_other, target_frames)

# 合併並 shuffle
all_frames = np.concatenate([frames_smash_balanced, frames_drive_balanced, frames_other_balanced], axis=0)
all_labels = np.concatenate([labels_smash_balanced, labels_drive_balanced, labels_other_balanced], axis=0)

# 打亂
shuffle_idx = np.random.permutation(len(all_frames))
frames = all_frames[shuffle_idx]
labels = all_labels[shuffle_idx]

print("\n平衡後 frame 數量：", len(frames))
print("平衡後類別分布：")
print(pd.Series(labels).value_counts())

# One-hot 編碼
le = LabelEncoder()
y_encoded = le.fit_transform(labels)
y_categorical = to_categorical(y_encoded)

# reshape CNN 輸入格式
X = frames.reshape(-1, 40, 6, 1)

# train / val split
X_train, X_val, y_train, y_val = train_test_split(
    X, y_categorical, test_size=0.2, random_state=42, stratify=y_encoded)

# CNN 模型
model = models.Sequential([
    layers.Conv2D(16, (2, 2), activation='relu', input_shape=(40, 6, 1)),
    layers.BatchNormalization(),
    layers.Dropout(0.2),

    layers.Conv2D(32, (2, 2), activation='relu'),
    layers.Dropout(0.1),

    layers.Flatten(),
    layers.Dense(64, activation='relu', kernel_regularizer=regularizers.l2(0.01)),
    layers.Dense(y_categorical.shape[1], activation='softmax')
])

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
model.summary()

# 訓練
history = model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=50, batch_size=64)

# 儲存模型
model.save("badminton_cnn_model.h5")
print("\n 已儲存模型：badminton_cnn_model.h5")

# 轉成 tflite 模型
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open("badminton_model.tflite", "wb") as f:
    f.write(tflite_model)
print(" 已轉存 tflite 模型：badminton_model.tflite")

# 顯示類別對應
print("模型類別順序：", le.classes_)
