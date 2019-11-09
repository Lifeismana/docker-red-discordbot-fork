#!/usr/bin/env sh
set -e

# Thank you https://stackoverflow.com/a/18558871
beginswith() { case $2 in "$1"*) true;; *) false;; esac; }
# Thank you https://unix.stackexchange.com/a/444676
prep_term()
{
    unset term_child_pid
    unset term_kill_needed
    trap 'handle_term' TERM INT
}
handle_term()
{
    if [ "${term_child_pid}" ]; then
        kill -TERM "${term_child_pid}" 2>/dev/null
    else
        term_kill_needed="yes"
    fi
}
wait_term()
{
    term_child_pid=$!
    if [ "${term_kill_needed}" ]; then
        kill -TERM "${term_child_pid}" 2>/dev/null 
    fi
    wait ${term_child_pid}
    trap - TERM INT
    wait ${term_child_pid}
}

# Patch older versions of user data if needed
/app/patch.sh

# If config symlink is broken because user mounted /config, make it
if [ $(readlink -f /config/.config/Red-DiscordBot/config.json) != "/config/config.json" ]; then
    rm -rf /config/.config/Red-DiscordBot
    mkdir -p /config/.config/Red-DiscordBot
    ln -s /config/config.json /config/.config/Red-DiscordBot/config.json
fi

# If the /config folder was not mounted (same filesystem as root directory), we want to always recreate /config/config.json (in case the user changes settings and doesn't delete the entire container)
if [ $(stat -c "%d" /) -eq $(stat -c "%d" /config) ]; then
    rm -rf /config/config.json
fi

# If config file does exist, skip all of this (user mounted the /config folder with a config.json in it)
if [ -f "/config/config.json" ]; then
    echo "Using existing /config/config.json file for Red-DiscordBot storage settings"
else
    STORAGE_TYPE=${STORAGE_TYPE:-json}
    if ! [ -f "/defaults/config.${STORAGE_TYPE}.json" ]; then
        echo "ERROR: The STORAGE_TYPE '${STORAGE_TYPE}' is not supported. Exiting..."
        exit 1
    fi
    echo "Using '${STORAGE_TYPE}' for Red-DiscordBot data storage"

    cp /defaults/config.${STORAGE_TYPE}.json /config/config.json
    if beginswith mongodb "${STORAGE_TYPE}"; then
        sed -i \
        -e "s/MONGODB_HOST/${MONGODB_HOST}/g" \
        -e "s/MONGODB_PORT/${MONGODB_PORT:-27017}/g" \
        -e "s/MONGODB_USERNAME/${MONGODB_USERNAME}/g" \
        -e "s/MONGODB_PASSWORD/${MONGODB_PASSWORD}/g" \
        -e "s/MONGODB_DB_NAME/${MONGODB_DB_NAME}/g" \
        /config/config.json
    fi
fi

# Set up token and prefixes if supplied
if ! [ -z ${PREFIX5+x} ]; then
    EXTRA_ARGS="--prefix ${PREFIX5} ${EXTRA_ARGS}"
fi
if ! [ -z ${PREFIX4+x} ]; then
    EXTRA_ARGS="--prefix ${PREFIX4} ${EXTRA_ARGS}"
fi
if ! [ -z ${PREFIX3+x} ]; then
    EXTRA_ARGS="--prefix ${PREFIX3} ${EXTRA_ARGS}"
fi
if ! [ -z ${PREFIX2+x} ]; then
    EXTRA_ARGS="--prefix ${PREFIX2} ${EXTRA_ARGS}"
fi
if ! [ -z ${PREFIX+x} ]; then
    EXTRA_ARGS="--prefix ${PREFIX} ${EXTRA_ARGS}"
fi
if ! [ -z ${TOKEN+x} ]; then
    EXTRA_ARGS="--token ${TOKEN} ${EXTRA_ARGS}"
fi

echo "Activating Python virtual environment..."
mkdir -p /data/venv
python -m venv --upgrade /data/venv
python -m venv /data/venv
. /data/venv/bin/activate

# Return code of 26 means the bot should restart
RETURN_CODE=26
while [ ${RETURN_CODE} -eq 26 ]; do
    echo "Updating Red-DiscordBot..."
    python -m pip install --upgrade --no-cache-dir pip

    if beginswith mongodb "${STORAGE_TYPE}"; then
        python -m pip install --upgrade --no-cache-dir Red-DiscordBot[mongo]
    else
        python -m pip install --upgrade --no-cache-dir Red-DiscordBot
    fi

    echo "Starting Red-DiscordBot!"

    set +e
    # If we are running in an interactive shell, we can't do any of the fancy interrupt catching
    if [ -t 0 ]; then
        redbot docker ${EXTRA_ARGS}
        RETURN_CODE=$?
    else
        prep_term
        redbot docker ${EXTRA_ARGS} &
        wait_term
        RETURN_CODE=$?
    fi
    set -e
done
