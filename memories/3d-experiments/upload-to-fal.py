"""Upload a local file to fal storage (multipart). Requires FAL_KEY."""
import os
import urllib.request
import uuid
import sys

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY in the environment.")

image_path = sys.argv[1] if len(sys.argv) > 1 else ""
if not image_path:
    sys.exit("Usage: python upload-to-fal.py <path-to-image.png>")

with open(image_path, "rb") as f:
    img_data = f.read()

boundary = uuid.uuid4().hex
filename = image_path.replace("\\", "/").split("/")[-1]

body = b""
body += ("--" + boundary + "\r\n").encode()
body += ('Content-Disposition: form-data; name="file_upload"; filename="' + filename + '"\r\n').encode()
body += b"Content-Type: image/png\r\n\r\n"
body += img_data
body += ("\r\n--" + boundary + "--\r\n").encode()

req = urllib.request.Request(
    "https://api.fal.ai/v1/serverless/files/file/local/" + filename,
    data=body,
    method="POST",
    headers={
        "Authorization": "Key " + FAL_KEY,
        "Content-Type": "multipart/form-data; boundary=" + boundary,
    },
)
resp = urllib.request.urlopen(req).read().decode()
print(resp)
