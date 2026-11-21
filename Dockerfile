FROM ubuntu:22.04

# Check https://github.com/actions/runner/releases for the latest version
ARG RUNNER_VERSION=2.335.0
ARG TERRAFORM_VERSION=1.14.6
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    git \
    sudo \
    ca-certificates \
    openssl \
    unzip \
    apt-transport-https \
    lsb-release \
    gnupg \
&& curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
&& apt-get install -y nodejs \
&& curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
&& curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
&& unzip /tmp/terraform.zip -d /usr/local/bin \
&& rm -f /tmp/terraform.zip \
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
