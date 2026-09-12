#=
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 📁File      📄 getready.jl                                                        ┃
┃ 📙Brief     📝 Getting redy for your computer to build Blunux                     ┃
┃ 🧾Details   🔎 Blunux /tmp 32GB expansion, package installation, and build setup  ┃
┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                           ┃
┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                          ┃
┃ 📆LastDate  📍 2026-09-12 🔄Please support to keep update🔄                       ┃
┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)         ┃
┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
=#

target_gb = 32

# 1. 루트 권한(sudo) 확인
if getuid() != 0
    println("⚠️  루트 권한이 필요합니다. 'sudo julia setup.jl'로 실행해주세요.")
    exit(1)
end

# 2. 시스템 전체 메모리(RAM + Swap) 계산
meminfo = readlines("/proc/meminfo")
mem_total_kb = 0
swap_total_kb = 0

for line in meminfo
    if startswith(line, "MemTotal:")
        global mem_total_kb = parse(Int, split(line)[2])
    elseif startswith(line, "SwapTotal:")
        global swap_total_kb = parse(Int, split(line)[2])
    end
end

total_memory_gb = (mem_total_kb + swap_total_kb) / (1024 * 1024)

println("📊 시스템 전체 메모리 (RAM + Swap): ", round(total_memory_gb, digits=2), " GB")
println("🎯 요청된 /tmp 용량: ", target_gb, " GB (필요한 전체 메모리: ", target_gb * 2, " GB 이상)")

# 3. 용량 조건 체크 (메모리 총합이 /tmp 용량의 2배 미만일 경우 중단)
if total_memory_gb < target_gb * 2
    println("❌ 오류: 메모리 용량이 부족합니다.")
    println("   /tmp를 $(target_gb)GB로 설정하려면 RAM + Swap 용량이 최소 $(target_gb * 2)GB 이상이어야 합니다.")
    exit(1)
end

target_size = "$(target_gb)G"
fstab_path = "/etc/fstab"
fstab_entry = "tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=$(target_size) 0 0"

println("\n🚀 [1단계] /tmp 용량을 $(target_size)로 변경합니다...")

# 4. 현재 실행 중인 시스템의 /tmp 즉시 재마운트
try
    run(`mount -o remount,size=$(target_size) /tmp`)
    println("✅ /tmp 마운트 용량이 $(target_size)로 즉시 변경되었습니다.")
catch e
    println("❌ 재마운트 실패: ", e)
    exit(1)
end

# 5. /etc/fstab 설정 (부팅 시 영구 적용)
lines = isfile(fstab_path) ? readlines(fstab_path) : String[]
updated = false
new_lines = String[]

for line in lines
    trimmed = strip(line)
    if !isempty(trimmed) && !startswith(trimmed, "#") && length(split(trimmed)) >= 2 && split(trimmed)[2] == "/tmp"
        push!(new_lines, fstab_entry)
        global updated = true
    else
        push!(new_lines, line)
    end
end

if !updated
    push!(new_lines, fstab_entry)
end

open(fstab_path, "w") do f
    for line in new_lines
        println(f, line)
    end
end

println("✅ /etc/fstab 갱신 완료 (재부팅 후에도 유지됨)")

# 6. [2단계] pacman 패키지 설치 진행
packages = ["archiso", "julia", "rust", "git", "base-devel", "imagemagick", "xorriso", "squashfs-tools", "curl", "libarchive"]
println("\n📦 [2단계] 필요한 패키지 설치를 시작합니다...")

try
    run(`pacman -S --needed $(packages) --noconfirm`)
    println("✅ 패키지 설치가 완료되었습니다.")
catch e
    println("❌ 패키지 설치 중 오류 발생: ", e)
    exit(1)
end

# 작업 디렉터리를 /tmp로 이동
cd("/tmp")

# 7. [3단계] GitHub에서 blnx2.tar.bz2 파일 다운로드 (Raw URL 사용)
file_url = "https://raw.githubusercontent.com/JaewooJoung/blnx/main/blnx2.tar.bz2"
output_file = "/tmp/blnx2.tar.bz2"
println("\n📥 [3단계] $(file_url) 에서 파일을 다운로드합니다...")

try
    run(`curl -L -o $(output_file) $(file_url)`)
    
    if isfile(output_file) && filesize(output_file) > 0
        println("✅ 다운로드 완료: $(output_file) ($(filesize(output_file)) bytes)")
    else
        println("❌ 다운로드된 파일이 비어있거나 존재하지 않습니다.")
        exit(1)
    end
catch e
    println("❌ 파일 다운로드 중 오류 발생: ", e)
    exit(1)
end

# 8. [4단계] 기존 디렉터리 삭제 및 압축 해제
println("\n📂 [4단계] 기존 디렉터리 정리 및 압축 해제를 진행합니다...")

try
    rm("./blnx2sb", recursive=true, force=true)
    println("✅ 기존 ./blnx2sb 디렉터리를 삭제(정리)했습니다.")

    run(`bsdtar -xjvf blnx2.tar.bz2`)
    println("✅ 압축 해제 완료.")
catch e
    println("❌ 압축 해제 작업 중 오류 발생: ", e)
    exit(1)
end

# 9. [5단계] 작업 디렉터리 이동 (cd ./blnx2sb/)
target_dir = "/tmp/blnx2sb"
println("\n📂 [5단계] $(target_dir) 디렉터리로 이동합니다...")

if isdir(target_dir)
    cd(target_dir)
    println("🎉 현재 작업 위치: ", pwd())
else
    println("❌ 오류: $(target_dir) 디렉터리가 존재하지 않습니다.")
    exit(1)
end
