# Use NGINX to serve the React build
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
