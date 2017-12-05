# Zen Secure Node Docker Image

This is an attempt to package the Zencash daemon and secure node tracker in a Docker container.
The development branch of the Zencash daemon and node trackers are used.

It's loosely based on the offical Zen Docker image: https://github.com/ZencashOfficial/zen-node-docker

The `Dockerfile` has a a two stage process to keep image size down:
1. Build the zen daemon
2. Copy artifacts from build image and install runtime packages

All configuration data must be in the `config` volume and mapped in either via bind mount or a Docker volume. The zend `data` and `zcash-params` folders will be created in the container at runtime, or can be mapped in as volumes. I don't recommend the approach of keeping this data in the container as you'll have to resync the whole blockchain should you delete the container. Volumes give you much more flexibility.

If you wanted to run two containers, one for mainnet and one for testnet, set `testnet=0/1` in a duplicate of the config folder, create a new data volume for the main/test blockchain and run a second instance.

## Geting Started
1. **Build the image**
`build -t zen-secure .`

2. **Edit the files in the config folder**
- `config/zen.conf` : zend configuration
- `config/ssl/cert.pem` : zend SSL certificate
- `config/ssl/key.pem` : private key for SSL certificate
- `config/root_certs/*` : Additional root CA authorities you want to trust. Already includes the letsencrypt CA in here as Ubuntu does not include it. These will be installed on container startup
- `config/sec_tracker_config` -> Config files for the secure node tracker.
- This is a little hacky at present as these files are for Node local storage used by the tracker. It's setup script creates thesebut is a prompted process. The files that need to be configured manually are:
  - `email` : Your email address
  - `fqdn` : FQDN of your host
  - `rpcallowip` : Copy from `zen.conf`
  - `rpcbind` : Copy from `zen.conf`
  - `rpcpassword` : Copy from `zen.conf`
  - `rpcport` : Copy from `zen.conf`
  - `rpcuser` : Copy from `zen.conf`
  - `serverurl` : Normally http://devtracksys.secnodes.com
  - `stakeaddr` : t_addr with 42 Zen stake minimum for this node

3. **Create folders/volumes for data and zcash_params or utilise existing data**
Either:
- `mkdir data && mkdir zcash_params`
Or:
- `docker volume create data && docker volume create zcash_params`
Or:
- Use existing folders/volumes

4. **Start the container**
```
$docker run -t -d --rm  \
-p 19033:19033 \
-v "$(pwd)"/config:/mnt/zen/config \
-v "$(pwd)"/zcash_params:/mnt/zen/zcash-params \
-v "$(pwd)"/data:/mnt/zen/data \
--env LOCAL_USER_ID="$(id -u)" \
--env LOCAL_GRP_ID="$(id -g)" \
--name zen-node \
zen_secure <command>
```

5. **Ensure a z_address for transaction processing has at least 1 ZEN in a local wallet**

- Create a new z address:
```
$docker exec -t -i zen-node zen-cli \
-conf=/home/user/.zen/zen.conf \
z_getnewaddress
```

- Send some coins to that address:
```
$docker exec -t -i zen-node zen-cli \
-conf=/home/user/.zen/zen.conf \
z_sendmany "FROM_ADDRESS" "[{\"amount\": 2, \"address\": \"<TO Z ADDRESS>\"}]"
```

The staking t address does not need to be held in a wallet on the node.

### Logs?
- zend logs to `<data volume>/testnet3/debug.log` (if using testnet)
- secure node/zend metrics visible in console log (`$docker logs zen-node`)

### Container user
The docker container runs as a use/group specified by environment variables `LOCAL_USER_ID` and `LOCAL_GRP_ID`. The example above sets them to the logged in user.

### Volumes
If using external volumes, the mount points are:
- Zen Config : `/mnt/zen/config`
- Zen Data : `/mnt/zen/data`
- zcash_params : `/mnt/zcash-params`

### Network Ports
Ports Exposed By Default :
- P2P MainNet: 9033

These are not bound to host ports on startup. You need to map them with `-p` Docker option.
RPC access is by default restricted to 127.0.0.1 in the config files.

