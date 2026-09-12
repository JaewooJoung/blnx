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
=#

const TARGET_GB = 32

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
    if mem_kb == 0
        # 안내용 정보일 뿐이므로 읽기 실패로 중단하지는 않는다.
        println("⚠️  /proc/meminfo 에서 MemTotal 값을 읽지 못했습니다. 메모리 안내를 건너뜁니다.")
    end
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

"""
명령을 실행하고, 실패하면 종료 코드와 실제 명령줄을 보여준 뒤 끝낸다.
ignorestatus 를 쓰므로 Julia 의 "failed process" 예외 대신 읽을 수 있는 메시지가 나온다.
"""
function run_or_die(cmd::Base.AbstractCmd, what::AbstractString)
    proc = run(ignorestatus(cmd))
    if !success(proc)
        println(stderr, "❌ ", what, " 실패 (종료 코드: ", proc.exitcode, ")")
        println(stderr, "   실행한 명령: ", cmd)
        println(stderr, "   위에 출력된 명령 자체의 메시지가 실제 원인입니다.")
        exit(1)
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

"해당 패키지가 설치되어 있는지 확인한다."
function is_installed(pkg::AbstractString)
    return success(pipeline(`pacman -Qq $pkg`; stdout = devnull, stderr = devnull))
end

"""
rust / rustup 충돌을 정리한다.

Arch 의 `rust` 패키지와 `rustup` 은 둘 다 /usr/bin/rustc, /usr/bin/cargo 를 제공하므로
서로 conflict 한다. 하나라도 설치되어 있으면 `pacman -S rust` 가 충돌로 실패하기 때문에
설치 전에 먼저 제거한다. 제거 직후 [2단계]에서 `rust` 를 다시 설치한다.
"""
function cleanup_rust_conflicts()
    for pkg in ("rustup", "rust")
        is_installed(pkg) || continue
        println("🧹 충돌 방지: 기존 ", pkg, " 패키지를 제거합니다...")
        # 먼저 정상 제거를 시도한다.
        if success(run(ignorestatus(`pacman -R --noconfirm $pkg`)))
            println("✅ ", pkg, " 제거 완료.")
            continue
        end
        # 다른 패키지가 의존하고 있으면 -R 이 거부된다.
        # rust 는 바로 아래에서 다시 설치되므로, 의존성 검사를 건너뛰고 제거한다.
        println("ℹ️  의존성 때문에 일반 제거가 거부되었습니다. 의존성 검사를 건너뛰고 제거합니다...")
        if success(run(ignorestatus(`pacman -Rdd --noconfirm $pkg`)))
            println("✅ ", pkg, " 제거 완료 (-Rdd).")
        else
            println(stderr, "❌ ", pkg, " 제거에 실패했습니다.")
            println(stderr, "   수동으로 정리한 뒤 다시 실행해주세요:")
            println(stderr, "       sudo pacman -Rdd ", pkg)
            exit(1)
        end
    end
    # 참고: rustup 이 ~/.cargo, ~/.rustup 에 설치한 툴체인은 그대로 남습니다.
    #       PATH 에 ~/.cargo/bin 이 앞서 있으면 pacman 의 rustc 대신 그쪽이 잡힐 수 있습니다.
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
    println("🎯 요청된 /tmp 용량: ", TARGET_GB, " GB")
    println("📐 권장 여유 기준(참고용): RAM + Swap ", TARGET_GB * 2, " GB 이상")

    # ── 3. 용량 상태 안내 (참고용 — 진행을 막지 않는다) ─────────────────
    if total_gb < TARGET_GB * 2
        println("ℹ️  참고: 전체 메모리가 권장 기준($(TARGET_GB * 2)GB)보다 적습니다.")
        println("   tmpfs 는 실제로 쓴 만큼만 메모리를 차지하므로 $(TARGET_GB)GB 설정 자체는 문제 없지만,")
        println("   빌드 중 /tmp 를 가득 채우면 OOM 이나 심한 스와핑이 날 수 있습니다.")
    else
        println("✅ 전체 메모리가 권장 기준을 충족합니다.")
    end
    println("   (이 항목은 안내용이며 진행을 막지 않습니다.)")

    target_size = "$(TARGET_GB)G"
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

    # 2-a. DB 잠금 확인 — pacman 실패 원인 1위.
    lock_file = "/var/lib/pacman/db.lck"
    if isfile(lock_file)
        println(stderr, "❌ pacman 데이터베이스가 잠겨 있습니다: ", lock_file)
        println(stderr, "   다른 pacman / pamac / Discover 가 실행 중인지 먼저 확인하세요:")
        println(stderr, "       pgrep -a pacman")
        println(stderr, "   실행 중인 것이 없다면 잠금 파일을 지우고 다시 실행하세요:")
        println(stderr, "       sudo rm ", lock_file)
        exit(1)
    end

    # 2-b. rust / rustup 충돌 정리 (설치 전에 반드시 먼저)
    cleanup_rust_conflicts()

    # 2-c. -Syu 를 쓴다.
    #   -S  만  : 로컬 DB 가 오래되면 미러에 없는 옛 버전을 받으려다 404 로 실패한다.
    #   -Sy 만  : DB 만 갱신하고 설치하면 partial upgrade 가 되어 시스템이 깨질 수 있다.
    #   -Syu   : DB 갱신 + 전체 업그레이드 + 설치. Arch 에서 유일하게 안전한 방식.
    # 이미 root 로 실행 중이므로 sudo 는 붙이지 않는다.
    pacman_cmd = `pacman -Syu --noconfirm $PACKAGES`
    println("   실행: ", pacman_cmd)
    proc = run(ignorestatus(pacman_cmd))
    if !success(proc)
        println(stderr, "\n❌ 패키지 설치 실패 (pacman 종료 코드: ", proc.exitcode, ")")
        println(stderr, "   위에 출력된 pacman 메시지가 실제 원인입니다. 자주 나오는 경우:")
        println(stderr, "   • signature is unknown trust / PGP 오류")
        println(stderr, "       → sudo pacman -Sy archlinux-keyring  후 다시 실행")
        println(stderr, "   • 404 / failed retrieving file")
        println(stderr, "       → 미러 목록이 낡음. sudo reflector --latest 20 --save /etc/pacman.d/mirrorlist")
        println(stderr, "   • could not resolve host / 네트워크 오류")
        println(stderr, "       → 연결 확인: ping -c1 archlinux.org")
        println(stderr, "   • target not found")
        println(stderr, "       → Arch 계열이 아니거나 extra 저장소가 꺼져 있음. /etc/pacman.conf 확인")
        println(stderr, "   • exists in filesystem / conflicting files")
        println(stderr, "       → 충돌 파일을 확인한 뒤 수동 처리 (--overwrite 는 신중히)")
        println(stderr, "   • rust 관련 conflict 가 또 난다면")
        println(stderr, "       → sudo pacman -Qq | grep -i rust  로 남은 패키지를 확인하세요")
        exit(1)
    end
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
