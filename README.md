# kenv — uv 기반 conda 스타일 가상환경 관리자 (pip/PyPI 일원화)

Anaconda 유료 라이선스 대체용. **conda 패키지 설치는 완전히 배제**하고, 라이브러리는 pip(PyPI)로만 관리합니다.
엔진은 [uv](https://github.com/astral-sh/uv) (MIT/Apache-2.0), Python 인터프리터는 `uv python install`(python-build-standalone)로 받습니다.
conda+pip 혼용으로 인한 의존성 꼬임 문제가 원천적으로 사라집니다.

## 설치

### Windows 11 (PowerShell, WSL 불필요)
1. `dist/kenv-windows.zip` 압축 해제
2. PowerShell에서:
   ```powershell
   cd kenv-windows
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   - uv가 없으면 공식 설치기(`irm https://astral.sh/uv/install.ps1 | iex`)로 설치
   - `%LOCALAPPDATA%\kenv`에 `kenv.psm1`, `kenv.cmd` 복사, 사용자 PATH 추가
   - PowerShell 5.1/7 프로필에 `Import-Module ...kenv.psm1` 추가, 실행 정책이 미설정이면 CurrentUser=RemoteSigned
3. 새 터미널에서 `kenv list`. 환경 위치: `%USERPROFILE%\.kenv\envs`
- cmd.exe: `kenv.cmd`가 동작(`kenv activate NAME`은 env의 `activate.bat` 호출, 그 외는 PowerShell 모듈로 위임)
- 제거: `uninstall.ps1` (환경 폴더는 보존)

### Linux 서버
```bash
tar xzf kenv-linux.tar.gz && cd kenv-linux
./install.sh                 # 사용자 설치: ~/.local/share/kenv, 환경은 ~/.kenv/envs, ~/.bashrc 자동 설정
source ~/.bashrc && kenv list
./install.sh --uninstall     # 제거 (환경은 보존). 재실행해도 중복 설정 없음
```
연구실 공용 서버(공유 환경):
```bash
sudo ./install.sh --system           # /opt/kenv, 공용 환경 /opt/kenv/envs, Python 빌드 /opt/kenv/python
sudo usermod -aG kenv <사용자>        # kenv 그룹원은 공용 env 생성/설치 가능 (setgid + umask 002), 재로그인 필요
```
`/etc/profile.d/kenv.sh`가 `KENV_HOME=/opt/kenv`, `UV_PYTHON_INSTALL_DIR`을 설정합니다.
기존 Anaconda는 PATH/`conda init` 블록 제거 후 삭제.

## 명령 대응표
| 작업 | conda | kenv |
|---|---|---|
| 환경 생성 | `conda create -n sci python=3.11 numpy` | `kenv create sci --python 3.11 numpy` |
| 활성화/비활성화 | `conda activate sci` / `conda deactivate` | `kenv activate sci` / `kenv deactivate` |
| 목록 | `conda env list` | `kenv list` (`*` = 활성) |
| 패키지 설치 | `conda install pandas` | `kenv install pandas` (활성 env) 또는 `kenv install -n sci pandas` |
| 패키지 제거 | `conda remove pandas` | `kenv uninstall pandas` |
| 패키지 목록 | `conda list` | `kenv freeze` |
| 내보내기 | `conda env export > env.yml` | `kenv export -o req.txt` / 해시 고정 lock: `kenv export --lock -o req.lock` |
| 파일로 생성 | `conda env create -f env.yml` | `kenv import sci2 req.txt` (python 버전 헤더 자동 인식, 정확히 sync) |
| 복제 | `conda create --clone sci -n sci2` | `kenv clone sci sci2` |
| 환경 삭제 | `conda env remove -n sci` | `kenv remove sci` (Jupyter 커널도 함께 삭제) |
| Jupyter 커널 | `python -m ipykernel install ...` | `kenv kernel -n sci` → 커널명 `kenv-sci` |
| 취약점 점검 | (없음) | `kenv audit -n sci` (pip-audit, uvx로 일회 실행) |
| Python 버전 | `conda search python` | `kenv python list` / `kenv python install 3.13` |

## 검증 결과 (2026-10-27, Linux, uv 0.13.5)
- `create sci --python 3.11 numpy pandas` → Python 3.11.17, numpy 2.4.6, pandas 3.1.0 import 성공
- `create ml --python 3.12 requests==2.25.0` → Python 3.12.15 (두 버전 공존 확인)
- `activate sci` → `which python` = `~/.kenv/envs/sci/bin/python`, `list`에 `*sci` 표시; `deactivate` 후 VIRTUAL_ENV 해제
- 활성 상태에서 `kenv install scipy` 성공
- `export`(평문) / `export --lock`(sha256 해시 197개) → `import sci2`, `import sci3` → 원본과 `freeze` **완전 동일**
- `clone ml ml-copy` → requests==2.25.0 등 동일 핀 재현
- `kernel -n sci` → `~/.local/share/jupyter/kernels/kenv-sci` 등록
- `audit -n ml` → 구버전 requests/urllib3 등 **24건 취약점 탐지**, `audit -n sci` → 취약점 없음
- `remove sci2 sci3 ml-copy` → 디렉터리 삭제 확인

### 패키지 검증 (2026-10-27)
- Linux tarball: 빈 HOME에서 압축 해제 → `install.sh` → `create/activate/list/deactivate/remove` 정상
- Linux `--system`: 테스트 사용자 2명이 /opt/kenv 공용 env를 생성·활성화·설치 공유 확인 (테스트 후 원복)
- Windows 모듈: Linux의 PowerShell 7.4.6에서 전체 명령 시나리오 통과 (create 3.11/3.13, activate/deactivate, install, export/lock(해시 136)/import 동일 재현, clone, kernel, audit 24건 탐지·rc=1, remove 시 커널 삭제)
- 실제 (v0.1.0 기준) Windows 11에서 미검증 → v0.1.1부터 GitHub Actions windows-latest에서 검증: `install.ps1`(uv 설치, PATH/프로필/실행 정책), `kenv.cmd`, `Scripts\` 경로, Windows PowerShell 5.1 호환성, `%APPDATA%\jupyter` 커널 경로 → 문법 파싱만 확인

## 한계 / 주의 (conda가 제공하던 비-Python 바이너리)
| 항목 | pip 휠 현황 |
|---|---|
| CUDA | `torch`, `jax[cuda12]`, `cupy-cuda12x`, `nvidia-*-cu12` 휠이 CUDA 런타임/cuDNN을 포함 → **드라이버만** 시스템에 설치하면 됨. `nvcc` 등 툴킷 컴파일은 불가(시스템 CUDA Toolkit 필요) |
| GDAL/GIS | `rasterio`, `pyogrio`, `fiona`, `pyproj`, `shapely`는 GDAL/PROJ/GEOS 내장 휠 제공. `from osgeo import gdal`(GDAL 파이썬 바인딩)은 공식 휠 없음 → 시스템 `libgdal-dev` 후 빌드, 또는 rasterio/pyogrio로 대체 |
| MKL/BLAS | numpy/scipy 휠은 OpenBLAS 내장(충분). MKL 필요 시 `pip install mkl` 가능하나 numpy 연동은 제한적 |
| R, Julia, 비Python 도구(ffmpeg, graphviz 바이너리 등) | pip 범위 밖 → OS 패키지(apt/brew/winget)로 설치. 일부는 `imageio-ffmpeg` 등 휠 대체 존재 |
| 컴파일러/빌드 | 휠 없는 패키지는 소스 빌드 → gcc/MSVC 필요 |
| Windows | PowerShell 네이티브 버전 제공(`kenv.psm1`). 실제 Windows 11에서는 아직 미검증 (아래 참조) |
| 프로젝트 단위 | 재현성이 중요한 연구 코드는 중앙 env 대신 `uv init` + `uv add`(pyproject + uv.lock) 병행 권장 |

## 파일
- `dist/kenv-windows.zip`, `dist/kenv-linux.tar.gz` — 배포 패키지
- `windows/` — kenv.psm1, install.ps1, uninstall.ps1, kenv.cmd
- `install.sh` — Linux 설치기
- `bin/kenv` — CLI 본체 / `kenv.sh` — activate·deactivate 셸 함수 / `README.md`

## 테스트 / CI
- `tests/test_linux.sh` (bash 38개 케이스), `tests/test_install.sh` (깨끗한 HOME 설치·재설치·제거)
- `tests/test.ps1` (PowerShell 5.1/7, 37개 케이스), `tests/test_install_windows.ps1` (install.ps1·kenv.cmd·uninstall.ps1)
- GitHub Actions: ubuntu-latest + windows-latest (실제 Windows에서 PowerShell 5.1/7, cmd.exe 검증)
- 환경 이름 규칙: 영문/숫자/`. _ -`, `.`/`-`로 시작 불가. 생성·import·clone 실패 시 자동 롤백. `kenv audit`은 취약점 발견 시 exit 1.
