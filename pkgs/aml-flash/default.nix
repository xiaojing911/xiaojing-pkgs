# Amlogic USB 烧录工具（Amlogic USB Burning Tool 的 Linux 命令行版）
# 用于给 S905/S912 等 Amlogic 芯片的盒子/开发板刷机
{ lib
, stdenv
, fetchFromGitHub
, autoPatchelfHook
, libusb-compat-0_1
}:

stdenv.mkDerivation {
  pname = "aml-flash";
  version = "unstable-2023-08-29";

  src = fetchFromGitHub {
    owner = "Stane1983";
    repo = "aml-linux-usb-burn";
    rev = "257b808ba8550db023875b139db2eca9d11d55a4";
    hash = "sha256-pYr1wLHVDc1oEkRT+D625guyM1oTvXw65Am1FIpgH5Y=";
  };

  # `update` 是 64 位动态链接的二进制，需要 autoPatchelf 修补才能在
  # NixOS 上运行（NixOS 没有 FHS 的 /lib64/ld-linux...，系统里也没有
  # libusb-0.1.so.4）。
  # `aml_image_v2_packer` 是 32 位静态链接的二进制，无需修补——只依赖
  # 内核的 IA32 兼容层，x86_64 内核基本都默认开启。
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ libusb-compat-0_1 ];

  # 上游只提供预编译二进制，跳过 configure 和 build 阶段
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/aml-flash
    cp -r tools $out/libexec/aml-flash/tools
    install -Dm755 aml-flash $out/libexec/aml-flash/aml-flash

    # 脚本通过 "$(dirname $0)/tools/..." 定位辅助二进制。
    # 由于脚本会被符号链接到 $out/bin，dirname $0 会解析错位置，
    # 这里直接把工具路径硬编码为 store 路径。
    substituteInPlace $out/libexec/aml-flash/aml-flash \
      --replace 'TOOL_PATH="$(cd $(dirname $0); pwd)"' \
                 'TOOL_PATH="'"$out"'/libexec/aml-flash"'

    ln -s $out/libexec/aml-flash/aml-flash $out/bin/aml-flash

    runHook postInstall
  '';

  # 随包附带 udev 规则（普通用户可访问烧录模式下的 USB 设备），
  # 在 NixOS 配置中通过 `services.udev.packages = [ <本包> ];` 启用，
  # 无需手动编辑 /etc/udev/rules.d。
  postInstall = ''
    mkdir -p $out/lib/udev/rules.d
    cat > $out/lib/udev/rules.d/70-amlogic-usb.rules <<'EOF'
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="1b8e", ATTR{idProduct}=="c003", MODE:="0666", SYMLINK+="worldcup"
EOF
  '';

  meta = {
    description = "Linux command-line version of the Amlogic USB Burning Tool, for flashing Amlogic SoC boards (S905/S905X/S912/A113/T962/...) over USB";
    homepage = "https://github.com/Stane1983/aml-linux-usb-burn";
    # `update` 和 `aml_image_v2_packer` 是上游再分发的 Amlogic 闭源
    # 预编译二进制，没有源码
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "aml-flash";
    maintainers = [ ];
  };
}
