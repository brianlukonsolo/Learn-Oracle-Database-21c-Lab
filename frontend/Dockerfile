# =====================================================================
#  dashboard (frontend)  -  React build, served by nginx.
#
#  Multi-stage so Node only exists at build time -- nothing is installed
#  on the host, and the final image is a tiny static nginx server.
# =====================================================================
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
# /usr/share/nginx/html/api is mounted from the shared 'monitor-status' volume.
EXPOSE 80
