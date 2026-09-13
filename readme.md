# Blunux 빌드 절차

> 다른 Arch Linux 기계에서 `blnx2sb` 키트로 Live ISO 만들기 · RAM 16 GB 이상 기준

---

### 1. 준비물 설치

빌드에 필요한 도구를 한 번에 깝니다.

```bash
sudo pacman -S --needed archiso julia rust git base-devel imagemagick xorriso squashfs-tools

```

| 도구 | 쓰임 |
| --- | --- |
| `archiso` | mkarchiso — ISO 를 만드는 본체 |
| `julia` | build.jl 실행 (추가 패키지 불필요) |
| `rust` | 설치기·마법사 컴파일 |
| `base-devel`, `git` | AUR 패키지 빌드 |
| `imagemagick` | 아이콘·배경화면·부팅 스플래시 |
| `xorriso`, `squashfs-tools` | 완성된 ISO 검사 |

---

### 2. 다운로드 및 압축 해제

빌드 소스 패키지를 가져온 뒤 `bsdtar`를 통해 압축을 해제합니다.

```bash
curl -LO https://raw.githubusercontent.com/JaewooJoung/blnx/main/blnx2.tar.bz2

```

다운로드한 아카이브 파일의 압축을 풉니다.

```bash
bsdtar -xf blnx2.tar.bz2

```

---

### 3. TOML 카피

설정을 가져옵니다.

```bash
curl -LO https://raw.githubusercontent.com/JaewooJoung/blnx/main/config.toml

```

---

### 4. /tmp 크기를 32GB로 설정

빌드 용량이 부족해 멈추는 것을 방지하기 위해 `/tmp` 마운트 크기를 32GB로 확장합니다.

```bash
sudo mount -o remount,size=32G /tmp

```

---

### 5. TOML 설정 파일 이동 및 이동 폴더 입장

다운로드한 `config.toml` 파일을 `blnx2sb` 폴더 안으로 이동하고, 해당 폴더로 들어갑니다.

```bash
mv ./config.toml ./blnx2sb/config.toml && cd ./blnx2sb

```

---

### 6. 빌드

빌드를 시작합니다:

```bash
julia build.jl config.toml

```

> ⚠️ **주의:** **root 로 실행하지 마세요.** 중간에 `sudo` 암호를 묻는 것은 정상입니다 — mkarchiso 단계에서만 씁니다.

**40~60분** 걸립니다. AUR 에서 calamares·kime·yay-bin 을 처음부터 만드느라 20~30분이 더 붙고, 네트워크가 있어야 합니다.

다른 언어로 만들고 싶으면 파일만 바꾸면 됩니다 — 언어·커널·키보드·입력기가 모두 따라갑니다.

```bash
julia build.jl config_EN.toml

```

---

### 7. 결과 확인

빌드 끝에 검사가 자동으로 돕니다. 마지막 줄이 이래야 합니다:

```text
NN ok, 3 warn, 0 fail

```

**0 fail 이 핵심입니다.** warn 3개는 예상된 것입니다. 나중에 다시 보려면:

```bash
./scripts/verify-iso out/blunux2-*.iso config.toml

```

만들어진 ISO 확인:

```bash
ls -lh out/*.iso

```

> ⚠️ **주의:** 검사가 **0 fail 이 아니면 그 ISO 는 설치하지 마세요.** 실패한 줄이 무엇이 빠졌고 그래서 무엇이 깨지는지 말해 줍니다.

---

### 8. Ventoy USB 만들고 ISO 넣기

Ventoy 는 USB 하나에 ISO 를 여러 개 넣어두고 부팅할 때 고르는 도구입니다. AUR 에 있습니다.

```bash
yay -S ventoy-bin

```

#### 대상 USB 확인

여기서 장치를 잘못 고르면 엉뚱한 디스크가 지워집니다. **용량과 모델명을 눈으로 확인하세요.**

```bash
lsblk -o NAME,SIZE,TRAN,MODEL,MOUNTPOINTS

```

`TRAN` 이 `usb` 인 것이 대상입니다. 아래에서 `/dev/sdX` 를 그 이름으로 바꾸세요.

#### 언마운트

```bash
sudo umount /dev/sdX*

```

#### Ventoy 설치

> ⚠️ **주의:** **이 명령은 USB 전체를 지웁니다.** 확인하고 진행하세요.

```bash
sudo ventoy -i /dev/sdX

```

이미 Ventoy 가 깔린 USB 에 다시 깔려면 `-i` 대신 `-I` 를 씁니다.

#### ISO 넣기

USB 를 뽑았다 꽂으면 `Ventoy` 라는 이름으로 마운트됩니다. 거기에 그냥 복사하면 끝입니다.

```bash
cp ~/blnx2sb/out/blunux2-*.iso /run/media/$USER/Ventoy/

```

```bash
sync && udisksctl unmount -b /dev/sdX1

```

이 USB 로 부팅하면 ISO 목록이 나오고, 고르면 그대로 Blunux 라이브가 시작됩니다.

---

## 잘 안 될 때

#### gdb-add-index ... No debugging symbols 가 쏟아집니다

kime 빌드 때 나오는 알려진 잡음입니다. 무시하세요 — 패키지는 제대로 만들어집니다.

#### 작업 폴더에서 공간이 부족합니다

4단계를 다시 실행해 `/tmp` 용량을 늘리세요. 이미 실패했다면 남은 작업 폴더를 지우고 다시 시작합니다.

```bash
sudo rm -rf /tmp/blunux2-work

```

#### mkarchiso: command not found

`archiso` 가 설치되지 않았습니다. 1단계를 다시 보세요.

#### 설치가 마지막에 bootloader ... main.py 오류로 멈춥니다

만든 ISO 로 설치할 때 나오는 것입니다. 그 기계가 **BIOS(레거시) 모드로 부팅**된 것입니다 — Blunux 는 UEFI 로만 설치됩니다. 펌웨어에서 **CSM / Legacy Support 를 끄고** 부팅 메뉴에서 `UEFI:` 로 시작하는 항목을 고르세요.

#### USB 에 복사한 파일의 실행 권한이 사라집니다

USB 가 exFAT 이나 FAT32 입니다. 권한과 심볼릭 링크를 저장하지 못해 빌드가 깨집니다. 키트를 옮길 USB 는 **ext4** 여야 합니다. (Ventoy USB 는 ISO 만 담으므로 상관없습니다.)
