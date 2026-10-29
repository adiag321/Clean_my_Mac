#!/bin/bash
# lib/status/status.sh — Live system health dashboard: CPU, RAM, disk, network, processes.
# Source this file; do not execute directly.

# Gather all metrics into globals for this sample. Shared by text and JSON renderers.
_status_collect() {
    cpu_usage=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {
        user=$3; sys=$5;
        gsub(/%,?/,"",user); gsub(/%,?/,"",sys);
        printf "%.1f", user+sys
    }')
    idle=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {print $7}' | tr -d '%')

    local vm
    vm=$(vm_stat 2>/dev/null)
    local pages_free pages_active pages_wired pages_compressed
    pages_free=$(echo "$vm" | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
    pages_active=$(echo "$vm" | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
    pages_wired=$(echo "$vm" | awk '/Pages wired/ {gsub(/\./,"",$4); print $4}')
    pages_compressed=$(echo "$vm" | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')

    local page_size=4096
    used_mb=$(( (${pages_active:-0} * page_size) / 1048576 ))
    wired_mb=$(( (${pages_wired:-0} * page_size) / 1048576 ))
    compressed_mb=$(( (${pages_compressed:-0} * page_size) / 1048576 ))
    free_mb=$(( (${pages_free:-0} * page_size) / 1048576 ))
    local phys_ram_b
    phys_ram_b=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    total_mb=$(( phys_ram_b / 1048576 ))
    mem_pct_num=0
    [[ "${total_mb:-0}" -gt 0 ]] && mem_pct_num=$(( used_mb * 100 / total_mb ))

    disk_pct_num=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    disk_line=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s / %s (%s used, %s free)", $3, $2, $5, $4}')

    # Battery: percentage + charging/AC state, when present (desktops report none)
    local batt_raw
    batt_raw=$(pmset -g batt 2>/dev/null)
    battery_pct=$(echo "$batt_raw" | awk -F'[\t;]' '/InternalBattery/ {gsub(/[^0-9]/,"",$2); print $2}')
    battery_state="none"
    echo "$batt_raw" | grep -q "InternalBattery" && {
        if echo "$batt_raw" | grep -q "AC attached"; then battery_state="AC"; else battery_state="Battery"; fi
        echo "$batt_raw" | grep -q "charging;" && battery_state="Charging"
    }

    # Thermal pressure: macOS only exposes coarse warning levels without root/third-party tools
    thermal_level=$(pmset -g therm 2>/dev/null | awk -F'= ' '/CPU_Scheduler_Limit/ {print $2}')
    [[ -z "$thermal_level" ]] && thermal_level="normal"

    # Zombie processes, with parent command when resolvable
    zombie_count=0
    zombie_list=""
    while IFS= read -r zpid; do
        [[ -z "$zpid" ]] && continue
        zombie_count=$(( zombie_count + 1 ))
        local ppid pname
        ppid=$(ps -o ppid= -p "$zpid" 2>/dev/null | tr -d ' ')
        pname=$(ps -o comm= -p "$ppid" 2>/dev/null | xargs -I{} basename {} 2>/dev/null)
        zombie_list+="${zombie_list:+, }PID ${zpid} (parent: ${pname:-?})"
    done < <(ps aux 2>/dev/null | awk '$8 ~ /Z/ {print $2}')

    top_procs=$(ps aux 2>/dev/null | sort -rk3 | head -6 | awk '
        NR==1 { next }
        { name=$11; gsub(/.*\//,"",name); printf "  %-30s  CPU: %5s%%  MEM: %5s%%  PID: %s\n", name, $3, $4, $2 }')

    net_ifaces=$(ifconfig 2>/dev/null | awk '/^[a-z]/ {iface=$1} /inet / && iface !~ /lo/ {print "  " iface " " $2}')

    health_score=$(( 100 - ( (${cpu_usage%.*} + mem_pct_num + disk_pct_num) / 3 ) ))
    [[ $health_score -lt 0 ]] && health_score=0
}

_status_render_text() {
    echo -e "${BOLD}MacCleanUp — Live Status${NC}  ${GRAY}$(date '+%H:%M:%S') · Press Ctrl+C to exit${NC}"
    echo ""

    echo -e "${BOLD}CPU${NC}"
    _bar "${cpu_usage:-0}" 100 40
    echo -e "  Usage: ${GREEN}${cpu_usage:-?}%${NC}  Idle: ${GRAY}${idle:-?}%${NC}"
    echo ""

    echo -e "${BOLD}Memory${NC}"
    _bar "$used_mb" "$total_mb" 40
    echo -e "  Used: ${GREEN}${used_mb}MB${NC}  Wired: ${GRAY}${wired_mb}MB${NC}  Compressed: ${GRAY}${compressed_mb}MB${NC}  Free: ${GRAY}${free_mb}MB${NC}  Total: ${GRAY}${total_mb}MB${NC}"
    echo ""

    echo -e "${BOLD}Disk${NC}"
    _bar "${disk_pct_num:-0}" 100 40
    echo -e "  Used: ${disk_line}"
    echo ""

    echo -e "${BOLD}Battery${NC}"
    if [[ "$battery_state" == "none" ]]; then
        echo -e "  ${GRAY}No battery (desktop Mac)${NC}"
    else
        echo -e "  ${GREEN}${battery_pct:-?}%${NC}  ${GRAY}(${battery_state})${NC}  ${GRAY}Thermal: ${thermal_level}${NC}"
    fi
    echo ""

    echo -e "${BOLD}Zombie Processes${NC}"
    if [[ "$zombie_count" -eq 0 ]]; then
        echo -e "  ${GREEN}None${NC}"
    else
        echo -e "  ${YELLOW}${zombie_count} found${NC} ${GRAY}${zombie_list}${NC}"
    fi
    echo ""

    _health_score "${cpu_usage:-0}" "$mem_pct_num" "${disk_pct_num:-0}"
    echo ""

    echo -e "${BOLD}Top Processes (by CPU)${NC}"
    echo -e "$top_procs"
    echo ""

    echo -e "${BOLD}Network Interfaces${NC}"
    echo -e "$net_ifaces"
    echo ""
}

# Single-line JSON snapshot, mirroring mole's `status --json` shape
_status_render_json() {
    local zombie_json="[]"
    if [[ "$zombie_count" -gt 0 ]]; then
        zombie_json=$(echo "$zombie_list" | sed 's/, /","/g; s/^/["/; s/$/"]/')
    fi
    printf '{"timestamp":"%s","health_score":%d,"cpu":{"usage_pct":%s,"idle_pct":%s},"memory":{"used_mb":%d,"wired_mb":%d,"compressed_mb":%d,"free_mb":%d,"total_mb":%d},"disk":{"used_pct":%s},"battery":{"state":"%s","pct":%s},"thermal_level":"%s","zombie_count":%d,"zombie_parents":%s}\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${health_score:-0}" \
        "${cpu_usage:-0}" "${idle:-0}" \
        "${used_mb:-0}" "${wired_mb:-0}" "${compressed_mb:-0}" "${free_mb:-0}" "${total_mb:-0}" \
        "${disk_pct_num:-0}" \
        "$battery_state" "${battery_pct:-null}" \
        "$thermal_level" "${zombie_count:-0}" "$zombie_json"
}

run_status() {
    local refresh="${STATUS_REFRESH_SECONDS:-2}"
    local once="${STATUS_ONCE:-false}"
    local json="${STATUS_JSON:-false}"
    local watch="${STATUS_WATCH:-false}"

    local cpu_usage idle used_mb wired_mb compressed_mb free_mb total_mb mem_pct_num
    local disk_pct_num disk_line battery_pct battery_state thermal_level
    local zombie_count zombie_list top_procs net_ifaces health_score

    if [[ "$json" == "true" && "$watch" != "true" ]]; then
        _status_collect
        _status_render_json
        return 0
    fi

    if [[ "$watch" == "true" ]]; then
        trap 'exit 0' INT TERM
        while true; do
            _status_collect
            _status_render_json
            sleep "$refresh"
        done
        return 0
    fi

    # Hide cursor, trap Ctrl+C to restore
    tput civis 2>/dev/null || true
    trap 'tput cnorm 2>/dev/null; echo ""; exit 0' INT TERM

    while true; do
        [[ "$once" != "true" ]] && { tput clear 2>/dev/null || clear; }
        _status_collect
        _status_render_text
        [[ "$once" == "true" ]] && break
        sleep "$refresh"
    done

    tput cnorm 2>/dev/null || true
}

# Draw an ASCII progress bar, color-coded by load (green/yellow/red)
_bar() {
    local value="${1:-0}" max="${2:-100}" width="${3:-40}"
    # Strip decimals for bash integer arithmetic
    value="${value%.*}"
    value="${value:-0}"
    max="${max%.*}"
    max="${max:-100}"
    [[ "$max" -le 0 ]] && max=100

    local pct=$(( value * 100 / max ))
    local color="$GREEN"
    [[ $pct -ge 60 ]] && color="$YELLOW"
    [[ $pct -ge 85 ]] && color="$RED"

    local filled=$(( value * width / max ))
    [[ $filled -gt $width ]] && filled=$width
    [[ $filled -lt 0 ]] && filled=0
    local empty=$(( width - filled ))

    printf "  ["
    printf "${color}"
    local i
    for (( i=0; i<filled; i++ )); do printf "█"; done
    printf "${NC}${GRAY}"
    for (( i=0; i<empty; i++ )); do printf "░"; done
    printf "${NC}]\n"
}

# Composite 0-100 health score from CPU/mem/disk load, color-coded like mole
_health_score() {
    local cpu="${1:-0}" mem="${2:-0}" disk="${3:-0}"
    cpu="${cpu%.*}"; cpu="${cpu:-0}"

    local load=$(( (cpu + mem + disk) / 3 ))
    [[ $load -gt 100 ]] && load=100
    local score=$(( 100 - load ))

    local color="$GREEN" label="Good"
    if [[ $score -lt 50 ]]; then
        color="$RED"; label="Poor"
    elif [[ $score -lt 80 ]]; then
        color="$YELLOW"; label="Fair"
    fi

    echo -e "${BOLD}Health Score${NC}  ${color}${BOLD}${score}/100${NC} ${GRAY}(${label})${NC}"
}
