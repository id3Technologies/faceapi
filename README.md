# faceapi on-premise docker-compose

Docker compose to install all the needed components in an "on premise" environment.

## How to start ?

Checkout the project and replace the variables in .env file by yours :
- YOUR_API_KEY
- YOUR_SECRET
- YOUR_PROFILE
- YOUR_LICENSE_OWNER_NAME


You can obtain these 4 properties by asking us.


Additionnaly, you must replace the property :
- YOUR_PRIMARY_INSTANCE_IP
by the ip address of your primary instance. If you only have one instance, then put the ip of this server, else, please choose which instance will be the primary.


Then execute the script `./start.sh` in your primary instance. On other instances, execute with the 'secondary' argument `./start.sh --secondary` (or `./start.sh -s`).