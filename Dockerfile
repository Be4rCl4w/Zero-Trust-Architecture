FROM ubuntu:22.04

# Check https://github.com/actions/runner/releases for the latest version
ARG RUNNER_VERSION=2.335.0
ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update && apt-get install -y --no-install-recommends \
      curl jq git sudo ca-certificates openssl nodejs unzip \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m runner
WORKDIR /home/runner/actions-runner

RUN curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
      | tar xz \
    && ./bin/installdependencies.sh

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh && chown -R runner:runner /home/runner

USER runner
ENTRYPOINT ["./entrypoint.sh"]