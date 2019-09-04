#!/bin/bash

#
# m3u8_bypass
# copyright 2018 - 2019 @guardiancrow
# Released under the MIT license
#

uri=
oname=
tmpdir=.
origin=
referer=
refflag=false
resume=0

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
  esac
done

#echo $uri

fname=$(basename $uri)
dname=$(basename $uri .m3u8)
outname=$dname.mp4

if [ -n ${oname} ]; then
  outname=$oname
fi

#echo $outname
#echo $tmpdir"/"$fname
#echo $tmpdir"/"$dname"/"_$fname

#####

echo "getting original m3u8..."

if $refflag ; then
	curl -sS -f -H "Origin: null" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.5" -H "Accept: */*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:69.0) Gecko/20100101 Firefox/69.0" -e "${referer}" --compressed -o $tmpdir/$fname $uri
else
	curl -sS -f -H "Origin: null" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.5" -H "Accept: */*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:69.0) Gecko/20100101 Firefox/69.0" --compressed -o $tmpdir/$fname $uri
fi

mkdir $tmpdir/$dname

#####

echo "downloading sources..."

maxcount=`awk 'BEGIN{c=0} /^http/{c=c+1} END{print c}' ${tmpdir}/${fname}`
count=1

for u in `awk '/^http/' ${tmpdir}/${fname}` ; do
  if [ ${count} -lt ${resume} ]; then
    echo "("$count"/"$maxcount"): skipping..."
  else
    echo "("$count"/"$maxcount"):" $tmpdir/$dname/${u##*/}
	if $refflag ; then
		curl -sS -f -H "Origin: ${origin}" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.5" -H "Accept: */*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:69.0) Gecko/20100101 Firefox/69.0" -e "${referer}" --compressed -o $tmpdir/$dname/${u##*/} $u
	else
		curl -sS -f -H "Origin: ${origin}" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.5" -H "Accept: */*" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:69.0) Gecko/20100101 Firefox/69.0" --compressed -o $tmpdir/$dname/${u##*/} $u
	fi
  fi
  count=$((count+1))
done


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
