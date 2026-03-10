#!/bin/bash

# Usage: ./upload_to_gdrive.sh <file_path> <file_name> <folder_id> <service_account_json>

FILEPATH=$1
FILENAME=$2
FOLDER_ID=$3
SERVICE_ACCOUNT_JSON=$4

# Extract info from Service Account JSON
PRIVATE_KEY=$(echo "$SERVICE_ACCOUNT_JSON" | jq -r .private_key)
CLIENT_EMAIL=$(echo "$SERVICE_ACCOUNT_JSON" | jq -r .client_email)

# Create JWT Header
HEADER='{"alg":"RS256","typ":"JWT"}'
ENCODED_HEADER=$(echo -n "$HEADER" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Create JWT Claim Set
NOW=$(date +%s)
EXP=$((NOW + 3600))
CLAIM_SET="{\"iss\":\"$CLIENT_EMAIL\",\"scope\":\"https://www.googleapis.com/auth/drive.file\",\"aud\":\"https://oauth2.googleapis.com/token\",\"iat\":$NOW,\"exp\":$EXP}"
ENCODED_CLAIM_SET=$(echo -n "$CLAIM_SET" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Create Signature
SIGNATURE=$(echo -n "$ENCODED_HEADER.$ENCODED_CLAIM_SET" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# Get Access Token
JWT="$ENCODED_HEADER.$ENCODED_CLAIM_SET.$SIGNATURE"
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    --data-urlencode "assertion=$JWT" | jq -r .access_token)

# Upload File
echo "Uploading $FILENAME to Google Drive..."
curl -X POST "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -F "metadata={name : '$FILENAME', parents : ['$FOLDER_ID']};type=application/json;charset=UTF-8" \
    -F "file=@$FILEPATH;type=application/vnd.android.package-archive"
