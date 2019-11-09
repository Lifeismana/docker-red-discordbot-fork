ARG ARCH_IMG

FROM alpine
ARG DRONE_COMMIT_SHA
RUN if [ "x$DRONE_COMMIT_SHA" = "x" ] ; then echo Build argument 'DRONE_COMMIT_SHA' needs to be set and non-empty. ; exit 1 ; else echo DRONE_COMMIT_SHA=${DRONE_COMMIT_SHA} ; fi



FROM ${ARCH_IMG}

# noaudio tag
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
# Redbot dependencies
        libssl-dev \
        libffi-dev \
        git \
        unzip \
    ; \
    rm -rf /var/lib/apt/lists/*; \
# Set up all three config locations
    mkdir -p /root/.config/Red-DiscordBot; \
    ln -s /config/config.json /root/.config/Red-DiscordBot/config.json; \
    mkdir -p /usr/local/share/Red-DiscordBot; \
    ln -s /config/config.json /usr/local/share/Red-DiscordBot/config.json; \
    mkdir -p /config/.config/Red-DiscordBot; \
    ln -s /config/config.json /config/.config/Red-DiscordBot/config.json;

# audio tag
RUN set -eux; \
    mkdir -p /usr/share/man/man1/; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
# Redbot audio dependencies
        default-jre-headless \
    ; \
    rm -rf /var/lib/apt/lists/*;

COPY root/ /

ARG DRONE_COMMIT_SHA
ENV PCX_DISCORDBOT_COMMIT ${DRONE_COMMIT_SHA}
ENV PCX_DISCORDBOT_TAG audio

VOLUME /data

CMD ["/app/start-redbot.sh"]

LABEL maintainer="Ryan Foster <phasecorex@gmail.com>"
