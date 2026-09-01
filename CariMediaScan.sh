#!/bin/zsh
#
# 🦌 CariMediaScan — Automator Quick Action script (v6.8) — by Caribou Labs
# 1 fichier sélectionné  → mode NAVIGATEUR : ↑/↓ ou ←/→ pour parcourir le dossier,
#                          clic sur une vidéo dans le Finder = mise à jour auto.
# 2 fichiers sélectionnés → mode COMPARAISON : les deux rapports côte à côte.
# Bouton Copy : copie le rapport dans le presse-papiers.
# Détection Dolby Vision et HDR10+ dans Color space.
# Échap, Entrée ou OK pour fermer.
#

# ============================================================
# 1. ÉCRITURE DU SCRIPT D'ANALYSE (appelé pour chaque fichier)
# ============================================================
ANALYZER="/tmp/carimediascan_analyzer.sh"

cat > "$ANALYZER" <<'ANALYZER_EOF'
#!/bin/zsh
# Analyse UN fichier vidéo ($1) et imprime le rapport formaté.

FFPROBE=""
for p in /opt/homebrew/bin/ffprobe /usr/local/bin/ffprobe /usr/bin/ffprobe; do
    if [[ -x "$p" ]]; then FFPROBE="$p"; break; fi
done

pretty_codec() {
    case "$1" in
        h264|avc1) echo "H.264 / AVC" ;;
        hevc|hvc1|hev1) echo "H.265 / HEVC" ;;
        av1|av01) echo "AV1" ;;
        vp9|vp09) echo "VP9" ;;
        vp8) echo "VP8" ;;
        mpeg4|mp4v) echo "MPEG-4 Visual" ;;
        mpeg2video) echo "MPEG-2" ;;
        prores|apch|apcn|apcs|apco) echo "Apple ProRes" ;;
        mjpeg|jpeg) echo "Motion JPEG" ;;
        aac) echo "AAC" ;;
        ac3) echo "Dolby Digital (AC-3)" ;;
        eac3) echo "Dolby Digital+ (E-AC-3)" ;;
        dts) echo "DTS" ;;
        truehd) echo "Dolby TrueHD" ;;
        flac) echo "FLAC" ;;
        opus) echo "Opus" ;;
        vorbis) echo "Vorbis" ;;
        mp3) echo "MP3" ;;
        alac) echo "Apple Lossless" ;;
        pcm_s16le|pcm_s24le|lpcm) echo "PCM" ;;
        "") echo "—" ;;
        *) echo "${(U)1}" ;;
    esac
}

pretty_sub_codec() {
    case "$1" in
        subrip|srt) echo "SRT" ;;
        ass) echo "ASS" ;;
        ssa) echo "SSA" ;;
        hdmv_pgs_subtitle) echo "PGS (Blu-ray)" ;;
        dvd_subtitle) echo "VobSub (DVD)" ;;
        dvb_subtitle) echo "DVB" ;;
        mov_text) echo "MOV Text" ;;
        webvtt) echo "WebVTT" ;;
        eia_608|cea708) echo "Closed Captions" ;;
        "") echo "—" ;;
        *) echo "${(U)1}" ;;
    esac
}

pretty_lang() {
    case "$1" in
        fre|fra|fr) echo "French" ;;
        eng|en) echo "English" ;;
        spa|es) echo "Spanish" ;;
        ger|deu|de) echo "German" ;;
        ita|it) echo "Italian" ;;
        jpn|ja) echo "Japanese" ;;
        kor|ko) echo "Korean" ;;
        chi|zho|zh) echo "Chinese" ;;
        por|pt) echo "Portuguese" ;;
        rus|ru) echo "Russian" ;;
        ara|ar) echo "Arabic" ;;
        nld|dut|nl) echo "Dutch" ;;
        pol|pl) echo "Polish" ;;
        tur|tr) echo "Turkish" ;;
        swe|sv) echo "Swedish" ;;
        nor|no) echo "Norwegian" ;;
        dan|da) echo "Danish" ;;
        fin|fi) echo "Finnish" ;;
        hin|hi) echo "Hindi" ;;
        tha|th) echo "Thai" ;;
        heb|he) echo "Hebrew" ;;
        und|"") echo "" ;;
        *) echo "${(U)1}" ;;
    esac
}

resolution_label() {
    local w=$1
    if (( w >= 7600 )); then echo " (8K)"
    elif (( w >= 3800 )); then echo " (4K UHD)"
    elif (( w >= 2500 )); then echo " (2.5K)"
    elif (( w >= 1900 )); then echo " (Full HD 1080p)"
    elif (( w >= 1200 )); then echo " (HD 720p)"
    elif (( w >= 700 )); then echo " (SD)"
    else echo ""
    fi
}

pretty_colorspace() {
    local space="$1" transfer="$2"
    local label=""
    case "$space" in
        bt709) label="BT.709 (Rec. 709)" ;;
        bt2020nc|bt2020c) label="BT.2020 (Rec. 2020)" ;;
        smpte170m) label="SMPTE 170M (NTSC)" ;;
        bt470bg) label="BT.470 (PAL)" ;;
        ""|unknown) label="—" ;;
        *) label="${(U)space}" ;;
    esac
    case "$transfer" in
        smpte2084) label="$label · HDR10 (PQ)" ;;
        arib-std-b67) label="$label · HLG (HDR)" ;;
    esac
    echo "$label"
}

pretty_channels() {
    local layout="$1" count="$2"
    case "$layout" in
        mono) echo "Mono" ;;
        stereo) echo "Stereo" ;;
        5.1*) echo "5.1" ;;
        7.1*) echo "7.1" ;;
        ""|unknown)
            case "$count" in
                1) echo "Mono" ;;
                2) echo "Stereo" ;;
                6) echo "5.1" ;;
                8) echo "7.1" ;;
                "") echo "" ;;
                *) echo "$count ch" ;;
            esac ;;
        *) echo "$layout" ;;
    esac
}

get_val() {
    echo "$1" | grep "^$2=" | head -1 | cut -d= -f2-
}

SEP="───────────────────────────────────────────────"

f="$1"
[[ -f "$f" ]] || { echo "File not found: $f"; exit 0 }

name="${f##*/}"
ext="${${f##*.}:u}"

bytes=$(stat -f%z "$f" 2>/dev/null || echo 0)
size=$(awk -v s="$bytes" 'BEGIN {
    split("bytes KB MB GB TB", u, " "); i=1
    while (s >= 1000 && i < 5) { s /= 1000; i++ }
    if (i == 1) printf "%d %s", s, u[i]; else printf "%.2f %s", s, u[i]
}')

resolution="—"; fps="—"; vcodec="—"; vbitrate="—"
pixfmt="—"; colorspace="—"; driver="—"; timecode="—"
duration="—"
audio_section=""; sub_section=""

# ============================================================
# DÉTECTION : fichier Blackmagic RAW (.braw) ?
# Le BRAW est propriétaire : ffprobe ne le lit pas, mais le plugin
# Spotlight de DaVinci Resolve expose tout via mdls.
# ============================================================
if [[ "${${f##*.}:l}" == "braw" ]]; then
    # Lecture d'un attribut mdls (renvoie "" si absent ou (null))
    md() {
        local v
        v=$(mdls -raw -name "$1" "$f" 2>/dev/null)
        [[ "$v" == "(null)" || -z "$v" ]] && echo "" || echo "$v"
    }
    P="com_blackmagic_design_braw_movie_clip"
    F="com_blackmagic_design_braw_movie_frame0"

    b_res=$(md ${P}_resolution)
    [[ -n "$b_res" ]] && b_res="${b_res// x / × }"
    b_ratio=$(md ${P}_braw_compression_ratio)
    b_bitrate_raw=$(md ${P}_braw_codec_bitrate)
    b_bitrate=""
    [[ -n "$b_bitrate_raw" ]] && b_bitrate=$(awk -v b="$b_bitrate_raw" 'BEGIN { printf "%.0f Mb/s", b/1000000 }')
    b_cam=$(md ${P}_camera_type)
    b_fw=$(md ${P}_firmware_version)
    b_lens=$(md ${P}_lens_type)
    b_rate=$(md ${F}_sensor_rate)
    b_iso=$(md ${F}_iso)
    b_aperture=$(md ${F}_aperture)
    b_focal=$(md ${F}_focal_length)
    b_shutter=$(md ${F}_shutter_value)
    b_wb=$(md ${F}_white_balance_kelvin)
    b_tint=$(md ${F}_white_balance_tint)
    b_gamma=$(md ${P}_viewing_gamma)
    b_gamut=$(md ${P}_viewing_gamut)
    b_lut=$(md ${P}_post_3dlut_embedded_name)
    b_dir=$(md ${P}_director)
    b_scene=$(md ${P}_scene)
    b_take=$(md ${P}_take)
    b_reel=$(md ${P}_reel_name)
    b_date=$(md ${P}_date_recorded)
    b_env=$(md ${P}_environment)
    b_daynight=$(md ${P}_day_night)
    b_focusdist=""   # distance de mise au point (rempli en repli réseau ci-dessous)

    nd() { [[ -n "$1" ]] && echo "$1" || echo "—"; }

    # ------------------------------------------------------------
    # REPLI RÉSEAU : si mdls n'a rien donné (Spotlight n'indexe pas
    # les volumes réseau), on lit ce qu'on peut via ffprobe + strings.
    # ------------------------------------------------------------
    braw_source="Spotlight"
    if [[ -z "$b_res" && -n "$FFPROBE" ]]; then
        braw_source="réseau (partiel)"
        vinfo=$("$FFPROBE" -v error -select_streams v:0 \
            -show_entries stream=width,height,r_frame_rate,bit_rate \
            -of default=noprint_wrappers=1 "$f" 2>/dev/null)
        bw=$(echo "$vinfo" | grep '^width=' | cut -d= -f2)
        bh=$(echo "$vinfo" | grep '^height=' | cut -d= -f2)
        [[ -n "$bw" && -n "$bh" ]] && b_res="$bw × $bh"

        frac=$(echo "$vinfo" | grep '^r_frame_rate=' | cut -d= -f2)
        if [[ -n "$frac" && "$frac" != "0/0" ]]; then
            b_rate=$(echo "$frac" | awk -F/ '{ v=($2>0)?$1/$2:$1;
                if (v==int(v)) printf "%d fps", v; else printf "%.3f fps", v }')
        fi

        bbr=$(echo "$vinfo" | grep '^bit_rate=' | cut -d= -f2)
        [[ -z "$bbr" || "$bbr" == "N/A" ]] && bbr=$("$FFPROBE" -v error \
            -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
        if [[ -n "$bbr" && "$bbr" != "N/A" ]]; then
            b_bitrate_raw="$bbr"
            b_bitrate=$(awk -v b="$bbr" 'BEGIN { printf "%.0f Mb/s", b/1000000 }')
        fi

        # Durée réelle via ffprobe (plus fiable que l'estimation ici)
        secs=$("$FFPROBE" -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)

        # Réglages de prise lisibles en clair dans l'en-tête du .braw
        # (on limite à un échantillon pour rester rapide sur gros fichiers réseau)
        raw_strings=$(strings -n 4 "$f" 2>/dev/null | grep -m 40 -E "aptr|fcln|shtv|dsnc")
        pick() { echo "$raw_strings" | grep -m1 "$1" | sed "s/.*$1//" | tr -d '\r' | xargs 2>/dev/null; }
        [[ -z "$b_aperture" ]] && b_aperture=$(pick "aptr")
        [[ -z "$b_focal"    ]] && b_focal=$(pick "fcln")
        [[ -z "$b_shutter"  ]] && b_shutter=$(pick "shtv")
        b_focusdist=$(pick "dsnc")
    fi

    # Compression + débit sur une ligne
    compression=""
    [[ -n "$b_ratio" ]] && compression="$b_ratio"
    [[ -n "$b_bitrate" ]] && compression="${compression:+$compression · }$b_bitrate"
    [[ -z "$compression" ]] && compression="—"

    # Caméra + firmware
    camera=$(nd "$b_cam")
    [[ -n "$b_fw" ]] && camera="$camera · firmware $b_fw"

    # Réglages de prise (champs présents seulement)
    shot=""
    [[ -n "$b_iso" ]] && shot="ISO $b_iso"
    [[ -n "$b_aperture" ]] && shot="${shot:+$shot · }$b_aperture"
    [[ -n "$b_focal" ]] && shot="${shot:+$shot · }$b_focal"
    [[ -n "$b_shutter" ]] && shot="${shot:+$shot · }$b_shutter"
    if [[ -n "$b_wb" && "$b_wb" != "0" ]]; then
        wbtxt="${b_wb}K"
        [[ -n "$b_tint" && "$b_tint" != "0" ]] && wbtxt="$wbtxt, tint $b_tint"
        shot="${shot:+$shot · }WB $wbtxt"
    fi
    [[ -n "$b_focusdist" ]] && shot="${shot:+$shot · }focus $b_focusdist"
    [[ -z "$shot" ]] && shot="—"

    # Gamma / Gamut
    gg="—"
    [[ -n "$b_gamma" ]] && gg="$b_gamma"
    [[ -n "$b_gamut" ]] && gg="${gg} / ${b_gamut}"

    # Durée : réelle via ffprobe si dispo (réseau), sinon estimée (taille × 8 ÷ débit)
    braw_duration=""
    if [[ -n "$secs" && "$secs" != "N/A" ]]; then
        braw_duration=$(awk -v t="$secs" 'BEGIN {
            s = int(t + 0.5); h = int(s/3600); m = int((s%3600)/60); sec = s%60
            if (h > 0) printf "%dh %02dm %02ds", h, m, sec
            else if (m > 0) printf "%dm %02ds", m, sec
            else printf "%ds", sec
        }')
    elif [[ -n "$b_bitrate_raw" && "$b_bitrate_raw" != "0" && "$bytes" -gt 0 ]]; then
        braw_duration=$(awk -v sz="$bytes" -v br="$b_bitrate_raw" 'BEGIN {
            t = (sz * 8) / br
            s = int(t + 0.5); h = int(s/3600); m = int((s%3600)/60); sec = s%60
            if (h > 0) printf "≈ %dh %02dm %02ds", h, m, sec
            else if (m > 0) printf "≈ %dm %02ds", m, sec
            else printf "≈ %ds", sec
        }')
    fi

    # Bloc production (champs présents seulement)
    prod=""
	  [[ -n "$b_dir" ]] && prod="🎬  Director:	$b_dir"
    [[ -n "$b_scene" ]] && prod="${prod:+$prod
}🎞	Scene:	$b_scene"
    [[ -n "$b_take" ]] && prod="${prod:+$prod
}🎯	Take:	$b_take"
    [[ -n "$b_reel" ]] && prod="${prod:+$prod
}🎟	Reel:	$b_reel"
    [[ -n "$b_date" ]] && prod="${prod:+$prod
}📅	Date:	$b_date"
    envline=""
    [[ -n "$b_env" ]] && envline="$b_env"
    [[ -n "$b_daynight" ]] && envline="${envline:+$envline · }$b_daynight"
    [[ -n "$envline" ]] && prod="${prod:+$prod
}🌗	Environment:	$envline"
    [[ -z "$prod" ]] && prod="(no production metadata)"

    msg="🎥  $name

📐	Resolution:	$(nd "$b_res")
🎞	Frame rate:	$(nd "$b_rate")
🗜	Compression:	$compression
🌈	Gamma / Gamut:	$gg
🎨	Embedded LUT:	$(nd "$b_lut")

$SEP
CAMERA

📷	Camera:	$camera
🔭	Lens:	$(nd "$b_lens")

$SEP
SHOT SETTINGS

⚙️	$shot

$SEP
PRODUCTION

$prod

$SEP

⏱	Duration:	$(nd "$braw_duration")
💾	File size:	$size
📦	Container:	Blackmagic RAW (.$ext)
🔎	Metadata:	$braw_source"

    print -r -- "$msg"
    exit 0
fi

# ============================================================
# DÉTECTION : fichier AUDIO (aucune piste vidéo "animée") ?
# ffprobe voit parfois une pochette comme un flux vidéo : on l'ignore
# en regardant si la (les) piste(s) vidéo ont >1 frame.
# ============================================================
is_audio=0
if [[ -n "$FFPROBE" ]]; then
    vcount=$("$FFPROBE" -v error -select_streams V -show_entries stream=index \
        -of csv=p=0 "$f" 2>/dev/null | grep -c .)
    # -select_streams V (majuscule) = pistes vidéo HORS pochettes/images attachées
    if (( vcount == 0 )); then is_audio=1; fi
else
    # Sans ffmpeg : on se fie à l'extension pour choisir la mise en page
    case "${${f##*.}:l}" in
        mp3|flac|wav|m4a|aac|ogg|opus|aiff|aif|wma|alac|ape|wv) is_audio=1 ;;
    esac
fi

if (( is_audio == 1 )) && [[ -z "$FFPROBE" ]]; then
    # ---- Mode audio dégradé (métadonnées Spotlight) ----
    acodec=$(mdls -raw -name kMDItemCodecs "$f" 2>/dev/null | tr -d '()"' | tr ',' '\n' | sed 's/^ *//' | grep -v '^$' | paste -sd ', ' -)
    [[ -z "$acodec" || "$acodec" == "(null)" ]] && acodec="—"
    asr=$(mdls -raw -name kMDItemAudioSampleRate "$f" 2>/dev/null)
    asamplerate="—"; [[ "$asr" != "(null)" && -n "$asr" ]] && asamplerate="${asr%.*} Hz"
    abitrate="—"
    abits=$(mdls -raw -name kMDItemTotalBitRate "$f" 2>/dev/null)
    [[ "$abits" != "(null)" && -n "$abits" ]] && abitrate=$(awk -v b="$abits" 'BEGIN { printf "%d kb/s", b/1000 }')
    seconds=$(mdls -raw -name kMDItemDurationSeconds "$f" 2>/dev/null)
    duration="—"
    if [[ -n "$seconds" && "$seconds" != "(null)" ]]; then
        duration=$(awk -v t="$seconds" 'BEGIN {
            s = int(t + 0.5); h = int(s/3600); m = int((s%3600)/60); sec = s%60
            if (h > 0) printf "%dh %02dm %02ds", h, m, sec
            else if (m > 0) printf "%dm %02ds", m, sec
            else printf "%ds", sec }')
    fi
    t_title=$(mdls -raw -name kMDItemTitle "$f" 2>/dev/null)
    t_artist=$(mdls -raw -name kMDItemAuthors "$f" 2>/dev/null | tr -d '()"' | tr ',' ' ' | xargs 2>/dev/null)
    t_album=$(mdls -raw -name kMDItemAlbum "$f" 2>/dev/null)
    nz() { [[ "$1" == "(null)" || -z "$1" ]] && echo "" || echo "$1"; }
    tags_section=""
	  [[ -n "$(nz "$t_title")" ]] && tags_section="🎵  Title:	$t_title"
    [[ -n "$(nz "$t_artist")" ]] && tags_section="${tags_section:+$tags_section
}🎤	Artist:	$t_artist"
    [[ -n "$(nz "$t_album")" ]] && tags_section="${tags_section:+$tags_section
}💿	Album:	$t_album"
    [[ -z "$tags_section" ]] && tags_section="(install ffmpeg for full tags)"

    msg="🎧  $name

🔊	Codec:	$acodec
⚡	Bitrate:	$abitrate
📻	Sample rate:	$asamplerate
🎚	Bit depth:	— (install ffmpeg)

$SEP
TAGS

$tags_section

$SEP

⏱	Duration:	$duration
💾	File size:	$size
📦	Container:	$ext"
    print -r -- "$msg"
    exit 0
fi

if (( is_audio == 1 )); then
    # ========================================================
    # RAPPORT AUDIO
    # ========================================================
    acodec="—"; aformat="—"; abitrate="—"; asamplerate="—"
    abitdepth="—"; achannels="—"

    ainfo=$("$FFPROBE" -v error -select_streams a:0 \
        -show_entries stream=codec_name,codec_long_name,bit_rate,sample_rate,channels,channel_layout,bits_per_raw_sample,bits_per_sample \
        -of default=noprint_wrappers=1 "$f" 2>/dev/null)

    raw_acodec=$(get_val "$ainfo" codec_name)
    acodec=$(pretty_codec "$raw_acodec")
    raw_aformat=$(get_val "$ainfo" codec_long_name)
    [[ -n "$raw_aformat" && "$raw_aformat" != "unknown" ]] && aformat="$raw_aformat"

    # Débit : flux d'abord, sinon débit global du fichier
    abits=$(get_val "$ainfo" bit_rate)
    if [[ -z "$abits" || "$abits" == "N/A" ]]; then
        abits=$("$FFPROBE" -v error -show_entries format=bit_rate \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
    fi
    [[ -n "$abits" && "$abits" != "N/A" ]] && abitrate=$(awk -v b="$abits" 'BEGIN { printf "%d kb/s", b/1000 }')

    asr=$(get_val "$ainfo" sample_rate)
    [[ -n "$asr" && "$asr" != "N/A" ]] && asamplerate="$asr Hz ($(awk -v s="$asr" 'BEGIN { printf "%.1f", s/1000 }') kHz)"

    # Profondeur de bits (FLAC/WAV/ALAC) : bits_per_raw_sample sinon bits_per_sample
    bps=$(get_val "$ainfo" bits_per_raw_sample)
    [[ -z "$bps" || "$bps" == "N/A" || "$bps" == "0" ]] && bps=$(get_val "$ainfo" bits_per_sample)
    [[ -n "$bps" && "$bps" != "N/A" && "$bps" != "0" ]] && abitdepth="$bps bits"

    achannels=$(pretty_channels "$(get_val "$ainfo" channel_layout)" "$(get_val "$ainfo" channels)")

    # Durée
    seconds=$("$FFPROBE" -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
    if [[ -n "$seconds" && "$seconds" != "(null)" && "$seconds" != "N/A" ]]; then
        duration=$(awk -v t="$seconds" 'BEGIN {
            s = int(t + 0.5); h = int(s/3600); m = int((s%3600)/60); sec = s%60
            if (h > 0) printf "%dh %02dm %02ds", h, m, sec
            else if (m > 0) printf "%dm %02ds", m, sec
            else printf "%ds", sec
        }')
    fi

    # ---- Tags musicaux (format-level) ----
    fmt_tags=$("$FFPROBE" -v error -show_entries format_tags \
        -of default=noprint_wrappers=1 "$f" 2>/dev/null)
    get_tag() {
        echo "$fmt_tags" | grep -i "^TAG:$1=" | head -1 | cut -d= -f2-
    }
    t_title=$(get_tag title)
    t_artist=$(get_tag artist)
    [[ -z "$t_artist" ]] && t_artist=$(get_tag album_artist)
    t_album=$(get_tag album)
    t_date=$(get_tag date)
    [[ -z "$t_date" ]] && t_date=$(get_tag year)
    t_track=$(get_tag track)
    t_genre=$(get_tag genre)

    tags_section=""
    add_tag() {  # $1 = libellé, $2 = valeur
        [[ -n "$2" ]] && tags_section="${tags_section:+$tags_section
}$1:	$2"
    }
    add_tag "🎵  Title" "$t_title"
    add_tag "🎤  Artist" "$t_artist"
    add_tag "💿  Album" "$t_album"
    add_tag "📅  Year" "$t_date"
    add_tag "#️⃣  Track" "$t_track"
    add_tag "🏷  Genre" "$t_genre"
    [[ -z "$tags_section" ]] && tags_section="(no tags found)"

    # Pochette intégrée ? On lit sa résolution et on l'extrait dans /tmp.
    cover="No"
    cover_path=""
    pic_idx=$("$FFPROBE" -v error -select_streams v -show_entries stream=index:stream_disposition=attached_pic \
        -of csv=p=0 "$f" 2>/dev/null | grep ",1$" | head -1 | cut -d, -f1)
    if [[ -n "$pic_idx" ]]; then
        cw=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=width \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
        ch=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=height \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
        if [[ -n "$cw" && -n "$ch" ]]; then
            cover="Yes — $cw × $ch"
        else
            cover="Yes"
        fi
        # Extraction de la pochette dans un fichier temporaire unique au fichier
        FFMPEG="${FFPROBE%ffprobe}ffmpeg"
        if [[ -x "$FFMPEG" ]]; then
            hash=$(echo -n "$f" | md5 2>/dev/null || echo -n "$f" | md5sum | cut -d' ' -f1)
            cover_path="/tmp/carimediascan_cover_${hash}.jpg"
            "$FFMPEG" -y -v error -i "$f" -an -vcodec mjpeg -frames:v 1 "$cover_path" 2>/dev/null
            [[ -f "$cover_path" ]] || cover_path=""
        fi
    fi

    msg="🎧  $name

🔊	Codec:	$acodec
🎼	Format:	$aformat
⚡	Bitrate:	$abitrate
📻	Sample rate:	$asamplerate
🎚	Bit depth:	$abitdepth
🔈	Channels:	$achannels

$SEP
TAGS

$tags_section

$SEP

⏱	Duration:	$duration
💾	File size:	$size
🖼	Cover art:	$cover
📦	Container:	$ext"

    # Ligne marqueur (non affichée) lue par la fenêtre pour charger l'image
    [[ -n "$cover_path" ]] && msg="${msg}
@@COVER@@${cover_path}"

    print -r -- "$msg"
    exit 0
fi

if [[ -n "$FFPROBE" ]]; then
    # ============ VIDEO ============
    vinfo=$("$FFPROBE" -v error -select_streams v:0 \
        -show_entries stream=codec_name,width,height,r_frame_rate,bit_rate,pix_fmt,color_space,color_transfer:stream_tags=handler_name \
        -of default=noprint_wrappers=1 "$f" 2>/dev/null)

    w=$(get_val "$vinfo" width)
    h=$(get_val "$vinfo" height)
    raw_codec=$(get_val "$vinfo" codec_name)
    fraction=$(get_val "$vinfo" r_frame_rate)
    vbits=$(get_val "$vinfo" bit_rate)
    raw_pixfmt=$(get_val "$vinfo" pix_fmt)
    raw_space=$(get_val "$vinfo" color_space)
    raw_transfer=$(get_val "$vinfo" color_transfer)
    raw_handler=$(get_val "$vinfo" TAG:handler_name)

    [[ -n "$w" && -n "$h" ]] && resolution="$w × $h$(resolution_label $w)"
    vcodec=$(pretty_codec "$raw_codec")
    [[ -n "$raw_pixfmt" && "$raw_pixfmt" != "unknown" ]] && pixfmt="$raw_pixfmt"
    colorspace=$(pretty_colorspace "$raw_space" "$raw_transfer")
    [[ -n "$raw_handler" ]] && driver="$raw_handler"

    # Timecode de départ : tag du flux vidéo, sinon du conteneur (format),
    # sinon d'une piste "data" dédiée (fréquent sur les .mov de tournage)
    tc=$(get_val "$vinfo" TAG:timecode)
    if [[ -z "$tc" ]]; then
        tc=$("$FFPROBE" -v error -show_entries format_tags=timecode \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | head -1)
    fi
    if [[ -z "$tc" ]]; then
        tc=$("$FFPROBE" -v error -select_streams d -show_entries stream_tags=timecode \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | grep -v '^$' | head -1)
    fi
    [[ -n "$tc" && "$tc" != "N/A" ]] && timecode="$tc"

    # Dolby Vision : métadonnées DOVI au niveau du flux
    hdr_extra=""
    dovi=$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=side_data_list \
        -of default=noprint_wrappers=1 "$f" 2>/dev/null | grep -ci "dovi\|dv_profile")
    (( dovi > 0 )) && hdr_extra="Dolby Vision"

    # HDR10+ : métadonnées dynamiques SMPTE 2094-40 sur la première frame
    hdrplus=$("$FFPROBE" -v error -select_streams v:0 -read_intervals "%+#1" \
        -show_entries frame=side_data_list -of default=noprint_wrappers=1 "$f" 2>/dev/null | grep -c "SMPTE2094-40")
    (( hdrplus > 0 )) && hdr_extra="${hdr_extra:+$hdr_extra + }HDR10+"

    if [[ -n "$hdr_extra" ]]; then
        if [[ "$colorspace" == "—" ]]; then colorspace="$hdr_extra"
        else colorspace="$colorspace · $hdr_extra"
        fi
    fi

    if [[ -n "$fraction" && "$fraction" != "0/0" ]]; then
        fps=$(echo "$fraction" | awk -F/ '{
            v = ($2 > 0) ? $1/$2 : $1
            if (v == int(v)) printf "%d fps", v; else printf "%.3f fps", v
        }')
    fi

    if [[ -z "$vbits" || "$vbits" == "N/A" ]]; then
        vbits=$("$FFPROBE" -v error -show_entries format=bit_rate \
            -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
    fi
    if [[ -n "$vbits" && "$vbits" != "N/A" ]]; then
        vbitrate=$(awk -v b="$vbits" 'BEGIN { printf "%.1f Mb/s", b/1000000 }')
    fi

    # ============ AUDIO TRACKS ============
    acount=$("$FFPROBE" -v error -select_streams a -show_entries stream=index \
        -of csv=p=0 "$f" 2>/dev/null | grep -c .)

    if (( acount == 0 )); then
        audio_section="🔊  No audio track"
    else
        i=0
        while (( i < acount )); do
            ainfo=$("$FFPROBE" -v error -select_streams a:$i \
                -show_entries stream=codec_name,channels,channel_layout,sample_rate,bit_rate:stream_tags=language,title:stream_disposition=default,forced \
                -of default=noprint_wrappers=1 "$f" 2>/dev/null)

            line=$(pretty_codec "$(get_val "$ainfo" codec_name)")

            ch=$(pretty_channels "$(get_val "$ainfo" channel_layout)" "$(get_val "$ainfo" channels)")
            [[ -n "$ch" ]] && line="$line · $ch"

            asr=$(get_val "$ainfo" sample_rate)
            [[ -n "$asr" && "$asr" != "N/A" ]] && line="$line · $((asr / 1000)) kHz"

            abits=$(get_val "$ainfo" bit_rate)
            if [[ -n "$abits" && "$abits" != "N/A" ]]; then
                line="$line · $(awk -v b="$abits" 'BEGIN { printf "%d kb/s", b/1000 }')"
            fi

            lang=$(pretty_lang "$(get_val "$ainfo" TAG:language)")
            [[ -n "$lang" ]] && line="$line · $lang"

            atitle=$(get_val "$ainfo" TAG:title)
            [[ -n "$atitle" ]] && line="$line · \"$atitle\""

            flags=""
            [[ "$(get_val "$ainfo" DISPOSITION:default)" == "1" ]] && flags="default"
            [[ "$(get_val "$ainfo" DISPOSITION:forced)" == "1" ]] && flags="${flags:+$flags, }forced"
            [[ -n "$flags" ]] && line="$line  ($flags)"

            audio_section="${audio_section:+$audio_section
}🔊  #$((i + 1)) · $line"
            (( i++ ))
        done
    fi

    # ============ SUBTITLE TRACKS ============
    scount=$("$FFPROBE" -v error -select_streams s -show_entries stream=index \
        -of csv=p=0 "$f" 2>/dev/null | grep -c .)

    if (( scount == 0 )); then
        sub_section="💬  No subtitle track"
    else
        i=0
        while (( i < scount )); do
            sinfo=$("$FFPROBE" -v error -select_streams s:$i \
                -show_entries stream=codec_name:stream_tags=language,title:stream_disposition=default,forced,hearing_impaired \
                -of default=noprint_wrappers=1 "$f" 2>/dev/null)

            line=$(pretty_sub_codec "$(get_val "$sinfo" codec_name)")

            lang=$(pretty_lang "$(get_val "$sinfo" TAG:language)")
            [[ -n "$lang" ]] && line="$line · $lang"

            stitle=$(get_val "$sinfo" TAG:title)
            [[ -n "$stitle" ]] && line="$line · \"$stitle\""

            flags=""
            [[ "$(get_val "$sinfo" DISPOSITION:default)" == "1" ]] && flags="default"
            [[ "$(get_val "$sinfo" DISPOSITION:forced)" == "1" ]] && flags="${flags:+$flags, }forced"
            [[ "$(get_val "$sinfo" DISPOSITION:hearing_impaired)" == "1" ]] && flags="${flags:+$flags, }SDH"
            [[ -n "$flags" ]] && line="$line  ($flags)"

            sub_section="${sub_section:+$sub_section
}💬  #$((i + 1)) · $line"
            (( i++ ))
        done
    fi

    seconds=$("$FFPROBE" -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)

else
    # ============ Fallback: mdls ============
    w=$(mdls -raw -name kMDItemPixelWidth "$f" 2>/dev/null)
    h=$(mdls -raw -name kMDItemPixelHeight "$f" 2>/dev/null)
    [[ "$w" != "(null)" && -n "$w" ]] && resolution="$w × $h$(resolution_label $w)"

    codecs=$(mdls -raw -name kMDItemCodecs "$f" 2>/dev/null | tr -d '()"' | tr ',' '\n' | sed 's/^ *//' | grep -v '^$' | paste -sd ', ' -)
    [[ -n "$codecs" && "$codecs" != "(null)" ]] && vcodec="$codecs"

    bits=$(mdls -raw -name kMDItemTotalBitRate "$f" 2>/dev/null)
    [[ "$bits" != "(null)" && -n "$bits" ]] && vbitrate=$(awk -v b="$bits" 'BEGIN { printf "%.1f Mb/s", b/1000000 }')

    seconds=$(mdls -raw -name kMDItemDurationSeconds "$f" 2>/dev/null)
    fps="— (install ffmpeg for full details)"
    audio_section="🔊  Install ffmpeg for per-track details (brew install ffmpeg)"
    sub_section="💬  Install ffmpeg for subtitle details"
fi

if [[ -n "$seconds" && "$seconds" != "(null)" && "$seconds" != "N/A" ]]; then
    duration=$(awk -v t="$seconds" 'BEGIN {
        s = int(t + 0.5); h = int(s/3600); m = int((s%3600)/60); sec = s%60
        if (h > 0) printf "%dh %02dm %02ds", h, m, sec
        else if (m > 0) printf "%dm %02ds", m, sec
        else printf "%ds", sec
    }')
fi

msg="🎬  $name

$SEP
VIDEO TRACK

📐	Resolution:	$resolution
🎞	Frame rate:	$fps
🎥	Video codec:	$vcodec
🧩	Pixel format:	$pixfmt
🌈	Color space:	$colorspace
⚡	Video bitrate:	$vbitrate
⏱	Start timecode:	$timecode
🛠	Driver:	$driver

$SEP
AUDIO TRACKS

$audio_section

$SEP
SUBTITLES

$sub_section

$SEP

⏱	Duration:	$duration
💾	File size:	$size
📦	Container:	$ext"

print -r -- "$msg"
ANALYZER_EOF

# ============================================================
# 2. SÉLECTION : 1 vidéo → navigateur, 2+ vidéos → comparaison
# ============================================================
typeset -a videos
exts=" mp4 mov m4v mkv avi webm mts m2ts ts wmv flv mpg mpeg 3gp ogv vob mxf braw mp3 flac wav m4a aac ogg opus aiff aif wma alac ape wv "
for f in "$@"; do
    [[ -f "$f" ]] || continue
    e="${${f##*.}:l}"
    [[ "$exts" == *" $e "* ]] && videos+=("$f")
done
(( ${#videos} == 0 )) && exit 0

if (( ${#videos} >= 2 )); then
    set -- "${videos[1]}" "${videos[2]}"
else
    set -- "${videos[1]}"
fi

/usr/bin/osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('Cocoa');

function run(argv) {
    const ANALYZER = '/tmp/carimediascan_analyzer.sh';
    const APP_VERSION = '6.8';  // ← numéro de version affiché dans le titre
    const width = 740;          // largeur du contenu (mode navigateur)
    const cmpWidth = 560;       // largeur de chaque colonne (mode comparaison)
    const fontSize = 13;
    const pad = 24;
    const btnW = 120, btnH = 32, gap = 14;
    const minWidth = 740;       // ← largeur plancher de la fenêtre (redimensionnable)
    const defaultBodyH = 560;   // hauteur initiale de la zone de texte
    const labelTab = 30;        // ← position (px) de la colonne des libellés (après emoji)
    const valueTab = 178;       // ← position (px) de la colonne des valeurs
    const lineGap = 6;          // ← espace supplémentaire entre les lignes
    const videoExts = ['mp4','mov','m4v','mkv','avi','webm','mts','m2ts','ts',
                       'wmv','flv','mpg','mpeg','3gp','ogv','vob','mxf','braw',
                       'mp3','flac','wav','m4a','aac','ogg','opus','aiff','aif',
                       'wma','alac','ape','wv'];

    $.NSApplication.sharedApplication;
    $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
    $.NSApp.activateIgnoringOtherApps(true);

    // ---- Analyse d'un fichier (chemin complet) via le script /tmp ----
    function runAnalyzer(full) {
        const task = $.NSTask.alloc.init;
        task.setLaunchPath('/bin/zsh');
        task.setArguments($([ANALYZER, full]));
        const pipe = $.NSPipe.pipe;
        task.setStandardOutput(pipe);
        task.setStandardError($.NSPipe.pipe);
        task.launch;
        task.waitUntilExit;
        const data = pipe.fileHandleForReading.readDataToEndOfFile;
        const out = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding);
        return out.isNil() ? '(analysis failed)' : out.js;
    }

    // ---- Presse-papiers ----
    function copyToClipboard(text) {
        const pb = $.NSPasteboard.generalPasteboard;
        pb.clearContents;
        pb.setStringForType($(text), $('public.utf8-plain-text'));
    }

    // ---- Fabrique de zone de texte DÉFILANTE (NSTextView dans NSScrollView) ----
    // Le contenu défile quand la fenêtre est plus petite que le rapport.
    // ---- Style de paragraphe : colonne de valeurs alignée + interligne ----
    function makeParagraphStyle() {
        const para = $.NSMutableParagraphStyle.alloc.init;
        try {
            const tab1 = $.NSTextTab.alloc.initWithTypeLocation(0, labelTab); // colonne libellés
            const tab2 = $.NSTextTab.alloc.initWithTypeLocation(0, valueTab); // colonne valeurs
            para.setTabStops($([tab1, tab2]));
        } catch (e) {}
        para.setDefaultTabInterval(20);   // filet de sécurité si un libellé dépasse
        para.setLineSpacing(lineGap);     // aère les lignes
        return para;
    }
    const reportStyle = makeParagraphStyle();

    // Applique le texte du rapport en réappliquant le style à tout le contenu
    function setReport(tv, text) {
        tv.setString(text);
        try {
            const len = tv.string.length;
            tv.textStorage.addAttributeValueRange(
                $.NSParagraphStyleAttributeName, reportStyle, $.NSMakeRange(0, len));
        } catch (e) {}
    }

    function makeScrollText(x, y, w, h) {
        const scroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(x, y, w, h));
        scroll.setHasVerticalScroller(true);
        scroll.setHasHorizontalScroller(false);
        scroll.setBorderType(0);           // pas de bordure
        scroll.setDrawsBackground(false);

        const tv = $.NSTextView.alloc.initWithFrame($.NSMakeRect(0, 0, w, h));
        tv.setEditable(false);
        tv.setSelectable(true);
        tv.setDrawsBackground(false);
        tv.setFont($.NSFont.systemFontOfSize(fontSize));
        tv.setTextContainerInset($.NSMakeSize(0, 0));
        tv.setVerticallyResizable(true);
        tv.setHorizontallyResizable(false);
        tv.textContainer.setWidthTracksTextView(true);
        try { tv.setDefaultParagraphStyle(reportStyle); } catch (e) {}
        // Largeur suit le scrollview, hauteur libre (=> défilement vertical)
        tv.setAutoresizingMask(2);         // NSViewWidthSizable

        scroll.setDocumentView(tv);
        return { scroll: scroll, tv: tv };
    }

    // ---- Handlers globaux, réassignés par chaque mode ----
    let goPrev = function() {};
    let goNext = function() {};
    let closeWin = function() { $.NSApp.stopModal; };
    let doCopy = function() {};
    let doTick = function() {};
    let layoutCompare = function() {};
    let layoutNav = function() {};

    // Délégué de fenêtre : relaie le redimensionnement vers le bon layout
    ObjC.registerSubclass({
        name: 'CaribWinDelegate',
        superclass: 'NSObject',
        protocols: ['NSWindowDelegate'],
        methods: {
            'windowDidResize:': {
                types: ['void', ['id']],
                implementation: function(notif) { layoutCompare(); layoutNav(); }
            }
        }
    });
    const winDelegate = $.CaribWinDelegate.alloc.init;

    ObjC.registerSubclass({
        name: 'CaribKeyView',
        superclass: 'NSView',
        methods: {
            'keyDown:': {
                types: ['void', ['id']],
                implementation: function(ev) {
                    const c = ev.keyCode;
                    if (c === 123 || c === 126) goPrev();        // ← ou ↑
                    else if (c === 124 || c === 125) goNext();   // → ou ↓
                    else if (c === 53) closeWin();               // Échap
                    else if (c === 36 || c === 76) closeWin();   // Entrée / Entrée pavé num.
                }
            },
            'mouseDown:': {
                types: ['void', ['id']],
                implementation: function(ev) {
                    this.window.makeFirstResponder(this);
                }
            },
            'acceptsFirstResponder': {
                types: ['BOOL', []],
                implementation: function() { return true; }
            }
        }
    });

    ObjC.registerSubclass({
        name: 'CaribActions',
        superclass: 'NSObject',
        methods: {
            'tick:': {
                types: ['void', ['id']],
                implementation: function(t) { doTick(); }
            },
            'copyReport:': {
                types: ['void', ['id']],
                implementation: function(s) { doCopy(); }
            }
        }
    });
    const actions = $.CaribActions.alloc.init;

    // ---- Boutons Copy + OK en bas à droite (positionnables) ----
    let _btnCopy = null, _btnOK = null;
    function positionButtons(cw) {
        if (!_btnCopy) return;
        _btnCopy.setFrame($.NSMakeRect(cw - pad - btnW * 2 - 12, pad - 6, btnW, btnH));
        _btnOK.setFrame($.NSMakeRect(cw - pad - btnW, pad - 6, btnW, btnH));
    }
    function addButtons(content, totalW) {
        const btnCopy = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, btnW, btnH));
        btnCopy.setTitle('Copy');
        btnCopy.setBezelStyle(1);
        btnCopy.setTarget(actions);
        btnCopy.setAction('copyReport:');
        content.addSubview(btnCopy);

        const btnOK = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, btnW, btnH));
        btnOK.setTitle('OK');
        btnOK.setBezelStyle(1);
        btnOK.setKeyEquivalent('\r');
        btnOK.setTarget($.NSApp);
        btnOK.setAction('stopModal');
        content.addSubview(btnOK);

        _btnCopy = btnCopy;
        _btnOK = btnOK;
        positionButtons(totalW);
        return btnCopy;
    }

    // ============================================================
    // MODE COMPARAISON (2 fichiers sélectionnés)
    // ============================================================
    if (argv.length >= 2) {
        const msgA = runAnalyzer(argv[0]);
        const msgB = runAnalyzer(argv[1]);

        const totalW = pad + cmpWidth + pad + cmpWidth + pad;
        const totalH = pad + btnH + gap + defaultBodyH + pad;

        const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
            $.NSMakeRect(0, 0, totalW, totalH),
            1 | 8,   // barre de titre + redimensionnable
            2, false);
        win.setReleasedWhenClosed(false);
        win.setMinSize($.NSMakeSize(minWidth, 360));

        const content = $.CaribKeyView.alloc.initWithFrame($.NSMakeRect(0, 0, totalW, totalH));
        win.setContentView(content);

        const A = makeScrollText(0, 0, 100, 100);
        const B = makeScrollText(0, 0, 100, 100);
        setReport(A.tv, msgA);
        setReport(B.tv, msgB);
        content.addSubview(A.scroll);
        content.addSubview(B.scroll);

        const vline = $.NSBox.alloc.initWithFrame($.NSMakeRect(0, 0, 1, 10));
        vline.setBoxType(2);
        content.addSubview(vline);

        const btnCopy = addButtons(content, totalW);
        doCopy = function() {
            copyToClipboard(msgA +
                '\n\n════════════════════════════════════════\n\n' + msgB);
            btnCopy.setTitle('Copied ✓');
        };

        // Repositionne tout selon la taille courante de la fenêtre
        layoutCompare = function() {
            const cw = content.frame.size.width;
            const ch = content.frame.size.height;
            const barY = pad + btnH + gap;
            const colH = ch - barY - pad;
            const colW = (cw - pad * 3) / 2;
            A.scroll.setFrame($.NSMakeRect(pad, barY, colW, colH));
            B.scroll.setFrame($.NSMakeRect(pad * 2 + colW, barY, colW, colH));
            vline.setFrame($.NSMakeRect(cw / 2 - 1, barY, 1, colH));
            positionButtons(cw);
        };

        win.setDelegate(winDelegate);
        win.setTitle('CariMediaScan ----------  v' + APP_VERSION +
                     ' by Caribou Labs 🦌 ·  Compare');
        layoutCompare();
        win.center;
        win.makeKeyAndOrderFront($());
        win.makeFirstResponder(content);
        $.NSApp.runModalForWindow(win);
        win.orderOut($());
        return;
    }

    // ============================================================
    // MODE NAVIGATEUR (1 fichier sélectionné)
    // ============================================================
    const startPath = argv[0];

    // ---- Liste des vidéos d'un dossier, triées (réutilisable) ----
    const fm = $.NSFileManager.defaultManager;
    function listVideos(dir) {
        const raw = ObjC.deepUnwrap(fm.contentsOfDirectoryAtPathError($(dir), null)) || [];
        return raw.filter(function(n) {
            const dot = n.lastIndexOf('.');
            return dot > 0 && videoExts.indexOf(n.substring(dot + 1).toLowerCase()) >= 0;
        }).sort(function(a, b) {
            return a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' });
        });
    }

    const slash = startPath.lastIndexOf('/');
    let dirPath = startPath.substring(0, slash);
    const startName = startPath.substring(slash + 1);
    let files = listVideos(dirPath);

    if (files.length === 0) return;
    let index = files.indexOf(startName);
    if (index < 0) index = 0;

    // ---- Analyse à la volée + cache ----
    const cache = {};
    let currentMsg = '';
    function analyze(name) {
        const full = dirPath + '/' + name;
        if (cache[full]) return cache[full];
        const msg = runAnalyzer(full);
        cache[full] = msg;
        return msg;
    }

    // ---- Synchronisation avec la sélection du Finder ----
    const finder = Application('Finder');
    let lastSel = startPath;

    function pollFinder() {
        try {
            const sel = finder.selection();
            if (!sel || sel.length === 0) return;
            let u = sel[0].url();
            if (!u) return;
            let p = decodeURIComponent(String(u).replace(/^file:\/\//, '')).replace(/\/+$/, '');
            if (p === lastSel) return;
            lastSel = p;

            const s = p.lastIndexOf('/');
            if (s <= 0) return;
            const dir = p.substring(0, s);
            const nm = p.substring(s + 1);
            const dot = nm.lastIndexOf('.');
            if (dot <= 0 || videoExts.indexOf(nm.substring(dot + 1).toLowerCase()) < 0) return;

            let dirChanged = false;
            if (dir !== dirPath) {
                const newFiles = listVideos(dir);
                if (newFiles.length === 0) return;
                dirPath = dir;
                files = newFiles;
                dirChanged = true;
            }
            const idx = files.indexOf(nm);
            if (idx >= 0 && (dirChanged || idx !== index)) show(idx);
        } catch (e) {
            // Finder occupé ou permission refusée : on ignore ce cycle
        }
    }
    doTick = pollFinder;

    // ---- Construction de la fenêtre ----
    const totalW = width + pad * 2;
    const totalH = pad + btnH + gap + defaultBodyH + pad;

    const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
        $.NSMakeRect(0, 0, totalW, totalH),
        1 | 8,   // barre de titre + redimensionnable
        2, false
    );
    win.setReleasedWhenClosed(false);
    win.setMinSize($.NSMakeSize(minWidth, 360));

    const content = $.CaribKeyView.alloc.initWithFrame($.NSMakeRect(0, 0, totalW, totalH));
    win.setContentView(content);

    // Zone de texte défilante (le contenu défile, la fenêtre garde sa taille)
    const ST = makeScrollText(0, 0, 100, 100);
    content.addSubview(ST.scroll);

    // Vue image pour la pochette audio (masquée tant qu'il n'y en a pas)
    const coverMax = 220;       // côté max de la pochette affichée (px)
    let coverShown = false;
    const coverView = $.NSImageView.alloc.initWithFrame($.NSMakeRect(0, 0, 10, 10));
    coverView.setImageScaling($.NSImageScaleProportionallyUpOrDown);
    coverView.setHidden(true);
    content.addSubview(coverView);

    const btnCopy = addButtons(content, totalW);
    doCopy = function() {
        copyToClipboard(currentMsg);
        btnCopy.setTitle('Copied ✓');
    };

    // Petit rappel des raccourcis en bas à gauche
    const hint = $.NSTextField.alloc.initWithFrame($.NSMakeRect(pad, pad, 430, 18));
    hint.setStringValue('Click on a file or use ↑ or ↓ to navigate in your folder.');
    hint.setFont($.NSFont.systemFontOfSize(11));
    hint.setTextColor($.NSColor.secondaryLabelColor);
    hint.setBezeled(false);
    hint.setDrawsBackground(false);
    hint.setEditable(false);
    hint.setSelectable(false);
    content.addSubview(hint);

    // Repositionne la zone de texte, la pochette et les boutons selon la taille
    layoutNav = function() {
        const cw = content.frame.size.width;
        const ch = content.frame.size.height;
        const barY = pad + btnH + gap;
        let topReserve = 0;
        if (coverShown) {
            const img = coverView.image;
            const sz = img.size;
            const scale = Math.min(coverMax / sz.width, coverMax / sz.height, 1);
            const iw = Math.round(sz.width * scale);
            const ih = Math.round(sz.height * scale);
            coverView.setFrame($.NSMakeRect((cw - iw) / 2, ch - pad - ih, iw, ih));
            topReserve = ih + 12;
        }
        ST.scroll.setFrame($.NSMakeRect(pad, barY, cw - pad * 2, ch - barY - pad - topReserve));
        hint.setFrame($.NSMakeRect(pad, pad, Math.min(430, cw - pad * 2 - btnW * 2 - 24), 18));
        positionButtons(cw);
    };
    win.setDelegate(winDelegate);

    // ---- Affichage d'un fichier (le contenu défile, fenêtre figée) ----
    function show(i) {
        index = ((i % files.length) + files.length) % files.length;  // boucle
        let raw = analyze(files[index]);

        // Extraire l'éventuel marqueur de pochette @@COVER@@/chemin
        coverShown = false;
        coverView.setHidden(true);
        const mIdx = raw.indexOf('\n@@COVER@@');
        if (mIdx >= 0) {
            const coverPath = raw.substring(mIdx + 10).split('\n')[0].trim();
            raw = raw.substring(0, mIdx);
            const img = $.NSImage.alloc.initWithContentsOfFile(coverPath);
            if (!img.isNil() && img.size.width > 0) {
                coverView.setImage(img);
                coverView.setHidden(false);
                coverShown = true;
            }
        }

        currentMsg = raw;
        setReport(ST.tv, currentMsg);
        ST.tv.scrollRangeToVisible($.NSMakeRange(0, 0));  // revient en haut
        btnCopy.setTitle('Copy');
        layoutNav();
        win.setTitle('CariMediaScan ----------  v' + APP_VERSION +
                     ' by Caribou Labs 🦌 ·  ' + (index + 1) + '/' + files.length);
    }

    goPrev = function() { show(index - 1); };
    goNext = function() { show(index + 1); };
    closeWin = function() { $.NSApp.stopModal; };

    layoutNav();
    show(index);
    win.center;
    win.makeKeyAndOrderFront($());
    win.makeFirstResponder(content);

    // Timer de surveillance du Finder, actif pendant la session modale
    const timer = $.NSTimer.timerWithTimeIntervalTargetSelectorUserInfoRepeats(
        0.5, actions, 'tick:', $(), true
    );
    $.NSRunLoop.currentRunLoop.addTimerForMode(timer, $('NSModalPanelRunLoopMode'));

    $.NSApp.runModalForWindow(win);
    timer.invalidate;
    win.orderOut($());
}
JXA
