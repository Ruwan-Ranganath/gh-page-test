#!/bin/bash

# Assign arguments to variables
base_dir=$1
service_prod_suffix=$2
service_qe_suffix=$3
skip_services=$4
commit_hash=$5

# Convert comma-separated list of services to skip into an array
IFS=',' read -r -a skip_array <<< "$skip_services"

# function to check yaml and yml kustomization file 
find_kustomization_file() {
    local base_path="$1"
    for ext in yaml yml; do
        if [[ -f "$base_path/kustomization.$ext" ]]; then
            echo "$base_path/kustomization.$ext"
            return
        fi
    done
    echo ""
}


extract_newTag() {
    local kustomization_file=$(find_kustomization_file "$1")

    if [ -n "$kustomization_file" ]; then 
        grep "newTag:" "$kustomization_file" | sed -E 's/.*newTag: (.*)/\1/'
    fi

}

# replace tags with given prod / commit-hash values 
update_newTag() {
    local file_path="$1"  # full path to the kustomization.yaml file
    local new_tag="$2"

# Just adding this here, so users will not need to update the code when testing locally in macos. 
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|newTag: .*|newTag: $new_tag|" "$file_path"
    else
        sed -i "s|newTag: .*|newTag: $new_tag|" "$file_path"
    fi
  
}

for service_dir in "$base_dir"/*; do
    if [ -d "$service_dir" ]; then
        service_name=$(basename "$service_dir")

        prod_kustomization=$(find_kustomization_file "$service_dir/overlays/$service_prod_suffix")
        qe_kustomization=$(find_kustomization_file "$service_dir/overlays/$service_qe_suffix")

        tag_prod=$(extract_newTag "$service_dir/overlays/$service_prod_suffix")
        tag_qe=$(extract_newTag "$service_dir/overlays/$service_qe_suffix")

        
        # Check if current service is in the service_name to skip from prod equal
        # This will come from remote repository where user dispatch the workflow 
        if printf '%s\n' "${skip_array[@]}" | grep -q "^$service_name$"; then
            echo "Workflow dispatch to use commit hash from $service_name will use commit id : $commit_hash."
                update_newTag "$qe_kustomization" "$commit_hash"  #Calling above function to update
                echo "updated $service_qe_suffix with $commit_hash" 
                continue
        fi

        # if not a service defined in dispatch workflow reset of the services will update from prod.
        if [ -f "$qe_kustomization" ]; then 
            if [ "$tag_prod" != "$tag_qe" ]; then 
                echo "$service_name in $service_qe_suffix $tag_qe not equal to $service_prod_suffix $tag_prod" 
                update_newTag "$qe_kustomization" "$tag_prod"  #Calling above function to update
                echo "updated $service_qe_suffix with $service_prod_suffix"
            else
                echo " "
            fi
        fi

        echo "===================================="

    fi
done

