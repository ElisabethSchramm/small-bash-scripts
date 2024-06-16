#!/bin/bash
# Video stabilization
# Files and directories should not contain special characters
# "unable to read exif data from opened file:" is normal
# Required: ffmpeg, imagemagick, realpath, mediainfo

chooseoptions () {
    local intoduction="Introduction:"
    local complete="[1] complete conversion to stabilized video"
    local second="[2] go to 2nd step: save audio from the original video"
    local third="[3] go to 3rd step: stabilize extracted jpgs (this can take some hours or days)"
    local fourth="[4] go to 4th step: convert stabilized tifs to jpgs" 
    local fifth="[5] go to 5th step: cut stabilized jpgs" 
    local sixt="[6] go to 6th step: convert cutted jpgs to video" 
    local seventh="[7] go to 7th step: convert video and audio to video"
    local quit="[q] quit" 
    local newline='\n'
    local options="${complete}"$'\n'"${second}"$'\n'"${third}"$'\n'"${fourth}"$'\n'"${fifth}"$'\n'"${sixt}"$'\n'"${seventh}"$'\n'${quit}
    
    while true; do
            echo "${intoduction}"
            echo "${options}"
            read -p "[1/2/3/4/5/6/7/q]: " q1234567
            case $q1234567 in
                 [1]* ) completeConversion "1" ;;
                 [2]* ) completeConversion "2" ;;
                 [3]* ) completeConversion "3" ;;
                 [4]* ) completeConversion "4" ;;
                 [5]* ) completeConversion "5" ;;
                 [6]* ) completeConversion "6" ;;
                 [7]* ) completeConversion "7" ;;
                [Qq]* ) exit ;;                
                    * ) echo "please answer complete converion [1], step from conversion [2/3/4/5/6/7], or quit [q] " ;;
            esac
        done
}

completeConversion () { # step to beginn
    local step=${1} &&

    until [ -f "${input}" -a "${format}" == "AVI" ]; do  
        read -ep "path to the movie: " input 
        local format=$(mediainfo --Inform="General;%Format%" "${input}")
    done

    local video=$(realpath "${input}") &&
    local video_dir=$(dirname "${video}")  &&
    local video_fname_wo_ext="${video%.*}" &&
    local video_basename_wo_path_wo_ex="${video_fname_wo_ext##*/}"
    
    if [ $step -eq "1" ]; then
        saved_jpgs_dir=$(saveJpgs "${video}") # save jpgs 
        if [ $? -ne 0 ]; then
            echo "saveJpgs failed" >&2
            continue 2
        else 
            saved_jpgs_dir=$(echo "${saved_jpgs_dir}" | tail -n 1) 
            echo "jpgs are extracted to: '${saved_jpgs_dir}'" 
        fi
    else saved_jpgs_dir="${video_dir}/extracted/jpgs"   
    fi &&


    if [ $step -le "2" ]; then
        saved_audio=$(continueSaveAudio "${video}")  # save audio 
        if [ $? -ne 0 ]; then
            echo "continueSaveAudio failed" >&2
            continue 2 
        else 
            saved_audio=$(echo "${saved_audio}" | tail -n 1) 
            echo "audio is extracted to: '${saved_audio}'"
        fi
    else 
        saved_audio_name=$(ls "${video_dir}/extracted/audio" | head -n 1)
        saved_audio="${video_dir}/extracted/audio/${saved_audio_name}"     
    fi && 
 

    if [ $step -le "3" ]; then
        stabilized_tifs_dir=$(continueStabilizeJpgs "${saved_jpgs_dir}") # stabilize jpgs 
        if [ $? -ne 0 ]; then
            echo "continueStabilizeJpgs failed" >&2
            continue 2  
        else 
            stabilized_tifs_dir=$(echo "${stabilized_tifs_dir}" | tail -n 1) 
            echo "stabilized tifs are saved under: '${stabilized_tifs_dir}'"
        fi
    else stabilized_tifs_dir="${video_dir}/extracted/stabilized/tifs"
    fi &&


    if [ $step -le "4" ]; then
        stabilized_jpgs_dir=$(continueConvertTifsToJpgs "${stabilized_tifs_dir}") # convert stabilized tifs to jpgs
        if [ $? -ne 0 ]; then
            echo "continueConvertTifsToJpgs" >&2
            continue 2  
        else 
            stabilized_jpgs_dir=$(echo "${stabilized_jpgs_dir}" | tail -n 1) 
            echo "converted jpgs are saved under: '${stabilized_jpgs_dir}'"
        fi
    else stabilized_jpgs_dir="${video_dir}/extracted/stabilized/jpgs" 
    fi &&
      
  
    if [ $step -le "5" ]; then
        cutted_jpgs_dir=$(continueCutJpgs "${stabilized_jpgs_dir}") # cut stabilized jpgs
        if [ $? -ne 0 ]; then
            echo "continueCutJpgs failed" >&2
            continue 2  
        else 
            cutted_jpgs_dir=$(echo "${cutted_jpgs_dir}" | tail -n 1) 
            echo "cutted jpgs are saved under: '${cutted_jpgs_dir}'"
        fi
    else cutted_jpgs_dir="${video_dir}/extracted/stabilized/cutted/jpgs"
    fi &&


    if [ $step -le "6" ]; then        
        video_wo_audio=$(continueConvertJpgsToAvi "${cutted_jpgs_dir}" "${video}") # convert jpgs to avi
        if [ $? -ne 0 ]; then
            echo "continueConvertJpgsToAvi failed" >&2
            continue 2  
        else 
            video_wo_audio=$(echo "${video_wo_audio}" | tail -n 1) 
            echo "merged video saved under: '${video_wo_audio}'"
        fi
    else video_wo_audio="${video_dir}/extracted/stabilized/cutted/movie/${video_basename_wo_path_wo_ext}_stabilized_Video_Without_Audio.avi"
    fi &&


    if [ $step -le "7" ]; then
        video_w_audio=$(continueConvertVideoAndAudioToAvi "${video_wo_audio}" "${saved_audio}" "${video_basename_wo_path_wo_ex}") # convert video and audio to avi
        if [ $? -ne 0 ]; then
            echo "continueConvertVideoAndAudioToAvi failed" >&2
            continue 2  
        else 
            video_w_audio=$(echo "${video_w_audio}" | tail -n 1) 
            echo "merged video saved under: '${video_w_audio}'"
        fi
    fi       
}

saveJpgs () {  # convert input video.avi to jpgs; arg1: realpath of the input video.avi 
    local video="${1}" 
    local video_dir=$(dirname "$video")

    local target_dir="${video_dir}"/extracted/jpgs 
    mkdir -pv  "${target_dir}" >&2  

    local jpgs_path="${video_dir}"/extracted/jpgs/%09d.jpg 

    ffmpeg -hide_banner -i "${video}" -qscale 0 "${jpgs_path}" >&2 # convert video.avi to jpgs

    echo "${target_dir}" 
}

continueSaveAudio () { # save audio audio from input video.avi, arg1: realpath of the input video.avi
    local video="${1}" 

    while true; do
        read -p "[c/q] continue [c] extract Audio or quit [q]? " cq
        case $cq in
           [Cc]* )  audio=$(saveAudio "${video}") # save audio
                    if [ $? -ne 0 ]; then
                        echo "saveAudio failed" >&2
                        return 1 
                    else 
                        audio=$(echo "${audio}" | tail -n 1)
                        echo "${audio}" 
                    fi
                    break ;;
           [Qq]* )  return 1 ;;                
               * )  echo "please answer continue [c] or quit [q] " ;;
        esac
    done  
}

saveAudio () { # save audio from input video.avi, arg1: realpath of the input video.avi
    local video="${1}"

    local stream_number=$(ffprobe -v error -show_entries format=nb_streams -of default=nw=1:nk=1 "${video}")

    if [ "${stream_number}" -le 1 ]; then 
        echo "video contains no audiostream" >&2
        return 1 ;
    else
        local audio_Extension=$(getAudioExtension "${video}")
        if [ $? -ne 0 ]; then
            echo "getAudioExtension failed" >&2
            return 1
        else
            audio_Extension=$(echo "${audio_Extension}" | tail -n 1)  
            local video_dir=$(dirname "${video}") 
            local video_wo_ext="${video%.*}" 
            local video_basename_wo_path_wo_ex="${video_wo_ext##*/}"
            local target_dir="${video_dir}/extracted/audio"

            mkdir -pv "${target_dir}" >&2

            local audio="${target_dir}/${video_basename_wo_path_wo_ex}_audio.${audio_Extension}" 
              
            ffmpeg -hide_banner -i "${video}" -vn -codec: copy "${audio}" >&2 # save audio

            echo "${audio}"
        fi
    fi   
}

getAudioExtension () { # search for audioformat, arg1 = realpath of video
    local video="${1}" 
 
    audio_info=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_long_name -of default=nw=1:nk=1 "${video}")
    audio_info_wav=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_long_name -of default=nw=1:nk=1 "${video}" | grep WAV) 
    audio_info_aac=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_long_name -of default=nw=1:nk=1 "${video}" | grep AAC) 
    
    
    if [ -z "${audio_info}" ] ; then 
        echo "video contains no audiostream" >&2 
        return 1    
    elif [ ! -z "${audio_info_wav}" ]; then audio_Extension="wav"
    elif [ ! -z "${audio_info_aac}" ]; then audio_Extension="avi"  
    else
        echo "Audioinfo: '${audio_info}'" >&2 
        echo "script didnt found the audioformat from the input_video."$'\n'"please search it out from the previous output and insert "
        while true; do        
            read -p "examples: mp3 wav ogg or simply avi " audio_input 
            while true; do
                read -p "is '${audio_input}' the correct audioformat? [y/n] " yn 
                case $yn in
                    [Yy]* ) audio_Extension="${audio_input}"
                            echo "${audio_Extension}"
                            break ;;
                    [Nn]* ) ;;
                    [Qq]* ) return 1 ;;
                    * ) echo "please answer yes [y] or no [n] " ;;
                esac
            done 
        done      
    fi
    echo "${audio_Extension}"     
}

continueStabilizeJpgs () { # stabilize jpgs, arg1: realpath of the input directory
    local jpgs="${1}" &&
    while true; do
        read -p "attention!!! this can take some hours or days."$'\n'"[c/q] continue [c] stabilize or quit [q]? " cq
        case $cq in
            [Cc]* ) target_dir=$(stabilizeJpgs "${jpgs}"| tail -n 1) && # stabilize jpgs and convert to tifs 
                    if [ $? -ne 0 ]; then
                        echo "stabilizeJpgs failed" >&2
                        return 1 
                    else
                        target_dir=$(echo "${target_dir}" | tail -n 1)
                        echo "${target_dir}"  
                        break 
                    fi ;;
           [Qq]* ) return 1 ;;                
               * ) echo "please answer continue [c] or quit [q] " ;;
        esac
    done    
}

stabilizeJpgs () { # stabilize jpgs, arg1: realpath of the input directory
    local jpgs_dir="${1}"    

    local target_dir="${jpgs_dir}/../stabilized/tifs" 
    mkdir -pv "${target_dir}" >&2 &&
    local target_dir=$(realpath "${target_dir}") &&

    cd "${jpgs_dir}" && 

    align_image_stack -a t *.jpg --gpu -v >&2 && # stabilize jpgs and convert to tifs 

    mv -iv *.tif "${target_dir}" >&2  &&
    renameToSequentialNumbers "${target_dir}" "" 9 tif "${target_dir}" &&

    echo "${target_dir}" 
    
}

renameToSequentialNumbers () { # arg1: input directory, arg2: part befor numbers, arg3: number of digits ; arg4=fileextension of files, arg5: output directory
    local input_dir="${1}"
    local input_beginning="${2}" 
    local input_number_of_digits="${3}"    
    local fileextension="${4}"
    local output_directory="${5}" 

    local files="${input_beginning}%0${input_number_of_digits}d.${fileextension}" &&

    cd "${input_dir}" &&

    i=0; 
    for file in $(ls | sort -n); do # rename files to sequential numbers
        ((i++)) 
        newName=`printf "${files}" "${i}"`
        mv -iv "${file}" "${output_directory}/${newName}"         
    done
}

continueConvertTifsToJpgs () { # arg1: realpath of input directory
    local tifs_dir="${1}" 

    while true; do
        read -p "[c/q] continue [c] convert tifs to jpgs or quit [q]? " cq
        case $cq in
            [Cc]* ) target_dir=$(convertTifsToJpgs "${tifs_dir}") # convert tifs to jpgs
                    if [ $? -ne 0 ]; then
                        echo "convertTifsToJpgs failed" >&2
                        return 1 
                    else
                        target_dir=$(echo "${target_dir}" | tail -n 1)
                        echo "${target_dir}"    
                        break 
                    fi ;;
            [Qq]* ) return 1 ;;
            * ) echo "please answer continue [c] or quit [q] " ;;
        esac
    done
}

convertTifsToJpgs () { # arg1: realpath of input directory
    local tifs_dir="${1}"

    local target_dir="${tifs_dir}/../jpgs"  

    mkdir -pv "${target_dir}" >&2 &&

    local target_dir=$(realpath "${target_dir}") >&2 &&

    for f in "${tifs_dir}"/*.tif; do  # convert tifs to jpgs
        echo "converting ${f}" >&2 
        convert "${f}" "${f%.*}".jpg
    done  
                                                                                  
    mv -iv "${tifs_dir}"/*.jpg "${target_dir}" >&2 # move converted jpgs
 
    echo "${target_dir}"
}

continueCutJpgs () { # arg1: realpath of jpgs directory
    local jpgs_dir="${1}" 

    while true; do
        read -p "[c/q] continue [c] cutting stabilized images or quit [q] ? " cq
        case $cq in
            [Cc]* ) target_dir=$(cutJpgs "${jpgs_dir}") # cut jpgs
                    
                    if [ $? -ne 0 ]; then
                        echo "cutJpgs failed" >&2
                        return 1 
                    else
                        target_dir=$(echo "${target_dir}" | tail -n 1)
                        echo "${target_dir}"
                        break 
                    fi ;;
            [Qq]* ) return 1;;
                * ) echo "please answer continue [c] or quit [q] " ;;
        esac
    done
}

cutJpgs () { #arg1 = realpath of directory of the jpgs 

    local jpgs_dir="${1}" 
    local width="0"
    local height="0"
    local horizontal="0"
    local vertical="0"

    while true; do
        
        echo "cut stabilized images"
        echo "please view the stabilized images in stabilized/jpg with an external programm. then enter the images selection which you want to keep. "
        echo "first insert the the size (width, height). then insert the startpoint (left, top) where the selection begins."
        echo "after that you can view the result and choose between keeping or doing it again"

        read -p "width: (last width = '${width}' ) " width
        read -p "height: (last height = '${height}' ) " height
        echo "startpoint (left, top):"
        read -p "horizontal: (last horizontal = '${horizontal}' ) " horizontal
        read -p "vertikal: (last width = '${vertical}' ) " vertical

        local target_dir="${jpgs_dir}/../cutted/jpgs" &&    
        mkdir -pv "${target_dir}" >&2 &&
        local target_dir=$(realpath "${target_dir}") >&2 &&

        cp -ir "$jpgs_dir" "${target_dir}/.." 
        
        for file in "${target_dir}/*.jpg"
            do  echo "converting '${file}'" >&2
            convert "${file}" -crop  ${width}x${height}+${horizontal}+${vertical} +repage "${file}" >&2 # cut jpgs
        done 

        while true; do # continue? 
            read -p "[r/c/q] remove [r] cutted jpgs and cut again, continue [c] or quit [q]? " crq
            case $crq in 
                [Cc]* ) target_dir=$(echo "${target_dir}" | tail -n 1)
                        echo "${target_dir}"  
                        break 3 ;;
                [Rr]* ) target_dir=$(echo "${target_dir}" | tail -n 1)
                        rm -rv "${target_dir}" >&2 
                        break ;;
                [Qq]* ) return 1 ;;
                    * ) echo "please answer remove [r], continue [c] or quit [q] " ;;
                esac
        done  
    done  
}

continueConvertJpgsToAvi () { # arg1: realpath of the jpgs; arg2: realpath of the original video
    local jpgs="${1}"
    local video="${2}" 
 
    while true; do
        read -p "[c/q] continue [c] converting cutted images to avi or quit [q]? " cq 
        case $cq in
            [Cc]* ) target_name=$(convertJpgsToAvi "${jpgs}" "${video}") # convert jpgs to avi
                    if [ $? -ne 0 ]; then
                        echo "convertJpgsToAvi failed" >&2
                        return 1 
                    else
                        target_name=$(echo "${target_name}" | tail -n 1)
                        echo "${target_name}" 
                        break
                    fi ;;
            [Qq]* ) return 1;;
                * ) echo "please answer continue [c] or quit [q] " ;;
        esac
    done     
}

convertJpgsToAvi () { # arg1: realpath of directory the jpgs; arg2: realpath of the original video 

    local jpgs_dir="${1}"
    local video="${2}"    
  
    local first_jpg=$(ls "$jpgs_dir" | head -n 1)
    local first_jpg_basename=$(basename "${first_jpg}")
    local first_jpg_basename_length=$(expr length "${first_jpg_basename}")
    local first_jpg_basename_length=$(expr "${first_jpg_basename_length}" - 4)   
    local jpgs_name="${jpgs_dir}/%0${first_jpg_basename_length}d.jpg"
    echo ${jpgs_name} >&2

    local target_dir="${jpgs_dir}/../movie"
    mkdir -pv "${target_dir}" >&2      
    local target_dir=$(realpath "${target_dir}") >&2 

    local video_fname_wo_ext="${video%.*}" 
    local video_basename_wo_path_wo_ex="${video_fname_wo_ext##*/}"    

    local target_name="${target_dir}/${video_basename_wo_path_wo_ex}_stabilized_Video_Without_Audio.avi" &&
    
    local codec_type=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of default=nw=1:nk=1 "${video}") 
    local framerate=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nw=1:nk=1 "${video}")
    local codec_name=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "${video}") 
    local pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "${video}")    

    ffmpeg -hide_banner -f image2 -r "${framerate}" -i "${jpgs_name}" -codec:v "${codec_name}" -q:v 0 -pix_fmt "${pix_fmt}" "${target_name}" >&2 && # convert jpgs to avi

    echo "${target_name}"
}

continueConvertVideoAndAudioToAvi () { # arg1: input video; arg2: input audio  arg3: basename of the video without extention
    local video="${1}"  
    local audio="${2}"  
    local video_basename_wo_path_wo_ext="${3}" 

    while true; do
        read -p "[c/q] continue [c] converting video and audio to avi or quit [q]? " cq 
        case $cq in
            [Cc]* ) local target_name=$(convertVideoAndAudioToAvi "${video}" "${audio}" "${video_basename_wo_path_wo_ext}" | tail -n 1) # merge video with audio
                    if [ $? -ne 0 ]; then
                        echo "convertVideoAndAudioToAvi failed" >&2
                        return 1 
                    else
                        target_name=$(echo "${target_name}" | tail -n 1)
                        echo "${target_name}"
                        break 
                    fi ;;
            [Qq]* ) return 1 ;;
            * ) echo "please answer continue [c] or quit [q] " ;;
        esac
    done    
    
}

convertVideoAndAudioToAvi () { # arg1: input video.avi; arg2: input audio  arg3: basename of the video without extention
    local video="${1}"  
    local audio="${2}"
    local video_basename_wo_path_wo_ext="${3}" 

    local video_dir=$(dirname "${video}") 

    local target_name="${video_dir}/${video_basename_wo_path_wo_ext}_stabilized_Video_With_Audio.avi" 

    ffmpeg -hide_banner -i "${video}" -i "${audio}" -c copy "${target_name}" >&2 # merge video with audio

    echo "${target_name}"
}

    chooseoptions


