import os
from dotenv import load_dotenv

# load .env

_PY_DIR=os.path.dirname(__file__)
load_dotenv(os.path.join(_PY_DIR, '../.env'))

def getEnv(key):
  return os.environ.get(key, '')

# generate config json

with open(os.path.join(_PY_DIR, 'templete.json')) as f:
  content = f.read()

content = content.replace('@REALM_NAME@', getEnv('_KEYCLOAK_REALMS'))
content = content.replace('@GITLAB_URL@', 'http://{0}:{1}'.format(getEnv('_HOSTNAME'), getEnv('_GITLAB_HTTP_PORT')))
content = content.replace('@GROWI_URL@', 'https://{0}:{1}'.format(getEnv('_HOSTNAME'), getEnv('_GROWI_HTTPS_PORT')))
content = content.replace('@USERS_DN@', getEnv('_SEARCH_BASE_DN'))
content = content.replace('@BIND_DN@', getEnv('_BIND_USER_DN'))
content = content.replace('@BIND_CREDENTIAL@', getEnv('_BIND_USER_PSWD'))

with open(os.path.join(_PY_DIR, 'import.json'), mode='w') as f:
    f.write(content)
