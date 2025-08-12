# Use NGINX to serve the React build
FROM public.ecr.aws/nginx/nginx:alpine
COPY dist/ /usr/share/nginx/html
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]

