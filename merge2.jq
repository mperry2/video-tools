# Helper function to normalize track types
def normalize_type(mkv_type; media_type):
  if   mkv_type == "video"     and media_type == "Video" then "video"
  elif mkv_type == "audio"     and media_type == "Audio" then "audio" 
  elif mkv_type == "subtitles" and media_type == "Text"  then "subtitles"
  else empty end;

# Group tracks by type from both sources
def mkv_by_type: $mkv.tracks | group_by(.type);
def media_by_type: $media.media.track[1:] | group_by(."@type");

{
  file: $mkv.file_name,
  container: {
    format: $mkv.container.type,
    duration_ns: $mkv.container.properties.duration,
    duration_readable: $media.media.track[0].Duration,
    title: $mkv.container.properties.title,
    muxing_application: $mkv.container.properties.muxing_application,
    writing_application: $mkv.container.properties.writing_application
  },
  tracks: [
    # Process each track type
    foreach $mkv.tracks[] as $mkv_track (0; . + 1; . as $idx |
      # Find corresponding mediainfo track
      ($media.media.track[1:] | map(select(
        normalize_type($mkv_track.type; ."@type") == $mkv_track.type
        and
        $mkv_track.properties.number == (.ID|tonumber)
      ))) as $matching_media |
      
      if $matching_media | length > 0 then
        $matching_media[($idx - 1) % ($matching_media | length)] as $media_track |
        {
          index: $idx,
          id: $mkv_track.id,
          type: $mkv_track.type,
          combined: {
            # Combined essential info
            codec: ($mkv_track.codec // $media_track.Format),
            language: $mkv_track.properties.language,
            title: ($mkv_track.properties.track_name // $media_track.Title),
            default: ($mkv_track.properties.default_track // false),
            forced: ($mkv_track.properties.forced_track // false),
            
            # Type-specific data
            video: (if $mkv_track.type == "video" then {
              resolution: "\($media_track.Width)x\($media_track.Height)",
              framerate: $media_track.FrameRate,
              bitrate: $media_track.BitRate,
              pixel_dimensions: $mkv_track.properties.pixel_dimensions
            } else null end),
            
            audio: (if $mkv_track.type == "audio" then {
              channels: $media_track.Channels,
              sample_rate: $media_track.SamplingRate,
              bitrate: $media_track.BitRate,
              bits_per_sample: $mkv_track.properties.audio_bits_per_sample
            } else null end),
            
            subtitle: (if $mkv_track.type == "subtitles" then {
              format: $media_track.Format,
              encoding: $mkv_track.properties.encoding
            } else null end)
          },
          # Keep original data for reference
          raw: {
            mkvmerge: $mkv_track,
            mediainfo: $media_track
          }
        }
      else
        # Track only in mkvmerge
        {
          index: $idx,
          id: $mkv_track.id,
          type: $mkv_track.type,
          combined: {
            codec: $mkv_track.codec,
            language: $mkv_track.properties.language,
            title: $mkv_track.properties.track_name,
            default: ($mkv_track.properties.default_track // false),
            forced: ($mkv_track.properties.forced_track // false)
          },
          raw: {
            mkvmerge: $mkv_track,
            mediainfo: null
          },
          note: "No matching mediainfo track found"
        }
      end
    )
  ],
  # Keep original data for reference
  raw: {
    mkvmerge: $mkv,
    mediainfo: $media
  }
}
