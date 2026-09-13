# Blunux (블루눅스)

![Blunux](logo-512.png)

[Arch Linux](https://archlinux.org) 기반의 리눅스 배포판. [KDE Plasma](https://kde.org/plasma-desktop/)를
기본 데스크톱 환경으로 사용하며, 스웨덴에 거주하는 한국인 개발자 Jaewoo Joung이 개인 프로젝트로
개발하고 있다. 2026년 2월 8일 첫 공개 릴리스가 배포되었다.

| 항목 | 내용 |
| --- | --- |
| 개발 | Jaewoo Joung / Blunux Team |
| 최초 공개 | 2026년 2월 8일 |
| 커널 | Linux (기본 `linux-zen`, 빌드 시 `linux` / `linux-lts` 선택 가능) |
| 기반 | [Arch Linux](https://archlinux.org) |
| 패키지 관리자 | [Pacman](https://wiki.archlinux.org/title/Pacman), [yay](https://github.com/Jguer/yay) ([AUR](https://aur.archlinux.org) 헬퍼) |
| 릴리스 주기 | 롤링 릴리스 |
| 최신 ISO | Blunux 2 (`blunux2-2026.09.03`) |
| 지원 플랫폼 | x86-64 (AMD64) |
| 기본 데스크톱 환경 | [KDE Plasma](https://kde.org/plasma-desktop/) |
| 라이선스 | MIT |
| 소스 코드 | [github.com/JaewooJoung/blnx](https://github.com/JaewooJoung/blnx) |
| 공식 사이트 | [blunux.com](https://blunux.com) |

## 개요

아치 리눅스의 설치와 초기 설정 과정을 단순화하고, 언어별 환경(입력기 · 로캘 · 기본 패키지)을
ISO 단계에서 미리 구성해 배포하는 것을 목표로 한다. 한국어(ko_KR), 스웨덴어(sv_SE) 등
언어별 에디션이 별도 ISO로 제공된다.

배포 방식이 다른 배포판과 구분되는 지점은 **'직접 빌드'를 전제로 한다**는 것이다.
완성된 ISO를 내려받아 쓸 수도 있지만, `blnx2sb` 빌드 키트와 TOML 설정 파일을 이용해
사용자가 원하는 패키지 구성으로 Live ISO를 직접 만들어 쓰는 것을 기본 사용 방식으로 상정하고 있다.

## 이름의 유래

Blunux는 **Blue**와 **Linux**의 합성어이며, 한글로는 '블루눅스'로 읽는다.
줄여서 `blnx`로 표기하기도 한다.

아치 리눅스에 영감을 준 [CRUX](https://crux.nu/) 리눅스처럼 심플함을 지향하면서도,
리눅스 마스코트 턱스(Tux)의 모티브가 된 쇠푸른펭귄에서 착안해
'푸른색'이 가진 신선함을 아치 기반 시스템에 접목한다는 의미를 담았다.

리누스 토르발스가 호주에서 쇠푸른펭귄에게 물린 일이 턱스의 모티브가 되었고,
CRUX 역시 푸른색 펭귄을 로고로 사용하고 있다.
Blunux의 로고인 푸른 펭귄 픽셀 아트는 그 계보 위에서 만들어진 것으로,
접근하기 쉽고 친근한 성격을 나타낸다.

## 특징

### TOML 기반 빌드 구성

`config.toml` 파일의 항목을 참(`true`) / 거짓(`false`)으로 조정해 웹 브라우저, 개발 도구,
멀티미디어 패키지, 게이밍 플랫폼 등의 포함 여부를 결정하고, 그 구성대로 ISO를 생성한다.
언어별 설정 파일(`config_EN.toml` 등)이 함께 제공된다.

### 빌드 키트 (blnx2sb)

[Julia](https://julialang.org)로 작성된 `build.jl` 스크립트가 AUR 패키지
([Calamares](https://calamares.io), [kime](https://github.com/Riey/kime), yay 등) 컴파일부터
ISO 생성까지의 과정을 수행하며, `verify-iso` 스크립트가 생성된 ISO를 검사한다.
릴리스 ISO는 공개 전 자동 검사를 거친다.

### 언어 환경

한국어 에디션에는 한글 입력기 [kime](https://github.com/Riey/kime)와 한국어 로캘이
기본 반영되어 있어 설치 직후 별도 설정 없이 한글 입출력이 가능하다.
스웨덴어 에디션에는 Steam이 기본 포함되는 등 에디션별로 기본 패키지 구성이 다르다.

### 설치

GUI 설치 프로그램인 [Calamares](https://calamares.io)를 기본 설치기로 사용한다.
UEFI 환경을 기준으로 하며, **설치 전 BIOS에서 Secure Boot를 비활성화해야 한다.**

### 저장소와 배포

아치 리눅스 공식 저장소와 AUR을 그대로 사용하며, 별도의 자체 패키지 저장소도 운영한다.
ISO는 공식 사이트에서 직접 내려받거나 BitTorrent로 받을 수 있으며,
SHA256 체크섬과 GPG 서명이 함께 공개된다.

## 시스템 요구 사항

설치 · 사용 요구 사항은 아치 리눅스 및 KDE Plasma 기준을 따른다.
UEFI 부팅을 전제로 하므로 레거시 BIOS 전용 환경에서는 부팅 및 설치가 제한될 수 있다.

ISO를 직접 빌드하는 경우에는 별도의 자원이 필요하다.
빌드 디렉터리에 15GB 이상의 여유 공간과 16GB 이상의 RAM이 권장되며,
AUR 패키지 컴파일에 시간이 소요된다.

롤링 릴리스 배포판이므로 주기적인 업데이트 관리가 필요하고,
문제 발생 시 아치 리눅스 수준의 기본적인 문제 해결 지식이 요구된다.

## 링크

- 공식 사이트 — <https://blunux.com>
- 소스 코드 — <https://github.com/JaewooJoung/blnx>
- 패키지 저장소 및 ISO 체크섬 — <https://blunux.com/repo/>
