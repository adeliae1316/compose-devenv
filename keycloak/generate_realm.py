import os
from dotenv import load_dotenv

# load .env

_PY_DIR=os.path.dirname(__file__)
load_dotenv(os.path.join(_PY_DIR, '../.env'))

def getEnv(key):
  return os.environ.get(key, '')

# generate config json

with open(os.path.join(_PY_DIR, 'template.json')) as f:
  content = f.read()

content = content.replace('${_KEYCLOAK_REALMS}', getEnv('_KEYCLOAK_REALMS'))
content = content.replace('${_KEYCLOAK_CLIENT_GITL}', getEnv('_KEYCLOAK_CLIENT_GITL'))
content = content.replace('${_KEYCLOAK_CLIENT_WIKI}', getEnv('_KEYCLOAK_CLIENT_WIKI'))
content = content.replace('${GITLAB_URL}', 'https://{0}:{1}'.format(getEnv('_HOSTNAME'), getEnv('_GITLAB_HTTPS_PORT')))
content = content.replace('${GROWI_URL}', 'https://{0}:{1}'.format(getEnv('_HOSTNAME'), getEnv('_GROWI_HTTPS_PORT')))
content = content.replace('${_SEARCH_BASE_DN}', getEnv('_SEARCH_BASE_DN'))
content = content.replace('${_BIND_USER_DN}', getEnv('_BIND_USER_DN'))
content = content.replace('${_BIND_USER_PASSWORD}', getEnv('_BIND_USER_PASSWORD'))

with open(os.path.join(_PY_DIR, 'import.json'), mode='w') as f:
    f.write(content)
