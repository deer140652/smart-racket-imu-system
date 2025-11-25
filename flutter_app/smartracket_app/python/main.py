import numpy as np
import tensorflow as tf

# 載入 TFLite 模型並分配張量
interpreter = tf.lite.Interpreter(model_path="../assets/badminton_model.tflite")
interpreter.allocate_tensors()

# 獲取輸入和輸出張量
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input details:", input_details)
print("Output details:", output_details)