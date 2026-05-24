# set -x
set -e

source $(dirname $0)/config.sh



cur_tag_id=$(date +%Y%m%d)
build_script_dir=$(dirname $0)


function build() {
  image_id=$1
  check_param_empty $image_id "image_id"
  if [ ! -d $image_id ];then
    echo "folder $image_id not exist"
    exit 1
  fi

  build_arg="--build-arg http_proxy=http://172.17.0.3:8118 --build-arg https_proxy=http://172.17.0.3:8118"
  cur_image_tag=$image_id:$cur_tag_id
  tag_file=$build_script_dir/$image_id/$TAG_ID_FILE

  echo "building image"
  cd $image_id && docker build $build_arg --network host -t $cur_image_tag .
  if [ $? -ne 0 ];then
    echo "build image fail"
    exit 1
  fi
  cd ..

  echo "write tag_id $cur_tag_id into $tag_file"
  echo $cur_tag_id > "$tag_file"
}

function cbuild() {
  image_id=$1
  check_param_empty $image_id "image_id"
  echo "get removed image tags"
  removed_images=$(docker image ls | grep $image_id | grep -v $cur_tag_id | awk '{print $3}' | uniq) 

  build $image_id

  echo "remove old images:$removed_images"
  if [ ! -z "$removed_images" ];then
    docker image rm -f $removed_images
  fi
}


function push() {
  image_id=$1
  check_param_empty $image_id "image_id"

  cur_image_tag=$image_id:$cur_tag_id
  echo "push image $cur_image_tag to registry:$REPO_REGISTRY"
  docker tag $cur_image_tag  $REPO_REGISTRY/$cur_image_tag 
  # bash registry_ctrl.sh -r $cur_image_tag
  docker push $REPO_REGISTRY/$cur_image_tag 
}


    
while [ "$#" -gt 0 ]
do
  case "$1" in
    --build)
      build $2
      exit 0
      ;;
    --cbuild)
      cbuild $2
      exit 0
      ;;
    --push)
      push $2
      exit 0
      ;;
  esac
  shift
done
