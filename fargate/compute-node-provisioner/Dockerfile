FROM debian:bullseye

WORKDIR /usr/src/app

RUN  apt-get update && apt-get -y install wget && apt-get -y install gpg && apt-get install -y lsb-release && apt-get install -y curl && apt-get install -y unzip

# Install terraform
RUN apt-get update && apt-get install -y lsb-release && \
    echo "Distribution: $(lsb_release -cs)" && \
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get -y install terraform

  RUN terraform -v

# install Go
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz

RUN  rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

ENV PATH="${PATH}:/usr/local/go/bin"

# cleanup
RUN rm -f go1.21.0.linux-amd64.tar.gz
 
COPY . ./
RUN go mod tidy

RUN go build -v -o /usr/local/bin/app .

ADD terraform/ /usr/src/app/terraform/

CMD [ "app" ]