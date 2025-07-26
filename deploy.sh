#! /bin/bash

VALID_ARGS=$(getopt --long machine-init,deploy)

if [[ $(id -u) -ne 0 ]]; then
    echo "script must be executed with root rights!"
    exit 1
else
    if [[ $(command -v podman) ]]; then
        eval set -- "$VALID_ARGS"
        while [ : ]; do
            case "$1" in
                --machine-init)
                    INIT_MACHINE=true
                    shift
                    ;;
                --deploy)
                    DEPLOY_SERVICE=true
                    shift
                    ;;
                --)
                    shift
                    break
                    ;;
            esac

        # satisfy dependencies

        # initiate podman machine
        if [[ ${INIT_MACHINE} ]]; then
            if [[ $(command -v apt) ]]; then
                apt-get install -y qemu-utils qemu-system-x86 virtiofsd
            fi

            if [[ $(command -v dnf) ]]; then
                dnf install -y qemu-img qemu-system-x86 podman-gvproxy virtiofsd
            fi

            podman machine init --cpus 2 --rootfull -v /tmp:/tmp:Z -v $PWD:$PWD
            podman machine start
        fi

        if [[ ${DEPLOY_SERVICE} ]]; then
            podman volume create kestra-data
            podman volume create kestra-postgresql

            # ensure database password is present
            if [[ $(podman secret exists kestra_db_password) -ne 0 ]]; then
                echo "Please enter a password for PostgreSQL database:"
                psqlpw=$(gum input --password)
                podman secrete create --env=true kestra_db_password psgqlpw
                unset psqlpw 
            fi

            podman run -dt --recreate \
                --pull=allways \
                -v kestra-postgresql:/var/lib/postgresql/data:Z \
                -e POSTGRES_DB=kresta \
                -e POSTGRES_USER=kresta \
                --secrete kestra_db_password,type=env,target=POSTGRES_PASSWORD \
                --name kestra-postgresql \
                docker.io/postgres
        fi
    else
        echo "podman could not be found in path"
        exit 1
    fi
fi
# EEOFS