#!/usr/bin/env julia
#=
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 📁File      📄 getready.jl                                                       ┃
┃ 📙Brief     📝 Getting ready for your computer to build Blunux                   ┃
┃ 🧾Details   🔎 Blunux /tmp 32GB expansion, package installation, and build setup ┃
┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                          ┃
┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
┃ 📆LastDate  📍 2026-09-12 🔄Please support to keep update🔄                      ┃
┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

사용법 / Usage:
    sudo julia getready.jl           # /tmp 를 32GB 로 설정
    sudo julia getready.jl 48        # /tmp 를 48GB 로 설정
=#

const DEFAULT_TARGET_GB = 32

const PACKAGES = [
    "archiso", "julia", "rust", "git", "base-devel",
    "imagemagick", "xorriso", "squashfs-tools", "curl", "libarchive",
]

const FSTAB_PATH  = "/etc/fstab"
const FILE_URL    = "https://raw.githubusercontent.com/JaewooJoung/blnx/main/blnx2.tar.bz2"
const OUTPUT_FILE = "/tmp/blnx2.tar.bz2"
const TARGET_DIR  = "/tmp/blnx2sb"

"오류 메시지를 출력하고 종료 코드 1 로 스크립트를 끝낸다."
die(msg...) = (println(stderr, "❌ ", msg...); exit(1))

"현재 프로세스의 실제 UID. Julia Base 에는 getuid() 가 없으므로 libc 를 직접 호출한다."
current_uid() = Int(ccall(:getuid, Cuint, ()))

"명령이 존재하는지 확인한다."
has_command(cmd::AbstractString) = Sys.which(cmd) !== nothing

"/proc/meminfo 에서 (RAM + Swap) 총량을 GB 단위로 돌려준다."
function total_memory_gb()
    mem_kb  = 0
    swap_kb = 0
    for line in eachline("/proc/meminfo")
        fields = split(line)
        length(fields) >= 2 || continue
        value = tryparse(Int, fields[2])
        value === nothing && continue
        if fields[1] == "MemTotal:"
            mem_kb = value
        elseif fields[1] == "SwapTotal:"
            swap_kb = value
        end
    end
    mem_kb == 0 && die("/proc/meminfo 에서 MemTotal 값을 읽지 못했습니다.")
    return (mem_kb + swap_kb) / (1024 * 1024)
end

"/tmp 가 이미 tmpfs 로 마운트되어 있는지 확인한다."
function tmp_is_tmpfs()
    for line in eachline("/proc/mounts")
        fields = split(line)
        length(fields) >= 3 || continue
        if fields[2] == "/tmp" && fields[3] == "tmpfs"
            return true
        end
    end
    return false
end

"명령을 실행하고, 실패하면 설명과 함께 종료한다."
function run_or_die(cmd::Base.AbstractCmd, what::AbstractString)
    try
        run(cmd)
    catch err
        die(what, " 실패: ", sprint(showerror, err))
    end
    return nothing
end

"""
/etc/fstab 의 /tmp 항목을 새 항목으로 갱신한다.
기존 /tmp 항목은 첫 번째 것만 교체하고 나머지 중복 항목은 주석 처리한다.
"""
function update_fstab(entry::AbstractString)
    lines = isfile(FSTAB_PATH) ? readlines(FSTAB_PATH) : String[]

    # 원본 백업 (한 번만 만든다)
    backup = FSTAB_PATH * ".blunux.bak"
    if isfile(FSTAB_PATH) && !isfile(backup)
        cp(FSTAB_PATH, backup)
        println("🗄  기존 fstab 을 백업했습니다: ", backup)
    end

    new_lines = String[]
    replaced = false
    for line in lines
        trimmed = strip(line)
        fields = split(trimmed)
        is_tmp_entry = !isempty(trimmed) && !startswith(trimmed, "#") &&
                       length(fields) >= 2 && fields[2] == "/tmp"
        if is_tmp_entry
            if replaced
                push!(new_lines, "# (blunux) 중복 /tmp 항목 비활성화: " * line)
            else
                push!(new_lines, entry)
                replaced = true
            end
        else
            push!(new_lines, line)
        end
    end
    replaced || push!(new_lines, entry)

    # 원자적으로 쓰기: 임시 파일에 쓴 뒤 교체한다.
    tmp_path = FSTAB_PATH * ".blunux.new"
    open(tmp_path, "w") do io
        for line in new_lines
            println(io, line)
        end
    end
    mv(tmp_path, FSTAB_PATH; force = true)
    chmod(FSTAB_PATH, 0o644)
    return nothing
end

"내려받은 파일이 실제 bzip2 아카이브인지 매직 바이트로 확인한다."
function is_bzip2(path::AbstractString)
    filesize(path) > 4 || return false
    magic = open(path, "r") do io
        read(io, 3)
    end
    return magic == UInt8['B', 'Z', 'h']
end

function main()
    # ── 0. 실행 환경 확인 ────────────────────────────────────────────────
    Sys.islinux() || die("이 스크립트는 Linux 전용입니다. (현재: ", Sys.KERNEL, ")")

    target_gb = DEFAULT_TARGET_GB
    if !isempty(ARGS)
        parsed = tryparse(Int, ARGS[1])
        (parsed === nothing || parsed <= 0) && die("용량 인자가 잘못되었습니다: ", ARGS[1])
        target_gb = parsed
    end

    # ── 1. 루트 권한(sudo) 확인 ─────────────────────────────────────────
    if current_uid() != 0
        println("⚠️  루트 권한이 필요합니다. 'sudo julia getready.jl' 로 실행해주세요.")
        exit(1)
    end

    for cmd in ("mount", "pacman", "curl", "bsdtar")
        has_command(cmd) || die("필수 명령을 찾을 수 없습니다: ", cmd)
    end

    # ── 2. 시스템 전체 메모리(RAM + Swap) 계산 ──────────────────────────
    total_gb = total_memory_gb()
    println("📊 시스템 전체 메모리 (RAM + Swap): ", round(total_gb, digits = 2), " GB")
    println("🎯 요청된 /tmp 용량: ", target_gb, " GB (필요한 전체 메모리: ", target_gb * 2, " GB 이상)")

    # ── 3. 용량 조건 체크 ───────────────────────────────────────────────
    if total_gb < target_gb * 2
        println(stderr, "❌ 오류: 메모리 용량이 부족합니다.")
        println(stderr, "   /tmp 를 $(target_gb)GB 로 설정하려면 RAM + Swap 이 최소 $(target_gb * 2)GB 이상이어야 합니다.")
        exit(1)
    end

    target_size = "$(target_gb)G"
    fstab_entry = "tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=$(target_size) 0 0"

    # ── 4. 현재 실행 중인 시스템의 /tmp 즉시 적용 ───────────────────────
    println("\n🚀 [1단계] /tmp 용량을 $(target_size) 로 변경합니다...")
    if tmp_is_tmpfs()
        run_or_die(`mount -o remount,size=$(target_size),mode=1777,noatime /tmp`, "/tmp 재마운트")
        println("✅ /tmp 마운트 용량이 $(target_size) 로 즉시 변경되었습니다.")
    else
        println("ℹ️  /tmp 가 tmpfs 가 아닙니다. tmpfs 를 새로 마운트합니다.")
        println("   (기존 /tmp 안의 파일은 지워지지 않고, 마운트가 해제될 때까지 가려집니다.)")
        run_or_die(`mount -t tmpfs -o size=$(target_size),mode=1777,noatime tmpfs /tmp`, "/tmp tmpfs 마운트")
        println("✅ /tmp 에 $(target_size) tmpfs 를 마운트했습니다.")
    end

    # ── 5. /etc/fstab 설정 (부팅 시 영구 적용) ──────────────────────────
    update_fstab(fstab_entry)
    println("✅ /etc/fstab 갱신 완료 (재부팅 후에도 유지됨)")

    # ── 6. [2단계] pacman 패키지 설치 ───────────────────────────────────
    println("\n📦 [2단계] 필요한 패키지 설치를 시작합니다...")
    # 주의: -Sy 뒤에 설치하면 부분 업그레이드(partial upgrade) 위험이 있으므로 쓰지 않는다.
    #       DB 가 오래됐다면 먼저 `pacman -Syu` 를 직접 실행하세요.
    run_or_die(`pacman -S --needed --noconfirm $PACKAGES`, "패키지 설치")
    println("✅ 패키지 설치가 완료되었습니다.")

    # ── 7. [3단계] GitHub 에서 blnx2.tar.bz2 다운로드 ───────────────────
    cd("/tmp")
    println("\n📥 [3단계] $(FILE_URL) 에서 파일을 다운로드합니다...")
    rm(OUTPUT_FILE; force = true)
    # -f: HTTP 오류를 실패로 처리(404 페이지를 저장하지 않음), --retry: 일시적 오류 재시도
    run_or_die(`curl -fL --retry 3 --retry-delay 2 -o $OUTPUT_FILE $FILE_URL`, "파일 다운로드")

    isfile(OUTPUT_FILE) && filesize(OUTPUT_FILE) > 0 ||
        die("다운로드된 파일이 비어있거나 존재하지 않습니다.")
    is_bzip2(OUTPUT_FILE) ||
        die("다운로드된 파일이 bzip2 아카이브가 아닙니다. URL 이나 네트워크를 확인해주세요.")
    println("✅ 다운로드 완료: $(OUTPUT_FILE) ($(filesize(OUTPUT_FILE)) bytes)")

    # ── 8. [4단계] 기존 디렉터리 삭제 및 압축 해제 ──────────────────────
    println("\n📂 [4단계] 기존 디렉터리 정리 및 압축 해제를 진행합니다...")
    if isdir(TARGET_DIR)
        rm(TARGET_DIR; recursive = true, force = true)
        println("✅ 기존 $(TARGET_DIR) 디렉터리를 삭제(정리)했습니다.")
    end
    run_or_die(`bsdtar -xjf $OUTPUT_FILE -C /tmp`, "압축 해제")
    println("✅ 압축 해제 완료.")

    # ── 9. [5단계] 결과 확인 ────────────────────────────────────────────
    println("\n📂 [5단계] $(TARGET_DIR) 디렉터리를 확인합니다...")
    isdir(TARGET_DIR) || die("오류: $(TARGET_DIR) 디렉터리가 존재하지 않습니다.")

    println("🎉 준비가 모두 끝났습니다!")
    println("   이어서 빌드하려면 셸에서 다음을 실행하세요:")
    println("       cd $(TARGET_DIR)")
    return 0
end

# 스크립트로 직접 실행될 때만 main() 을 호출한다 (include 시에는 실행되지 않음).
if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
