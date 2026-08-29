# Production Nginx Container for Angular PKP Music Web Application
FROM nginx:alpine
COPY dist/pkp-music-web/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
