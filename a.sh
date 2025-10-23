#!/bin/bash
#######################################################################
# Linux 2FA 管理脚本
# 功能：配置、强制、回滚、管理2FA
# 支持：SSH、TTY、GUI登录
#######################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 日志函数
log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_title() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                          ║${NC}"
    echo -e "${CYAN}║      ${BOLD}Linux 2FA 管理系统${NC}${CYAN}              ║${NC}"
    echo -e "${CYAN}║                                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC} 配置2FA（SSH + TTY + GUI）"
    echo -e "${GREEN}[2]${NC} 为单个用户配置2FA"
    echo -e "${GREEN}[3]${NC} 为多个用户批量配置2FA"
    echo -e "${YELLOW}[4]${NC} 强制2FA（移除nullok）"
    echo -e "${CYAN}[5]${NC} 查看2FA状态"
    echo -e "${CYAN}[6]${NC} 查看用户2FA配置"
    echo -e "${CYAN}[7]${NC} 查看恢复码"
    echo -e "${MAGENTA}[8]${NC} 禁用2FA（添加nullok）"
    echo -e "${RED}[9]${NC} 完全移除2FA配置"
    echo -e "${RED}[10]${NC} 回滚到备份配置"
    echo -e "${BLUE}[11]${NC} 查看认证日志"
    echo -e "${BLUE}[12]${NC} 测试2FA配置"
    echo ""
    echo -e "${MAGENTA}═══ 时间同步功能 ═══${NC}"
    echo -e "${GREEN}[13]${NC} 安装开机时间同步服务"
    echo -e "${CYAN}[14]${NC} 查看时间同步状态"
    echo -e "${CYAN}[15]${NC} 手动同步时间"
    echo -e "${RED}[16]${NC} 卸载时间同步服务"
    echo ""
    echo -e "${MAGENTA}═══ 安全加固功能 ═══${NC}"
    echo -e "${GREEN}[17]${NC} 设置GRUB密码保护"
    echo -e "${GREEN}[18]${NC} 保护关键配置文件"
    echo -e "${CYAN}[19]${NC} 查看安全状态"
    echo -e "${YELLOW}[20]${NC} 一键完整加固"
    echo -e "${RED}[21]${NC} 移除文件保护"
    echo -e "${GREEN}[22]${NC} SSH安全加固（密钥+2FA）"
    echo -e "${GREEN}[23]${NC} 隐私保护增强"
    echo ""
    echo -e "${YELLOW}[0]${NC} 退出"
    echo ""
    echo -n "请选择操作 [0-23]: "
}

# 备份配置文件
backup_configs() {
    log_step "备份现有PAM配置文件..."
    
    BACKUP_DIR="/root/2fa-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # 备份所有相关PAM配置
    cp /etc/pam.d/sshd "$BACKUP_DIR/sshd.bak" 2>/dev/null
    cp /etc/pam.d/login "$BACKUP_DIR/login.bak" 2>/dev/null
    cp /etc/pam.d/gdm-password "$BACKUP_DIR/gdm-password.bak" 2>/dev/null
    cp /etc/pam.d/lightdm "$BACKUP_DIR/lightdm.bak" 2>/dev/null
    cp /etc/pam.d/sddm "$BACKUP_DIR/sddm.bak" 2>/dev/null
    cp /etc/pam.d/common-auth "$BACKUP_DIR/common-auth.bak" 2>/dev/null
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak" 2>/dev/null
    
    log_info "配置文件已备份到: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /root/.2fa-backup-location
    echo "$BACKUP_DIR"
}

# 安装Google Authenticator
install_google_auth() {
    log_step "检查并安装Google Authenticator..."
    
    if command -v google-authenticator &> /dev/null; then
        log_info "Google Authenticator 已安装"
        return 0
    fi
    
    # 检测系统类型
    if [ -f /etc/debian_version ]; then
        apt-get update >/dev/null 2>&1
        apt-get install -y libpam-google-authenticator qrencode
    elif [ -f /etc/redhat-release ]; then
        yum install -y google-authenticator qrencode
    else
        log_error "不支持的系统类型"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Google Authenticator 安装成功"
        return 0
    else
        log_error "Google Authenticator 安装失败"
        return 1
    fi
}

# 为用户配置2FA
configure_user_2fa() {
    local username=$1
    
    log_step "为用户 $username 配置2FA..."
    
    # 检查用户是否存在
    if ! id "$username" &>/dev/null; then
        log_error "用户 $username 不存在"
        return 1
    fi
    
    # 获取用户home目录
    user_home=$(eval echo ~$username)
    
    # 检查是否已配置
    if [ -f "$user_home/.google_authenticator" ]; then
        log_warn "用户 $username 已配置2FA"
        read -p "是否重新配置？(y/n): " reconfigure
        if [[ ! $reconfigure =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # 为用户生成2FA配置
    log_step "生成2FA密钥和二维码..."
    
    sudo -u "$username" google-authenticator -t -d -f -r 3 -R 30 -w 3 -q -Q UTF8
    
    if [ $? -eq 0 ]; then
        log_info "2FA配置文件已生成"
        
        # 显示二维码和密钥
        echo ""
        echo "=========================================="
        echo "  用户: $username 的2FA配置信息"
        echo "=========================================="
        echo ""
        
        # 显示二维码
        if [ -f "$user_home/.google_authenticator" ]; then
            secret=$(head -n 1 "$user_home/.google_authenticator")
            echo "密钥: $secret"
            echo ""
            echo "请使用手机APP扫描以下二维码："
            qrencode -t ANSIUTF8 "otpauth://totp/$username@$(hostname)?secret=$secret"
            echo ""
            
            # 显示备用恢复码
            echo "紧急恢复码（请妥善保存）："
            tail -n +2 "$user_home/.google_authenticator" | head -n 5
            echo ""
            echo "=========================================="
            echo ""
            
            # 保存到文件
            cat > "$user_home/2fa-backup-codes.txt" << EOF
用户: $username
主机: $(hostname)
密钥: $secret
生成时间: $(date)

紧急恢复码:
$(tail -n +2 "$user_home/.google_authenticator" | head -n 5)

请将此文件保存到安全位置后删除！
EOF
            chown "$username:$username" "$user_home/2fa-backup-codes.txt"
            chmod 600 "$user_home/2fa-backup-codes.txt"
            
            log_info "恢复码已保存到: $user_home/2fa-backup-codes.txt"
            return 0
        fi
    else
        log_error "2FA配置失败"
        return 1
    fi
}

# 配置SSH 2FA
configure_ssh_2fa() {
    log_step "配置SSH服务的2FA..."
    
    # 检查是否已配置
    if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd 2>/dev/null; then
        log_warn "SSH 2FA 已配置"
    else
        # 添加2FA到SSH PAM配置
        sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/sshd
        log_info "SSH PAM配置已更新"
    fi
    
    # 配置SSH服务
    log_step "更新SSH服务配置..."
    
    # 启用ChallengeResponseAuthentication
    if grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
    fi
    
    # 确保UsePAM启用
    if grep -q "^UsePAM" /etc/ssh/sshd_config; then
        sed -i 's/^UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    else
        echo "UsePAM yes" >> /etc/ssh/sshd_config
    fi
    
    # 设置认证方法
    if grep -q "^AuthenticationMethods" /etc/ssh/sshd_config; then
        sed -i 's/^AuthenticationMethods.*/AuthenticationMethods keyboard-interactive/' /etc/ssh/sshd_config
    else
        echo "AuthenticationMethods keyboard-interactive" >> /etc/ssh/sshd_config
    fi
    
    log_info "SSH服务配置已更新"
}

# 配置TTY登录2FA
configure_tty_2fa() {
    log_step "配置TTY终端登录的2FA..."
    
    if grep -q "pam_google_authenticator.so" /etc/pam.d/login 2>/dev/null; then
        log_warn "TTY 2FA 已配置"
    else
        if grep -q "@include common-auth" /etc/pam.d/login; then
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/login
        else
            sed -i '1i auth required pam_google_authenticator.so nullok' /etc/pam.d/login
        fi
        log_info "TTY登录2FA已配置"
    fi
}

# 配置GUI登录2FA
configure_gui_2fa() {
    log_step "配置GUI图形界面登录的2FA..."
    
    local configured=false
    
    # GDM
    if [ -f /etc/pam.d/gdm-password ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/gdm-password 2>/dev/null; then
            log_warn "GDM 2FA 已配置"
        else
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/gdm-password
            log_info "GDM (GNOME) 2FA已配置"
            configured=true
        fi
    fi
    
    # LightDM
    if [ -f /etc/pam.d/lightdm ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/lightdm 2>/dev/null; then
            log_warn "LightDM 2FA 已配置"
        else
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/lightdm
            log_info "LightDM 2FA已配置"
            configured=true
        fi
    fi
    
    # SDDM
    if [ -f /etc/pam.d/sddm ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/sddm 2>/dev/null; then
            log_warn "SDDM 2FA 已配置"
        else
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/sddm
            log_info "SDDM (KDE) 2FA已配置"
            configured=true
        fi
    fi
    
    if [ "$configured" = false ]; then
        log_warn "未检测到GUI显示管理器"
    fi
}

# 测试SSH配置
test_ssh_config() {
    if sshd -t 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 重启SSH服务
restart_ssh() {
    log_step "重启SSH服务..."
    
    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        log_info "SSH服务已重启"
        return 0
    else
        log_error "SSH服务重启失败"
        return 1
    fi
}

# 选项1: 完整配置2FA
option_full_setup() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  配置2FA (SSH + TTY + GUI)"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将配置系统级2FA，请确保："
    echo "  1. 有物理访问或KVM控制台权限"
    echo "  2. 当前SSH会话保持打开"
    echo "  3. 已准备好手机Authenticator APP"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        return
    fi
    
    echo ""
    backup_configs
    install_google_auth || return
    
    # 配置用户
    echo ""
    echo "请输入要配置2FA的用户名（用空格分隔）："
    read -p "用户名: " users
    
    echo ""
    for user in $users; do
        configure_user_2fa "$user"
        echo ""
        read -p "按Enter继续..." 
    done
    
    # 配置系统
    echo ""
    configure_ssh_2fa
    configure_tty_2fa
    configure_gui_2fa
    
    # 测试并重启
    if test_ssh_config; then
        restart_ssh
        echo ""
        log_info "2FA配置完成！"
        echo ""
        log_warn "重要提示："
        echo "  1. 请在新终端测试登录"
        echo "  2. 确保已保存恢复码"
        echo "  3. 当前使用nullok，未配置2FA的用户仍可登录"
        echo "  4. 所有用户配置后，选择菜单[4]强制2FA"
        
        # 提示配置时间同步
        echo ""
        log_step "建议配置开机时间同步服务"
        echo "  - 2FA需要准确的系统时间"
        echo "  - 时间误差会导致验证码验证失败"
        echo ""
        read -p "是否现在配置时间同步？(y/n): " setup_time_sync
        
        if [[ $setup_time_sync =~ ^[Yy]$ ]]; then
            echo ""
            option_install_time_sync
            return
        fi
    else
        log_error "SSH配置测试失败"
    fi
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项2: 为单个用户配置2FA
option_single_user() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  为单个用户配置2FA"
    log_title "══════════════════════════════════════════"
    echo ""
    
    install_google_auth || return
    
    read -p "请输入用户名: " username
    
    if [ -z "$username" ]; then
        log_error "用户名不能为空"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    configure_user_2fa "$username"
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项3: 批量配置用户
option_batch_users() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  批量配置多个用户"
    log_title "══════════════════════════════════════════"
    echo ""
    
    install_google_auth || return
    
    echo "请输入要配置的用户名（用空格分隔）："
    read -p "用户名: " users
    
    if [ -z "$users" ]; then
        log_error "未输入用户名"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    for user in $users; do
        configure_user_2fa "$user"
        echo ""
        read -p "按Enter继续下一个用户..." 
    done
    
    echo ""
    log_info "批量配置完成"
    read -p "按Enter返回主菜单..."
}

# 选项4: 强制2FA
option_enforce() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  强制2FA（移除nullok）"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将强制所有用户使用2FA"
    echo "未配置2FA的用户将无法登录！"
    echo ""
    read -p "确认所有用户都已配置2FA？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "移除nullok参数..."
    
    sed -i 's/pam_google_authenticator.so nullok/pam_google_authenticator.so/g' /etc/pam.d/sshd
    sed -i 's/pam_google_authenticator.so nullok/pam_google_authenticator.so/g' /etc/pam.d/login
    sed -i 's/pam_google_authenticator.so nullok/pam_google_authenticator.so/g' /etc/pam.d/gdm-password 2>/dev/null
    sed -i 's/pam_google_authenticator.so nullok/pam_google_authenticator.so/g' /etc/pam.d/lightdm 2>/dev/null
    sed -i 's/pam_google_authenticator.so nullok/pam_google_authenticator.so/g' /etc/pam.d/sddm 2>/dev/null
    
    restart_ssh
    
    echo ""
    log_info "2FA现已强制执行"
    log_warn "所有用户必须配置2FA才能登录"
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项5: 查看2FA状态
option_view_status() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  2FA配置状态"
    log_title "══════════════════════════════════════════"
    echo ""
    
    echo -e "${BOLD}系统配置状态:${NC}"
    echo ""
    
    # 检查SSH
    echo -n "SSH 2FA: "
    if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd 2>/dev/null; then
        if grep -q "pam_google_authenticator.so nullok" /etc/pam.d/sshd; then
            echo -e "${YELLOW}已启用 (宽松模式)${NC}"
        else
            echo -e "${GREEN}已启用 (强制模式)${NC}"
        fi
    else
        echo -e "${RED}未配置${NC}"
    fi
    
    # 检查TTY
    echo -n "TTY 2FA: "
    if grep -q "pam_google_authenticator.so" /etc/pam.d/login 2>/dev/null; then
        if grep -q "pam_google_authenticator.so nullok" /etc/pam.d/login; then
            echo -e "${YELLOW}已启用 (宽松模式)${NC}"
        else
            echo -e "${GREEN}已启用 (强制模式)${NC}"
        fi
    else
        echo -e "${RED}未配置${NC}"
    fi
    
    # 检查GDM
    echo -n "GDM 2FA: "
    if [ -f /etc/pam.d/gdm-password ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/gdm-password 2>/dev/null; then
            if grep -q "pam_google_authenticator.so nullok" /etc/pam.d/gdm-password; then
                echo -e "${YELLOW}已启用 (宽松模式)${NC}"
            else
                echo -e "${GREEN}已启用 (强制模式)${NC}"
            fi
        else
            echo -e "${RED}未配置${NC}"
        fi
    else
        echo -e "${CYAN}未安装${NC}"
    fi
    
    # 检查LightDM
    echo -n "LightDM 2FA: "
    if [ -f /etc/pam.d/lightdm ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/lightdm 2>/dev/null; then
            if grep -q "pam_google_authenticator.so nullok" /etc/pam.d/lightdm; then
                echo -e "${YELLOW}已启用 (宽松模式)${NC}"
            else
                echo -e "${GREEN}已启用 (强制模式)${NC}"
            fi
        else
            echo -e "${RED}未配置${NC}"
        fi
    else
        echo -e "${CYAN}未安装${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}已配置2FA的用户:${NC}"
    echo ""
    
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            if [ -f "$user_home/.google_authenticator" ]; then
                echo -e "  ${GREEN}✓${NC} $username"
            fi
        fi
    done
    
    # 检查root
    if [ -f /root/.google_authenticator ]; then
        echo -e "  ${GREEN}✓${NC} root"
    fi
    
    echo ""
    echo -e "${BOLD}备份位置:${NC}"
    if [ -f /root/.2fa-backup-location ]; then
        echo "  $(cat /root/.2fa-backup-location)"
    else
        echo "  无备份记录"
    fi
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项6: 查看用户2FA配置
option_view_user_config() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  查看用户2FA配置"
    log_title "══════════════════════════════════════════"
    echo ""
    
    read -p "请输入用户名: " username
    
    if [ -z "$username" ]; then
        log_error "用户名不能为空"
        read -p "按Enter返回..."
        return
    fi
    
    user_home=$(eval echo ~$username 2>/dev/null)
    
    if [ ! -d "$user_home" ]; then
        log_error "用户不存在"
        read -p "按Enter返回..."
        return
    fi
    
    if [ ! -f "$user_home/.google_authenticator" ]; then
        log_warn "用户 $username 未配置2FA"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    echo "用户: $username"
    echo "密钥: $(head -n 1 $user_home/.google_authenticator)"
    echo ""
    echo "配置文件: $user_home/.google_authenticator"
    
    if [ -f "$user_home/2fa-backup-codes.txt" ]; then
        echo "恢复码文件: $user_home/2fa-backup-codes.txt"
    fi
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项7: 查看恢复码
option_view_recovery_codes() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  查看恢复码"
    log_title "══════════════════════════════════════════"
    echo ""
    
    read -p "请输入用户名: " username
    
    if [ -z "$username" ]; then
        log_error "用户名不能为空"
        read -p "按Enter返回..."
        return
    fi
    
    user_home=$(eval echo ~$username 2>/dev/null)
    
    if [ ! -f "$user_home/.google_authenticator" ]; then
        log_error "用户 $username 未配置2FA"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    echo "用户: $username"
    echo ""
    echo "恢复码（每个只能使用一次）："
    tail -n +2 "$user_home/.google_authenticator" | head -n 5
    echo ""
    
    log_warn "请妥善保存这些恢复码"
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项8: 禁用2FA（添加nullok）
option_disable_enforcement() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  禁用2FA强制（添加nullok）"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将允许未配置2FA的用户登录"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "添加nullok参数..."
    
    # 替换不带nullok的为带nullok的
    sed -i 's/pam_google_authenticator.so$/pam_google_authenticator.so nullok/g' /etc/pam.d/sshd
    sed -i 's/pam_google_authenticator.so$/pam_google_authenticator.so nullok/g' /etc/pam.d/login
    sed -i 's/pam_google_authenticator.so$/pam_google_authenticator.so nullok/g' /etc/pam.d/gdm-password 2>/dev/null
    sed -i 's/pam_google_authenticator.so$/pam_google_authenticator.so nullok/g' /etc/pam.d/lightdm 2>/dev/null
    sed -i 's/pam_google_authenticator.so$/pam_google_authenticator.so nullok/g' /etc/pam.d/sddm 2>/dev/null
    
    restart_ssh
    
    echo ""
    log_info "2FA强制已禁用（宽松模式）"
    log_warn "未配置2FA的用户现在可以正常登录"
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项9: 完全移除2FA
option_remove_2fa() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  完全移除2FA配置"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_error "警告: 此操作将完全移除2FA配置！"
    echo ""
    read -p "确认要移除所有2FA配置？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "移除2FA配置..."
    
    # 从PAM配置中移除
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sshd 2>/dev/null
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/login 2>/dev/null
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/gdm-password 2>/dev/null
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/lightdm 2>/dev/null
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sddm 2>/dev/null
    sed -i '/pam_google_authenticator.so/d' /etc/pam.d/common-auth 2>/dev/null
    
    restart_ssh
    
    echo ""
    log_info "2FA配置已完全移除"
    log_warn "用户的2FA配置文件 (~/.google_authenticator) 仍保留"
    
    echo ""
    read -p "是否删除所有用户的2FA配置文件？(y/n): " delete_confirm
    
    if [[ $delete_confirm =~ ^[Yy]$ ]]; then
        for user_home in /home/*; do
            if [ -f "$user_home/.google_authenticator" ]; then
                username=$(basename "$user_home")
                rm -f "$user_home/.google_authenticator"
                rm -f "$user_home/2fa-backup-codes.txt"
                log_info "已删除 $username 的2FA配置"
            fi
        done
        
        if [ -f /root/.google_authenticator ]; then
            rm -f /root/.google_authenticator
            rm -f /root/2fa-backup-codes.txt
            log_info "已删除 root 的2FA配置"
        fi
    fi
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项10: 回滚到备份
option_rollback() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  回滚到备份配置"
    log_title "══════════════════════════════════════════"
    echo ""
    
    if [ ! -f /root/.2fa-backup-location ]; then
        log_error "未找到备份位置信息"
        read -p "按Enter返回..."
        return
    fi
    
    BACKUP_DIR=$(cat /root/.2fa-backup-location)
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "备份目录不存在: $BACKUP_DIR"
        read -p "按Enter返回..."
        return
    fi
    
    echo "备份位置: $BACKUP_DIR"
    echo ""
    log_warn "此操作将恢复到备份时的配置"
    echo ""
    read -p "确认要回滚？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "恢复备份配置..."
    
    [ -f "$BACKUP_DIR/sshd.bak" ] && cp "$BACKUP_DIR/sshd.bak" /etc/pam.d/sshd
    [ -f "$BACKUP_DIR/login.bak" ] && cp "$BACKUP_DIR/login.bak" /etc/pam.d/login
    [ -f "$BACKUP_DIR/gdm-password.bak" ] && cp "$BACKUP_DIR/gdm-password.bak" /etc/pam.d/gdm-password
    [ -f "$BACKUP_DIR/lightdm.bak" ] && cp "$BACKUP_DIR/lightdm.bak" /etc/pam.d/lightdm
    [ -f "$BACKUP_DIR/sddm.bak" ] && cp "$BACKUP_DIR/sddm.bak" /etc/pam.d/sddm
    [ -f "$BACKUP_DIR/common-auth.bak" ] && cp "$BACKUP_DIR/common-auth.bak" /etc/pam.d/common-auth
    [ -f "$BACKUP_DIR/sshd_config.bak" ] && cp "$BACKUP_DIR/sshd_config.bak" /etc/ssh/sshd_config
    
    restart_ssh
    
    echo ""
    log_info "配置已回滚"
    log_warn "用户的2FA配置文件未删除"
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项11: 查看认证日志
option_view_logs() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  2FA认证日志"
    log_title "══════════════════════════════════════════"
    echo ""
    
    echo "1. 查看所有2FA相关日志"
    echo "2. 查看最近的2FA登录"
    echo "3. 查看失败的2FA尝试"
    echo "4. 实时监控日志"
    echo "0. 返回"
    echo ""
    read -p "请选择 [0-4]: " log_choice
    
    case $log_choice in
        1)
            echo ""
            log_step "所有2FA相关日志:"
            echo ""
            grep "google_authenticator" /var/log/auth.log 2>/dev/null | tail -20
            ;;
        2)
            echo ""
            log_step "最近的2FA登录:"
            echo ""
            grep "google_authenticator" /var/log/auth.log 2>/dev/null | grep "Accepted" | tail -10
            ;;
        3)
            echo ""
            log_step "失败的2FA尝试:"
            echo ""
            grep "google_authenticator" /var/log/auth.log 2>/dev/null | grep -i "fail\|invalid" | tail -20
            ;;
        4)
            echo ""
            log_step "实时监控（按Ctrl+C停止）:"
            echo ""
            tail -f /var/log/auth.log | grep --line-buffered "google_authenticator"
            ;;
    esac
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项12: 测试2FA配置
option_test_config() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  测试2FA配置"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "测试SSH配置语法..."
    if sshd -t 2>/dev/null; then
        log_info "SSH配置语法正确"
    else
        log_error "SSH配置有错误："
        sshd -t
    fi
    
    echo ""
    log_step "测试SSH服务状态..."
    if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
        log_info "SSH服务运行正常"
    else
        log_error "SSH服务未运行"
    fi
    
    echo ""
    log_step "检查PAM配置..."
    
    if [ -f /etc/pam.d/sshd ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
            log_info "SSH PAM配置正确"
        else
            log_warn "SSH PAM未配置2FA"
        fi
    fi
    
    echo ""
    log_step "测试建议："
    echo "  1. 保持当前会话打开"
    echo "  2. 新开终端运行: ssh $(whoami)@localhost"
    echo "  3. 输入密码后应提示输入验证码"
    echo "  4. 验证通过后才关闭原会话"
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# ==================== 时间同步功能 ====================

# NTP服务器列表
NTP_SERVERS=(
    "ntp.aliyun.com"
    "ntp.tencent.com"
    "cn.pool.ntp.org"
    "pool.ntp.org"
    "time.google.com"
)

# 同步时间函数
sync_time_now() {
    local method=$1
    
    case $method in
        "ntpdate")
            # 安装ntpdate（如果未安装）
            if ! command -v ntpdate >/dev/null 2>&1; then
                apt-get update >/dev/null 2>&1
                apt-get install -y ntpsec-ntpdate >/dev/null 2>&1
            fi
            
            # 尝试每个NTP服务器
            for server in "${NTP_SERVERS[@]}"; do
                if timeout 5 ntpdate -u "$server" >/dev/null 2>&1; then
                    log_info "时间已通过 $server 同步"
                    return 0
                fi
            done
            return 1
            ;;
        "timesyncd")
            timedatectl set-ntp true >/dev/null 2>&1
            sleep 2
            if timedatectl status | grep -q "System clock synchronized: yes"; then
                log_info "时间已通过timesyncd同步"
                return 0
            fi
            return 1
            ;;
    esac
}

# 选项13: 安装开机时间同步服务
option_install_time_sync() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  安装开机时间同步服务"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此功能将配置系统在开机时自动同步时间"
    echo "  - 确保2FA验证码时间准确"
    echo "  - 避免因时间不准导致登录失败"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    
    # 安装必要软件
    log_step "安装必要软件包..."
    apt-get update >/dev/null 2>&1
    apt-get install -y ntpsec-ntpdate >/dev/null 2>&1
    log_info "软件包安装完成"
    
    # 创建同步脚本
    log_step "创建时间同步脚本..."
    cat > /usr/local/bin/sync-time-on-boot.sh << 'SYNCSCRIPT'
#!/bin/bash
# 开机时间同步脚本

NTP_SERVERS=(
    "ntp.aliyun.com"
    "ntp.tencent.com"
    "cn.pool.ntp.org"
    "pool.ntp.org"
    "time.google.com"
)

logger -t time-sync "开始同步系统时间"

# 等待网络
count=0
while [ $count -lt 30 ]; do
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 2 223.5.5.5 >/dev/null 2>&1; then
        logger -t time-sync "网络已连接"
        break
    fi
    sleep 1
    ((count++))
done

if [ $count -ge 30 ]; then
    logger -t time-sync "网络不可用，跳过时间同步"
    exit 1
fi

# 同步时间
for server in "${NTP_SERVERS[@]}"; do
    if timeout 5 ntpdate -u "$server" >/dev/null 2>&1; then
        logger -t time-sync "时间已通过 $server 同步"
        hwclock --systohc >/dev/null 2>&1
        logger -t time-sync "时间同步完成: $(date)"
        exit 0
    fi
done

logger -t time-sync "时间同步失败"
exit 1
SYNCSCRIPT
    
    chmod +x /usr/local/bin/sync-time-on-boot.sh
    log_info "脚本已创建: /usr/local/bin/sync-time-on-boot.sh"
    
    # 创建systemd服务
    log_step "创建systemd服务..."
    cat > /etc/systemd/system/time-sync.service << 'SYNCSERVICE'
[Unit]
Description=Sync System Time on Boot
After=network-online.target
Wants=network-online.target
Before=gdm.service lightdm.service sddm.service ssh.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sync-time-on-boot.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
SYNCSERVICE
    
    chmod 644 /etc/systemd/system/time-sync.service
    log_info "服务文件已创建"
    
    # 启用服务
    log_step "启用服务..."
    systemctl daemon-reload
    systemctl enable time-sync.service >/dev/null 2>&1
    log_info "服务已设置为开机自启动"
    
    # 启用systemd-timesyncd
    log_step "启用systemd-timesyncd..."
    timedatectl set-ntp true >/dev/null 2>&1
    
    # 配置NTP服务器
    log_step "配置NTP服务器..."
    cat > /etc/systemd/timesyncd.conf << 'TIMESYNCDCONF'
[Time]
NTP=ntp.aliyun.com ntp.tencent.com cn.pool.ntp.org
FallbackNTP=pool.ntp.org time.google.com
TIMESYNCDCONF
    
    systemctl restart systemd-timesyncd >/dev/null 2>&1
    log_info "NTP服务器配置完成"
    
    echo ""
    log_info "开机时间同步服务安装完成！"
    echo ""
    log_step "服务将在下次开机时自动运行"
    echo ""
    
    read -p "是否现在测试运行？(y/n): " test_run
    if [[ $test_run =~ ^[Yy]$ ]]; then
        echo ""
        log_step "执行时间同步..."
        /usr/local/bin/sync-time-on-boot.sh
        echo ""
        log_info "当前时间: $(date)"
    fi
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项14: 查看时间同步状态
option_view_time_status() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  时间同步状态"
    log_title "══════════════════════════════════════════"
    echo ""
    
    echo -e "${BOLD}当前时间:${NC}"
    echo ""
    echo "系统时间: $(date)"
    echo "硬件时钟: $(hwclock -r 2>/dev/null || echo '无法读取')"
    echo ""
    
    echo -e "${BOLD}系统时间配置:${NC}"
    echo ""
    timedatectl status
    echo ""
    
    echo -e "${BOLD}开机同步服务状态:${NC}"
    echo ""
    if [ -f /etc/systemd/system/time-sync.service ]; then
        systemctl status time-sync.service --no-pager
    else
        echo -e "${YELLOW}未安装${NC}"
    fi
    echo ""
    
    echo -e "${BOLD}systemd-timesyncd状态:${NC}"
    echo ""
    if systemctl is-active --quiet systemd-timesyncd; then
        echo -e "${GREEN}运行中${NC}"
        timedatectl timesync-status 2>/dev/null || echo "无详细信息"
    else
        echo -e "${RED}未运行${NC}"
    fi
    echo ""
    
    echo -e "${BOLD}NTP服务器可达性测试:${NC}"
    echo ""
    for server in "${NTP_SERVERS[@]}"; do
        echo -n "  $server ... "
        if ping -c 1 -W 2 "$server" >/dev/null 2>&1; then
            echo -e "${GREEN}可达${NC}"
        else
            echo -e "${RED}不可达${NC}"
        fi
    done
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项15: 手动同步时间
option_manual_sync_time() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  手动同步时间"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "同步前时间: $(date)"
    echo ""
    
    echo "选择同步方法："
    echo "  1. 使用 ntpdate（推荐）"
    echo "  2. 使用 systemd-timesyncd"
    echo "  3. 运行开机同步脚本"
    echo ""
    read -p "请选择 [1-3]: " sync_method
    
    echo ""
    log_step "开始同步..."
    echo ""
    
    case $sync_method in
        1)
            if sync_time_now "ntpdate"; then
                hwclock --systohc 2>/dev/null
                log_info "时间已写入硬件时钟"
            else
                log_error "同步失败"
            fi
            ;;
        2)
            if sync_time_now "timesyncd"; then
                hwclock --systohc 2>/dev/null
                log_info "时间已写入硬件时钟"
            else
                log_error "同步失败"
            fi
            ;;
        3)
            if [ -f /usr/local/bin/sync-time-on-boot.sh ]; then
                /usr/local/bin/sync-time-on-boot.sh
            else
                log_error "同步脚本未安装"
            fi
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    echo ""
    log_step "同步后时间: $(date)"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项16: 卸载时间同步服务
option_uninstall_time_sync() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  卸载时间同步服务"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "确认要卸载开机时间同步服务？"
    echo ""
    read -p "输入 yes 确认: " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    
    # 停止并禁用服务
    log_step "停止服务..."
    systemctl stop time-sync.service 2>/dev/null
    
    log_step "禁用服务..."
    systemctl disable time-sync.service 2>/dev/null
    
    # 删除文件
    log_step "删除服务文件..."
    rm -f /etc/systemd/system/time-sync.service
    
    log_step "删除脚本..."
    rm -f /usr/local/bin/sync-time-on-boot.sh
    
    # 重载systemd
    log_step "重载systemd..."
    systemctl daemon-reload
    
    echo ""
    log_info "卸载完成"
    log_warn "systemd-timesyncd仍保持启用状态"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# ==================== 安全加固功能 ====================

# 选项17: 设置GRUB密码
option_grub_password() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  设置GRUB密码保护"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将为GRUB引导加载器设置密码"
    echo "  - 防止在启动时编辑内核参数"
    echo "  - 防止进入单用户模式绕过2FA"
    echo "  - 防止通过恢复模式绕过2FA"
    echo ""
    log_error "重要：请务必记住此密码！"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    
    # 检查grub-mkpasswd-pbkdf2是否存在
    if ! command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        log_error "未找到grub-mkpasswd-pbkdf2命令"
        apt-get install -y grub2-common
    fi
    
    # 备份GRUB配置
    log_step "备份GRUB配置..."
    [ -f /etc/grub.d/40_custom ] && cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup
    [ -f /etc/default/grub ] && cp /etc/default/grub /etc/default/grub.backup
    
    # 生成密码哈希
    log_step "生成GRUB密码..."
    echo ""
    echo "请输入GRUB密码（至少8位）："
    
    grub_hash=$(grub-mkpasswd-pbkdf2 | grep "grub.pbkdf2" | awk '{print $NF}')
    
    if [ -z "$grub_hash" ]; then
        log_error "密码生成失败"
        read -p "按Enter返回..."
        return
    fi
    
    # 创建GRUB密码配置
    log_step "配置GRUB密码..."
    
    # 移除旧配置（如果存在）
    sed -i '/# GRUB密码保护/,/^$/d' /etc/grub.d/40_custom 2>/dev/null
    
    cat >> /etc/grub.d/40_custom << EOF

# GRUB密码保护 - 防止物理访问绕过2FA
set superusers="admin"
password_pbkdf2 admin $grub_hash
EOF
    
    # 禁用恢复模式
    log_step "禁用恢复模式..."
    if grep -q "GRUB_DISABLE_RECOVERY" /etc/default/grub; then
        sed -i 's/^#*GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY=true/' /etc/default/grub
    else
        echo "GRUB_DISABLE_RECOVERY=true" >> /etc/default/grub
    fi
    
    # 配置单用户模式需要密码
    log_step "配置单用户模式保护..."
    if [ -f /usr/lib/systemd/system/rescue.service ]; then
        cp /usr/lib/systemd/system/rescue.service /usr/lib/systemd/system/rescue.service.backup
        sed -i 's/ExecStart=.*/ExecStart=-\/usr\/lib\/systemd\/systemd-sulogin-shell rescue/' /usr/lib/systemd/system/rescue.service
    fi
    
    if [ -f /usr/lib/systemd/system/emergency.service ]; then
        cp /usr/lib/systemd/system/emergency.service /usr/lib/systemd/system/emergency.service.backup
        sed -i 's/ExecStart=.*/ExecStart=-\/usr\/lib\/systemd\/systemd-sulogin-shell emergency/' /usr/lib/systemd/system/emergency.service
    fi
    
    systemctl daemon-reload
    
    # 更新GRUB配置
    log_step "更新GRUB配置..."
    update-grub >/dev/null 2>&1
    
    echo ""
    log_info "GRUB密码保护已设置"
    echo ""
    log_warn "重要提示："
    echo "  1. 系统可以正常启动（不需要密码）"
    echo "  2. 编辑启动参数时需要密码"
    echo "  3. 恢复模式已禁用"
    echo "  4. 单用户模式需要root密码"
    echo "  5. 按 'e' 编辑时需要输入："
    echo "     用户名: admin"
    echo "     密码: [您刚才设置的密码]"
    echo ""
    log_error "请务必记住此密码！"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项18: 保护关键配置文件
option_protect_files() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  保护关键配置文件"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将保护关键的2FA和PAM配置文件"
    echo "  - 设置文件不可变属性（immutable）"
    echo "  - 防止被删除或修改"
    echo "  - 即使root用户也无法修改"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "设置关键文件不可变属性..."
    echo ""
    
    # 关键2FA和PAM配置文件
    PROTECTED_FILES=(
        "/etc/pam.d/sshd"
        "/etc/pam.d/login"
        "/etc/pam.d/gdm-password"
        "/etc/pam.d/lightdm"
        "/etc/pam.d/common-auth"
        "/etc/ssh/sshd_config"
    )
    
    for file in "${PROTECTED_FILES[@]}"; do
        if [ -f "$file" ]; then
            chattr +i "$file"
            log_info "已保护: $file"
        fi
    done
    
    echo ""
    log_step "注意：用户2FA配置文件不设置保护"
    log_warn "原因：.google_authenticator 每次登录后需要更新"
    echo "  - 记录已使用的验证码（防止重放攻击）"
    echo "  - 如果设置不可变，会导致登录失败"
    echo ""
    log_info "已跳过 .google_authenticator 文件的保护"
    
    # 禁用USB存储（可选）
    echo ""
    read -p "是否同时禁用USB存储设备？(y/n): " disable_usb
    
    if [[ $disable_usb =~ ^[Yy]$ ]]; then
        log_step "禁用USB存储..."
        cat > /etc/modprobe.d/disable-usb-storage.conf << 'EOF'
# 禁用USB存储设备 - 防止通过USB引导绕过系统
install usb-storage /bin/true
blacklist usb-storage
EOF
        rmmod usb_storage 2>/dev/null
        log_info "USB存储已禁用"
    fi
    
    echo ""
    log_info "关键配置文件已保护"
    echo ""
    log_warn "注意："
    echo "  - 这些文件现在无法被修改或删除"
    echo "  - 需要修改时运行菜单 [21] 移除保护"
    echo "  - 这可以防止物理访问时修改配置"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项19: 查看安全状态
option_security_status() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  系统安全状态"
    log_title "══════════════════════════════════════════"
    echo ""
    
    echo -e "${BOLD}1. GRUB密码保护:${NC}"
    if grep -q "set superusers" /etc/grub.d/40_custom 2>/dev/null; then
        echo -e "   ${GREEN}✓ 已启用 - 防止编辑启动参数${NC}"
    else
        echo -e "   ${RED}✗ 未启用 - 可通过编辑内核参数绕过${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}2. 恢复模式:${NC}"
    if grep -q "GRUB_DISABLE_RECOVERY=true" /etc/default/grub 2>/dev/null; then
        echo -e "   ${GREEN}✓ 已禁用 - 无法通过恢复模式绕过${NC}"
    else
        echo -e "   ${YELLOW}⚠ 已启用 - 存在绕过风险${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}3. 单用户模式保护:${NC}"
    if grep -q "sulogin" /usr/lib/systemd/system/rescue.service 2>/dev/null; then
        echo -e "   ${GREEN}✓ 需要密码 - 已保护${NC}"
    else
        echo -e "   ${YELLOW}⚠ 可能无密码访问${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}4. 文件保护（不可变属性）:${NC}"
    if lsattr /etc/pam.d/sshd 2>/dev/null | grep -q "i"; then
        echo -e "   ${GREEN}✓ 关键文件已保护${NC}"
        protected_count=0
        for file in /etc/pam.d/sshd /etc/pam.d/login /etc/ssh/sshd_config; do
            [ -f "$file" ] && lsattr "$file" 2>/dev/null | grep -q "i" && ((protected_count++))
        done
        echo "   已保护 $protected_count 个关键配置文件"
    else
        echo -e "   ${YELLOW}⚠ 文件未设置不可变属性${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}5. USB存储:${NC}"
    if [ -f /etc/modprobe.d/disable-usb-storage.conf ]; then
        echo -e "   ${GREEN}✓ USB存储已禁用${NC}"
    else
        echo -e "   ${YELLOW}⚠ USB存储已启用 - 可通过USB引导${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}6. 磁盘加密:${NC}"
    if lsblk -f | grep -q "crypto_LUKS"; then
        echo -e "   ${GREEN}✓ LUKS磁盘加密已启用（最佳防护）${NC}"
    else
        echo -e "   ${RED}✗ 未启用磁盘加密${NC}"
        echo "   建议：重装系统时启用全盘加密"
    fi
    
    echo ""
    echo -e "${BOLD}7. Root密码:${NC}"
    if passwd -S root 2>/dev/null | grep -q " P "; then
        echo -e "   ${GREEN}✓ 已设置${NC}"
    else
        echo -e "   ${RED}✗ 未设置 - 请立即设置！${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}安全评级:${NC}"
    
    # 计算安全分数
    score=0
    grep -q "set superusers" /etc/grub.d/40_custom 2>/dev/null && ((score+=2))
    grep -q "GRUB_DISABLE_RECOVERY=true" /etc/default/grub 2>/dev/null && ((score++))
    grep -q "sulogin" /usr/lib/systemd/system/rescue.service 2>/dev/null && ((score++))
    lsattr /etc/pam.d/sshd 2>/dev/null | grep -q "i" && ((score+=2))
    [ -f /etc/modprobe.d/disable-usb-storage.conf ] && ((score++))
    lsblk -f | grep -q "crypto_LUKS" && ((score+=3))  # 磁盘加密权重最高
    
    total=10
    if [ $score -ge 8 ]; then
        echo -e "   ${GREEN}优秀 ($score/$total)${NC} - 系统安全性很高"
    elif [ $score -ge 5 ]; then
        echo -e "   ${YELLOW}良好 ($score/$total)${NC} - 建议启用更多安全功能"
    else
        echo -e "   ${RED}较弱 ($score/$total)${NC} - 存在被物理访问绕过的风险"
    fi
    
    echo ""
    echo -e "${BOLD}防护建议:${NC}"
    
    if [ $score -lt 8 ]; then
        echo ""
        if ! grep -q "set superusers" /etc/grub.d/40_custom 2>/dev/null; then
            echo "  • 设置GRUB密码（菜单 17）"
        fi
        if ! lsattr /etc/pam.d/sshd 2>/dev/null | grep -q "i"; then
            echo "  • 保护关键配置文件（菜单 18）"
        fi
        if ! lsblk -f | grep -q "crypto_LUKS"; then
            echo "  • 启用磁盘全盘加密（重装系统时配置）"
        fi
        echo "  • 执行一键完整加固（菜单 20）"
    fi
    
    echo ""
    log_warn "最佳防护：磁盘全盘加密 + GRUB密码 + 文件保护"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项20: 一键完整加固
option_full_hardening() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  一键完整安全加固"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将执行所有安全加固措施："
    echo "  ✓ 设置GRUB密码保护"
    echo "  ✓ 禁用恢复模式"
    echo "  ✓ 配置单用户模式需要密码"
    echo "  ✓ 保护关键配置文件（不可变）"
    echo "  ✓ 禁用USB存储设备"
    echo ""
    log_error "请务必记住GRUB密码！"
    echo ""
    read -p "确认执行完整加固？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "============================================"
    log_step "  开始安全加固..."
    log_step "============================================"
    echo ""
    
    # 1. GRUB密码
    log_step "[1/5] 设置GRUB密码保护..."
    echo ""
    echo "请输入GRUB密码（至少8位）："
    grub_hash=$(grub-mkpasswd-pbkdf2 | grep "grub.pbkdf2" | awk '{print $NF}')
    
    if [ -n "$grub_hash" ]; then
        [ -f /etc/grub.d/40_custom ] && cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup
        sed -i '/# GRUB密码保护/,/^$/d' /etc/grub.d/40_custom 2>/dev/null
        
        cat >> /etc/grub.d/40_custom << EOF

# GRUB密码保护 - 防止物理访问绕过2FA
set superusers="admin"
password_pbkdf2 admin $grub_hash
EOF
        log_info "GRUB密码已设置"
    else
        log_error "GRUB密码设置失败"
    fi
    
    # 2. 禁用恢复模式
    echo ""
    log_step "[2/5] 禁用恢复模式..."
    [ -f /etc/default/grub ] && cp /etc/default/grub /etc/default/grub.backup
    if grep -q "GRUB_DISABLE_RECOVERY" /etc/default/grub; then
        sed -i 's/^#*GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY=true/' /etc/default/grub
    else
        echo "GRUB_DISABLE_RECOVERY=true" >> /etc/default/grub
    fi
    log_info "恢复模式已禁用"
    
    # 3. 单用户模式保护
    echo ""
    log_step "[3/5] 配置单用户模式保护..."
    if [ -f /usr/lib/systemd/system/rescue.service ]; then
        cp /usr/lib/systemd/system/rescue.service /usr/lib/systemd/system/rescue.service.backup 2>/dev/null
        sed -i 's/ExecStart=.*/ExecStart=-\/usr\/lib\/systemd\/systemd-sulogin-shell rescue/' /usr/lib/systemd/system/rescue.service
    fi
    if [ -f /usr/lib/systemd/system/emergency.service ]; then
        cp /usr/lib/systemd/system/emergency.service /usr/lib/systemd/system/emergency.service.backup 2>/dev/null
        sed -i 's/ExecStart=.*/ExecStart=-\/usr\/lib\/systemd\/systemd-sulogin-shell emergency/' /usr/lib/systemd/system/emergency.service
    fi
    systemctl daemon-reload
    log_info "单用户模式已保护"
    
    # 4. 文件保护
    echo ""
    log_step "[4/5] 保护关键配置文件..."
    PROTECTED_FILES=(
        "/etc/pam.d/sshd"
        "/etc/pam.d/login"
        "/etc/pam.d/gdm-password"
        "/etc/pam.d/lightdm"
        "/etc/pam.d/common-auth"
        "/etc/ssh/sshd_config"
    )
    for file in "${PROTECTED_FILES[@]}"; do
        [ -f "$file" ] && chattr +i "$file" 2>/dev/null
    done
    # 注意：不保护 .google_authenticator 文件（需要每次登录后更新）
    log_info "关键文件已保护（.google_authenticator除外）"
    
    # 5. 禁用USB
    echo ""
    log_step "[5/5] 禁用USB存储..."
    cat > /etc/modprobe.d/disable-usb-storage.conf << 'EOF'
install usb-storage /bin/true
blacklist usb-storage
EOF
    rmmod usb_storage 2>/dev/null
    log_info "USB存储已禁用"
    
    # 更新GRUB
    echo ""
    log_step "更新GRUB配置..."
    update-grub >/dev/null 2>&1
    
    echo ""
    log_step "============================================"
    log_info "  安全加固完成！"
    log_step "============================================"
    echo ""
    log_warn "重要提示："
    echo "  1. 请记住GRUB密码（用户名：admin）"
    echo "  2. 文件已保护，需要修改时运行菜单 [21]"
    echo "  3. 建议重启系统测试"
    echo "  4. 最佳防护：重装系统时启用全盘加密"
    echo "  5. 查看安全状态：菜单 [19]"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项21: 移除文件保护
option_remove_protection() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  移除文件保护"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将移除文件不可变属性"
    echo "  - 允许修改关键配置文件"
    echo "  - 移除文件保护后可以修改PAM配置"
    echo ""
    read -p "确认要移除保护？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_step "移除不可变属性..."
    
    # 移除不可变属性
    chattr -i /etc/pam.d/* 2>/dev/null
    chattr -i /etc/ssh/sshd_config 2>/dev/null
    
    # 清理可能之前设置的 .google_authenticator 保护
    chattr -i /home/*/.google_authenticator 2>/dev/null
    chattr -i /root/.google_authenticator 2>/dev/null
    
    log_info "PAM和SSH配置文件保护已移除"
    log_info ".google_authenticator 文件保护已清理（如果之前设置过）"
    log_warn "现在可以修改配置文件"
    echo ""
    log_step "注意：.google_authenticator 文件不应设置保护"
    log_step "修改完成后，建议重新启用保护（菜单 18）"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项22: SSH安全加固
option_ssh_hardening() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  SSH安全加固（仅密钥+2FA）"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此操作将配置SSH为最高安全级别："
    echo "  - 禁用密码登录（仅允许密钥登录）"
    echo "  - 强制使用密钥+2FA双重认证"
    echo "  - 禁用root直接登录"
    echo "  - 禁用空密码"
    echo "  - 限制登录尝试"
    echo ""
    log_error "配置前请确保已设置SSH密钥！"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    
    # 检查当前用户是否有SSH密钥
    current_user=$(logname 2>/dev/null || echo $SUDO_USER)
    if [ -n "$current_user" ]; then
        user_home=$(eval echo ~$current_user)
        if [ ! -f "$user_home/.ssh/authorized_keys" ]; then
            log_warn "未检测到 $current_user 的SSH公钥"
            echo ""
            echo "请先为用户配置SSH密钥："
            echo "  1. 在客户端生成密钥对："
            echo "     ssh-keygen -t ed25519 -C \"your_email@example.com\""
            echo ""
            echo "  2. 复制公钥到服务器："
            echo "     ssh-copy-id $current_user@localhost"
            echo ""
            read -p "现在配置吗？(y/n): " setup_key
            
            if [[ ! $setup_key =~ ^[Yy]$ ]]; then
                log_warn "请先配置SSH密钥后再运行此功能"
                read -p "按Enter返回..."
                return
            fi
        fi
    fi
    
    # 备份SSH配置
    log_step "备份SSH配置..."
    [ -f /etc/ssh/sshd_config ] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config.hardening-backup
    
    # 移除文件保护（如果有）
    chattr -i /etc/ssh/sshd_config 2>/dev/null
    
    # 创建安全配置
    log_step "配置SSH安全参数..."
    
    cat > /etc/ssh/sshd_config.d/99-security-hardening.conf << 'EOF'
# SSH安全加固配置 - 参考"编程随想"安全指南

# 禁用密码认证 - 仅允许密钥
PasswordAuthentication no
ChallengeResponseAuthentication yes
PubkeyAuthentication yes

# 密钥+2FA双重认证
AuthenticationMethods publickey,keyboard-interactive

# 禁用root直接登录
PermitRootLogin no

# 禁用空密码
PermitEmptyPasswords no

# 限制登录尝试
MaxAuthTries 3
MaxSessions 3

# 登录超时
LoginGraceTime 30

# 禁用不安全的认证方式
HostbasedAuthentication no
IgnoreRhosts yes
PermitUserEnvironment no

# 禁用X11转发（如不需要）
X11Forwarding no

# 协议版本
Protocol 2

# 日志级别
LogLevel VERBOSE

# 强制使用强加密算法
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# 客户端活动检测（防止连接僵死）
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    
    log_info "SSH安全配置已更新"
    
    # 限制SSH访问用户（可选）
    echo ""
    read -p "是否限制特定用户可SSH登录？(y/n): " limit_users
    
    if [[ $limit_users =~ ^[Yy]$ ]]; then
        echo "请输入允许SSH登录的用户名（空格分隔）："
        read -p "用户名: " allowed_users
        
        if [ -n "$allowed_users" ]; then
            echo "AllowUsers $allowed_users" >> /etc/ssh/sshd_config.d/99-security-hardening.conf
            log_info "已限制SSH访问用户: $allowed_users"
        fi
    fi
    
    # 限制SSH来源IP（可选）
    echo ""
    read -p "是否限制SSH连接来源IP？(y/n): " limit_ip
    
    if [[ $limit_ip =~ ^[Yy]$ ]]; then
        echo "请输入允许的IP或网段（如：192.168.1.0/24）："
        read -p "IP/网段: " allowed_ip
        
        if [ -n "$allowed_ip" ]; then
            log_step "配置防火墙规则..."
            # 使用ufw
            if command -v ufw &> /dev/null; then
                ufw delete allow ssh 2>/dev/null
                ufw allow from "$allowed_ip" to any port 22
                log_info "已限制SSH来源: $allowed_ip"
            fi
        fi
    fi
    
    # 测试配置
    log_step "测试SSH配置..."
    if sshd -t 2>/dev/null; then
        log_info "SSH配置测试通过"
        
        # 重启SSH
        log_step "重启SSH服务..."
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        log_info "SSH服务已重启"
    else
        log_error "SSH配置测试失败！"
        sshd -t
        echo ""
        log_step "恢复备份配置..."
        [ -f /etc/ssh/sshd_config.hardening-backup ] && cp /etc/ssh/sshd_config.hardening-backup /etc/ssh/sshd_config
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    log_info "SSH安全加固完成！"
    echo ""
    log_warn "重要提示："
    echo "  1. 密码登录已禁用，只能使用密钥+2FA"
    echo "  2. 请在新终端测试密钥登录"
    echo "  3. 确保密钥登录成功后再关闭当前会话"
    echo "  4. 测试命令: ssh -i ~/.ssh/id_ed25519 user@server"
    echo ""
    log_error "如果无法登录，请从控制台恢复配置！"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项23: 隐私保护增强
option_privacy_enhancement() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  隐私保护增强"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_warn "此功能将增强系统隐私保护："
    echo "  - MAC地址随机化"
    echo "  - 禁用不必要的网络服务"
    echo "  - 清理系统日志中的敏感信息"
    echo "  - 配置更严格的文件权限"
    echo "  - 禁用遥测和报告"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    
    # MAC地址随机化
    log_step "[1/6] 配置MAC地址随机化..."
    
    cat > /etc/NetworkManager/conf.d/wifi-mac-randomization.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
    
    systemctl restart NetworkManager 2>/dev/null
    log_info "MAC地址随机化已启用"
    
    # 禁用不必要的服务
    echo ""
    log_step "[2/6] 禁用不必要的服务..."
    
    # 禁用蓝牙（如果不需要）
    systemctl stop bluetooth 2>/dev/null
    systemctl disable bluetooth 2>/dev/null
    log_info "蓝牙服务已禁用"
    
    # 禁用CUPS打印服务（如果不需要）
    systemctl stop cups 2>/dev/null
    systemctl disable cups 2>/dev/null
    log_info "打印服务已禁用"
    
    # 禁用Avahi（mDNS）
    systemctl stop avahi-daemon 2>/dev/null
    systemctl disable avahi-daemon 2>/dev/null
    log_info "Avahi已禁用"
    
    # 配置日志保留策略
    echo ""
    log_step "[3/6] 配置日志保留策略..."
    
    cat > /etc/logrotate.d/privacy-enhanced << 'EOF'
/var/log/auth.log {
    rotate 3
    weekly
    compress
    delaycompress
    missingok
    notifempty
}

/var/log/syslog {
    rotate 3
    weekly
    compress
    delaycompress
    missingok
    notifempty
}
EOF
    
    log_info "日志保留策略已配置"
    
    # 配置更严格的umask
    echo ""
    log_step "[4/6] 配置更严格的文件权限..."
    
    # 设置默认umask为027（新文件权限750）
    if ! grep -q "umask 027" /etc/profile; then
        echo "umask 027" >> /etc/profile
    fi
    
    if ! grep -q "umask 027" /etc/bash.bashrc; then
        echo "umask 027" >> /etc/bash.bashrc
    fi
    
    log_info "默认文件权限已加强"
    
    # 禁用core dumps
    echo ""
    log_step "[5/6] 禁用core dumps..."
    
    cat > /etc/security/limits.d/no-core-dumps.conf << 'EOF'
* hard core 0
* soft core 0
EOF
    
    echo "* hard core 0" >> /etc/security/limits.conf
    echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    
    log_info "Core dumps已禁用"
    
    # 禁用不必要的内核模块
    echo ""
    log_step "[6/6] 禁用不必要的内核模块..."
    
    cat > /etc/modprobe.d/privacy-blacklist.conf << 'EOF'
# 禁用不必要的协议和模块
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true

# 禁用不常用的文件系统
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF
    
    log_info "不必要的内核模块已禁用"
    
    # 清理历史命令（可选）
    echo ""
    read -p "是否清理所有用户的命令历史？(y/n): " clear_history
    
    if [[ $clear_history =~ ^[Yy]$ ]]; then
        log_step "清理命令历史..."
        
        for home in /home/*; do
            [ -f "$home/.bash_history" ] && > "$home/.bash_history"
            [ -f "$home/.zsh_history" ] && > "$home/.zsh_history"
        done
        
        [ -f /root/.bash_history ] && > /root/.bash_history
        [ -f /root/.zsh_history ] && > /root/.zsh_history
        
        log_info "命令历史已清理"
    fi
    
    # 配置自动清理历史
    echo ""
    read -p "是否配置退出时自动清理命令历史？(y/n): " auto_clear
    
    if [[ $auto_clear =~ ^[Yy]$ ]]; then
        log_step "配置自动清理..."
        
        for home in /home/*; do
            username=$(basename "$home")
            if [ -f "$home/.bashrc" ]; then
                if ! grep -q "HISTSIZE=0" "$home/.bashrc"; then
                    cat >> "$home/.bashrc" << 'EOF'

# 隐私保护 - 不保存命令历史
HISTSIZE=0
HISTFILESIZE=0
unset HISTFILE
EOF
                    chown "$username:$username" "$home/.bashrc"
                fi
            fi
        done
        
        log_info "自动清理已配置"
    fi
    
    echo ""
    log_info "隐私保护增强完成！"
    echo ""
    log_step "已完成的配置："
    echo "  ✓ MAC地址随机化"
    echo "  ✓ 禁用不必要的服务"
    echo "  ✓ 日志保留策略"
    echo "  ✓ 更严格的文件权限"
    echo "  ✓ 禁用core dumps"
    echo "  ✓ 禁用不必要的内核模块"
    echo ""
    log_warn "建议重启系统使所有更改生效"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 主循环
main() {
    check_root
    
    while true; do
        show_main_menu
        read choice
        
        case $choice in
            1)
                option_full_setup
                ;;
            2)
                option_single_user
                ;;
            3)
                option_batch_users
                ;;
            4)
                option_enforce
                ;;
            5)
                option_view_status
                ;;
            6)
                option_view_user_config
                ;;
            7)
                option_view_recovery_codes
                ;;
            8)
                option_disable_enforcement
                ;;
            9)
                option_remove_2fa
                ;;
            10)
                option_rollback
                ;;
            11)
                option_view_logs
                ;;
            12)
                option_test_config
                ;;
            13)
                option_install_time_sync
                ;;
            14)
                option_view_time_status
                ;;
            15)
                option_manual_sync_time
                ;;
            16)
                option_uninstall_time_sync
                ;;
            17)
                option_grub_password
                ;;
            18)
                option_protect_files
                ;;
            19)
                option_security_status
                ;;
            20)
                option_full_hardening
                ;;
            21)
                option_remove_protection
                ;;
            22)
                option_ssh_hardening
                ;;
            23)
                option_privacy_enhancement
                ;;
            0)
                clear
                echo ""
                log_info "感谢使用 2FA 管理系统"
                echo ""
                exit 0
                ;;
            *)
                log_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main


