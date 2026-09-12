# 🚀 Blunux Build Preparation

Arch Linux 환경에서 Blunux 빌드를 위해 `/tmp` 용량을 32GB로 확장하고, 필용 패키지 설치 및 소스 코드를 자동으로 준비하는 스크립트 실행 가이드입니다.

---

## 🛠️ Quick Start (빠른 시작)

터미널에서 아래 명령어들을 순서대로 실행하세요.

```bash
# 1. getready.jl 스크립트 다운로드
curl -L -o getready.jl [https://raw.githubusercontent.com/JaewooJoung/blnx/main/getready.jl](https://raw.githubusercontent.com/JaewooJoung/blnx/main/getready.jl)

# 2. 실행 권한 부여
chmod +x getready.jl

# 3. 루트 권한으로 스크립트 실행
sudo ./getready.jl
