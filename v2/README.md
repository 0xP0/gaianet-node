# GaiaNet Installer v2

> [!NOTE]
> GaiaNet Installer v2 is still in active development. Please report any issues you encounter.

## install.sh

```bash
gaianet-node/v2$ bash install.sh
```

or

```bash
bash <(curl -sSfL 'https://raw.githubusercontent.com/GaiaNet-AI/gaianet-node/main/v2/install.sh')
```

<details><summary> The output should look like below: </summary>

```console
[+] Downloading default config file ...

[+] Downloading nodeid.json ...

[+] Installing WasmEdge with wasi-nn_ggml plugin ...

Info: Detected Linux-x86_64

Info: WasmEdge Installation at /home/azureuser/.wasmedge

Info: Fetching WasmEdge-0.13.5

/tmp/wasmedge.2884467 ~/gaianet
######################################################################## 100.0%
~/gaianet
Info: Fetching WasmEdge-GGML-Plugin

Info: Detected CUDA version:

/tmp/wasmedge.2884467 ~/gaianet
######################################################################## 100.0%
~/gaianet
Installation of wasmedge-0.13.5 successful
WasmEdge binaries accessible

    The WasmEdge Runtime wasmedge version 0.13.5 is installed in /home/azureuser/.wasmedge/bin/wasmedge.


[+] Installing Qdrant binary...
    * Download Qdrant binary
################################################################################################## 100.0%

    * Initialize Qdrant directory

[+] Downloading the rag-api-server.wasm ...
################################################################################################## 100.0%

[+] Downloading dashboard ...
################################################################################################## 100.0%
```

</details>

## GaiaNet CLI Tool

```bash
$ gaianet --help

Usage: gaianet {config|init|run|stop|OPTIONS}

Subcommands:
  config             Update the configuration.
  init              Initialize with optional argument.
  run|start         Run the program.
  stop [arg]        Stop the program.

Options:
  --help            Show this help message
```

### Update configuration

Using `gaianet config` subcommand can update the following fields defined in the `config.json` file:

```bash
$ gaianet config --help

Usage: gaianet config [OPTIONS]

Options:
  --chat-url <val>           Update the url of chat model.
  --chat-ctx-size <val>      Update the context size of chat model.
  --embedding-url <val>      Update the url of embedding model.
  --embedding-ctx-size <val> Update the context size of embedding model.
  --prompt-template <val>    Update the prompt template of chat model.
  --port <val>               Update the port of LlamaEdge API Server.
  --system-prompt <val>      Update the system prompt.
  --rag-prompt <val>         Update the rag prompt.
  --reverse-prompt <val>     Update the reverse prompt.
  --base <path>              The base directory of GaiaNet.
  --help                     Show this help message
```

To update the `chat` field, for example, use the following command:

```bash
gaianet config --chat-url "https://huggingface.co/second-state/Llama-2-13B-Chat-GGUF/resolve/main/Llama-2-13b-chat-hf-Q5_K_M.gguf"
```

To update the `chat_ctx_size` field, for example, use the following command:

```bash
gaianet config --chat-ctx-size 5120
```

### Initialize GaiaNet-node

```bash
$ gaianet init --help

Usage: gaianet init [OPTIONS]

Options:
  --config <val|url>          Name of a pre-defined GaiaNet config or a url. Possible values: default, paris_guide, mua, gaia.
  --base <path>              The base directory of GaiaNet.
  --help                     Show this help message
```

<details><summary> The output should look like below: </summary>

```bash
[+] Downloading Llama-2-7b-chat-hf-Q5_K_M.gguf ...
############################################################################################################################## 100.0%############################################################################################################################## 100.0%

[+] Downloading all-MiniLM-L6-v2-ggml-model-f16.gguf ...

############################################################################################################################## 100.0%############################################################################################################################## 100.0%

[+] Creating 'default' collection in the Qdrant instance ...

    * Start a Qdrant instance ...

    * Remove the existed 'default' Qdrant collection ...

    * Download Qdrant collection snapshot ...
############################################################################################################################## 100.0%############################################################################################################################## 100.0%

    * Import the Qdrant collection snapshot ...

    * Recovery is done successfully
```

</details>

### Start GaiaNet-node

```bash
$ gaianet start --help

Usage: gaianet start|run [OPTIONS]

Options:
  --local-only               Start the program in local mode.
  --base <path>              The base directory of GaiaNet.
  --help                     Show this help message
```

<details><summary> The output should look like below: </summary>

```bash
[+] Starting Qdrant instance ...

    Qdrant instance started with pid: 39762

[+] Starting LlamaEdge API Server ...

    Run the following command to start the LlamaEdge API Server:

wasmedge --dir .:./dashboard --nn-preload default:GGML:AUTO:Llama-2-7b-chat-hf-Q5_K_M.gguf --nn-preload embedding:GGML:AUTO:all-MiniLM-L6-v2-ggml-model-f16.gguf rag-api-server.wasm --model-name Llama-2-7b-chat-hf-Q5_K_M,all-MiniLM-L6-v2-ggml-model-f16 --ctx-size 4096,384 --prompt-template llama-2-chat --qdrant-collection-name default --web-ui ./ --socket-addr 0.0.0.0:8080 --log-prompts --log-stat --rag-prompt "Use the following pieces of context to answer the user's question.\nIf you don't know the answer, just say that you don't know, don't try to make up an answer.\n----------------\n"


    LlamaEdge API Server started with pid: 39796
```

</details>

### Stop GaiaNet-node

```bash
$ gaianet stop

Usage: gaianet stop [OPTIONS]

Options:
  --force                    Force stop the program.
  --base <path>              The base directory of GaiaNet.
  --help                     Show this help message
```

<details><summary> The output should look like below: </summary>

```bash
[+] Stopping Qdrant instance ...
[+] Stopping API server ...
```

To force stop the GaiaNet-node, use the following command:

```bash
gaianet stop --force
```

</details>
