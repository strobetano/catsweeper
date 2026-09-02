# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
shopt -s expand_aliases
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  function rg {
  local _cc_bin="${CLAUDE_CODE_EXECPATH:-}"
  [[ -x $_cc_bin ]] || _cc_bin=/c/Users/rober/.local/bin/claude.exe
  if [[ ! -x $_cc_bin ]]; then command rg ${1+"$@"}; return; fi
  if [[ -n ${ZSH_VERSION:-} ]]; then
    ARGV0=rg "$_cc_bin" ${1+"$@"}
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=rg "$_cc_bin" ${1+"$@"}
  else
    (exec -a rg "$_cc_bin" ${1+"$@"})
  fi
}
fi
# Shadow pkill to refuse patterns matching the CLI process
unalias pkill 2>/dev/null || true
function pkill {
  if [ -n "${CLAUDE_PID:-}" ] && [ -r "/proc/${CLAUDE_PID}/comm" ]; then
    local _cc_skip="" _cc_a
    local -a _cc_probe=()
    for _cc_a in ${1+"$@"}; do
      if [ -n "$_cc_skip" ]; then _cc_skip=""; continue; fi
      case "$_cc_a" in
        --signal) _cc_skip=1 ;;
        --signal=*|-e|--echo) ;;
        -[0-9]*) ;;
        -[PUGOF]?*) _cc_probe+=("$_cc_a") ;;
        -[ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ0-9]*) ;;
        *) _cc_probe+=("$_cc_a") ;;
      esac
    done
    if command pgrep ${_cc_probe[@]+"${_cc_probe[@]}"} 2>/dev/null | command grep -qx "${CLAUDE_PID}"; then
      printf 'pkill: refusing to run — this pattern matches the Claude CLI process (PID %s). Narrow the pattern, or target your own children with `pkill -P $$ ...`.\n' "${CLAUDE_PID}" >&2
      return 1
    fi
  fi
  command pkill ${1+"$@"}
}
export PATH='/c/Users/rober/bin:/mingw64/bin:/usr/local/bin:/usr/bin:/bin:/mingw64/bin:/usr/bin:/c/Users/rober/bin:/c/Users/rober/.volta/bin:/c/Users/rober/.asdf/shims:/c/Users/rober/.local/share/mise/shims:/c/Users/rober/.npm-global/bin:/c/Users/rober/.fnm/aliases/default/bin:/c/Users/rober/.local/share/pnpm:/c/Users/rober/AppData/Local/Programs/GitHub CLI:/c/Users/rober/AppData/Local/Programs/Git/cmd:/c/Users/rober/scoop/shims:/c/Program Files (x86)/nodejs:/c/Program Files (x86)/Git/cmd:/c/Program Files (x86)/GitHub CLI:/c/Program Files (x86)/GitLab/glab:/c/Program Files/GitLab/glab:/c/Program Files/Eclipse Adoptium/jdk-21.0.9.10-hotspot/bin:/c/Program Files/Eclipse Adoptium/jdk-17.0.18.8-hotspot/bin:/c/Program Files/Eclipse Adoptium/jdk-25.0.1.8-hotspot/bin:/c/Python312/Scripts:/c/Python312:/c/Program Files (x86)/Common Files/Oracle/Java/java8path:/c/Program Files (x86)/Common Files/Oracle/Java/javapath:/c/WINDOWS/system32:/c/WINDOWS:/c/WINDOWS/System32/Wbem:/c/WINDOWS/System32/WindowsPowerShell/v1.0:/c/WINDOWS/System32/OpenSSH:/c/Program Files (x86)/NVIDIA Corporation/PhysX/Common:/c/ProgramData/chocolatey/bin:/cmd:/c/Program Files/nodejs:/c/Program Files/dotnet:/c/Program Files/Docker/Docker/resources/bin:/c/Program Files/Java/jdk1.8.0_211/bin:/c/Android/android-sdk/tools:/c/Android/android-sdk/platform-tools:/c/Android/android-sdk/tools/bin:/c/Program Files/GitHub CLI:/c/Users/rober/AppData/Local/Programs/OpenAI/Codex/bin:/c/Users/rober/.cargo/bin:/c/Users/rober/AppData/Local/Microsoft/WindowsApps:/c/Users/rober/AppData/Local/GitHubDesktop/bin:/c/Users/rober/AppData/Roaming/npm:/c/Users/rober/AppData/Local/Programs/cursor/resources/app/bin:/c/Users/rober/.dotnet/tools:/c/Users/rober/.local/bin:/c/tools/flutter/bin:/c/Users/rober/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1-full_build/bin:/c/Users/rober/AppData/Local/Microsoft/WinGet/Packages/PHP.PHP.8.4_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/rober/AppData/Local/Microsoft/WinGet/Packages/JernejSimoncic.Wget_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/rober/AppData/Local/Microsoft/WinGet/Packages/astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/rober/AppData/Local/Microsoft/WinGet/Packages/oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe/poppler-25.07.0/Library/bin:/c/Users/rober/AppData/Local/Microsoft/WindowsApps:/c/Users/rober/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/rober/AppData/Local/Microsoft/WinGet/Links:/usr/bin/vendor_perl:/usr/bin/core_perl'
