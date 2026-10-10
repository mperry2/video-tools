#!/usr/bin/env bash

# Output CSV files with information about MKV files. The CSV files will be used
# as data sources for a spreadsheet report.

# TODO:
#
# * Create report in a temp file and update real file once report is successful
# * Make sure path exists and is readable before processing
# * Add search paths for directories so there's more flexibility in specifying paths
# * Add ability to store data in a SQLite database


shopt -s globstar

LIBRARY_PATH="/srv/videos/libraries"
REPORT_PATH="/srv/videos/00-reports"

# Directory with the script
BASE_PATH="$(dirname "$0")"



#
# Functions
#

# create_csv_file(media_type, directory, output_file, jq_filter, header)
# header is optional
create_csv_file() {
  local type=$1
  local dir=$2
  local output_file=$3
  local jq_filter=$4
  local header=$5

  if [[ -n $header ]]; then
    echo "$header" >> "$output_file"
  fi

  for file in "$dir"/**; do
    if [[ -f $file && $file == *.mkv ]]; then
      mkvmerge_json=$(mkvmerge -J "$file")
      mediainfo_json=$(mediainfo --Output=JSON "$file")
      jq -n -f "$BASE_PATH/merge2.jq" \
        --argjson mkv "$mkvmerge_json" \
        --argjson media "$mediainfo_json" \
        | jq -r -f <(echo "$jq_filter") --arg type "$type" >> "$output_file"
    fi
  done
}

# join_by(delimiter, items...)
join_by() {
  local IFS="$1"
  shift
  echo "$*"
}



#
# Main
#

# jq filter for general information
read -r -d '' jq_filter_general << 'EOM'
. as $root | .container | [
  $type,
  $root.file,
  (.title),
  (.muxing_application),
  (.writing_application)
] | @tsv
EOM

fields=(
  "Type"
  "File name"
  "Movie name"
  "muxing_application"
  "writing_application"
)
header_general="$( join_by $'\t' "${fields[@]}" )"



# jq filter for video information
read -r -d '' jq_filter_video << 'EOM'
. as $root | .tracks[] | select(.type == "video") | [
  $type,
  $root.file,
  ([$root.tracks[] | select(.type == "video")] | length),
  (.raw.mkvmerge.properties.number),
  (.raw.mkvmerge.properties.codec_id),
  (.raw.mkvmerge.properties.language               // ""),
  (.raw.mkvmerge.properties.language_ietf          // ""),
  (.raw.mkvmerge.properties.display_dimensions     // ""),
  (.raw.mkvmerge.properties.pixel_dimensions       // ""),

  (try (.raw.mediainfo.BitRate | tonumber / 1000 | round) catch ""),
  (.raw.mediainfo.FrameRate                        // ""),
  (.raw.mediainfo.FrameRate_Mode                   // ""),
  (.raw.mediainfo.BitDepth                         // ""),
  (.raw.mediainfo.HDR_Format_Compatibility         // ""),

  (.raw.mkvmerge.properties.default_track          // ""),
  (.raw.mkvmerge.properties.enabled_track          // ""),
  (.raw.mkvmerge.properties.forced_track           // ""),
  (.raw.mkvmerge.properties.flag_commentary        // ""),
  (.raw.mkvmerge.properties.flag_hearing_impaired  // ""),
  (.raw.mkvmerge.properties.flag_original          // ""),
  (.raw.mkvmerge.properties.flag_text_descriptions // ""),
  (.raw.mkvmerge.properties.flag_visual_impaired   // ""),
  (.raw.mkvmerge.properties.track_name             // "")
] | @tsv
EOM

fields=(
  "Type"
  "File name"
  "total"
  "number"
  "codec_id"
  "lang"
  "lang_ietf"
  "display_dimensions"
  "pixel_dimensions"
  "bitrate"
  "framerate"
  "fr_mode"
  "bitdepth"
  "hdr"
  "default"
  "enabled"
  "forced"
  "commentary"
  "hearing_impaired"
  "original_lang"
  "text_desc"
  "visual_impaired"
  "track_name"
)
header_video="$( join_by $'\t' "${fields[@]}" )"



# jq filter for audio information
read -r -d '' jq_filter_audio << 'EOM'
. as $root | .tracks[] | select(.type == "audio") | [
  $type,
  $root.file,
  ([$root.tracks[] | select(.type == "audio")] | length),
  (.raw.mkvmerge.properties.number),
  (.raw.mkvmerge.properties.codec_id),
  (.raw.mkvmerge.properties.language               // ""),
  (.raw.mkvmerge.properties.language_ietf          // ""),

  (.raw.mediainfo.Channels         // ""),

  (.raw.mkvmerge.properties.default_track          // ""),
  (.raw.mkvmerge.properties.enabled_track          // ""),
  (.raw.mkvmerge.properties.forced_track           // ""),
  (.raw.mkvmerge.properties.flag_commentary        // ""),
  (.raw.mkvmerge.properties.flag_hearing_impaired  // ""),
  (.raw.mkvmerge.properties.flag_original          // ""),
  (.raw.mkvmerge.properties.flag_text_descriptions // ""),
  (.raw.mkvmerge.properties.flag_visual_impaired   // ""),
  (.raw.mkvmerge.properties.track_name             // "")
] | @tsv
EOM

fields=(
  "Type"
  "File name"
  "total"
  "number"
  "codec_id"
  "lang"
  "lang_ietf"
  "channels"
  "default"
  "enabled"
  "forced"
  "commentary"
  "hearing_impaired"
  "original_lang"
  "text_desc"
  "visual_impaired"
  "track_name"
)
header_audio="$( join_by $'\t' "${fields[@]}" )"



# jq filter for subtitle information
read -r -d '' jq_filter_subtitle << 'EOM'
. as $root | .tracks[] | select(.type == "subtitles") | [
  $type,
  $root.file,
  ([$root.tracks[] | select(.type == "subtitles")] | length),
  (.raw.mkvmerge.properties.number),
  (.raw.mkvmerge.properties.codec_id),
  (.raw.mkvmerge.properties.language               // ""),
  (.raw.mkvmerge.properties.language_ietf          // ""),
  (.raw.mkvmerge.properties.num_index_entries      // ""),
  (.raw.mkvmerge.properties.default_track          // ""),
  (.raw.mkvmerge.properties.enabled_track          // ""),
  (.raw.mkvmerge.properties.forced_track           // ""),
  (.raw.mkvmerge.properties.flag_commentary        // ""),
  (.raw.mkvmerge.properties.flag_hearing_impaired  // ""),
  (.raw.mkvmerge.properties.flag_original          // ""),
  (.raw.mkvmerge.properties.flag_text_descriptions // ""),
  (.raw.mkvmerge.properties.flag_visual_impaired   // ""),
  (.raw.mkvmerge.properties.track_name             // "")
] | @tsv
EOM

fields=(
  "Type"
  "File name"
  "total"
  "number"
  "codec_id"
  "lang"
  "lang_ietf"
  "frames"
  "default"
  "enabled"
  "forced"
  "commentary"
  "hearing_impaired"
  "original_lang"
  "text_desc"
  "visual_impaired"
  "track_name"
)
header_subtitle="$( join_by $'\t' "${fields[@]}" )"



# jq filter for chapter information
read -r -d '' jq_filter_chapters << 'EOM'
def menu_count(root): root.raw.mediainfo.media.track[] | select(."@type" == "Menu").extra | length;

if (menu_count(.) // 0) > 0 then
  . as $root | .raw.mediainfo.media.track[] | select(."@type" == "Menu").extra | to_entries[] | [
    $type,
    $root.file,
    menu_count($root),
    .key,
    .value
  ]
else
  [$type, .file, 0]
end
  | @tsv
EOM

fields=(
  "Type"
  "File name"
  "Total"
  "Chapter Mark"
  "Chapter Title"
)
header_chapters="$( join_by $'\t' "${fields[@]}" )"



# Zero-out the target files
true > "${REPORT_PATH}/data-general.csv"
true > "${REPORT_PATH}/data-video.csv"
true > "${REPORT_PATH}/data-audio.csv"
true > "${REPORT_PATH}/data-subtitle.csv"
true > "${REPORT_PATH}/data-chapters.csv"

# function: create_csv_file( dir_to_scan, report_filename, jq_filter_variable, header_variable, media_type_string )
create_csv_file "Ambience Video"         "${LIBRARY_PATH}/Ambience_Videos"       "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   "$header_general"
create_csv_file "Ambience Video"         "${LIBRARY_PATH}/Ambience_Videos"       "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     "$header_video"
create_csv_file "Ambience Video"         "${LIBRARY_PATH}/Ambience_Videos"       "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     "$header_audio"
create_csv_file "Ambience Video"         "${LIBRARY_PATH}/Ambience_Videos"       "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  "$header_subtitle"
create_csv_file "Ambience Video"         "${LIBRARY_PATH}/Ambience_Videos"       "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  "$header_chapters"
                                                                                                                                         
create_csv_file "Concert"                "${LIBRARY_PATH}/Concerts"              "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Concert"                "${LIBRARY_PATH}/Concerts"              "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Concert"                "${LIBRARY_PATH}/Concerts"              "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Concert"                "${LIBRARY_PATH}/Concerts"              "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Concert"                "${LIBRARY_PATH}/Concerts"              "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "Documentary Movie"      "${LIBRARY_PATH}/Documentaries-Movies"  "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Documentary Movie"      "${LIBRARY_PATH}/Documentaries-Movies"  "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Documentary Movie"      "${LIBRARY_PATH}/Documentaries-Movies"  "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Documentary Movie"      "${LIBRARY_PATH}/Documentaries-Movies"  "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Documentary Movie"      "${LIBRARY_PATH}/Documentaries-Movies"  "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "Documentary TV Series"  "${LIBRARY_PATH}/Documentaries-TV"      "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Documentary TV Series"  "${LIBRARY_PATH}/Documentaries-TV"      "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Documentary TV Series"  "${LIBRARY_PATH}/Documentaries-TV"      "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Documentary TV Series"  "${LIBRARY_PATH}/Documentaries-TV"      "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Documentary TV Series"  "${LIBRARY_PATH}/Documentaries-TV"      "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "Movie"                  "${LIBRARY_PATH}/Movies"                "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Movie"                  "${LIBRARY_PATH}/Movies"                "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Movie"                  "${LIBRARY_PATH}/Movies"                "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Movie"                  "${LIBRARY_PATH}/Movies"                "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Movie"                  "${LIBRARY_PATH}/Movies"                "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "Opera"                  "${LIBRARY_PATH}/Operas"                "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Opera"                  "${LIBRARY_PATH}/Operas"                "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Opera"                  "${LIBRARY_PATH}/Operas"                "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Opera"                  "${LIBRARY_PATH}/Operas"                "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Opera"                  "${LIBRARY_PATH}/Operas"                "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "Stand-Up Comedy"        "${LIBRARY_PATH}/Stand_Up_Comedy"       "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Stand-Up Comedy"        "${LIBRARY_PATH}/Stand_Up_Comedy"       "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Stand-Up Comedy"        "${LIBRARY_PATH}/Stand_Up_Comedy"       "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Stand-Up Comedy"        "${LIBRARY_PATH}/Stand_Up_Comedy"       "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Stand-Up Comedy"        "${LIBRARY_PATH}/Stand_Up_Comedy"       "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "Theater"                "${LIBRARY_PATH}/Theater"               "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "Theater"                "${LIBRARY_PATH}/Theater"               "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "Theater"                "${LIBRARY_PATH}/Theater"               "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "Theater"                "${LIBRARY_PATH}/Theater"               "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "Theater"                "${LIBRARY_PATH}/Theater"               "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
                                                                                                                                         
create_csv_file "TV Series"              "${LIBRARY_PATH}/TV"                    "${REPORT_PATH}/data-general.csv"   "$jq_filter_general"   ""
create_csv_file "TV Series"              "${LIBRARY_PATH}/TV"                    "${REPORT_PATH}/data-video.csv"     "$jq_filter_video"     ""
create_csv_file "TV Series"              "${LIBRARY_PATH}/TV"                    "${REPORT_PATH}/data-audio.csv"     "$jq_filter_audio"     ""
create_csv_file "TV Series"              "${LIBRARY_PATH}/TV"                    "${REPORT_PATH}/data-subtitle.csv"  "$jq_filter_subtitle"  ""
create_csv_file "TV Series"              "${LIBRARY_PATH}/TV"                    "${REPORT_PATH}/data-chapters.csv"  "$jq_filter_chapters"  ""
