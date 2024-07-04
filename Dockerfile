FROM node:18
RUN apt update && \
    apt install git -y 
WORKDIR /root/
RUN git clone https://github.com/maheshryali1122/strapi-terraform.git
WORKDIR /root/strapi-terraform
COPY .env .
RUN npm install && \
    npm run build && \
    npm install pm2 -g
EXPOSE 1337
CMD ["pm2-runtime", "start", "npm", "--", "run", "start"]    

