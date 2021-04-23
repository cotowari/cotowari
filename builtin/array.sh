str_to_array() {
  str_val=$1
  name=$2
  eval "${name}_len=0"
  i=0
  for v in $str_val
  do
    eval "${name}_len=$(( ${name_len} + 1 ))"
    eval "${name}_$i=$v"
    i=$(( i + 1 ))
  done
}

array_to_str() {
  name=$1
  len="$(eval echo "${name}_len")"
  for i in $(seq 0 $(( len - 1 )) )
  do
    eval echo "${name}_$i"
  done
}

array_get() {
  name=$1
  i=$2
  eval echo "${name}_$i"
}

array_set() {
  name=$1
  i=$2
  val=$3
  eval "${name}_$i=$val"
}