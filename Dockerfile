
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG SUPABASE_URL
ARG SUPABASE_KEY

RUN flutter build web --release \
    --dart-define=SUPABASE_URL="https://ecipnzomxnwlsuzydqty.supabase.co" \
    --dart-define=SUPABASE_KEY="sb_publishable_rVOQZeIMmXhzP2EPQPoK5A_lpnkTlL8"

FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
