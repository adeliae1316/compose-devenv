# variables
# TODO: to use .env variables
REALM_NAME='local'

IP_ADDRESS='192.168.77.48'
GITLAB_PORT='20080'
GROWI_PORT='20079'

USERS_DN='ou=worker,dc=workspace,dc=local'
BIND_DN='cn=maintainer,dc=workspace,dc=local'
BIND_CREDENTIAL='maintainer-pswd'

with open("templete.json") as f:
  content = f.read()

content = content.replace('@REALM_NAME@', REALM_NAME)
content = content.replace('@IP_ADDRESS@', IP_ADDRESS)
content = content.replace('@GITLAB_PORT@', GITLAB_PORT)
content = content.replace('@GROWI_PORT@', GROWI_PORT)
content = content.replace('@USERS_DN@', USERS_DN)
content = content.replace('@BIND_DN@', BIND_DN)
content = content.replace('@BIND_CREDENTIAL@', BIND_CREDENTIAL)

with open("import.json", mode='w') as f:
    f.write(content)
