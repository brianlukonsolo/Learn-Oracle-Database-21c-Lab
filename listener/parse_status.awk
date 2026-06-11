# =====================================================================
# parse_status.awk
# Turns `lsnrctl status <descriptor>` output into a JSON fragment:
#
#   {"reachable":true,"error":"","alias":"LISTENER","version":"...",
#    "uptime":"...","start_date":"...",
#    "services":[{"name":"XEPDB1","instances":[{"name":"XE","status":"READY"}]}]}
#
# Pass -v rc=<lsnrctl exit code>.
# =====================================================================
function jesc(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/,  "\\\"", s)
    return s
}
function trimlabel(line, label,   v) {
    v = line
    sub("^" label "[ \t]+", "", v)
    return v
}
BEGIN {
    alias = ""; version = ""; uptime = ""; start_date = ""
    err = ""; nsvc = 0
    reachable = (rc == 0) ? "true" : "false"
}
# Capture the first TNS-xxxxx error code, if any.
/TNS-[0-9]+/ {
    if (err == "") {
        if (match($0, /TNS-[0-9]+/)) err = substr($0, RSTART, RLENGTH)
    }
}
$1 == "Alias"   { alias = $2 }
/^Version/      { version = trimlabel($0, "Version") }
/^Start Date/   { start_date = trimlabel($0, "Start Date") }
/^Uptime/       { uptime = trimlabel($0, "Uptime") }
/^Service "/ {
    if (match($0, /"[^"]+"/)) {
        nsvc++
        svc[nsvc] = substr($0, RSTART + 1, RLENGTH - 2)
        ninst[nsvc] = 0
    }
}
/^[ \t]+Instance "/ {
    iname = ""; istat = ""
    if (match($0, /Instance "[^"]+"/)) {
        s = substr($0, RSTART, RLENGTH)
        match(s, /"[^"]+"/); iname = substr(s, RSTART + 1, RLENGTH - 2)
    }
    if (match($0, /status [A-Za-z]+/)) {
        s = substr($0, RSTART, RLENGTH); sub(/^status /, "", s); istat = s
    }
    if (nsvc > 0) {
        ninst[nsvc]++
        inm[nsvc, ninst[nsvc]] = iname
        ist[nsvc, ninst[nsvc]] = istat
    }
}
END {
    printf "{"
    printf "\"reachable\":%s,", reachable
    printf "\"error\":\"%s\",", jesc(err)
    printf "\"alias\":\"%s\",", jesc(alias)
    printf "\"version\":\"%s\",", jesc(version)
    printf "\"uptime\":\"%s\",", jesc(uptime)
    printf "\"start_date\":\"%s\",", jesc(start_date)
    printf "\"services\":["
    for (i = 1; i <= nsvc; i++) {
        if (i > 1) printf ","
        printf "{\"name\":\"%s\",\"instances\":[", jesc(svc[i])
        for (j = 1; j <= ninst[i]; j++) {
            if (j > 1) printf ","
            printf "{\"name\":\"%s\",\"status\":\"%s\"}", jesc(inm[i, j]), jesc(ist[i, j])
        }
        printf "]}"
    }
    printf "]}"
}
