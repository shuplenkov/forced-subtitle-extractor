#!/bin/bash
set -e

excludes_file="/db/.excluded"

: ${OUT_EXT:="ass"} #Sets the default value if not specified

lc(){
    case "$1" in
        [A-Z])
        n=$(printf "%d" "'$1")
        n=$((n+32))
        printf \\$(printf "%o" "$n")
        ;;
        *)
        printf "%s" "$1"
        ;;
    esac
}

extractSubs() {
  echo "Looking into ${1}"

  subsmappings=$(ffprobe -loglevel error -select_streams s -show_entries stream=index,codec_name:stream_tags=language,title -of csv=p=0 "$1")
  #Results formatted as : 2,eng,title

  #IFS is the command delimiter - https://bash.cyberciti.biz/guide/$IFS
  #We back it up before changing it to a ',' as used in the mappings
  OLDIFS=$IFS
  IFS=,
  (while read idx codec lang title; do
      if [[ "$codec" == *pgs* ]]; then
#          echo "codec $codec, forcing output format."
          EXT="sup"
          forceArgument=("-c:s" "copy" )
      else
          forceArgument=()
          EXT=$OUT_EXT
      fi
      if [ -z "$lang" ]; then
          lang="und"
          #When the subtitle language isn't present in the file, we note it as undefined and extract it regardless of the parameters
      else
          if [[ ! -z "$LANGS" ]] && [[ "$LANGS" != *$lang* ]]; then
              #If subtitles language restrictions were provided, we check that the subtitles lang is one of them before proceeding
              echo "Skipping ${lang} subtitle #${idx}"
              continue
          fi
      fi

      file_basename=$(basename "$1")
      file_dirname=$(dirname "$1")
      file=${file_basename%.*}

#      title in lower case
      lc_title="${title,,}"

      if [[ "$lc_title" = *"force"* ]]; then
        # file naming scheme "Movie_Name.[Language_Code].forced.ext" adopted from Plex (https://support.plex.tv/articles/200471133-adding-local-subtitles-to-your-media/#toc-3)
        sub_file="${file}.${lang}.forced.${EXT}"
        echo "Extracting ${file} ${lang} forced subtitle to ${sub_file}"

        ffmpeg -y -nostdin -hide_banner -loglevel error -i \
        "$1" -map 0:"$idx" "${forceArgument[@]}" "${file_dirname}/${sub_file}"
        # The -y option replaces existing files.
      fi

    done <<<"${subsmappings}")

    # Despite successful extraction, the error "At least one output file must be specified" seems to always appear.
    # The "|| true" part allows us to continue the script regardless.

    #Restore previous values
    IFS=$OLDIFS
}

addToExcluded() {
  printf "${1}\n" >> $excludes_file
}

process() {
#  check if file was already processed
  if grep -Fxq "$1" "$excludes_file"; then
    echo "skip ${1}"
  else
    #check if file was not removed during scan process
    if [[ -f "$pathname" ]]; then
      extractSubs "$pathname"
      addToExcluded "$pathname"
    fi
  fi
}

walkDir () {
    shopt -s nullglob dotglob

    for pathname in "$1"/*; do
        if [ -d "$pathname" ]; then
            walkDir "$pathname"
        else
            case "$pathname" in
                *.mkv)
#                *.mkv|*.mp4|*.m4v)
                    process "$pathname"
            esac
        fi
    done
}

echo "Start"

walkDir "/data"

echo "Finished."
