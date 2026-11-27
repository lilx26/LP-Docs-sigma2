# Local OVMS Deployment

This guide explains how to restore the pre-installed local AI API on LattePanda Sigma 2 after reinstalling Ubuntu.

It covers downloading and configuring OpenVINO Model Server (OVMS), deploying the Qwen3.6-35B-A3B model, and verifying the local API.

!!! note
    This guide applies to Ubuntu 24.04 LTS and Ubuntu 26.04 LTS. The Ubuntu 26.04 procedure has been tested on Sigma 2. For Ubuntu 24.04, use the corresponding package and dependencies.

## Prerequisites

Before starting, make sure the following requirements are met:

- Ubuntu 24.04 LTS (24.04.4 or later with HWE kernel) or Ubuntu 26.04 LTS.
- Linux kernel 6.17 or later; Linux 7.0 or later is recommended.
- Intel GPU Compute Driver installed and working.
- Current user belongs to the `render` group.
- Internet connection available for downloading OVMS and the model.
- Sufficient free disk space for the model files.

For driver installation, refer to the Intel GPU Compute Driver and Intel NPU Drivers sections in the Ubuntu guide.

## 1. Download and Install OVMS

OVMS provides a standalone binary package and does not require Docker for this deployment.

### Step 1. Install System Dependencies

Select the dependencies corresponding to your Ubuntu version.

=== "Ubuntu 24.04"

    ```bash
    sudo apt update
    sudo apt install -y curl ca-certificates libxml2
    ```

=== "Ubuntu 26.04"

    ```bash
    sudo apt update
    sudo apt install -y curl ca-certificates libxml2-16
    ```

### Step 2. Download the OVMS Package

Intel provides separate precompiled packages for Ubuntu 24.04 and Ubuntu 26.04.

Open a terminal and run the corresponding commands.

=== "Ubuntu 24.04"

    ```bash
    mkdir -p ~/Downloads
    cd ~/Downloads

    curl -fL https://storage.openvinotoolkit.org/repositories/openvino_model_server/packages/weekly/latest/ovms_ubuntu24.tar.gz -o ovms_ubuntu24.tar.gz
    ```

=== "Ubuntu 26.04"

    ```bash
    mkdir -p ~/Downloads
    cd ~/Downloads

    curl -fL https://storage.openvinotoolkit.org/repositories/openvino_model_server/packages/weekly/latest/ovms_ubuntu26.tar.gz -o ovms_ubuntu26.tar.gz
    ```

### Step 3. Extract the Package

After downloading, extract the archive:

```bash
cd ~/Downloads
tar -xzf ovms_ubuntu*.tar.gz
```

The directory structure should look like this:

```text
~/Downloads/
├── ovms_ubuntu26.tar.gz
└── ovms/
    ├── bin/
    │   └── ovms
    └── lib/
        └── ...
```

### Step 4. Configure Environment Variables

Configure the OVMS executable and library paths:

```bash
unset LD_LIBRARY_PATH

export OVMS_HOME="$HOME/Downloads/ovms"

export PATH="$OVMS_HOME/bin:$PATH"

export LD_LIBRARY_PATH="$OVMS_HOME/lib"
```

!!! warning
    If you have previously tested another OVMS package, open a new terminal or clear the old `LD_LIBRARY_PATH` before configuring the current installation. Make sure the library path points to the current OVMS directory.

### Step 5. Verify the Installation

Check which OVMS executable is being used:

```bash
which ovms
```

Check the OVMS version:

```bash
ovms --version
```

Check for missing shared library dependencies:

```bash
ldd "$OVMS_HOME/bin/ovms" | grep 'not found' || echo "No missing dependencies"
```

If the executable starts successfully and no missing dependencies are reported, the OVMS installation is ready.

The tested Ubuntu 26.04 configuration reported:

```text
OpenVINO Model Server 2026.5.0.c60cac3f5
OpenVINO backend 2026.5.0
OpenVINO GenAI backend 2026.5.0
```

<!-- Screenshot: OVMS version and dependency verification -->

!!! note
    The download URL uses Intel's `weekly/latest` build. Its contents are updated regularly, so the installed version may differ from the tested build. Check `ovms --version` and record the actual version.

### Optional: Enable Python Integration

Starting from OVMS 2026.5, Python integration is optional.

It provides Jinja-based chat-template rendering and Python custom nodes. It is useful for models requiring more advanced chat templates or tool-calling functionality.

If required, install the compatible system packages:

=== "Ubuntu 24.04"

    ```bash
    sudo apt install -y python3 libpython3.12 python3-jinja2
    ```

=== "Ubuntu 26.04"

    ```bash
    sudo apt install -y python3 libpython3.14 python3-jinja2
    ```

!!! note
    Python integration is not required to start OVMS or serve models that only use basic chat templates. Do not install separate `openvino`, `openvino-tokenizers`, or `openvino-genai` packages through pip, as these components are already included in OVMS.

## 2. Download and Deploy the LLM

Sigma 2 uses the OpenVINO IR version of Qwen3.6-35B-A3B with INT4 weight compression.

Model repository:

https://huggingface.co/OpenVINO/Qwen3.6-35B-A3B-int4-ov

### Step 1. Prepare the Model Directory

Create the model storage directory:

```bash
mkdir -p ~/models
```

The model will be downloaded and stored in this directory.

### Step 2. Download the Model and Start OVMS

Run the following command:

```bash
ovms --rest_port 8080 \
     --model_repository_path "$HOME/models" \
     --source_model OpenVINO/Qwen3.6-35B-A3B-int4-ov \
     --model_name qwen \
     --reasoning_parser qwen3 \
     --tool_parser qwen3coder \
     --target_device GPU \
     --task text_generation
```

This command performs the following operations:

1. Downloads the model from Hugging Face.
2. Stores the model files in the specified model repository.
3. Loads the model using the Intel GPU.
4. Starts the OVMS service on port `8080`.

Wait for the model to finish downloading and loading.

<!-- Screenshot: Model download and OVMS initialization -->

!!! note
    The first model initialization may take longer due to model loading and GPU compilation. Keep the terminal open while the service is running.

## 3. Verify the Local AI API

After OVMS has started, open another terminal.

### Step 1. Check the Available Models

Run:

```bash
curl http://localhost:8080/v3/models
```

The returned model list should contain the model name `qwen`.

<!-- Screenshot: /v3/models response -->

### Step 2. Test Chat Completion

Send a chat request:

```bash
curl http://localhost:8080/v3/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen",
    "messages": [
      {
        "role": "user",
        "content": "Hello, please introduce yourself."
      }
    ],
    "max_tokens": 200
  }'
```

If the API returns a valid response containing the model-generated answer, the local AI API is working correctly.

<!-- Screenshot: Chat completion response -->

### API Configuration

The local API uses the following settings:

| Item | Value |
|---|---|
| Base URL | `http://localhost:8080/v3` |
| API Format | OpenAI-compatible Chat Completions API |
| Model Name | `qwen` |
| API Key | Not required |
| Inference Device | Intel GPU |
| Port | `8080` |

## 4. Create a Startup Script (Optional)

To avoid entering the full startup command every time, create a shell script.

Create the file:

```bash
nano ~/start-ovms-api.sh
```

Add the following content:

```bash
#!/usr/bin/env bash
set -e

export OVMS_HOME="$HOME/Downloads/ovms"
export PATH="$OVMS_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OVMS_HOME/lib"

exec "$OVMS_HOME/bin/ovms" \
    --rest_port 8080 \
    --model_repository_path "$HOME/models" \
    --source_model OpenVINO/Qwen3.6-35B-A3B-int4-ov \
    --model_name qwen \
    --reasoning_parser qwen3 \
    --tool_parser qwen3coder \
    --target_device GPU \
    --task text_generation
```

Save and exit:

- Press `Ctrl+O`, then `Enter`.
- Press `Ctrl+X`.

Make the script executable:

```bash
chmod +x ~/start-ovms-api.sh
```

Start the service:

```bash
~/start-ovms-api.sh
```

The service runs in the foreground. Keep the terminal open while using the API.

Press `Ctrl+C` to stop the service.

## 5. Important Files

| File Path | Purpose |
|---|---|
| `~/Downloads/ovms/` | OVMS executable and dependency libraries |
| `~/Downloads/ovms_ubuntu26.tar.gz` | OVMS installation package for Ubuntu 26.04 |
| `~/models/` | Downloaded AI model files |
| `~/start-ovms-api.sh` | OVMS API startup script |

## 6. Troubleshooting

### E1. `libxml2.so.2: cannot open shared object file`

This error may occur when using an OVMS package built for Ubuntu 24.04 on Ubuntu 26.04.

Ubuntu 24.04 and Ubuntu 26.04 use different libxml2 shared library versions.

**Solution:**

- Use the OVMS package matching your Ubuntu version.
- Ubuntu 24.04: install `libxml2` and use `ovms_ubuntu24.tar.gz`.
- Ubuntu 26.04: install `libxml2-16` and use `ovms_ubuntu26.tar.gz`.
- Do not create a symbolic link between `libxml2.so.16` and `libxml2.so.2`.

If you previously tested another OVMS version, open a new terminal and reset the environment variables:

```bash
unset LD_LIBRARY_PATH

export OVMS_HOME="$HOME/Downloads/ovms"
export PATH="$OVMS_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OVMS_HOME/lib"
```

Then check the dependencies:

```bash
ldd "$OVMS_HOME/bin/ovms"
```

### E2. `ovms: command not found` or the wrong version is running

This usually indicates that the executable path is not configured correctly.

Check:

```bash
echo "$OVMS_HOME"
which ovms
```

Make sure `PATH` points to the current OVMS installation:

```bash
export OVMS_HOME="$HOME/Downloads/ovms"
export PATH="$OVMS_HOME/bin:$PATH"
```

### E3. Download Fails with a TLS Connection Error

A temporary TLS connection failure may interrupt the package download.

Retry the download:

```bash
curl --retry 5 --retry-all-errors -fL \
https://storage.openvinotoolkit.org/repositories/openvino_model_server/packages/weekly/latest/ovms_ubuntu26.tar.gz \
-o ovms_ubuntu26.tar.gz
```

If the issue persists, check the network connection and proxy settings.

### E4. Port 8080 Is Already in Use

Check whether another OVMS process is running:

```bash
ss -ltnp | grep ':8080'
```

Stop the existing OVMS instance before starting another one.

### E5. The API Cannot Be Reached

Check whether the OVMS process is still running and whether the model has finished loading.

```bash
curl http://localhost:8080/v3/models
```

Review the OVMS startup terminal for model loading or initialization errors.

### E6. The Model Is Not Available

Check the following:

- The model repository path is correct.
- The model name in the API request is `qwen`.
- The model download and initialization have completed.
- The OVMS startup log does not contain model loading errors.

If the model download is interrupted, check the network connection and OVMS logs before retrying.

## References

- LattePanda Sigma 2 Local AI Quick Start: https://docs.lattepanda.com/content/sigma2_edition/local_ai_getting_started/
- LattePanda Sigma 2 Ubuntu: https://docs.lattepanda.com/content/sigma2_edition/os_linux/
- OVMS Bare-metal Deployment: https://docs.openvino.ai/nightly/model-server/ovms_docs_deploying_server_baremetal.html
- OVMS Weekly Packages: https://storage.openvinotoolkit.org/repositories/openvino_model_server/packages/weekly/latest/
- Qwen3.6-35B-A3B OpenVINO Model: https://huggingface.co/OpenVINO/Qwen3.6-35B-A3B-int4-ov