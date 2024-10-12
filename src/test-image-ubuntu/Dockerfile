FROM ubuntu:latest

RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install nmap iproute2 iputils-ping -y

ENTRYPOINT ["tail"]
CMD ["-f","/dev/null"]