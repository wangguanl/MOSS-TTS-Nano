# 运行命令

- 项目：MOSS-TTS-Nano
- 生成时间：2026-09-09
- 运行方式：直接运行（`.venv` + FastAPI `app.py` / ONNX `app_onnx.py`）
- 硬件评估：**满足**（0.1B，空卡 15GB 绰绰有余；亦可 CPU）

## 环境准备

```powershell
$env:Path = "E:\Programs\ffmpeg-master-latest-win64-gpl\bin;" + $env:Path
cd E:\AI\local-voice\MOSS-TTS-Nano
$env:HF_ENDPOINT = "https://hf-mirror.com"

# 已有 .venv（Python 3.10 + torch cu128）。包需 editable：
# uv pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
# uv pip install -e . -i https://pypi.tuna.tsinghua.edu.cn/simple
```

本次已执行 `uv pip install -e .`（此前 `import moss_tts_nano` 失败）。

本地模型：
- `E:\huggingface_cache\MOSS-TTS-Nano`
- `E:\huggingface_cache\MOSS-Audio-Tokenizer-Nano`

## 启动

- 推荐：`pwsh -NoProfile -File .\start.ps1`
- 说明：菜单选 `app`（PyTorch Web，默认）或 `app_onnx`；端口起点 18083 / 18084。
- 等价手动：

```powershell
.\.venv\Scripts\python.exe app.py --checkpoint-path E:\huggingface_cache\MOSS-TTS-Nano --audio-tokenizer-path E:\huggingface_cache\MOSS-Audio-Tokenizer-Nano --host 127.0.0.1 --port 18083 --device auto
.\.venv\Scripts\python.exe app_onnx.py --host 127.0.0.1 --port 18084
# CLI：python infer.py --prompt-audio-path assets/audio/zh_1.wav --text "..."
```

## 验证

1. `app.py --help` / `infer.py --help` / `import moss_tts_nano` 已通过。
2. 浏览器 `http://127.0.0.1:18083` 完成一次合成。
3. **未长时间启动 GPU Web 服务**。

## 备注 / 发现问题

- 仅有 `.venv` 依赖但未 `pip install -e .` 时，`moss_tts_nano` 导入失败（已补）。
- Windows 上 WeTextProcessing / pynini 仍可能是文本前端坑点。
- 旧 `start_server.ps1` 写死缓存路径并后台启动；日常请用根目录交互 `start.ps1`。
- HF → `https://hf-mirror.com`；PyPI → 清华。
