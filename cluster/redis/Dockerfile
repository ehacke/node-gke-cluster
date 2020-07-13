FROM redis:5.0

RUN apt-get update && apt-get install -yy -q vim dnsutils curl sysfsutils

RUN mkdir /redis
COPY redis.conf /redis/redis.conf

COPY run.sh /run.sh
COPY healthCheck.sh /healthCheck.sh

RUN chmod 777 /run.sh
RUN chmod 777 /healthCheck.sh

CMD [ "/run.sh" ]
ENTRYPOINT [ "sh", "-c" ]
