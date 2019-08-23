FROM alpine:3.9 as installer

# Download base APK packages
RUN apk --no-cache add \
        curl \
        python \
        py-crcmod \
        bash \
        libc6-compat \
        openssh-client \
        git

# Terraform version
ENV TERRAFORM_VERSION=0.12.6 TERRAFORM_SHA256SUM=6544eb55b3e916affeea0a46fe785329c36de1ba1bdb51ca5239d3567101876f

# Download Terraform and put it's hash in the SUMS file
RUN curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip > terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    echo "${TERRAFORM_SHA256SUM}  terraform_${TERRAFORM_VERSION}_linux_amd64.zip" >> SHA256SUMS

# Validate the tool hashes
RUN sha256sum -c SHA256SUMS

# Unzip the files to their destinations after validated
RUN unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /bin

#########################
FROM gcr.io/distroless/static

# Disable Terraform CLI input by default
ENV TF_INPUT 0
ENV TF_IN_AUTOMATION 1

# Set location of Terraform CLI config
ENV TF_CLI_CONFIG_FILE /.terraformrc

# Set location of Google credentials
ENV GOOGLE_APPLICATION_CREDENTIALS /credentials.json

# Copy files from installer step
COPY --from=installer /bin/terraform /terraform

# Expose volumes
VOLUME ["/.terraformrc", "/credentials.json", "/tf-project"]

WORKDIR /tf-project

ENTRYPOINT ["/terraform"]
