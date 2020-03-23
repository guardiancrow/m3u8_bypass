#!/bin/bash

#
# m3u8_bypass
# copyright 2018 - 2020 @guardiancrow
# Released under the MIT license
#

uri=
oname=
tmpdir=.
origin=null
referer=
refflag=false
resume=0
prefix=$RANDOM
no_prefix=true
skip_if_exist=false
check_files=false

for OPT in "$@"
do
  case $OPT in
    --uri | --url)
      uri=$2
      shift 2
      ;;
    -o | --out)
      oname=$2
      shift 2
      ;;
    -t | --temp)
      tmpdir=$2
      shift 2
      ;;
    -r | --resume)
      resume=$2
      shift 2
      ;;
    --origin)
      origin=$2
      shift 2
      ;;
    --referer)
      referer=$2
	  refflag=true
      shift 2
      ;;
	-pn | --prefix-number)
	  prefix=$2
	  shift 2
	  ;;
	-p | --append-prefix)
	  no_prefix=false
	  shift 1
	  ;;
	-s | --skip-if-exist)
	  skip_if_exist=true
	  shift 1
	  ;;
	-c | --check-files)
	  check_files=true
	  shift 1
	  ;;
  esac
done

ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:74.0) Gecko/20100101 Firefox/74.0"

if $no_prefix ; then
  fname=$(basename $uri)
  dname=$(basename $uri .m3u8)
else
  fname=$prefix-$(basename $uri)
  dname=$prefix-$(basename $uri .m3u8)
fi

outname=$dname.mp4

if [ -n ${oname} ]; then
  outname=$oname
fi

#####

echo "getting original m3u8..."

if [ $skip_if_exist ] && [ -e $tmpdir/$fname ]; then
  echo "skipping... get original m3u8"
else
  if $refflag ; then
    curl -sS -f -H "Origin: null" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -H "Accept: */*" -A "${ua}" -e "${referer}" --compressed -o $tmpdir/$fname $uri
  else
    curl -sS -f -H "Origin: null" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -H "Accept: */*" -A "${ua}" --compressed -o $tmpdir/$fname $uri
  fi
  if [ $? -gt 0 ] && [ -e $tmpdir/$fname ]; then
    rm $tmpdir/$fname
    exit 1
  fi
fi

mkdir $tmpdir/$dname

#####

echo "downloading sources..."

maxcount=`awk 'BEGIN{c=0} /^http/{c=c+1} END{print c}' ${tmpdir}/${fname}`
count=1

for u in `awk '/^http/' ${tmpdir}/${fname}` ; do
  if [ ${count} -lt ${resume} ]; then
    echo "("$count"/"$maxcount"): skipping..."
  elif [ $skip_if_exist ] && [ -e $tmpdir/$dname/${u##*/} ]; then
	echo "("$count"/"$maxcount"): skipping... " $tmpdir/$dname/${u##*/}
  else
    echo "("$count"/"$maxcount"):" $tmpdir/$dname/${u##*/}
    if $refflag ; then
      curl -sS -f -H "Origin: ${origin}" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -H "Accept: */*" -A "${ua}" -e "${referer}" --compressed -o $tmpdir/$dname/${u##*/} $u
    else
      curl -sS -f -H "Origin: ${origin}" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -H "Accept: */*" -A "${ua}" --compressed -o $tmpdir/$dname/${u##*/} $u
    fi
    if [ $? -gt 0 ] && [ -e $tmpdir/$dname/${u##*/} ]; then
      rm $tmpdir/$dname/${u##*/}
      exit 1
    fi
  fi
  count=$((count+1))
done

#####

if $check_files ; then
  echo "checking downloaded files.."
  for u in `awk '/^http/' ${tmpdir}/${fname}` ; do
  	if  [ ! -e $tmpdir/$dname/${u##*/} ]; then
	  echo "file not found:" $tmpdir/$dname/${u##*/}
	  exit 2
	fi
  done
fi

#####

echo "rewriting m3u8..."

cat $tmpdir/$fname | while read line
do
  if [[ $line =~ ^http ]]; then
    echo ${line##*/}
	continue
  fi
  echo $line
done > $tmpdir/$dname/_$fname

#####

echo "concatenating...."

ffmpeg -i $tmpdir/$dname/_$fname -movflags faststart -c copy -bsf:a aac_adtstoasc $tmpdir/$outname

#####

read -p "remove temporary files? (y/N)" yesno

case "$yesno" in
  [yY]*)
    ;;
  *)
    exit;
    ;;
esac

rm $tmpdir/$dname/_$fname

#####

read -p "remove downloaded source files? (y/N)" yesno2

case "$yesno2" in
  [yY]*)
    ;;
  *)
    exit;
    ;;
esac

rm $tmpdir/$fname
rm $tmpdir/$dname/*.ts
rmdir $tmpdir/$dname
