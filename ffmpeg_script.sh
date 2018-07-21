#!/bin/bash
# Script By Sbarboff 2018
# Channel Name : TEST FHD
#
# Alcune Note:
#
# - Se si trascodifica con audio copy, funziona solo con http, rtmp richiede la trascodifica anche dell'audio.
# - Se si trascodifica in HEVC (h265) l'uscita in rtmp non é supportata!
# - Selezionare trascodifica GPU enable o CPU enable, non funziona se tutti e due sono abilitati.
# - Se si trascodifica in GPU, e se la sorgente é in mpeg2video usare il codec hwaccel mpeg2_cuvid, se é in h264 usare h264_cuvid.
#
# Lo script richiede i seguenti software : 
#
# - Testato su Ubuntu 16.04 Server
# - FFmpeg con supporto nvenc per la trascodifica con GPU.
# - FFprobe per analizzare gli stream.
# - Download FFmpeg/FFprobe Static ( NO NVENC SUPPORT ONLY CPU ) https://johnvansickle.com/ffmpeg/ 
# - Compile FFmpeg NVENC SUPPORT GPU TRASCODING - https://gist.github.com/Brainiarc7/3f7695ac2a0905b05c5b 
# - Patch NVIDIA unlock limit session on GForce Card https://github.com/keylase/nvidia-patch
# - Nginx per servire in http gli stream : installabile con apt-get install nginx-full.
# - Imagemagick viene utilizzato per ricavare la lunghezza/largehezza dell'immagine (logo), per mantenere la risoluzione in base alla risoluzione dello stream, installare con apt-get install imagemagick
#   Attualmente funziona solo con trascodifica GPU.
# - Nginx o Wowza per servire gli stream in rtmp

##################################################################
## Output Config

##--> Output type : 0 = rtmp | 1 = http
output_type="1"

##--> Channel Stream Output Name ( no space )
channel_stream_name="testfhd"

##--> Stream Output rtmp url, se abilitato usare in questo modo es. : rtmp://127.0.0.1:1935/live/ lasciare la variabile impostata : $channel_stream_name
output="rtmp://10.10.7.181:1935/live/$channel_stream_name"

##--> Channel Name
channel_name="TEST FHD"

##--> Metadata Service Provider
metadata_service_provider="SRV-STREAM"

##--> Metadata Service Name
metadata_service_name="TEST FHD"

##################################################################
## Script Config

##--> Script loop sleep time, 5 seconds default 
second="5"

##--> Debug on/off 0 = on, 1 = off
debug="1"

##################################################################
## Logo Config global for rtmp and http

##--> Logo enable 0 = on, 1 = off
logo_enable="0"

##--> Logo Position Y Value
logo_position_y="30"

##--> Logo Position X Value
logo_position_x="30"

##--> Logo Position
##--> Top Left 		| overlay=$logo_position_y:$logo_position_x 
##--> Top Right 	| overlay=main_w-overlay_w-$logo_position_y:$logo_position_x 
##--> Bottom Left 	| overlay=$logo_position_y:main_h-overlay_h-$logo_position_x 
##--> Bottom Right 	| overlay=main_w-overlay_w-$logo_position_y:main_h-overlay_h-$logo_position_x
##--> Center 		| overlay=main_w/2-overlay_w/2:main_h/2-overlay_h/2

logo_position="overlay=$logo_position_y:$logo_position_x"

##--> Logo Path
logo_path="/root/T5TV160.png"

##--> Logo Image Size w
logo_size_w=`identify -format "%w" $logo_path | awk {'print $1 '}`

##--> Logo Image Size h
logo_size_h=`identify -format "%h" $logo_path | awk {'print $1 '}`

##################################################################
## Delogo Config global for rtmp and http

##--> DeLogo enable 0 = on, 1 = off
delogo_enable="1"

##--> Delogo Position Y Value
delogo_position_y="10"

##--> Delogo Position X Value
delogo_position_x="10"

##--> Delogo Band Position w Value
delogo_position_w="10"

##--> Delogo Band Position h Value
delogo_position_h="10"

##--> Delogo Band Value, good is from 0 to 30, default 5
delogo_band="5"

##--> Delogo show 0 = on, 1 = off
delogo_show="0"

##################################################################
## GPU Transcoding Config

##--> GPU Transcoding : 0 = Enable, 1 = Disable
gpu_transcoding="0"

##--> Video Average Bitrate

v_bitrate="3500k"

##--> Video Max Bitrate
v_maxrate="4000k"

##--> GPU Device number 0, 1, 2, ...
gpu_device="0"

##--> Value : vbr_hq, cbr_hq
rate_control="vbr_hq"

##--> Preset llhq,llhp
v_preset="llhq"

##--> Video Profile Level 4.0, 4.1, 5.1 ....
v_level="4.1"

##--> Video Size es: 1280x720, 720x576 ....
v_size="1920x1080"

##--> Video Size
v_frame_rate="25"

##--> Video Codec HWaccels
v_codec="h264_cuvid"

##--> Video Codec : h264_nvenc, hevc_nvenc
gpu_codec="h264_nvenc"

##################################################################
## CPU Transcoding Config

##--> CPU Transcoding : 0 = Enable, 1 = Disable
cpu_transcoding="1"

##--> Video Average Bitrate
cpu_v_bitrate="3000k"

##--> Video Max Bitrate
cpu_v_max_bitrate="3500k"

##--> Video Frame Rate
cpu_v_framerate="25"

##--> Video Profile
cpu_v_profile="high"

##--> Video Preset : fast, veryfast, superfast
cpu_v_preset="veryfast"

##--> Video Profile Level 4.0, 4.1, 5.1 ....
cpu_v_level="4.1"

##--> Video Size es: 1280x720, 720x576 ....
cpu_v_size="1920x1080"

##################################################################
## Audio Transcoding Config

##--> Audio Bitrate : copy, 96k, 128k, 162k, 192k, ....

a_codec="-acodec aac"
a_bitrate="$a_codec -ac 2 -ab 96k"

##################################################################
## Define input source stream


SOURCE_ARRAY=( 'http://10.10.10.3/test_fhd' 'http://10.10.10.3/test2_fhd' 'http://10.10.10.3/test3_fhd' )

##################################################################
## Da qui in giù non toccare.
##################################################################

while :
do
		for alive in ${SOURCE_ARRAY[@]}; 
		do
		################################################################################################################# 
		# Check sulle sorgenti se sono online

		CHECK_STREAM_SOURCE=`timeout 1 ffprobe -probesize 100000 -v quiet -print_format json -show_streams -i $alive 2>&1 | grep index | wc -l`


			################################################################################################################# 
			## Se le sorgenti sono online setta la variabile $stream_online.

			if [ "$CHECK_STREAM_SOURCE" -ge "1" ]; then

				# Debug
				if [ "$debug" -eq "0" ]; then
					 echo $alive " stream up"
				fi

				stream_online=$alive

				else


				## Debug
				if [ "$debug" -eq "0" ]; then
					echo $alive " stream down"
				fi
			fi
		done


		#################################################################################################################


			#################################################################################################################
			# Check if stream is running

			if [ "$output_type" -eq "0" ]; then
			CMD=`ps x | grep -v grep | grep -w "$output" | wc -l`

				## Debug
				if [ "$debug" -eq "0" ]; then
					echo ""
					echo "CMD Result $output : " $CMD
					echo ""
				fi

			fi

			if [ "$output_type" -eq "1" ]; then
			CMD=`ps x | grep -v grep | grep -w "${channel_stream_name}.m3u8" | wc -l`

				## Debug
				if [ "$debug" -eq "0" ]; then
					echo ""
					echo "CMD Result ${channel_stream_name}.m3u8 : " $CMD
					echo ""
				fi

			fi
			
			## GPU Transcoding 
			if [ "$gpu_transcoding" -eq "0" ] && [ "$cpu_transcoding" -eq "1" ]; then
			
					## if result CMD is 0, ffmpeg process is not active!
					if [ "$CMD" -eq "0" ]; then

						## if output type = 0, rtmp output enable
						if [ "$output_type" -eq "0" ]; then

							###########################################################################################################
							## Se é abilitato logo e delogo
							if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "0" ]; then

								ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -i "$logo_path" -gpu $gpu_device -codec:v h264_nvenc -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show [base];[1:v][base] scale2ref=($logo_size_w/$logo_size_h)*ih/16/sar:ih/16 [logo][0v]; [0v][logo] $logo_position [marked]" -map "[marked]" -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									techo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi

							fi # END IF logo and delogo is enable

							###########################################################################################################
							## Se é abilitato logo e delogo disabilitato
							if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "1" ]; then

								ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -i "$logo_path" -gpu $gpu_device -codec:v h264_nvenc -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12 [base]; [1:v][base] scale2ref=($logo_size_w/$logo_size_h)*ih/16/sar:ih/16 [logo][0v]; [0v][logo] $logo_position [marked]" -map "[marked]" -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									techo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi

							fi # END IF logo and delogo is enable

							###########################################################################################################
							## Se é disabilitato logo e delogo abilitato
							if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "0" ]; then

								ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -gpu $gpu_device -codec:v h264_nvenc -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									techo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi

							fi # END IF logo and delogo is enable

							###########################################################################################################
							## Se é disabilitato logo e delogo disabilitato
							if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "1" ]; then

								ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -gpu $gpu_device -codec:v h264_nvenc -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									techo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi

							fi # END IF logo and delogo is enable

						fi ## end rtmp output



						## if output type = 1, http output enable
						if [ "$output_type" -eq "1" ]; then

							if [ "$gpu_codec" == "h264_nvenc" ]; then

								###########################################################################################################
								## Se é abilitato logo e delogo 
								if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "0" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -i "$logo_path" -gpu $gpu_device -codec:v h264_nvenc -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show [base]; [1:v][base] scale2ref=($logo_size_w/$logo_size_h)*ih/16/sar:ih/16 [logo][0v]; [0v][logo] $logo_position [marked]" -map "[marked]" -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

								###########################################################################################################
								## Se é abilitato logo e delogo disabilitato 
								if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "1" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -surfaces 8 -i "$stream_online" -i "$logo_path" -gpu $gpu_device -codec:v h264_nvenc -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12 [base]; [1:v][base] scale2ref=($logo_size_w/$logo_size_h)*ih/16/sar:ih/16 [logo][0v]; [0v][logo] $logo_position [marked]" -map "[marked]" -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

								###########################################################################################################
								## Se é disabilitato logo e delogo abilitato 
								if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "0" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -gpu $gpu_device -codec:v h264_nvenc -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

								###########################################################################################################
								## Se é disabilitato logo e delogo disabilitato 
								if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "1" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -gpu $gpu_device -codec:v h264_nvenc -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -profile:v high -level $v_level -r $v_frame_rate -preset $v_preset -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi


							fi ## END if gpu codec = h264_nvenc




							if [ "$gpu_codec" == "hevc_nvenc" ]; then

								###########################################################################################################
								## Se é abilitato logo e delogo 
								if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "0" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -i "$logo_path" -gpu $gpu_device -codec:v hevc_nvenc -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show [base]; [1:v][base] scale2ref=($logo_size_w/$logo_size_h)*ih/16/sar:ih/16 [logo][0v]; [0v][logo] $logo_position [marked]" -map "[marked]" -map a:0:1 $a_bitrate -vbsf hevc_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

								###########################################################################################################
								## Se é abilitato logo e delogo disabilitato 
								if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "1" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -i "$logo_path" -gpu $gpu_device -codec:v hevc_nvenc -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12 [base]; [1:v][base] scale2ref=($logo_size_w/$logo_size_h)*ih/16/sar:ih/16 [logo][0v]; [0v][logo] $logo_position [marked]" -map "[marked]" -map a:0:1 $a_bitrate -vbsf hevc_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

								###########################################################################################################
								## Se é disabilitato logo e delogo abilitato 
								if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "0" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -gpu $gpu_device -codec:v hevc_nvenc -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -level $v_level -r $v_frame_rate -preset $v_preset -filter_complex_threads 1 -filter_complex "[0:v]hwdownload,format=nv12,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map a:0:1 $a_bitrate -vbsf hevc_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

								###########################################################################################################
								## Se é disabilitato logo e delogo disabilitato 
								if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "1" ]; then


									ffmpeg -hwaccel_device $gpu_device -hwaccel cuvid -c:v $v_codec -probesize 2560000 -resize $v_size -async 0 -threads 4 -thread_queue_size 1024 -deint 2 -drop_second_field 1 -i "$stream_online" -gpu $gpu_device -codec:v hevc_nvenc -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $v_bitrate -maxrate:v $v_maxrate -force_key_frames "expr:gte(t,n_forced*5)" -rc $rate_control -level $v_level -r $v_frame_rate -preset $v_preset -map a:0:1 $a_bitrate -vbsf hevc_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

									PID=$!

									## Debug
									if [ "$debug" -eq "0" ]; then
										echo ""
										echo "Start Transcoding Stream : " $stream_online
										echo "PID : " $PID
										echo ""
									fi
								fi

							fi ## END if gpu codec = hevc_nvenc

						fi ## END if output type = 1

					fi ## END if CMD status = 0

			sleep 2


			fi ## END GPU Transcoding


			## CPU Transcoding 
			if [ "$gpu_transcoding" -eq "1" ] && [ "$cpu_transcoding" -eq "0" ]; then
			
					if [ "$CMD" -eq "0" ]; then

						if [ "$output_type" -eq "0" ]; then

							###########################################################################################################
							## Se é abilitato logo e delogo 
							if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "0" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -i "$logo_path" -codec:v libx264 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)" -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -filter_complex_threads 1 -filter_complex "$logo_position,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map v:0:0 -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

							###########################################################################################################
							## Se é abilitato logo e delogo disabilitato 
							if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "1" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -i "$logo_path" -codec:v libx264 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)" -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -filter_complex_threads 1 -filter_complex "$logo_position" -map v:0:0 -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

							###########################################################################################################
							## Se é disabilitato logo e delogo abilitato 
							if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "0" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -codec:v libx264 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)" -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -filter_complex_threads 1 -filter_complex "delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map v:0:0 -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

							###########################################################################################################
							## Se é disabilitato logo e delogo disabilitato 
							if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "1" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -codec:v libx264 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)" -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -map v:0:0 -map a:0:1 $a_bitrate -flags +global_header -f flv "$output" </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

						fi ## END if output type = 0


						if [ "$output_type" -eq "1" ]; then

							###########################################################################################################
							## Se é abilitato logo e delogo 
							if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "0" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -i "$logo_path" -codec:v libx264 -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)"  -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -filter_complex_threads 1 -filter_complex "$logo_position,delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

							###########################################################################################################
							## Se é abilitato logo e delogo disabilitato 
							if [ "$logo_enable" -eq "0" ] && [ "$delogo_enable" -eq "1" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -i "$logo_path" -codec:v libx264 -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)"  -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -filter_complex_threads 1 -filter_complex "$logo_position" -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

							###########################################################################################################
							## Se é disabilitato logo e delogo abilitato 
							if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "0" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -codec:v libx264 -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)"  -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -filter_complex_threads 1 -filter_complex "delogo=x=$delogo_position_x:y=$delogo_position_y:w=$delogo_position_w:h=$delogo_position_h:show=$delogo_show" -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

							###########################################################################################################
							## Se é disabilitato logo e delogo disabilitato 
							if [ "$logo_enable" -eq "1" ] && [ "$delogo_enable" -eq "1" ]; then


								ffmpeg -probesize 2560000 -i "$stream_online" -codec:v libx264 -map v:0:0 -metadata service_provider="$metadata_service_provider" -metadata service_name="$metadata_service_name" -b:v $cpu_v_bitrate -maxrate:v $cpu_v_max_bitrate -force_key_frames "expr:gte(t,n_forced*5)"  -profile:v $cpu_v_profile -level $cpu_v_level -r $cpu_v_framerate -preset $cpu_v_preset -map a:0:1 $a_bitrate -vbsf h264_mp4toannexb -flags +global_header -f hls -hls_time 10 -hls_list_size 6 -hls_segment_type mpegts -hls_flags delete_segments -hls_segment_filename /var/www/html/ch-$channel_stream_name-%d.ts "/var/www/html/ch-$channel_stream_name.m3u8"  </dev/null >/dev/null 2> /var/log/$channel_stream_name.log &

								PID=$!

								## Debug
								if [ "$debug" -eq "0" ]; then
									echo ""
									echo "Start Transcoding Stream : " $stream_online
									echo "PID : " $PID
									echo ""
								fi
							fi

						fi ## END if output type = 1 

					fi ## END if CMD status = 0

			sleep 2


			fi ## END CPU Transcoding


			## Check if first element of array are online, then stop current and start.

			FIRST_STREAM=${SOURCE_ARRAY[-1]}
			CHECK_FIRST_STREAM_SOURCE=`timeout 1 ffprobe -probesize 100000 -v quiet -print_format json -show_streams -i $FIRST_STREAM 2>&1 | grep index | wc -l`

			## if check result is >= 1 stream are active ( online ), kill actual pid then restart the first stream on array
			if [ "$CHECK_FIRST_STREAM_SOURCE" -ge "1" ]; then

				## Check if stream is already active
				CMD=`ps x | grep -v grep | grep -w "$FIRST_STREAM" | wc -l`

					if [ "$CMD" -ge "1" ]; then

						if [ "$debug" -eq "0" ]; then
							echo ""
							echo "The firt priority stream is active : " $FIRST_STREAM 
							echo ""
						fi

					else

						if [ "$debug" -eq "0" ]; then
							echo ""
							echo "Kill running ffmpeg process pid : " $PID
							echo ""
						fi

						kill -9 $PID

					fi
			fi
sleep $second


done
