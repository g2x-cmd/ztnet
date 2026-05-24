#!/bin/bash

# Enable error handling and debug tracing
set -e
# set -x  ( DEBUG )

error_handling() {
    echo "An error occurred. Exiting..."
    exit 1
}
# trap errors
trap error_handling ERR

cmd="$@"

DATA_DIR="${SQLITE_DIR:-/app/data}"
mkdir -p "$DATA_DIR" /var/lib/zerotier-one

export DATABASE_URL="${DATABASE_URL:-file:${DATA_DIR}/ztnet.sqlite}"
export ZT_ADDR="${ZT_ADDR:-http://127.0.0.1:9993}"
export ZT_SECRET_FILE="${ZT_SECRET_FILE:-/var/lib/zerotier-one/authtoken.secret}"

if command -v zerotier-one >/dev/null 2>&1; then
  echo "Starting ZeroTier daemon..."
  zerotier-one -d || true

  for i in $(seq 1 30); do
    if [ -f "$ZT_SECRET_FILE" ]; then
      break
    fi
    echo "Waiting for ZeroTier auth token..."
    sleep 1
  done
fi

# Create .env file for Prisma and Next runtime reads.
echo "Creating .env file..."
cat << EOF > .env
DATABASE_URL=${DATABASE_URL}
ZT_ADDR=${ZT_ADDR}
ZT_SECRET_FILE=${ZT_SECRET_FILE}
NEXTAUTH_URL=${NEXTAUTH_URL}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
NEXT_PUBLIC_APP_VERSION=${NEXT_PUBLIC_APP_VERSION}
EOF

# config
envFilename='.env'
nextFolder='.next'

# Currently not in use. 
function apply_path {
  # echo "Applying path..."
  while read line; do
    if [ "${line:0:1}" == "#" ] || [ "${line}" == "" ]; then
      continue
    fi
    configName="$(cut -d'=' -f1 <<<"$line")"
    configValue="$(cut -d'=' -f2 <<<"$line")"
    envValue="${!configName}";

    if [ -n "$configValue" ] && [ -n "$envValue" ]; then
      echo "Replace: ${configValue} with: ${envValue}"
      find $nextFolder \( -type d -name .git -prune \) -o -type f -print0 | xargs -0 sed -i "s#$configValue#$envValue#g"
    fi
  done < $envFilename
}

# apply_path

# SQLite experimental mode: create/update schema directly for fresh installs.
echo "Applying Prisma schema to SQLite database..."
npx prisma db push --accept-data-loss
echo "Database schema applied successfully!"

# seed the database
echo "Seeding the database..."
npx prisma db seed
echo "Database seeded successfully!"

echo "Executing command"
exec $cmd
