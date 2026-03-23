FROM quay.io/raywen/esp-idf:v5.5.3
MAINTAINER Raymond Wen

ENV MATTER_VERSION v1.5

ENV ESP_ROOT_DIR /opt/
WORKDIR ${ESP_ROOT_DIR}

RUN pwd

RUN apt-get update && apt-get install -y git gcc g++ pkg-config cmake curl libssl-dev libdbus-1-dev \
     libglib2.0-dev libavahi-client-dev ninja-build python3-venv python3-dev \
     python3-pip unzip libgirepository1.0-dev libcairo2-dev libreadline-dev \
     default-jre
RUN apt-get -y install python3.11 python3.11-dev python3.11-venv
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2
RUN python3 --version
RUN cd /opt/esp-idf && ./install.sh
RUN cd /opt && git clone --depth=1 --branch v1.5.0.1 https://github.com/project-chip/connectedhomeip.git
ENV PW_ENVSETUP_QUIET=1
ENV TERM=dumb
RUN cd connectedhomeip && \
    python3 scripts/checkout_submodules.py --shallow --platform esp32 && \
    bash -c "source /opt/esp-idf/export.sh && source scripts/bootstrap.sh" 2>&1 | tee /tmp/bootstrap.log

# Install Matter Python deps into the ESP-IDF venv, skipping packages already
# present to avoid version conflicts. Reads from connectedhomeip's own
# requirements files so it stays current across version upgrades.
COPY install_matter_deps.sh /opt/install_matter_deps.sh
RUN chmod +x /opt/install_matter_deps.sh && bash /opt/install_matter_deps.sh

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]
