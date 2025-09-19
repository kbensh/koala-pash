FROM ghcr.io/binpash/pash/pash

WORKDIR /benchmarks

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    wget \
    unzip \
    python3-pip \
    git \
    gpg

COPY . .
RUN chmod +x /benchmarks/main.sh

ENV LC_ALL=C
ENV TC=UTC

# Fake sudo for install scripts — makes it a no-op
RUN printf '#!/bin/sh\nexec "$@"\n' > /tmp/sudo && chmod +x /tmp/sudo
ENV PATH="/tmp:$PATH"

ENV KOALA_SHELL="/opt/pash/pa.sh -d 1 -p -w 4"

RUN git config --global --add safe.directory /benchmarks

RUN /benchmarks/setup.sh

CMD ["bash"]
