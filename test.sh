#!/bin/bash

if [ ! -d "./service" ]; then
    echo "Error: ./service directory not found"
    exit 1
fi

echo "Building and starting service in ./service"
cd service
docker compose up --build -d || { echo "Error: Failed to start service"; exit 1; }
cd ..

if [ -d "./checker" ]; then
    echo "Running checker in ./checker"
        cd ./checker && flagdata=$(docker run --rm --add-host=host.docker.internal:host-gateway -v ./:/test glitchrange/checkertest | tee /dev/tty | grep "flag")  && cd ..
elif [ -d "./checkers" ]; then
    for dir in ./checkers/*; do
        if [ -d "$dir" ]; then
            echo "Running checker in $dir"
            cd "$dir" && flagdata=$(docker run --rm --add-host=host.docker.internal:host-gateway -v ./:/test glitchrange/checkertest | tee /dev/tty | grep "flag")  && cd ../..
        fi
    done
else
    echo "Error: No ./checker or ./checkers directory found"
    exit 1
fi

echo "Service docker logs:"
cd service
docker compose logs
cd ..


# Test exploits
echo -e "\n\nTesting exploits..."
flag=$(echo "$flagdata" | tr ',' '\n' | grep -m 1 flag | awk -F: '{print $2}' | tr -d ' ' | tr -d '"')
flag_id=$(echo "$flagdata" | tr ',' '\n' | grep -m 1 flag_id | awk -F: '{print $2}' | tr -d ' ' | tr -d '"')

# Loop over every directory in ./exploits
for dir in ./exploits/*; do
    if [ -d "$dir" ]; then
        echo -e "Testing exploit $dir\n"
        cd "$dir"
        # Check if exploit.py exists
        if [ -f "exploit.py" ]; then
            exploit_output=$(docker run --rm --add-host=host.docker.internal:host-gateway -v ./:/exploit python:latest bash -c "cd /exploit; pip install --no-cache-dir --root-user-action=ignore --disable-pip-version-check --quiet -r requirements.txt; python exploit.py host.docker.internal '$flag_id'" | tee /dev/tty)
            # Check for flag in exploit output
            if echo "$exploit_output" | grep -q "$flag"; then
                echo -e "\n\033[92mSuccess: Flag found in exploit output for exploit $dir\033[0m"
            else
                echo -e "\n\033[91mError: Flag not found in exploit output for exploit $dir \033[0m"
            fi
        else
            echo "Error: exploit.py not found in $dir"
        fi
        echo ""
        cd ../..
    fi
done

cd service
docker compose down || { echo "Error: Failed to stop service"; exit 1; }
cd ..


echo "Done testing exploits"


echo "All tests complete"


