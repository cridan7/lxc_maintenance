#!/bin/bash

# Function to create a snapshot
create_snapshot() {
    local container_name=$1
    lxc snapshot $container_name
    echo "Snapshot for $container_name created successfully."
}

# Function to rollback to the latest snapshot
rollback() {
    local container_name=$1
    lxc rollback $container_name
    echo "Rolled back $container_name to the latest snapshot."
}

# Main script functionality
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <snapshot|rollback> <container_name>"
    exit 1
fi

case $1 in
    snapshot)
        create_snapshot $2
        ;;  
    rollback)
        rollback $2
        ;;  
    *)
        echo "Invalid option. Use 'snapshot' or 'rollback'."
        exit 1
        ;;  
esac
