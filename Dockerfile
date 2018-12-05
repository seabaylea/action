FROM seabaylea/expressjs-base

WORKDIR "/app/server/routers"

COPY *.js ./

CMD ["npm", "start"]
