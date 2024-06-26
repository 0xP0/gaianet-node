#!/bin/bash

# target name
target=$(uname -m)

# represents the directory where the script is located
cwd=$(pwd)

# 0: do not reinstall, 1: reinstall
reinstall=0
# url to the config file
config_url=""
# path to the gaianet base directory
gaianet_base_dir="$HOME/gaianet"

function print_usage {
    printf "Usage:\n"
    printf "  ./install.sh [Options]\n\n"
    printf "Options:\n"
    printf "  --config <Url>: specify a url to the config file\n"
    printf "  --base <Path>: specify a path to the gaianet base directory\n"
    printf "  --reinstall: install and download all required deps\n"
    printf "  --help: Print usage\n"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --config)
            config_url="$2"
            shift
            shift
            ;;
        --base)
            gaianet_base_dir="$2"
            shift
            shift
            ;;
        --reinstall)
            reinstall=1
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $key"
            print_usage
            exit 1
            ;;
    esac
done

printf "\n"

# if need to reinstall, remove the $gaianet_base_dir directory
if [ "$reinstall" -eq 1 ] && [ -d "$gaianet_base_dir" ]; then
    printf "[+] Removing the existing $gaianet_base_dir directory ...\n\n"
    rm -rf $gaianet_base_dir
fi

# Check if $gaianet_base_dir directory exists
if [ ! -d $gaianet_base_dir ]; then
    mkdir -p $gaianet_base_dir
fi

# check if `log` directory exists or not
if [ ! -d "$gaianet_base_dir/log" ]; then
    mkdir -p $gaianet_base_dir/log
fi
log_dir=$gaianet_base_dir/log

# 1. check if config.json and nodeid.json exist or not
cd $gaianet_base_dir
if [ -n "$config_url" ]; then
    printf "[+] Downloading config file from %s\n" "$config_url"
    curl -s -L $config_url -o config.json
    printf "\n"
elif [ ! -f "$gaianet_base_dir/config.json" ]; then
    printf "[+] Downloading default config file ...\n"
    curl -s -LO https://github.com/GaiaNet-AI/gaianet-node/raw/main/config.json
    printf "\n"
fi

# 2. download nodeid.json
if [ ! -f "$gaianet_base_dir/nodeid.json" ]; then
    printf "[+] Downloading nodeid.json ...\n\n"
    curl -s -LO https://github.com/GaiaNet-AI/gaianet-node/raw/main/nodeid.json
fi

# 3. Install WasmEdge with wasi-nn_ggml plugin for local user
if ! command -v wasmedge >/dev/null 2>&1 || [ "$reinstall" -eq 1 ]; then
    printf "[+] Installing WasmEdge with wasi-nn_ggml plugin ...\n\n"
    if curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install_v2.sh | bash -s; then
        source $HOME/.wasmedge/env
        wasmedge_path=$(which wasmedge)
        wasmedge_version=$(wasmedge --version)
        printf "\n    The WasmEdge Runtime %s is installed in %s.\n\n" "$wasmedge_version" "$wasmedge_path"
    else
        echo "Failed to install WasmEdge"
        exit 1
    fi
else
    wasmedge_version=$(wasmedge --version)
    printf "[+] WasmEdge Runtime %s is already installed.\n" "$wasmedge_version"
fi
printf "\n"

# 4. Install Qdrant at $HOME/gaianet/bin
# Check if "$gaianet_base_dir/bin" directory exists
if [ ! -d "$gaianet_base_dir/bin" ]; then
    # If not, create it
    mkdir -p $gaianet_base_dir/bin
fi
if [ ! -f "$gaianet_base_dir/bin/qdrant" ] || [ "$reinstall" -eq 1 ]; then
    printf "[+] Installing Qdrant binary...\n"

    qdrant_version="v1.8.1"
    if [ "$(uname)" == "Darwin" ]; then
        # download qdrant binary
        if [ "$target" = "x86_64" ]; then
            curl --retry 3 --progress-bar -LO https://github.com/qdrant/qdrant/releases/download/$qdrant_version/qdrant-x86_64-apple-darwin.tar.gz
            tar -xzf qdrant-x86_64-apple-darwin.tar.gz -C $gaianet_base_dir/bin
            rm qdrant-x86_64-apple-darwin.tar.gz
        elif [ "$target" = "arm64" ]; then
            curl --retry 3 --progress-bar -LO https://github.com/qdrant/qdrant/releases/download/$qdrant_version/qdrant-aarch64-apple-darwin.tar.gz
            tar -xzf qdrant-aarch64-apple-darwin.tar.gz -C $gaianet_base_dir/bin
            rm qdrant-aarch64-apple-darwin.tar.gz
        fi

    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        # download qdrant statically linked binary
        if [ "$target" = "x86_64" ]; then
            curl --retry 3 --progress-bar -LO https://github.com/qdrant/qdrant/releases/download/$qdrant_version/qdrant-x86_64-unknown-linux-musl.tar.gz
            tar -xzf qdrant-x86_64-unknown-linux-musl.tar.gz -C $gaianet_base_dir/bin
            rm qdrant-x86_64-unknown-linux-musl.tar.gz
        elif [ "$target" = "aarch64" ]; then
            curl --retry 3 --progress-bar -LO https://github.com/qdrant/qdrant/releases/download/$qdrant_version/qdrant-aarch64-unknown-linux-musl.tar.gz
            tar -xzf qdrant-aarch64-unknown-linux-musl.tar.gz -C $gaianet_base_dir/bin
            rm qdrant-aarch64-unknown-linux-musl.tar.gz
        fi

    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        printf "For Windows users, please run this script in WSL.\n"
        exit 1
    else
        printf "Only support Linux, MacOS and Windows.\n"
        exit 1
    fi

else
    printf "[+] Using the cached Qdrant binary ...\n"
fi
printf "\n"

# 5. Download GGUF chat model to $HOME/gaianet
url_chat_model=$(awk -F'"' '/"chat":/ {print $4}' $gaianet_base_dir/config.json)
chat_model=$(basename $url_chat_model)
if [ -f "$gaianet_base_dir/$chat_model" ]; then
    printf "[+] Using the cached chat model: $chat_model\n"
else
    printf "[+] Downloading $chat_model ...\n\n"
    curl --retry 3 --progress-bar -L $url_chat_model -o $gaianet_base_dir/$chat_model
fi
printf "\n"

# 6. Download GGUF embedding model to $HOME/gaianet
url_embedding_model=$(awk -F'"' '/"embedding":/ {print $4}' $gaianet_base_dir/config.json)
embedding_model=$(basename $url_embedding_model)
if [ -f "$gaianet_base_dir/$embedding_model" ]; then
    printf "[+] Using the cached embedding model: $embedding_model\n"
else
    printf "[+] Downloading $embedding_model ...\n\n"
    curl --retry 3 --progress-bar -L $url_embedding_model -o $gaianet_base_dir/$embedding_model
fi
printf "\n"


# 7. Download rag-api-server.wasm
cd $gaianet_base_dir
if [ ! -f "$gaianet_base_dir/rag-api-server.wasm" ] || [ "$reinstall" -eq 1 ]; then
    printf "[+] Downloading the rag-api-server.wasm ...\n"
    curl --retry 3 --progress-bar -LO https://github.com/LlamaEdge/rag-api-server/releases/latest/download/rag-api-server.wasm
else
    printf "[+] Using the cached rag-api-server.wasm ...\n"
fi
printf "\n"

# 7. Download dashboard to $HOME/gaianet
if ! command -v tar &> /dev/null
then
    echo "tar could not be found, please install it."
    exit
fi

if [ ! -d "$gaianet_base_dir/dashboard" ] || [ "$reinstall" -eq 1 ]; then
    printf "[+] Downloading dashboard ...\n"
    if [ -d "$gaianet_base_dir/gaianet-node" ]; then
        rm -rf $gaianet_base_dir/gaianet-node
    fi
    cd $gaianet_base_dir
    curl --retry 3 --progress-bar -LO https://github.com/GaiaNet-AI/gaianet-node/raw/main/dashboard.tar.gz
    tar xzf dashboard.tar.gz

    rm -rf $gaianet_base_dir/dashboard.tar.gz
else
    printf "[+] Using cached dashboard ...\n"
fi
printf "\n"

# 8 Generate node ID and copy config to dashboard
printf "[+] Downloading the registry.wasm ...\n\n"
curl -s -LO https://github.com/GaiaNet-AI/gaianet-node/raw/main/utils/registry/registry.wasm
# if [ ! -f "$gaianet_base_dir/registry.wasm" ] || [ "$reinstall" -eq 1 ]; then
#     printf "[+] Downloading the registry.wasm ...\n\n"
#     curl -s -LO https://github.com/GaiaNet-AI/gaianet-node/raw/main/utils/registry/registry.wasm
# else
#     printf "[+] Using cached registry ...\n\n"
# fi
printf "[+] Generating node ID ...\n"
wasmedge --dir .:. registry.wasm
printf "\n"

# 9. prepare qdrant dir if it does not exist
if [ ! -d "$gaianet_base_dir/qdrant" ]; then
    printf "[+] Preparing Qdrant directory ...\n"
    mkdir -p $gaianet_base_dir/qdrant && cd $gaianet_base_dir/qdrant

    # download qdrant binary
    curl --retry 3 -s -LO https://github.com/qdrant/qdrant/archive/refs/tags/v1.8.1.tar.gz
    # unzip to `qdrant-1.8.1` directory
    tar -xzf v1.8.1.tar.gz
    rm v1.8.1.tar.gz

    # copy the config directory to `qdrant` directory
    cp -r qdrant-1.8.1/config .

    # remove the `qdrant-1.8.1` directory
    rm -rf qdrant-1.8.1
    printf "\n"
fi

# 10. recover from the given qdrant collection snapshot =======================
printf "[+] Initializing the Qdrant server ...\n\n"

qdrant_pid=0
qdrant_already_running=false
if [ "$(uname)" == "Darwin" ] || [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    if lsof -Pi :6333 -sTCP:LISTEN -t >/dev/null ; then
        # printf "It appears that the GaiaNet node is running. Please stop it first.\n\n"
        # exit 1
	qdrant_already_running=true
    fi
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    printf "For Windows users, please run this script in WSL.\n"
    exit 1
else
    printf "Only support Linux, MacOS and Windows.\n"
    exit 1
fi

if [ "$qdrant_already_running" = false ]; then
    # start qdrant
    cd $gaianet_base_dir/qdrant
    nohup $gaianet_base_dir/bin/qdrant > $log_dir/init-qdrant.log 2>&1 &
    sleep 15
    qdrant_pid=$!
fi

cd $gaianet_base_dir
url_snapshot=$(awk -F'"' '/"snapshot":/ {print $4}' config.json)
url_document=$(awk -F'"' '/"document":/ {print $4}' config.json)
embedding_collection_name=$(awk -F'"' '/"embedding_collection_name":/ {print $4}' config.json)
if [[ -z "$embedding_collection_name" ]]; then
    embedding_collection_name="default"
fi

if [ -n "$url_snapshot" ]; then
    # 10.1 recover from the given qdrant collection snapshot

    printf "[+] Recovering the given Qdrant collection snapshot ...\n\n"
    curl --progress-bar -L $url_snapshot -o default.snapshot

    cd $gaianet_base_dir
    # remove the collection if it exists
    del_response=$(curl -s -X DELETE http://localhost:6333/collections/$embedding_collection_name \
        -H "Content-Type: application/json")
    status=$(echo "$del_response" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')
    if [ "$status" != "ok" ]; then
        printf "    Failed to remove the $embedding_collection_name collection. $del_response\n\n"
        kill $qdrant_pid
        exit 1
    fi

    # Import the default.snapshot file
    response=$(curl -s -X POST http://localhost:6333/collections/$embedding_collection_name/snapshots/upload?priority=snapshot \
        -H 'Content-Type:multipart/form-data' \
        -F 'snapshot=@default.snapshot')
    sleep 5

    if echo "$response" | grep -q '"status":"ok"'; then
        rm $gaianet_base_dir/default.snapshot
        printf "    Recovery is done.\n"
    else
        printf "    Failed to recover from the collection snapshot. $response \n"
        kill $qdrant_pid
        exit 1
    fi

elif [ -n "$url_document" ]; then
    # 10.2 generate a Qdrant collection from the given document

    printf "[+] Creating a Qdrant collection from the given document ...\n\n"

    # Remove the collection if it exists
    printf "    * Removing collection if it exists ...\n\n"
    # remove the 'default' collection if it exists
    del_response=$(curl -s -X DELETE http://localhost:6333/collections/$embedding_collection_name \
        -H "Content-Type: application/json")
    status=$(echo "$del_response" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')
    if [ "$status" != "ok" ]; then
        printf "    Failed to remove the collection. $del_response\n\n"
        kill $qdrant_pid
        exit 1
    fi

    # Start LlamaEdge API Server
    printf "    * Starting LlamaEdge API Server ...\n\n"

    # parse cli options for chat model
    cd $gaianet_base_dir
    url_chat_model=$(awk -F'"' '/"chat":/ {print $4}' config.json)
    # gguf filename
    chat_model_name=$(basename $url_chat_model)
    # stem part of the filename
    chat_model_stem=$(basename "$chat_model_name" .gguf)
    # parse context size for chat model
    chat_ctx_size=$(awk -F'"' '/"chat_ctx_size":/ {print $4}' config.json)
    # parse prompt type for chat model
    prompt_type=$(awk -F'"' '/"prompt_template":/ {print $4}' config.json)
    # parse reverse prompt for chat model
    reverse_prompt=$(awk -F'"' '/"reverse_prompt":/ {print $4}' config.json)
    # parse cli options for embedding model
    url_embedding_model=$(awk -F'"' '/"embedding":/ {print $4}' config.json)
    # gguf filename
    embedding_model_name=$(basename $url_embedding_model)
    # stem part of the filename
    embedding_model_stem=$(basename "$embedding_model_name" .gguf)
    # parse context size for embedding model
    embedding_ctx_size=$(awk -F'"' '/"embedding_ctx_size":/ {print $4}' config.json)
    # parse cli options for embedding vector collection name
    embedding_collection_name=$(awk -F'"' '/"embedding_collection_name":/ {print $4}' config.json)
    if [[ -z "$embedding_collection_name" ]]; then
        embedding_collection_name="default"
    fi
    # parse port for LlamaEdge API Server
    llamaedge_port=$(awk -F'"' '/"llamaedge_port":/ {print $4}' config.json)

    if [ "$(uname)" == "Darwin" ] || [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        if lsof -Pi :$llamaedge_port -sTCP:LISTEN -t >/dev/null ; then
            printf "It appears that the GaiaNet node is running. Please stop it first.\n\n"
            exit 1
            # pid=$(lsof -t -i:6333)
            # kill -9 $pid
        fi
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        printf "For Windows users, please run this script in WSL.\n"
        exit 1
    else
        printf "Only support Linux, MacOS and Windows.\n"
        exit 1
    fi

    cd $gaianet_base_dir
    llamaedge_wasm="$gaianet_base_dir/rag-api-server.wasm"
    if [ ! -f "$llamaedge_wasm" ]; then
        printf "LlamaEdge wasm not found at $llamaedge_wasm\n"
        exit 1
    fi

    # command to start LlamaEdge API Server
    cd $gaianet_base_dir
    cmd="wasmedge --dir .:. \
    --nn-preload default:GGML:AUTO:$chat_model_name \
    --nn-preload embedding:GGML:AUTO:$embedding_model_name \
    rag-api-server.wasm -p $prompt_type \
    --model-name $chat_model_stem,$embedding_model_stem \
    --ctx-size $chat_ctx_size,$embedding_ctx_size \
    --qdrant-collection-name $embedding_collection_name \
    --web-ui ./dashboard \
    --socket-addr 0.0.0.0:$llamaedge_port \
    --log-prompts \
    --log-stat"

    # printf "    Run the following command to start the LlamaEdge API Server:\n\n"
    # printf "    %s\n\n" "$cmd"

    nohup $cmd >> $log_dir/init-qdrant-gen-collection.log 2>&1 &
    sleep 2
    llamaedge_pid=$!
    echo $llamaedge_pid > $gaianet_base_dir/llamaedge.pid

    printf "    * Converting the document to embeddings ...\n\n"
    cd $gaianet_base_dir
    doc_filename=$(basename $url_document)
    curl -s $url_document -o $doc_filename

    if [[ $doc_filename != *.txt ]] && [[ $doc_filename != *.md ]]; then
        printf "Error: the document to upload should be a file with 'txt' or 'md' extension.\n"

        # stop the api-server
        if [ -f "$gaianet_base_dir/llamaedge.pid" ]; then
            # printf "[+] Stopping API server ...\n"
            kill $(cat $gaianet_base_dir/llamaedge.pid)
            rm $gaianet_base_dir/llamaedge.pid
        fi

        exit 1
    fi

    # compute embeddings
    embedding_response=$(curl -s -X POST http://127.0.0.1:$llamaedge_port/v1/create/rag -F "file=@$doc_filename")

    if [ -z "$embedding_response" ]; then
        printf "Failed to compute embeddings. Exit ...\n"
        exit 1
    fi

    # remove the downloaded document
    rm -f $gaianet_base_dir/$doc_filename

    # stop the api-server
    if [ -f "$gaianet_base_dir/llamaedge.pid" ]; then
        # stop API server
        kill $(cat $gaianet_base_dir/llamaedge.pid)
        rm $gaianet_base_dir/llamaedge.pid
    fi

else
    echo "Please set 'snapshot' or 'document' field in config.json"
fi
printf "\n"

if [ "$qdrant_already_running" = false ]; then
    # stop qdrant
    kill $qdrant_pid
fi

# ======================================================================================

# 11. Install gaianet-domain at $HOME/gaianet/bin
printf "[+] Installing gaianet-domain...\n"
# Check if the directory exists, if not, create it
if [ ! -d "$gaianet_base_dir/gaianet-domain" ]; then
    mkdir -p $gaianet_base_dir/gaianet-domain
fi

gaianet_domain_version="v0.1.0-alpha.1"
if [ "$(uname)" == "Darwin" ]; then
    # download gaianet-domain binary
    if [ "$target" = "x86_64" ]; then
        curl --retry 3 --progress-bar -LO https://github.com/GaiaNet-AI/gaianet-domain/releases/download/$gaianet_domain_version/gaianet_domain_${gaianet_domain_version}_darwin_amd64.tar.gz
        tar -xzf gaianet_domain_${gaianet_domain_version}_darwin_amd64.tar.gz --strip-components=1 -C $gaianet_base_dir/gaianet-domain
        rm gaianet_domain_${gaianet_domain_version}_darwin_amd64.tar.gz
    elif [ "$target" = "arm64" ]; then
        curl --retry 3 --progress-bar -LO https://github.com/GaiaNet-AI/gaianet-domain/releases/download/$gaianet_domain_version/gaianet_domain_${gaianet_domain_version}_darwin_arm64.tar.gz
        tar -xzf gaianet_domain_${gaianet_domain_version}_darwin_arm64.tar.gz --strip-components=1 -C $gaianet_base_dir/gaianet-domain
        rm gaianet_domain_${gaianet_domain_version}_darwin_arm64.tar.gz
    fi

elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # download gaianet-domain statically linked binary
    if [ "$target" = "x86_64" ]; then
        curl --retry 3 --progress-bar -LO https://github.com/GaiaNet-AI/gaianet-domain/releases/download/$gaianet_domain_version/gaianet_domain_${gaianet_domain_version}_linux_amd64.tar.gz
        tar --warning=no-unknown-keyword -xzf gaianet_domain_${gaianet_domain_version}_linux_amd64.tar.gz --strip-components=1 -C $gaianet_base_dir/gaianet-domain
        rm gaianet_domain_${gaianet_domain_version}_linux_amd64.tar.gz
    elif [ "$target" = "arm64" ]; then
        curl --retry 3 --progress-bar -LO https://github.com/GaiaNet-AI/gaianet-domain/releases/download/$gaianet_domain_version/gaianet_domain_${gaianet_domain_version}_linux_arm64.tar.gz
        tar --warning=no-unknown-keyword -xzf gaianet_domain_${gaianet_domain_version}_linux_arm64.tar.gz --strip-components=1 -C $gaianet_base_dir/gaianet-domain
        rm gaianet_domain_${gaianet_domain_version}_linux_arm64.tar.gz
    fi

elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    printf "For Windows users, please run this script in WSL.\n"
    exit 1
else
    printf "Only support Linux, MacOS and Windows.\n"
    exit 1
fi
printf "\n"

# Copy frpc from $gaianet_base_dir/gaianet-domain to $gaianet_base_dir/bin
cp $gaianet_base_dir/gaianet-domain/frpc $gaianet_base_dir/bin/

# 12. Download frpc.toml, generate a subdomain and print it
curl -s -L https://raw.githubusercontent.com/GaiaNet-AI/gaianet-node/main/frpc.toml -o $gaianet_base_dir/gaianet-domain/frpc.toml

# Read address from config.json as node subdomain
subdomain=$(awk -F'"' '/"address":/ {print $4}' $gaianet_base_dir/config.json)

# Check if the subdomain was read correctly
if [ -z "$subdomain" ]; then
    echo "Failed to read the address from config.json."
    exit 1
fi

# Read domain from config.json
gaianet_domain=$(awk -F'"' '/"domain":/ {print $4}' $gaianet_base_dir/config.json)

# Resolve the IP address of the domain
ip_address=$(dig +short a.$gaianet_domain | tr -d '\n')

# Check if the IP address was resolved correctly
if [ -z "$ip_address" ]; then
    echo "Failed to resolve the IP address of the domain."
    exit 1
fi

# Replace the serverAddr & subdomain in frpc.toml
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sed_i_cmd="sed -i"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    sed_i_cmd="sed -i ''"
else
    echo "Unsupported OS"
    exit 1
fi

# Generate a random string as Device ID
device_id="device-$(openssl rand -hex 12)"

$sed_i_cmd "s/subdomain = \".*\"/subdomain = \"$subdomain\"/g" $gaianet_base_dir/gaianet-domain/frpc.toml
$sed_i_cmd "s/serverAddr = \".*\"/serverAddr = \"$ip_address\"/g" $gaianet_base_dir/gaianet-domain/frpc.toml
$sed_i_cmd "s/name = \".*\"/name = \"$subdomain.$gaianet_domain\"/g" $gaianet_base_dir/gaianet-domain/frpc.toml
$sed_i_cmd "s/metadatas.deviceId = \".*\"/metadatas.deviceId = \"$device_id\"/g" $gaianet_base_dir/gaianet-domain/frpc.toml

# Remove all files in the directory except for frpc and frpc.toml
find $gaianet_base_dir/gaianet-domain -type f -not -name 'frpc' -not -name 'frpc.toml' -exec rm -f {} \;

printf "Please run the start.sh script to start the GaiaNet node. Once started, the node will be available at: https://$subdomain.$gaianet_domain\n"

printf "Your node ID is $subdomain Please register it in your portal account to receive awards!\n"

exit 0
