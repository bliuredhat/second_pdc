# Directory `misc` explained

## FAQ

### How to setup docker development environment (recommended)

Follow the steps
  1. ensure that docker works
  2. [build dev image]

### Switching from VM to docker as development environment
To make the switch, follow [how to docker].

### How do quickly bring up another errata environment
To make the switch, follow [adhoc docker dev].

### How do I avoid having to run `errata-init` everytime bring up dev container?
Refer the section: [my docker dev]

Docker contains all `docker` related contents. All docker images that
require a `errata` prefix are kept under `errata/` so that
`docker-compose` build would result in that prefix.


## Using the (Docker) Development Environment

## Prerequisites

Make sure you have the following software installed:

* docker (version 1.10 or above)
* docker-compose

### Building images

Use the `docker-compose` tool to build the necessary docker images:

```sh
$ cd <project-dir>/misc/docker/errata/

# Export your $UID to allow docker-compose access to the environment variable
# and its value since it's passed along as a build argument for the container.
# In case you're using sudo, you additionally need to enable to pass along the
# environment to the sub-process with `-E`.
# The user inside the container will be created using the exported UID to allow
# writing files to the mounted host file system.
$ export UID
$ docker-compose build
```

#### Build individual images (optional)
NOTE: Individual images can be built as well; e.g. to build `devbase` image

```sh
$ cd <project-dir>/misc/docker/errata/
$ docker-compose build devbase
```

### Running container

Use `docker-compose run` to use docker image.

```sh
$ cd <project-dir>/misc/docker/errata/
$ docker-compose run --service-ports dev
```

### Initialising the `dev` container with errata data

```sh
### Initialise gems and database ###
$ cd /code/misc/docker/errata/dev/ansible
$ ansible-playbook -vv -c local dev-env.yml --tags errata-init

# set mysql password so that you can access database from outside
$ mysql -u root
$ GRANT ALL PRIVILEGES ON *.* To '<someuser>'@'%'
  IDENTIFIED BY '<a strong password>' WITH GRANT OPTION;
```

### Initialising the `ruby22` container with errata data

```sh
### Initialise gems and database ###
$ bundle install --no-cache
$ bundle exec rake db:drop db:create db:schema:load db:migrate db:fixtures:load

```

### Opening another session to docker container
To open another session use `docker exec`

```sh
$ docker ps | grep errata_dev
# NOTE the container id something like: errata_dev_run_<n>
$ docker exec -it errata_dev_run_1
```

### Preserve history

To preserve bash or zsh history, consider mounting a directory on the host as
`home/dev/`. For this, change the `docker-compose.yml` files and uncomment the
currently commented out mount point:

```yaml
    - ~/Developer/Hat/Docker/errata/home/dev:/home/dev    # mount /home/dev
```

### Save the container for future (re)use
Once the database is initialized and a user is created, it is a good time to
save the progress using `docker commit`


```sh
# create a docker image and tag it et_dev:<month><day>
$ docker ps -a | grep errata_dev_run
# note the container id: something like errata_dev_run_1
$ docker commit -p -m='et dev: db init' <container_id> et_dev:$(date +%m%d)
$ docker tag et_dev$(date +%m%d) et_dev:latest
```

Modify the `docker-compose.yml` to use the saved image. Add to the file

```yaml
mydev: &mydev
  <<: *adhoc_settings
  image: et_dev
  ports:
    - "3000:3000"
    - "3306:3306"
    - "8000:8000"

myadhocdev:
  <<: *mydev
  ports:
    - 3000
    - 3306
    - 8000
```

Now you can run the `mydev` instead of `dev`

```
$ cd <project-dir>/misc/docker/errata/
$ docker-compose run --service-ports mydev
```
Changes to `mydev`can be preserved using the same technique

### Adhoc docker `dev` containers
The `docker-compose` yaml file has an `adhocdev` service defined which port
forwards to random ports on host. This is helpful when you want to bring up
adhoc instances of errata.

```sh
$ docker-compose run --service-port adhocdev
```

If you have your `dev` container preserved([my docker dev]), then you can
use `myadhocdev` instead of `adhocdev`
