#!/bin/bash
#video in gif konvertieren und zurück zu einem video 
# konvertieren für den gifeffekt 
# benötigte programme : mediainfo, realpath, ffmpeg, #imagemagick

# merge video and audio with same length; arg1: input video; arg2: input audio, arg3: target directory  
convertVideoAndAudioToVideo () { 
    local video="${1}"  
    local audio="${2}"
    local target_dir="${3}" 

    local video_wo_ext="${video%.*}" 
    local video_basename_wo_path_wo_ex="${video_wo_ext##*/}"
    local video_Extension="${video##*.}" 

    mkdir -pv "${target_dir}" >&2      

    echo "${video_basename_wo_path_wo_ex}" >&2 
    local target_name="${target_dir}"/"${video_basename_wo_path_wo_ex}"."${video_Extension}" 

    # merge video with audio
    ffmpeg -hide_banner -i "${video}" -i "${audio}" -map 0:0 -map 1:0 -q:a 0 -q:v 0 "${target_name}" >&2 &&

    echo "${target_name}"
}

# convert jpgs to video with format from inputvideo; 
# arg1: realpath of directory of the jpgs; arg2: realpath of the original video, arg3: target directory
convertJpgsToVideo () { 
    local jpgs_dir="${1}"
    local video="${2}"  
    local target_dir="${3}" 

    local jpgs_dir=$(realpath "${jpgs_dir}") 

    mkdir -pv "${target_dir}" >&2      
    local target_dir=$(realpath "${target_dir}") 

    local jpgs_name="${jpgs_dir}/%09d.jpg"
    local jpgs_dirname_wo_ext="${jpgs_dir%.*}" 
    local jpgs_dir_basename_wo_path_wo_ex="${jpgs_dirname_wo_ext##*/}"  
    local video_Extension="${video##*.}" 
    local target_name="${target_dir}"/"${jpgs_dir_basename_wo_path_wo_ex}"."${video_Extension}" &&

    if [ "${video_Extension}" == "MTS" ] || [ "${video_Extension}" == "mts" ]
    then
        local framerate=$(ffprobe -v error -select_streams v:0 -show_entries program_stream=avg_frame_rate -of default=nw=1:nk=1 "${video}")
        local codec_name=$(ffprobe -v error -select_streams v:0 -show_entries program_stream=codec_name -of default=nw=1:nk=1 "${video}") 
        local pixel_fmt=$(ffprobe -v error -select_streams v:0 -show_entries program_stream=pix_fmt -of default=nw=1:nk=1 "${video}")  
    else
        local framerate=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 "${video}")
        local codec_name=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "${video}") 
        local pixel_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "${video}") 
    fi

    # convert jpgs to video
    ffmpeg -hide_banner -framerate "${framerate}" -i "${jpgs_name}" -codec:v "${codec_name}" -q:v 0 -pix_fmt "${pixel_fmt}" "${target_name}" >&2  &&

    echo "${target_name}"
}

# resize gifs in % to jpgs; arg1: realpath of the gifs directory arg2: persent of the original gifs, arg3: target directory
resizeGifs () {  
    local gifs_dir="${1}"
    local persent="${2}" 
    local target_dir="${3}"

    mkdir -pv  "${target_dir}" >&2 
    local target_dir=$(realpath "${target_dir}")

    echo "resize to ${persent}%: " >&2  

    # rezise and convert gifs to jpgs
    for f in "${gifs_dir}"/*.gif; do  
        fname_wo_ext="${f%.*}" &&
        basename_wo_path_wo_ex="${fname_wo_ext##*/}"
        convert "${f}" -resize "${persent}"% "${target_dir}"/"${basename_wo_path_wo_ex}".jpg
    done  
}

# posterize jpgs to gif; arg1: realpath of the jpg directory; arg2: posterizevalue for the gif, arg3: dithering, arg4: target directory
posterizeJpgs () {  
    local jpgs_dir="${1}"
    local posterizeval="${2}"
    local dither="${3}"
    local target_dir="${4}"

    mkdir -pv  "${target_dir}" >&2 
    local target_dir=$(realpath "${target_dir}")

    echo "reduce the mount of steps in every color channel to ${posterizeval}: " >&2 

    # posterize jpgs
    for f in "${jpgs_dir}"/*.jpg; do  
        fname_wo_ext="${f%.*}" &&
        basename_wo_path_wo_ex="${fname_wo_ext##*/}"
        convert "${f}" -dither "${dither}" -posterize "${posterizeval}" "${target_dir}/${basename_wo_path_wo_ex}".gif  
    done
}

# quantize jpgs to gif; arg1: realpath of the jpg directory arg2: colors for the gif, arg3: dithering, arg4: target directory
quantizeJpgs () {  
    local jpgs_dir="${1}"
    local colors="${2}" 
    local dither="${3}"
    local target_dir="${4}"

    mkdir -pv  "${target_dir}" >&2
    local target_dir=$(realpath "${target_dir}")

    echo "quantize with ${dither} dithering. ${colors} colors: " >&2  

    # quantize jpgs
    for f in "${jpgs_dir}"/*.jpg; do  
        fname_wo_ext="${f%.*}" &&
        basename_wo_path_wo_ex="${fname_wo_ext##*/}"
        convert "${f}" -dither "${dither}" -colors "${colors}" "${target_dir}/${basename_wo_path_wo_ex}".gif  
    done 
}

# choose dither 
chooseDither () {
while true; do
    read -p "[n/r/f] dither None [n], Riemersma [r] or FloydSteinberg [f] ? " nrf
    local d="None"
    case $nrf in
        [Nn]* ) d="None"
                echo "${d}"
                break ;;
        [Rr]* ) d="Riemersma" 
                echo "${d}"
                break ;;
        [Ff]* ) d="FloydSteinberg"
                echo "${d}"
                break ;;
            * ) echo "please answer dither None [n], Riemersma [r] or FloydSteinberg [f] "
    esac 
done
}

# quantize or posterize jpgs to gif; arg1: realpath of the jpg directory arg2: parent of the target directory
ContinueQuantizeOrPosterize () { 
    local jpgs_dir="${1}"
    local gifs_dir_parent="${2}"

    while true; do
        read -p "[q/p] quantize [q] or posterize [p]? " qp
        case $qp in
           [Qq]* )  read -p "colors [2, 3, 4, ..., 256]: " colors 

                    local dither=$(chooseDither)
                    if [ $? -ne 0 ]; then
                        echo "chooseDither failed" >&2
                        return 1
                    else     
                        local dither=$(echo "${dither}" | tail -n 1) 
                    fi 

                    local quantized_jpgs_dir="${gifs_dir_parent}/gifs/quantized_${colors}_colors_${dither}_dithering" 
                    $(quantizeJpgs "${jpgs_dir}" "${colors}" "${dither}" "${quantized_jpgs_dir}")  # quantize jpgs to gifs
                    if [ $? -ne 0 ]; then
                        echo "quantizeJpgs failed" >&2
                    else 
                        echo 'jpgs are quantized to: '$(realpath "${quantized_jpgs_dir}") >&2
                    fi
                    echo "${quantized_jpgs_dir}"
                    break ;;
           [Pp]* )  read -p "posterize colors [2, 3, 4, ..., 256]: " colors        

                    local dither=$(chooseDither)
                    if [ $? -ne 0 ]; then
                        echo "chooseDither failed" >&2
                        return 1
                    else 
                        local dither=$(echo "${dither}" | tail -n 1) 
                    fi 

                    local posterized_jpgs_dir="${gifs_dir_parent}/gifs/posterized_${colors}_colors_${dither}_dithering"
                    $(posterizeJpgs "${jpgs_dir}" "${colors}" "${dither}" "${posterized_jpgs_dir}")  # posterize jpgs to gifs
                    if [ $? -ne 0 ]; then
                        echo "posterizeJpgs failed" >&2
                    else 
                        echo 'jpgs are posterized to: '$(realpath "${posterized_jpgs_dir}") >&2
                    fi 
                    echo "${posterized_jpgs_dir}"
                    break ;;                 
               * )  echo "please answer quantize [q] or posterize [p] " ;;
        esac
    done  
}

# resize jpgs in %; arg1: realpath of the jpgs directory arg2: persent of the original jpgs, arg3: target directory
resizeJpgs () {  
    local jpgs_dir="${1}"
    local persent="${2}"
    local target_dir="${3}" 

    mkdir -pv  "${target_dir}" >&2 
    local target_dir=$(realpath "${target_dir}")

    echo "resize to ${persent}%: " >&2  

    for f in "${jpgs_dir}"/*.jpg; do  # resize to jpgs
        convert "${f}" -resize "${persent}"% "${target_dir}/$(basename "${f}")"
    done  
}

# extract jpgs from given video; arg1: realpath of the video, arg2: target directory
extractJpgs () {  
    local video="${1}" 
    local target_dir="${2}"

    mkdir -pv  "${target_dir}" >&2  
    local target_dir=$(realpath "${target_dir}")

    local target_name="${target_dir}"/%09d.jpg 

    # extract jpgs from video
    ffmpeg -hide_banner -i "${video}" -q:v 0 "${target_name}" >&2 
}

# extract audio from input video, arg1: realpath of the input video, arg2: target directory
extractAudio () { 
    local video="${1}"
    local target_dir="${2}"

    local stream_number=$(ffprobe -v error -show_entries format=nb_streams -of default=nw=1:nk=1 "${video}")

    if [ "${stream_number}" -le 1 ]; then 
        echo "video contains no audiostream" >&2
        return 1 ;
    else
        local video_wo_ext="${video%.*}" 
        local video_basename_wo_path_wo_ex="${video_wo_ext##*/}"
        local video_Extension=${video##*.}

        mkdir -pv "${target_dir}" >&2
        local target_dir=$(realpath "${target_dir}")

        local target_name="${target_dir}/${video_basename_wo_path_wo_ex}_audio.${video_Extension}" 
       
        # extract audio from video
        ffmpeg -hide_banner -i "${video}" -vn -acodec copy "${target_name}" >&2 
        
        echo "${target_name}"
    fi
}

completeConversion () {
    input=-1;
    until [ -f "${input}" ]; do   
        read -ep "path to the movie: " input 
    done

    local video=$(realpath "${input}") 
    local video_dir=$(dirname "${video}") 
    local video_wo_ext="${video%.*}" 
    local video_basename_wo_path_wo_ex="${video_wo_ext##*/}"

######################extract audio from the video input file#####################################
    local audio_dir="${video_dir}"/"${video_basename_wo_path_wo_ex}"_extracted/audio      
    local audio=$(extractAudio "${video}" "${audio_dir}")  # extract audio 
    if [ $? -ne 0 ]; then
        echo "extractAudio failed" >&2
    else 
        audio=$(echo "${audio}" | tail -n 1) 
        echo 'audio is extracted to: '$(realpath "${audio_dir}") >&2
    fi

#######################extract jpgs from the video input file#####################################
    local jpgs_dir="${video_dir}"/"${video_basename_wo_path_wo_ex}"_extracted/jpgs 
    $(extractJpgs "${video}" "${jpgs_dir}") # extract jpgs 
    if [ $? -ne 0 ]; then
        echo "extractJpgs failed" >&2
        return 1
    else 
        echo 'jpgs are extracted to: '$(realpath "${jpgs_dir}") >&2
    fi

########################resize the extracted jpgs or dont#########################################
    while true; do
        read -p "[r/n] resize jpgs [r] or dont resize [n]? " rn
        case $rn in
           [Rr]* )  read -p "persent to resize: " persent 
                    local gifs_dir_parent="${video_dir}"/"${video_basename_wo_path_wo_ex}"_extracted/converted/resized"${persent}"persent
                    local resized_jpgs_dir="${gifs_dir_parent}"/jpgs"${persent}"persent
                    $(resizeJpgs "${jpgs_dir}" "${persent}" "${resized_jpgs_dir}")  # resize jpgs
                    if [ $? -ne 0 ]; then
                        echo "resizeJpgs failed" >&2
                    return 1
                    else 
                        echo 'jpgs are resized to: '$(realpath "${resized_jpgs_dir}") >&2
                    fi 
                    break ;;
           [Nn]* )  local resized_jpgs_dir="${jpgs_dir}" 
                    local gifs_dir_parent="${video_dir}"/"${video_basename_wo_path_wo_ex}"_extracted/converted/unresized
                    break ;;
                * ) echo "please answer resize [r] or dont rezise [n] " ;;
        esac
    done  

#########################posterize or quantize the jpgs###############################################
    local gifs_dir=$(ContinueQuantizeOrPosterize "${resized_jpgs_dir}" "${gifs_dir_parent}")
    if [ $? -ne 0 ]; then
        return 1
    else 
        local gifs_dir=$(echo "${gifs_dir}" | tail -n 1) 
    fi

########################resize the gifs to original size or dont and convert them to jpgs######################################
    if [ rn == "R" ] || [ rn == "r" ]
    then
        local persentBack=$(echo "scale=0; 10000/$persent" | bc )
        local resized_jpgs_dir="${gifs_dir}"/../../jpgs/"$(basename "${gifs_dir}")"
        $(resizeGifs "${gifs_dir}" "${persentBack}" "${resized_jpgs_dir}")  # resize jpgs
        if [ $? -ne 0 ]; then
            echo "resizeGifs failed" >&2
            return 1
        else 
            echo 'gifs are resized to: '$(realpath "${resized_jpgs_dir}") >&2
        fi
    else 
        local resized_jpgs_dir="${gifs_dir}"/../../jpgs/"$(basename "${gifs_dir}")"
        mkdir -pv  "${resized_jpgs_dir}" >&2  
        local resized_jpgs_dir=$(realpath "${resized_jpgs_dir}")
        for f in "${gifs_dir}"/*.gif; do  # resize to jpgs
            fname_wo_ext="${f%.*}" &&
            basename_wo_path_wo_ex="${fname_wo_ext##*/}"
            convert "${f}" "${resized_jpgs_dir}"/"${basename_wo_path_wo_ex}".jpg
        done 
        echo 'jpgs are converted to: '$(realpath "${resized_jpgs_dir}") >&2
        
    fi    

#########################convert the jpgs to video####################################################################
    local video_wo_audio_dir="${resized_jpgs_dir}"/../../video/video_without_audio
    local video_wo_audio=$(convertJpgsToVideo "${resized_jpgs_dir}" "${video}" "${video_wo_audio_dir}") # convert jpgs to video
    if [ $? -ne 0 ]; then
        echo "continueconvertJpgsToVideo failed" >&2 
        return 1
    else 
        echo 'video saved under: '$(realpath "${video_wo_audio_dir}") >&2
    fi
    
###########################merge extracted audio and new video########################################################
    local video_w_audio_dir="${video_wo_audio_dir}"/../video_with_audio
    $(convertVideoAndAudioToVideo "${video_wo_audio}" "${audio}" "${video_w_audio_dir}") # merge audio and video
    if [ $? -ne 0 ]; then
        echo "continueconvertJpgsToVideo failed" >&2 
    else 
        echo 'merged video saved under: '$(realpath "${video_w_audio_dir}") >&2
    fi
}

chooseOptions () {
    local intoduction="Introduction: Enter a number between 1 and 9 or enter q to quit"
    local complete="[1] complete conversion"
    local second="[2] go to 2nd step: extract audio from video"
    local third="[3] go to 3rd step: extract jpgs from video"
    local fourth="[4] go to 4th step: resize jpgs in persent" 
    local fifth="[5] go to 5th step: quantize jpgs (options: color, dither)" 
    local sixt="[6] go to 6th step: posterize jpgs (options: color, dither)" 
    local seventh="[7] go to 7th step: resize gifs in persent to jpgs"
    local eighth="[8] go to 8th step: merge jpgs to video"
    local ninth="[9] go to 9th step: merge video and audio"
    local quit="[q] quit" 
    local newline='\n'
    local options="${complete}"$'\n'"${second}"$'\n'"${third}"$'\n'"${fourth}"$'\n'"${fifth}"$'\n'"${sixt}"$'\n'"${seventh}"$'\n'"${eighth}"$'\n'"${ninth}"$'\n'"${quit}"

while true; do
            echo "${intoduction}"
            echo "${options}"
            read -p "[1/2/3/4/5/6/7/8/9/q]: " q123456789
            case $q123456789 in
                 [1]* ) completeConversion ;;
                 [2]* ) # extract audio from video
                        video=-1;
                        until [ -f "${video}" ]; do   
                            read -ep "path to the movie: " video 
                        done
                        local video=$(realpath "${video}") 
      
                        $(extractAudio "${video}" "${video_dir}")  
                        if [ $? -ne 0 ]; then
                            echo "extractAudio failed" >&2
                        else 
                            echo 'audio is extracted to: '$(realpath "${audio_dir}") >&2
                        fi ;;
                 [3]* ) # extract jpgs from video
                        video=-1;
                        until [ -f "${video}" ]; do   
                            read -ep "path to the movie: " video 
                        done
                        local video=$(realpath "${video}") 

                        local jpgs_dir="${video_dir}"/jpgs 
                        $(extractJpgs "${video}" "${jpgs_dir}") 
                        if [ $? -ne 0 ]; then
                            echo "extractJpgs failed" >&2
                            return 1
                        else 
                            echo 'jpgs are extracted to: '$(realpath "${jpgs_dir}") >&2
                        fi ;;

                 [4]* ) # resize jpgs
                        jpgs_dir=-1
                        until [ -d "${jpgs_dir}" ]; do   
                            read -ep "jpgs directory:" jpgs_dir
                        done
                        local jpgs_dir=$(realpath "${jpgs_dir}") 
                        local jpgs_dir_basename=$(basename "${jpgs_dir}")
                        read -p "persent to resize: " persent 
                        local resized_jpgs_dir="${jpgs_dir}"/../"${jpgs_dir_basename}"_jpgs"${persent}"persent
                        $(resizeJpgs "${jpgs_dir}" "${persent}" "${resized_jpgs_dir}")  
                        if [ $? -ne 0 ]; then
                            echo "resizeJpgs failed" >&2
                            return 1
                        else 
                            echo 'jpgs are resized to: '$(realpath "${resized_jpgs_dir}") >&2
                        fi ;;
                 [5]* ) # quantize jpgs to gifs
                        jpgs_dir=-1
                        until [ -d "${jpgs_dir}" ]; do   
                            read -ep "jpgs directory:" jpgs_dir
                        done

                        read -p "colors [2, 3, 4, ..., 256]: " colors 

                        dither=$(chooseDither)
                        if [ $? -ne 0 ]; then
                            echo "chooseDither failed" >&2
                            return 1
                        else     
                            dither=$(echo "${dither}" | tail -n 1) 
                        fi 

                        local quantized_jpgs_dir="${jpgs_dir}/../gifs/quantized_${colors}_colors_${dither}_dithering" 
                        $(quantizeJpgs "${jpgs_dir}" "${colors}" "${dither}" "${quantized_jpgs_dir}")  
                        if [ $? -ne 0 ]; then
                            echo "quantizeJpgs failed" >&2
                        else 
                            echo 'jpgs are quantized to: '$(realpath "${quantized_jpgs_dir}") >&2
                        fi ;;
                 [6]* ) # posterize jpgs to gifs
                        read -p "posterize colors [2, 3, 4, ..., 256]: " colors        

                        dither=$(chooseDither)
                        if [ $? -ne 0 ]; then
                            echo "chooseDither failed" >&2
                            return 1
                        else 
                            dither=$(echo "${dither}" | tail -n 1) 
                        fi 

                        local posterized_jpgs_dir="${jpgs_dir}/../gifs/posterized_${colors}_colors_${dither}_dithering"
                        $(posterizeJpgs "${jpgs_dir}" "${colors}" "${dither}" "${posterized_jpgs_dir}")  
                        if [ $? -ne 0 ]; then
                            echo "posterizeJpgs failed" >&2
                        else 
                            echo 'jpgs are posterized to: '$(realpath "${posterized_jpgs_dir}") >&2
                        fi ;;
                 [7]* ) # resize jpgs
                        gifs_dir=-1
                        until [ -d "${gifs_dir}" ]; do   
                            read -ep "gifs directory:" gifs_dir
                        done
                        local gifs_dir=$(realpath "${gifs_dir}")
                        local gifs_basename=$(basename "${gifs_dir}")
                        read -p "persent to resize: " persent 
                        local resized_gifs_dir="${gifs_dir}"/../"${gifs_basename}"_jpgs"${persent}"persent
                        $(resizeGifs "${gifs_dir}" "${persent}" "${resized_gifs_dir}")  
                        if [ $? -ne 0 ]; then
                            echo "resizeGifs failed" >&2
                            return 1
                        else 
                            echo 'gifs are resized to: '$(realpath "${resized_jpgs_dir}") >&2
                        fi ;;
                 [8]* ) # convert jpgs to video
                        gifs_dir=-1
                        until [ -d "${gifs_dir}" ]; do   
                            read -ep "gifs directory:" gifs_dir
                        done
                        local gifs_dir=$(realpath "${gifs_dir}") 

                        video=-1;
                        until [ -f "${video}" ]; do   
                            read -ep "path to the original movie: (for videoformat)" video 
                        done
                        local video=$(realpath "${video}") 

                        local video_wo_audio_dir="${gifs_dir}"/../
                        local video_wo_audio=$(convertJpgsToVideo "${resized_gifs_dir}" "${video}" "${video_wo_audio_dir}") 
                        if [ $? -ne 0 ]; then
                            echo "continueconvertJpgsToVideo failed" >&2 
                            return 1
                        else 
                            echo 'video saved under: '$(realpath "${video_wo_audio_dir}") >&2
                        fi ;;
                 [9]* ) # merge audio and video
                        video=-1;
                        until [ -f "${video}" ]; do   
                            read -ep "path to the videofile: " video 
                        done
                        local video=$(realpath "${video}") 
                        local video_dir=$(dirname "${video}") 
                        audio=-1;
                        until [ -f "${audio}" ]; do   
                            read -ep "path to the audiofile: " audio 
                        done
                        local audio=$(realpath "${audio}") 

                        local video_w_audio_dir="${video_dir}"/video_converted
                        $(convertVideoAndAudioToVideo "${video}" "${audio}" "${video_w_audio_dir}") 
                        if [ $? -ne 0 ]; then
                            echo "continueconvertJpgsToVideo failed" >&2 
                        else 
                            echo 'merged video saved under: '$(realpath "${video_w_audio_dir}") >&2
                        fi ;;
                [Qq]* ) exit ;;                
                    * ) echo "[1/2/3/4/5/6/7/8/9], or quit [q] " ;;
            esac
        done
}

chooseOptions
    
