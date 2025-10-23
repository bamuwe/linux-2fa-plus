#!/bin/bash
################################################################################
#
# Linux 2FA 管理系统 v2.0
#
# 功能：
#   - 2FA配置与管理（SSH、TTY、GUI）
#   - 时间同步服务
#   - 安全加固功能
#   - 防溯源工具（内存文件系统、安全删除）
#   - 故障诊断与修复
#
# 作者：基于编程随想的安全经验
# 更新：2025-10-23
# 许可：请遵守当地法律法规
#
################################################################################

#==============================================================================
# 全局变量和颜色定义
#==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'       # No Color
BOLD='\033[1m'

#==============================================================================
# 工具函数
#==============================================================================

# 日志输出函数
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

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

#==============================================================================
# 用户界面
#==============================================================================

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
    echo -e "${MAGENTA}═══ 故障诊断 ═══${NC}"
    echo -e "${BLUE}[24]${NC} 诊断并修复2FA问题"
    echo ""
    echo -e "${MAGENTA}═══ 防溯源功能 ═══${NC}"
    echo -e "${GREEN}[25]${NC} 内存文件系统管理"
    echo -e "${GREEN}[26]${NC} 安全删除文件"
    echo -e "${GREEN}[27]${NC} 元数据清理工具"
    echo -e "${GREEN}[28]${NC} 隐私浏览器启动器"
    echo ""
    echo -e "${YELLOW}[0]${NC} 退出"
    echo ""
    echo -n "请选择操作 [0-28]: "
}

#==============================================================================
# 核心功能 - 配置与管理
#==============================================================================

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
        
        # 确保 .google_authenticator 文件权限正确
        if [ -f "$user_home/.google_authenticator" ]; then
            # 设置正确的权限和归属（关键！）
            chown "$username:$username" "$user_home/.google_authenticator"
            chmod 600 "$user_home/.google_authenticator"
            
            # 移除可能存在的不可变属性
            chattr -i "$user_home/.google_authenticator" 2>/dev/null
            
            log_info "已设置 .google_authenticator 权限为 600"
        fi
        
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
            
            # 验证文件权限
            actual_perm=$(stat -c "%a" "$user_home/.google_authenticator")
            if [ "$actual_perm" = "600" ]; then
                log_info "权限验证通过: $actual_perm"
            else
                log_warn "权限异常: $actual_perm (应该是600)"
            fi
            
            return 0
        else
            log_error ".google_authenticator 文件未找到"
            return 1
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

# 重启显示管理器
restart_display_manager() {
    log_step "重启显示管理器..."
    
    local restarted=false
    
    # 尝试重启各种显示管理器
    if systemctl is-active --quiet gdm 2>/dev/null; then
        systemctl restart gdm && restarted=true
        log_info "GDM 已重启"
    elif systemctl is-active --quiet gdm3 2>/dev/null; then
        systemctl restart gdm3 && restarted=true
        log_info "GDM3 已重启"
    elif systemctl is-active --quiet lightdm 2>/dev/null; then
        systemctl restart lightdm && restarted=true
        log_info "LightDM 已重启"
    elif systemctl is-active --quiet sddm 2>/dev/null; then
        systemctl restart sddm && restarted=true
        log_info "SDDM 已重启"
    fi
    
    if [ "$restarted" = false ]; then
        log_warn "未检测到运行中的显示管理器，无需重启"
        return 1
    fi
    
    return 0
}

# 配置GUI登录2FA
configure_gui_2fa() {
    log_step "配置GUI图形界面登录的2FA..."
    
    local configured=false
    local need_restart=false
    
    # GDM (GNOME Display Manager)
    if [ -f /etc/pam.d/gdm-password ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/gdm-password 2>/dev/null; then
            log_warn "GDM 2FA 已配置"
        else
            # 在 @include common-auth 之后添加 2FA
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/gdm-password
            log_info "GDM (GNOME) 2FA已配置"
            configured=true
            need_restart=true
        fi
    fi
    
    # LightDM (轻量级显示管理器)
    if [ -f /etc/pam.d/lightdm ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/lightdm 2>/dev/null; then
            log_warn "LightDM 2FA 已配置"
        else
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/lightdm
            log_info "LightDM 2FA已配置"
            configured=true
            need_restart=true
        fi
    fi
    
    # SDDM (Simple Desktop Display Manager - KDE)
    if [ -f /etc/pam.d/sddm ]; then
        if grep -q "pam_google_authenticator.so" /etc/pam.d/sddm 2>/dev/null; then
            log_warn "SDDM 2FA 已配置"
        else
            sed -i '/^@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/sddm
            log_info "SDDM (KDE) 2FA已配置"
            configured=true
            need_restart=true
        fi
    fi
    
    if [ "$configured" = false ]; then
        log_warn "未检测到GUI显示管理器"
        return 1
    fi
    
    # 如果配置有更新，重启显示管理器
    if [ "$need_restart" = true ]; then
        echo ""
        log_warn "GUI显示管理器需要重启以应用配置"
        read -p "是否现在重启显示管理器？(y/n): " restart_dm
        
        if [[ $restart_dm =~ ^[Yy]$ ]]; then
            restart_display_manager
        else
            log_warn "请稍后手动重启显示管理器"
            log_step "重启命令: systemctl restart gdm (或 lightdm/sddm)"
        fi
    fi
    
    return 0
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
    echo "  - 禁用IPv6（防止IP泄露）"
    echo "  - DNS防泄露配置"
    echo "  - 禁用不必要的网络服务"
    echo "  - Swap安全管理（防内存数据泄露）"
    echo "  - 清理系统日志和历史记录"
    echo "  - 配置更严格的文件权限"
    echo ""
    read -p "是否继续？(y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_warn "操作已取消"
        read -p "按Enter返回..."
        return
    fi
    
    echo ""
    
    # MAC地址随机化
    log_step "[1/8] 配置MAC地址随机化..."
    
    cat > /etc/NetworkManager/conf.d/wifi-mac-randomization.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
    
    systemctl restart NetworkManager 2>/dev/null
    log_info "MAC地址随机化已启用"
    
    # 禁用IPv6（防止IP泄露）
    echo ""
    log_step "[2/8] 禁用IPv6（防止IP泄露）..."
    
    echo ""
    log_warn "IPv6可能导致以下隐私风险："
    echo "  • VPN/Tor下IPv6流量可能绕过代理"
    echo "  • 暴露真实IPv6地址"
    echo "  • DNS泄露"
    echo ""
    read -p "是否禁用IPv6？(y/n): " disable_ipv6
    
    if [[ $disable_ipv6 =~ ^[Yy]$ ]]; then
        # 立即禁用
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1
        
        # 永久禁用
        if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
            cat >> /etc/sysctl.conf << 'EOF'

# 禁用IPv6 - 防止IP泄露
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
            sysctl -p >/dev/null 2>&1
            log_info "IPv6已永久禁用"
        else
            log_warn "IPv6禁用规则已存在"
        fi
        
        # 验证
        ipv6_status=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
        if [ "$ipv6_status" = "1" ]; then
            log_info "✓ IPv6已成功禁用"
        else
            log_warn "IPv6禁用可能失败，请检查"
        fi
    else
        log_info "已跳过IPv6禁用"
    fi
    
    # DNS防泄露配置
    echo ""
    log_step "[3/9] DNS防泄露配置..."
    
    echo ""
    log_warn "DNS泄露风险："
    echo "  • ISP可以看到你访问的域名"
    echo "  • VPN可能不处理DNS查询"
    echo "  • 暴露浏览历史"
    echo ""
    read -p "是否配置DNS防泄露保护？(y/n): " dns_protect
    
    if [[ $dns_protect =~ ^[Yy]$ ]]; then
        echo ""
        echo "选择DNS方案："
        echo "  [1] 使用加密DNS（Cloudflare 1.1.1.1）"
        echo "  [2] 仅使用127.0.0.1（需配合Tor）"
        echo "  [3] 自定义DNS服务器"
        echo "  [4] 跳过"
        read -p "选择 [1-4]: " dns_choice
        
        case $dns_choice in
            1)
                # Cloudflare DNS
                log_step "配置Cloudflare加密DNS..."
                
                # 备份
                cp /etc/resolv.conf /etc/resolv.conf.backup
                
                # 配置DNS
                cat > /etc/resolv.conf << 'EOF'
# Cloudflare DNS - 隐私保护
nameserver 1.1.1.1
nameserver 1.0.0.1
# Google DNS（备用）
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
                
                # 防止被NetworkManager覆盖
                chattr +i /etc/resolv.conf
                
                log_info "DNS已配置为Cloudflare（1.1.1.1）"
                log_step "备份: /etc/resolv.conf.backup"
                ;;
                
            2)
                # 本地DNS（Tor）
                log_step "配置本地DNS（Tor）..."
                
                if systemctl is-active --quiet tor 2>/dev/null; then
                    cp /etc/resolv.conf /etc/resolv.conf.backup
                    
                    cat > /etc/resolv.conf << 'EOF'
# 使用Tor提供的DNS
nameserver 127.0.0.1
EOF
                    chattr +i /etc/resolv.conf
                    
                    log_info "DNS已配置为本地Tor"
                    log_warn "需要Tor配置DNSPort 127.0.0.1:53"
                else
                    log_error "Tor未运行，请先安装并启动Tor"
                fi
                ;;
                
            3)
                # 自定义DNS
                log_step "配置自定义DNS..."
                read -p "DNS服务器1: " dns1
                read -p "DNS服务器2（可选）: " dns2
                
                if [ -n "$dns1" ]; then
                    cp /etc/resolv.conf /etc/resolv.conf.backup
                    
                    echo "nameserver $dns1" > /etc/resolv.conf
                    [ -n "$dns2" ] && echo "nameserver $dns2" >> /etc/resolv.conf
                    
                    chattr +i /etc/resolv.conf
                    log_info "DNS已自定义配置"
                fi
                ;;
                
            4)
                log_info "已跳过DNS配置"
                ;;
        esac
    else
        log_info "已跳过DNS防泄露"
    fi
    
    # 禁用不必要的服务
    echo ""
    log_step "[4/9] 禁用不必要的服务..."
    
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
    log_step "[5/9] 配置日志保留策略..."
    
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
    log_step "[6/9] 配置更严格的文件权限..."
    
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
    log_step "[7/9] 禁用core dumps..."
    
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
    log_step "[8/9] 禁用不必要的内核模块..."
    
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
    
    # Swap安全管理（新增）
    echo ""
    log_step "[9/9] Swap安全管理..."
    
    # 检查当前swap状态
    swap_info=$(swapon --show 2>/dev/null)
    if [ -n "$swap_info" ]; then
        echo ""
        echo "当前Swap状态:"
        swapon --show
        echo ""
        swap_size=$(free -h | grep Swap | awk '{print $2}')
        echo "Swap总大小: $swap_size"
        echo ""
        
        log_warn "Swap分区可能包含敏感内存数据"
        echo "  风险: 系统休眠时内存数据写入Swap"
        echo "  建议: 禁用Swap（最安全）或加密Swap"
        echo ""
        echo "选择操作："
        echo "  [1] 禁用Swap（推荐，最安全）"
        echo "  [2] 加密Swap（高级，需重启）"
        echo "  [3] 跳过（保持现状）"
        echo ""
        read -p "请选择 [1-3]: " swap_choice
        
        case $swap_choice in
            1)
                # 禁用Swap
                echo ""
                log_step "禁用Swap分区..."
                
                log_warn "禁用Swap可能影响系统性能，确保有足够的RAM"
                read -p "确认禁用Swap？(y/n): " confirm_disable
                
                if [[ $confirm_disable =~ ^[Yy]$ ]]; then
                    # 立即禁用
                    swapoff -a
                    
                    if [ $? -eq 0 ]; then
                        log_info "Swap已禁用"
                        
                        # 从fstab中移除swap
                        cp /etc/fstab /etc/fstab.swap-backup
                        sed -i '/swap/d' /etc/fstab
                        log_info "已从/etc/fstab移除swap配置"
                        
                        # 验证
                        if swapon --show 2>/dev/null | grep -q .; then
                            log_warn "部分swap仍在运行"
                        else
                            log_info "✓ Swap完全禁用"
                        fi
                        
                        echo ""
                        log_step "备份文件: /etc/fstab.swap-backup"
                        log_step "如需恢复: sudo cp /etc/fstab.swap-backup /etc/fstab"
                    else
                        log_error "禁用失败"
                    fi
                else
                    log_info "已跳过Swap禁用"
                fi
                ;;
                
            2)
                # 加密Swap
                echo ""
                log_step "配置Swap加密..."
                
                log_warn "此功能将配置加密swap，需要重启系统"
                echo ""
                echo "加密方法："
                echo "  • 使用dm-crypt加密swap分区"
                echo "  • 每次启动时生成随机密钥"
                echo "  • 无法休眠到磁盘（hibernation）"
                echo ""
                read -p "确认配置加密swap？(y/n): " confirm_encrypt
                
                if [[ $confirm_encrypt =~ ^[Yy]$ ]]; then
                    # 获取swap设备
                    swap_device=$(swapon --show --noheadings | awk '{print $1}' | head -1)
                    
                    if [ -z "$swap_device" ]; then
                        log_error "未找到swap设备"
                    else
                        echo "Swap设备: $swap_device"
                        echo ""
                        
                        # 禁用当前swap
                        swapoff -a
                        
                        # 配置crypttab
                        if ! grep -q "cryptswap" /etc/crypttab 2>/dev/null; then
                            echo "# 加密swap - 防止内存数据泄露" >> /etc/crypttab
                            echo "cryptswap $swap_device /dev/urandom swap,cipher=aes-xts-plain64,size=256" >> /etc/crypttab
                            log_info "已配置 /etc/crypttab"
                        else
                            log_warn "cryptswap已存在于/etc/crypttab"
                        fi
                        
                        # 备份fstab
                        cp /etc/fstab /etc/fstab.swap-crypt-backup
                        
                        # 修改fstab
                        sed -i "s|$swap_device|/dev/mapper/cryptswap|g" /etc/fstab
                        log_info "已更新 /etc/fstab"
                        
                        echo ""
                        log_info "Swap加密配置完成"
                        log_warn "⚠️  需要重启系统才能生效"
                        echo ""
                        log_step "备份文件: /etc/fstab.swap-crypt-backup"
                        log_step "如需恢复: sudo cp /etc/fstab.swap-crypt-backup /etc/fstab"
                    fi
                else
                    log_info "已跳过Swap加密"
                fi
                ;;
                
            3)
                log_info "已跳过Swap管理"
                ;;
                
            *)
                log_info "无效选择，已跳过"
                ;;
        esac
    else
        log_info "系统未启用Swap，无需处理"
    fi
    
    # 清理历史命令（可选）
    echo ""
    log_step "额外: 深度痕迹清理（可选）"
    echo ""
    read -p "是否清理所有用户的历史痕迹？(y/n): " clear_history
    
    if [[ $clear_history =~ ^[Yy]$ ]]; then
        log_step "正在清理所有用户痕迹..."
        
        for home in /home/*; do
            # Shell历史
            [ -f "$home/.bash_history" ] && > "$home/.bash_history"
            [ -f "$home/.zsh_history" ] && > "$home/.zsh_history"
            
            # 程序历史
            [ -f "$home/.python_history" ] && rm -f "$home/.python_history"
            [ -f "$home/.mysql_history" ] && rm -f "$home/.mysql_history"
            [ -f "$home/.psql_history" ] && rm -f "$home/.psql_history"
            [ -f "$home/.sqlite_history" ] && rm -f "$home/.sqlite_history"
            
            # 编辑器和工具历史
            [ -f "$home/.lesshst" ] && rm -f "$home/.lesshst"
            [ -f "$home/.viminfo" ] && rm -f "$home/.viminfo"
            [ -f "$home/.wget-hsts" ] && rm -f "$home/.wget-hsts"
            
            # SSH历史
            [ -f "$home/.ssh/known_hosts" ] && > "$home/.ssh/known_hosts"
            
            # 最近文件记录
            [ -f "$home/.local/share/recently-used.xbel" ] && rm -f "$home/.local/share/recently-used.xbel"
            [ -f "$home/.recently-used" ] && rm -f "$home/.recently-used"
            
            # 回收站
            [ -d "$home/.local/share/Trash" ] && rm -rf "$home/.local/share/Trash/*" 2>/dev/null
            
            # 缓存
            [ -d "$home/.cache" ] && rm -rf "$home/.cache/*" 2>/dev/null
        done
        
        # Root用户
        [ -f /root/.bash_history ] && > /root/.bash_history
        [ -f /root/.zsh_history ] && > /root/.zsh_history
        [ -f /root/.python_history ] && rm -f /root/.python_history
        [ -f /root/.mysql_history ] && rm -f /root/.mysql_history
        [ -f /root/.psql_history ] && rm -f /root/.psql_history
        [ -f /root/.sqlite_history ] && rm -f /root/.sqlite_history
        [ -f /root/.lesshst ] && rm -f /root/.lesshst
        [ -f /root/.viminfo ] && rm -f /root/.viminfo
        [ -f /root/.wget-hsts ] && rm -f /root/.wget-hsts
        [ -f /root/.ssh/known_hosts ] && > /root/.ssh/known_hosts
        [ -d /root/.cache ] && rm -rf /root/.cache/* 2>/dev/null
        
        log_info "所有用户痕迹已清理"
        echo ""
        log_step "已清理的内容："
        echo "  ✓ Shell历史 (bash, zsh)"
        echo "  ✓ 程序历史 (python, mysql, psql, sqlite)"
        echo "  ✓ 编辑器历史 (vim, less)"
        echo "  ✓ 工具历史 (wget)"
        echo "  ✓ SSH known_hosts"
        echo "  ✓ 最近文件记录"
        echo "  ✓ 回收站"
        echo "  ✓ 用户缓存"
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
    echo "  ✓ IPv6禁用（防止IP泄露）"
    echo "  ✓ DNS防泄露配置"
    echo "  ✓ 禁用不必要的服务（蓝牙、打印、mDNS）"
    echo "  ✓ 日志保留策略（3周轮换）"
    echo "  ✓ 更严格的文件权限（umask 027）"
    echo "  ✓ 禁用core dumps"
    echo "  ✓ 禁用不必要的内核模块"
    echo "  ✓ Swap安全管理"
    echo "  ✓ 深度痕迹清理（17项）"
    echo ""
    log_warn "建议重启系统使所有更改生效"
    echo ""
    
    read -p "按Enter返回主菜单..."
}

# 选项24: 诊断并修复2FA问题
option_diagnose_and_fix() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  2FA问题诊断与修复"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "开始诊断2FA配置..."
    echo ""
    
    # 1. 检测显示管理器
    echo -e "${BOLD}[1/6] 检测显示管理器${NC}"
    DM=""
    PAM_FILE=""
    
    if systemctl is-active --quiet gdm || systemctl is-active --quiet gdm3; then
        DM="GDM (GNOME)"
        PAM_FILE="/etc/pam.d/gdm-password"
        log_info "检测到: $DM"
    elif systemctl is-active --quiet lightdm; then
        DM="LightDM"
        PAM_FILE="/etc/pam.d/lightdm"
        log_info "检测到: $DM"
    elif systemctl is-active --quiet sddm; then
        DM="SDDM (KDE)"
        PAM_FILE="/etc/pam.d/sddm"
        log_info "检测到: $DM"
    else
        log_warn "未检测到运行中的显示管理器"
    fi
    echo ""
    
    # 2. 检查PAM配置
    echo -e "${BOLD}[2/6] 检查PAM配置${NC}"
    issues_found=0
    
    if [ -n "$PAM_FILE" ] && [ -f "$PAM_FILE" ]; then
        # 检查 common-auth
        if grep -q "^@include common-auth" "$PAM_FILE"; then
            log_info "@include common-auth 存在（正常）"
        else
            log_error "@include common-auth 缺失！"
            ((issues_found++))
        fi
        
        # 检查 2FA 配置
        if grep -q "pam_google_authenticator.so" "$PAM_FILE"; then
            log_info "2FA模块已配置"
            
            # 检查 nullok
            if grep "pam_google_authenticator.so" "$PAM_FILE" | grep -q "nullok"; then
                log_info "nullok 参数存在"
            else
                log_warn "nullok 参数缺失（强制模式）"
            fi
        else
            log_warn "2FA模块未配置"
        fi
        
        # 检查文件权限
        perm=$(stat -c "%a" "$PAM_FILE")
        if [ "$perm" = "644" ]; then
            log_info "PAM文件权限正确: $perm"
        else
            log_warn "PAM文件权限异常: $perm (应该是644)"
            ((issues_found++))
        fi
    fi
    echo ""
    
    # 3. 检查用户2FA文件
    echo -e "${BOLD}[3/6] 检查用户2FA配置文件${NC}"
    
    fixed_count=0
    for ga_file in /home/*/.google_authenticator /root/.google_authenticator; do
        if [ -f "$ga_file" ]; then
            username=$(echo "$ga_file" | cut -d'/' -f3)
            if [ "$username" = "root" ]; then
                username="root"
            fi
            
            perm=$(stat -c "%a" "$ga_file")
            owner=$(stat -c "%U:%G" "$ga_file")
            
            echo "  用户: $username"
            echo "    文件: $ga_file"
            echo "    权限: $perm"
            echo "    归属: $owner"
            
            needs_fix=false
            
            # 检查权限
            if [ "$perm" != "600" ]; then
                log_warn "    权限错误！修复中..."
                chmod 600 "$ga_file"
                needs_fix=true
                ((issues_found++))
            fi
            
            # 检查不可变属性
            if lsattr "$ga_file" 2>/dev/null | grep -q "^....i"; then
                log_warn "    发现不可变属性！移除中..."
                chattr -i "$ga_file"
                needs_fix=true
                ((issues_found++))
            fi
            
            # 检查归属
            expected_owner="$username:$username"
            if [ "$owner" != "$expected_owner" ] && [ "$username" != "root" ]; then
                log_warn "    归属错误！修复中..."
                chown "$expected_owner" "$ga_file"
                needs_fix=true
                ((issues_found++))
            fi
            
            if [ "$needs_fix" = true ]; then
                log_info "    ✓ 已修复"
                ((fixed_count++))
            else
                log_info "    ✓ 配置正常"
            fi
            echo ""
        fi
    done
    
    if [ $fixed_count -eq 0 ]; then
        log_info "所有用户2FA文件配置正常"
    else
        log_info "已修复 $fixed_count 个用户的2FA文件"
    fi
    echo ""
    
    # 4. 检查时间同步
    echo -e "${BOLD}[4/6] 检查系统时间同步${NC}"
    echo "  当前时间: $(date)"
    
    if systemctl is-active --quiet systemd-timesyncd; then
        log_info "时间同步服务运行中（systemd-timesyncd）"
    elif systemctl is-active --quiet chronyd; then
        log_info "时间同步服务运行中（chronyd）"
    elif systemctl is-active --quiet ntpd; then
        log_info "时间同步服务运行中（ntpd）"
    else
        log_warn "时间同步服务未运行"
        log_step "2FA需要准确的系统时间，建议启用时间同步"
        ((issues_found++))
    fi
    echo ""
    
    # 5. 检查PAM模块
    echo -e "${BOLD}[5/6] 检查PAM模块${NC}"
    if [ -f /usr/lib/x86_64-linux-gnu/security/pam_google_authenticator.so ] || \
       [ -f /usr/lib64/security/pam_google_authenticator.so ] || \
       [ -f /lib/security/pam_google_authenticator.so ]; then
        log_info "PAM Google Authenticator模块已安装"
    else
        log_error "PAM Google Authenticator模块未找到"
        log_step "请安装: apt install libpam-google-authenticator"
        ((issues_found++))
    fi
    echo ""
    
    # 6. 显示使用提示
    echo -e "${BOLD}[6/6] GUI登录2FA使用提示${NC}"
    echo ""
    echo -e "${GREEN}正确的GUI登录方式:${NC}"
    echo "  ┌─────────────────────────────────┐"
    echo "  │ 用户名: yourname                │"
    echo "  │ 密码: [password123456]          │"
    echo "  │       ^^^^^^^^  ^^^^^^          │"
    echo "  │       密码部分  2FA验证码       │"
    echo "  └─────────────────────────────────┘"
    echo ""
    echo "  • 在密码框中输入: 密码+6位验证码"
    echo "  • 连在一起输入，中间无空格"
    echo "  • 示例: 密码是 'MyPass'，验证码是 '123456'"
    echo "    →     输入 'MyPass123456'"
    echo ""
    
    # 总结
    echo "══════════════════════════════════════════"
    echo -e "${BOLD}诊断总结${NC}"
    echo "══════════════════════════════════════════"
    echo ""
    
    if [ $issues_found -eq 0 ]; then
        log_info "未发现问题，2FA配置正常"
    else
        log_warn "发现并尝试修复 $issues_found 个问题"
        echo ""
        log_step "如果问题仍然存在，请查看认证日志："
        if [ -f /var/log/auth.log ]; then
            echo "  sudo tail -f /var/log/auth.log"
        elif [ -f /var/log/secure ]; then
            echo "  sudo tail -f /var/log/secure"
        else
            echo "  sudo journalctl -xef -u $DM"
        fi
    fi
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项25: 内存文件系统管理
option_ramdisk_manager() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  内存文件系统管理"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "内存文件系统（tmpfs/ramdisk）可用于："
    echo "  • 敏感文件处理（重启后自动清除）"
    echo "  • 临时工作区（不留磁盘痕迹）"
    echo "  • 提高I/O性能"
    echo "  • 防取证分析"
    echo ""
    
    # 检查现有ramdisk
    echo -e "${BOLD}当前内存文件系统状态:${NC}"
    echo ""
    df -h | grep -E "tmpfs|Size" | grep -v "run\|dev"
    echo ""
    
    # 子菜单
    echo "请选择操作："
    echo "  [1] 创建新的内存盘"
    echo "  [2] 卸载内存盘"
    echo "  [3] 配置/tmp为tmpfs"
    echo "  [4] 查看内存使用情况"
    echo "  [0] 返回主菜单"
    echo ""
    read -p "请选择 [0-4]: " ramdisk_choice
    
    case $ramdisk_choice in
        1)
            # 创建新内存盘
            echo ""
            log_step "创建新的内存盘..."
            
            read -p "挂载点路径（如 /mnt/ramdisk）: " mount_point
            if [ -z "$mount_point" ]; then
                log_error "挂载点不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            read -p "大小（如 1G, 512M）[默认: 1G]: " size
            size=${size:-1G}
            
            # 创建挂载点
            if [ ! -d "$mount_point" ]; then
                mkdir -p "$mount_point"
                log_info "已创建目录: $mount_point"
            fi
            
            # 挂载tmpfs（默认700权限）
            mount -t tmpfs -o size=$size,mode=700 tmpfs "$mount_point"
            
            if [ $? -eq 0 ]; then
                log_info "内存盘创建成功！"
                echo ""
                echo "挂载点: $mount_point"
                echo "大小: $size"
                
                # 显示当前权限
                current_perm=$(stat -c "%a" "$mount_point")
                echo "当前权限: $current_perm"
                echo ""
                
                # 询问是否修改权限
                echo "权限选项："
                echo "  700 - 仅root可访问（当前）"
                echo "  755 - root可写，其他用户可读"
                echo "  777 - 所有用户可读写"
                echo "  1777 - 所有用户可读写，有粘滞位（类似/tmp）"
                echo ""
                read -p "是否修改权限？(y/n，默认保持700): " change_perm
                
                if [[ $change_perm =~ ^[Yy]$ ]]; then
                    echo ""
                    echo "请选择权限："
                    echo "  [1] 700  - 仅root（默认）"
                    echo "  [2] 755  - 其他用户可读"
                    echo "  [3] 777  - 所有用户可写"
                    echo "  [4] 1777 - 所有用户可写+粘滞位"
                    read -p "选择 [1-4]: " perm_choice
                    
                    case $perm_choice in
                        1)
                            chmod 700 "$mount_point"
                            log_info "权限设置为: 700 (仅root)"
                            ;;
                        2)
                            chmod 755 "$mount_point"
                            log_info "权限设置为: 755 (其他用户可读)"
                            ;;
                        3)
                            chmod 777 "$mount_point"
                            log_info "权限设置为: 777 (所有用户可写)"
                            ;;
                        4)
                            chmod 1777 "$mount_point"
                            log_info "权限设置为: 1777 (可写+粘滞位)"
                            ;;
                        *)
                            log_info "保持默认权限: 700"
                            ;;
                    esac
                    
                    # 显示修改后的权限
                    new_perm=$(stat -c "%a" "$mount_point")
                    echo "最终权限: $new_perm"
                else
                    log_info "保持默认权限: 700 (仅root可访问)"
                fi
                
                echo ""
                df -h "$mount_point"
                echo ""
                log_warn "提示："
                echo "  • 此内存盘在重启后会消失"
                echo "  • 请勿存储需要持久化的数据"
                echo "  • 使用完毕建议卸载: umount $mount_point"
                echo ""
                
                # 询问是否永久化配置
                read -p "是否添加到/etc/fstab（开机自动挂载）? (y/n): " add_fstab
                if [[ $add_fstab =~ ^[Yy]$ ]]; then
                    # 检查是否已存在
                    if grep -q "$mount_point" /etc/fstab; then
                        log_warn "该挂载点已在/etc/fstab中"
                    else
                        echo "tmpfs $mount_point tmpfs defaults,noatime,mode=700,size=$size 0 0" >> /etc/fstab
                        log_info "已添加到/etc/fstab"
                    fi
                fi
            else
                log_error "创建失败"
            fi
            ;;
            
        2)
            # 卸载内存盘
            echo ""
            log_step "卸载内存盘..."
            
            # 显示当前tmpfs
            echo "当前tmpfs挂载点："
            mount | grep tmpfs | grep -v "run\|dev\|sys" | nl
            echo ""
            
            read -p "要卸载的挂载点（完整路径）: " umount_point
            
            if [ -z "$umount_point" ]; then
                log_error "挂载点不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            # 检查是否有文件
            if [ -d "$umount_point" ]; then
                file_count=$(find "$umount_point" -type f 2>/dev/null | wc -l)
                if [ $file_count -gt 0 ]; then
                    log_warn "该内存盘包含 $file_count 个文件"
                    read -p "确认卸载（数据将丢失）? (yes/no): " confirm
                    if [ "$confirm" != "yes" ]; then
                        log_info "已取消"
                        read -p "按Enter返回..."
                        return
                    fi
                fi
            fi
            
            umount "$umount_point"
            
            if [ $? -eq 0 ]; then
                log_info "卸载成功: $umount_point"
                
                # 询问是否从fstab移除
                if grep -q "$umount_point" /etc/fstab; then
                    read -p "是否从/etc/fstab中移除? (y/n): " remove_fstab
                    if [[ $remove_fstab =~ ^[Yy]$ ]]; then
                        sed -i "\|$umount_point|d" /etc/fstab
                        log_info "已从/etc/fstab移除"
                    fi
                fi
            else
                log_error "卸载失败"
                echo "  可能原因："
                echo "    - 挂载点不存在"
                echo "    - 有进程正在使用"
                echo "  尝试强制卸载: umount -l $umount_point"
            fi
            ;;
            
        3)
            # 配置/tmp为tmpfs
            echo ""
            log_step "配置/tmp为内存文件系统..."
            
            log_warn "此操作将使/tmp目录使用内存而非硬盘"
            echo "  优点："
            echo "    • 重启自动清空"
            echo "    • 不留磁盘痕迹"
            echo "    • 提高性能"
            echo "  注意："
            echo "    • 需要足够的RAM"
            echo "    • 大文件可能占用过多内存"
            echo ""
            
            read -p "是否继续? (y/n): " confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                log_info "已取消"
                read -p "按Enter返回..."
                return
            fi
            
            # 检查是否已配置
            if grep -q "^tmpfs.*\/tmp" /etc/fstab; then
                log_warn "/tmp已配置为tmpfs"
                cat /etc/fstab | grep "^tmpfs.*\/tmp"
            else
                read -p "/tmp大小 [默认: 2G]: " tmp_size
                tmp_size=${tmp_size:-2G}
                
                # 添加到fstab
                echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=$tmp_size 0 0" >> /etc/fstab
                log_info "已添加到/etc/fstab"
                
                # 询问是否立即生效
                read -p "是否现在挂载（会清空当前/tmp）? (y/n): " mount_now
                if [[ $mount_now =~ ^[Yy]$ ]]; then
                    mount -o remount /tmp
                    
                    if [ $? -eq 0 ]; then
                        log_info "/tmp已重新挂载为tmpfs"
                        
                        # 检查权限
                        echo ""
                        current_perm=$(stat -c "%a" /tmp)
                        echo "当前/tmp权限: $current_perm"
                        
                        if [ "$current_perm" != "1777" ]; then
                            log_warn "权限不是1777，可能导致无法正常使用"
                            echo ""
                            echo "权限说明："
                            echo "  1777 - 所有用户可读写执行，有粘滞位（推荐）"
                            echo "  当前 - $current_perm"
                            echo ""
                            read -p "是否修改为1777？(y/n): " fix_perm
                            
                            if [[ $fix_perm =~ ^[Yy]$ ]]; then
                                chmod 1777 /tmp
                                new_perm=$(stat -c "%a" /tmp)
                                log_info "权限已修改为: $new_perm"
                                
                                # 验证权限
                                if [ "$new_perm" = "1777" ]; then
                                    log_info "✓ 权限设置成功"
                                    echo "  测试写入..."
                                    if touch /tmp/.test-$$ 2>/dev/null; then
                                        rm -f /tmp/.test-$$
                                        log_info "✓ /tmp可正常使用"
                                    else
                                        log_error "✗ /tmp仍无法写入，请检查配置"
                                    fi
                                else
                                    log_warn "权限修改可能失败，当前: $new_perm"
                                fi
                            else
                                log_info "保持当前权限: $current_perm"
                                log_warn "注意: 非1777权限可能导致程序无法使用/tmp"
                            fi
                        else
                            log_info "✓ 权限正确: 1777"
                            
                            # 测试写入
                            if touch /tmp/.test-$$ 2>/dev/null; then
                                rm -f /tmp/.test-$$
                                log_info "✓ /tmp可正常使用"
                            fi
                        fi
                    else
                        log_error "挂载失败"
                    fi
                else
                    log_info "重启后生效"
                    log_warn "重启后请检查/tmp权限是否为1777"
                fi
            fi
            
            # 可选：配置/var/tmp
            echo ""
            read -p "是否也将/var/tmp配置为tmpfs? (y/n): " var_tmp
            if [[ $var_tmp =~ ^[Yy]$ ]]; then
                if ! grep -q "^tmpfs.*\/var\/tmp" /etc/fstab; then
                    echo "tmpfs /var/tmp tmpfs defaults,noatime,mode=1777,size=1G 0 0" >> /etc/fstab
                    log_info "已配置/var/tmp"
                fi
            fi
            ;;
            
        4)
            # 查看内存使用
            echo ""
            log_step "内存使用情况..."
            echo ""
            
            echo -e "${BOLD}总体内存:${NC}"
            free -h
            echo ""
            
            echo -e "${BOLD}tmpfs使用情况:${NC}"
            df -h -t tmpfs | grep -v "run\|dev\|sys"
            echo ""
            
            echo -e "${BOLD}所有tmpfs挂载点:${NC}"
            mount | grep tmpfs | grep -v "run\|dev\|sys"
            ;;
            
        0)
            return
            ;;
            
        *)
            log_error "无效选项"
            ;;
    esac
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项26: 安全删除文件
option_secure_delete() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  安全删除文件"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "安全删除通过多次覆盖防止数据恢复"
    echo ""
    
    # 检查工具
    echo -e "${BOLD}检查安全删除工具:${NC}"
    
    has_shred=false
    has_wipe=false
    has_srm=false
    
    if command -v shred &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} shred (内置)"
        has_shred=true
    else
        echo -e "  ${RED}✗${NC} shred"
    fi
    
    if command -v wipe &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} wipe"
        has_wipe=true
    else
        echo -e "  ${YELLOW}!${NC} wipe (未安装)"
    fi
    
    if command -v srm &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} srm (secure-delete)"
        has_srm=true
    else
        echo -e "  ${YELLOW}!${NC} srm (未安装)"
    fi
    
    echo ""
    
    # 如果缺少工具，提示安装
    if [ "$has_wipe" = false ] || [ "$has_srm" = false ]; then
        log_step "安装缺失的工具？"
        echo "  sudo apt install wipe secure-delete"
        echo ""
        read -p "是否现在安装? (y/n): " install_tools
        if [[ $install_tools =~ ^[Yy]$ ]]; then
            apt update
            apt install -y wipe secure-delete
            has_wipe=true
            has_srm=true
            echo ""
        fi
    fi
    
    # 选择操作
    echo "请选择操作："
    echo "  [1] 安全删除文件"
    echo "  [2] 安全删除目录"
    echo "  [3] 安全擦除整个分区/磁盘"
    echo "  [4] 查看工具说明"
    echo "  [0] 返回主菜单"
    echo ""
    read -p "请选择 [0-4]: " delete_choice
    
    case $delete_choice in
        1)
            # 安全删除文件
            echo ""
            log_step "安全删除文件..."
            echo ""
            
            read -p "文件路径（支持通配符）: " file_path
            
            if [ -z "$file_path" ]; then
                log_error "文件路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            # 检查文件是否存在
            if ! ls $file_path &>/dev/null; then
                log_error "文件不存在: $file_path"
                read -p "按Enter返回..."
                return
            fi
            
            # 显示文件信息
            echo "将要删除的文件："
            ls -lh $file_path
            echo ""
            
            # 选择工具
            echo "选择删除工具："
            [ "$has_shred" = true ] && echo "  [1] shred (快速，3次覆盖)"
            [ "$has_wipe" = true ] && echo "  [2] wipe (标准，34次覆盖)"
            [ "$has_srm" = true ] && echo "  [3] srm (安全，7次覆盖)"
            echo ""
            read -p "选择工具 [1-3]: " tool_choice
            
            # 最终确认
            log_warn "⚠️  警告：此操作不可恢复！"
            read -p "确认删除? 输入 'DELETE' 继续: " final_confirm
            
            if [ "$final_confirm" != "DELETE" ]; then
                log_info "已取消"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "正在安全删除..."
            
            case $tool_choice in
                1)
                    if [ "$has_shred" = true ]; then
                        for file in $file_path; do
                            echo "删除: $file"
                            shred -vfz -n 3 "$file"
                        done
                        log_info "删除完成（使用shred）"
                    fi
                    ;;
                2)
                    if [ "$has_wipe" = true ]; then
                        wipe -rf $file_path
                        log_info "删除完成（使用wipe）"
                    fi
                    ;;
                3)
                    if [ "$has_srm" = true ]; then
                        srm -vz $file_path
                        log_info "删除完成（使用srm）"
                    fi
                    ;;
                *)
                    log_error "无效选择"
                    ;;
            esac
            ;;
            
        2)
            # 安全删除目录
            echo ""
            log_step "安全删除目录..."
            echo ""
            
            read -p "目录路径: " dir_path
            
            if [ -z "$dir_path" ]; then
                log_error "目录路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -d "$dir_path" ]; then
                log_error "目录不存在: $dir_path"
                read -p "按Enter返回..."
                return
            fi
            
            # 显示目录信息
            echo "目录信息："
            du -sh "$dir_path"
            echo "文件数量: $(find "$dir_path" -type f | wc -l)"
            echo ""
            
            log_warn "⚠️  警告：将递归删除目录及所有内容！"
            read -p "确认删除? 输入目录名确认: " confirm_dir
            
            if [ "$confirm_dir" != "$(basename "$dir_path")" ]; then
                log_info "已取消"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "正在安全删除目录..."
            
            # 使用shred递归删除
            find "$dir_path" -type f -exec shred -vfz -n 3 {} \;
            rm -rf "$dir_path"
            
            log_info "目录已安全删除"
            ;;
            
        3)
            # 擦除分区/磁盘
            echo ""
            log_title "⚠️  危险操作：擦除分区/磁盘 ⚠️"
            echo ""
            
            log_warn "此操作将永久销毁分区/磁盘上的所有数据！"
            echo ""
            
            # 显示可用设备
            echo "可用设备："
            lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
            echo ""
            
            read -p "要擦除的设备（如 /dev/sdb 或 /dev/sda3）: " device
            
            if [ -z "$device" ]; then
                log_error "设备不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -b "$device" ]; then
                log_error "设备不存在: $device"
                read -p "按Enter返回..."
                return
            fi
            
            # 显示设备信息
            echo ""
            echo "设备信息:"
            lsblk "$device"
            fdisk -l "$device" 2>/dev/null | head -5
            echo ""
            
            # 多重确认
            log_warn "⚠️⚠️⚠️  最后警告  ⚠️⚠️⚠️"
            echo "将要擦除: $device"
            echo "所有数据将永久丢失！"
            echo ""
            read -p "输入设备路径确认 (如 /dev/sdb): " confirm1
            
            if [ "$confirm1" != "$device" ]; then
                log_info "已取消"
                read -p "按Enter返回..."
                return
            fi
            
            read -p "再次确认，输入 'ERASE' 继续: " confirm2
            
            if [ "$confirm2" != "ERASE" ]; then
                log_info "已取消"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            echo "选择擦除方法："
            echo "  [1] 零填充（快速，安全性低）"
            echo "  [2] 随机数据（中速，安全性中）"
            echo "  [3] 多次覆盖（慢速，安全性高）"
            echo "  [4] shred（推荐，3次覆盖）"
            echo ""
            read -p "选择 [1-4]: " erase_method
            
            echo ""
            log_step "开始擦除 $device ..."
            echo ""
            
            case $erase_method in
                1)
                    dd if=/dev/zero of="$device" bs=1M status=progress
                    ;;
                2)
                    dd if=/dev/urandom of="$device" bs=1M status=progress
                    ;;
                3)
                    for i in {1..3}; do
                        echo "第 $i 次覆盖..."
                        dd if=/dev/urandom of="$device" bs=1M status=progress
                    done
                    ;;
                4)
                    shred -vfz -n 3 "$device"
                    ;;
                *)
                    log_error "无效选择"
                    read -p "按Enter返回..."
                    return
                    ;;
            esac
            
            if [ $? -eq 0 ]; then
                log_info "擦除完成！"
                sync
            else
                log_error "擦除失败"
            fi
            ;;
            
        4)
            # 工具说明
            echo ""
            log_title "安全删除工具说明"
            echo ""
            
            echo -e "${BOLD}1. shred (系统内置)${NC}"
            echo "   覆盖次数: 默认3次"
            echo "   速度: 快"
            echo "   命令示例: shred -vfz -n 10 文件"
            echo "   参数:"
            echo "     -v  显示进度"
            echo "     -f  强制修改权限"
            echo "     -z  最后用零覆盖"
            echo "     -n  覆盖次数"
            echo ""
            
            echo -e "${BOLD}2. wipe${NC}"
            echo "   覆盖次数: 34次（符合DOD标准）"
            echo "   速度: 中"
            echo "   命令示例: wipe -rf 文件"
            echo "   参数:"
            echo "     -r  递归"
            echo "     -f  强制"
            echo "   安装: apt install wipe"
            echo ""
            
            echo -e "${BOLD}3. srm (secure-delete)${NC}"
            echo "   覆盖次数: 7次（Gutmann算法）"
            echo "   速度: 中"
            echo "   命令示例: srm -vz 文件"
            echo "   参数:"
            echo "     -v  详细输出"
            echo "     -z  最后用零覆盖"
            echo "   安装: apt install secure-delete"
            echo ""
            
            echo -e "${BOLD}安全级别对比:${NC}"
            echo "  shred (3次)   : 🟡 基础安全"
            echo "  shred (10次)  : 🟢 良好安全"
            echo "  srm (7次)     : 🟢 高安全"
            echo "  wipe (34次)   : 🔵 最高安全"
            echo ""
            
            echo -e "${BOLD}性能对比（1GB文件）:${NC}"
            echo "  shred (3次)   : ~30秒"
            echo "  srm (7次)     : ~60秒"
            echo "  wipe (34次)   : ~180秒"
            echo ""
            
            echo -e "${BOLD}推荐使用场景:${NC}"
            echo "  日常文件:     shred -n 3"
            echo "  敏感文件:     shred -n 10 或 srm"
            echo "  极敏感文件:   wipe"
            echo "  整盘擦除:     shred + dd"
            ;;
            
        0)
            return
            ;;
            
        *)
            log_error "无效选项"
            ;;
    esac
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项27: 元数据清理工具
option_metadata_cleaner() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  元数据清理工具"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "元数据可能泄露的信息："
    echo "  • 拍摄时间、地点（GPS坐标）"
    echo "  • 相机型号、设备信息"
    echo "  • 软件版本、作者信息"
    echo "  • 文档编辑历史、修订记录"
    echo ""
    
    # 检查工具
    echo -e "${BOLD}检查元数据清理工具:${NC}"
    
    has_exiftool=false
    has_mat2=false
    
    if command -v exiftool &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} exiftool (图片/视频/音频)"
        has_exiftool=true
    else
        echo -e "  ${YELLOW}!${NC} exiftool (未安装)"
    fi
    
    if command -v mat2 &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} mat2 (Office文档/PDF)"
        has_mat2=true
    else
        echo -e "  ${YELLOW}!${NC} mat2 (未安装)"
    fi
    
    echo ""
    
    # 安装工具
    if [ "$has_exiftool" = false ] || [ "$has_mat2" = false ]; then
        log_step "安装元数据清理工具？"
        echo "  sudo apt install libimage-exiftool-perl mat2"
        echo ""
        read -p "是否现在安装? (y/n): " install_tools
        if [[ $install_tools =~ ^[Yy]$ ]]; then
            apt update
            apt install -y libimage-exiftool-perl mat2
            has_exiftool=true
            has_mat2=true
            echo ""
        fi
    fi
    
    # 选择操作
    echo "请选择操作："
    echo "  [1] 清理图片元数据（JPEG/PNG/等）"
    echo "  [2] 清理Office文档元数据（docx/xlsx/pptx）"
    echo "  [3] 清理PDF元数据"
    echo "  [4] 清理视频/音频元数据"
    echo "  [5] 批量清理目录"
    echo "  [6] 查看文件元数据"
    echo "  [0] 返回主菜单"
    echo ""
    read -p "请选择 [0-6]: " meta_choice
    
    case $meta_choice in
        1)
            # 清理图片元数据
            if [ "$has_exiftool" = false ]; then
                log_error "exiftool未安装"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "清理图片元数据..."
            read -p "图片路径（支持通配符，如 *.jpg）: " image_path
            
            if [ -z "$image_path" ]; then
                log_error "路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if ! ls $image_path &>/dev/null; then
                log_error "文件不存在"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "处理文件..."
            exiftool -all= -overwrite_original $image_path
            
            if [ $? -eq 0 ]; then
                log_info "元数据已清理"
                echo ""
                echo "已清理的信息包括："
                echo "  • GPS坐标"
                echo "  • 拍摄时间"
                echo "  • 相机型号"
                echo "  • 软件信息"
            else
                log_error "清理失败"
            fi
            ;;
            
        2)
            # 清理Office文档
            if [ "$has_mat2" = false ]; then
                log_error "mat2未安装"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "清理Office文档元数据..."
            read -p "文档路径（如 document.docx）: " doc_path
            
            if [ -z "$doc_path" ]; then
                log_error "路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -f "$doc_path" ]; then
                log_error "文件不存在"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "处理文件..."
            mat2 "$doc_path"
            
            if [ $? -eq 0 ]; then
                log_info "元数据已清理"
                echo "  清理后文件: ${doc_path%.

*}.cleaned.${doc_path##*.}"
            else
                log_error "清理失败"
            fi
            ;;
            
        3)
            # 清理PDF
            if [ "$has_mat2" = false ]; then
                log_error "mat2未安装"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "清理PDF元数据..."
            read -p "PDF路径: " pdf_path
            
            if [ -z "$pdf_path" ]; then
                log_error "路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -f "$pdf_path" ]; then
                log_error "文件不存在"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "处理文件..."
            mat2 "$pdf_path"
            
            if [ $? -eq 0 ]; then
                log_info "PDF元数据已清理"
            else
                log_error "清理失败"
            fi
            ;;
            
        4)
            # 清理视频/音频
            echo ""
            log_step "清理视频/音频元数据..."
            
            if ! command -v ffmpeg &>/dev/null; then
                log_warn "ffmpeg未安装"
                read -p "是否安装ffmpeg? (y/n): " install_ffmpeg
                if [[ $install_ffmpeg =~ ^[Yy]$ ]]; then
                    apt update
                    apt install -y ffmpeg
                else
                    read -p "按Enter返回..."
                    return
                fi
            fi
            
            read -p "媒体文件路径: " media_path
            
            if [ -z "$media_path" ]; then
                log_error "路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -f "$media_path" ]; then
                log_error "文件不存在"
                read -p "按Enter返回..."
                return
            fi
            
            # 获取文件扩展名
            ext="${media_path##*.}"
            output="${media_path%.*}.cleaned.$ext"
            
            echo ""
            log_step "处理文件..."
            ffmpeg -i "$media_path" -map_metadata -1 -c:v copy -c:a copy "$output" -y 2>/dev/null
            
            if [ $? -eq 0 ]; then
                log_info "元数据已清理"
                echo "  清理后文件: $output"
                echo ""
                read -p "是否删除原文件? (y/n): " del_orig
                if [[ $del_orig =~ ^[Yy]$ ]]; then
                    rm -f "$media_path"
                    mv "$output" "$media_path"
                    log_info "原文件已替换"
                fi
            else
                log_error "清理失败"
            fi
            ;;
            
        5)
            # 批量清理
            if [ "$has_exiftool" = false ]; then
                log_error "exiftool未安装"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "批量清理目录..."
            read -p "目录路径: " dir_path
            
            if [ -z "$dir_path" ]; then
                log_error "路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -d "$dir_path" ]; then
                log_error "目录不存在"
                read -p "按Enter返回..."
                return
            fi
            
            # 统计文件
            file_count=$(find "$dir_path" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.pdf" -o -iname "*.docx" \) | wc -l)
            
            echo ""
            echo "找到 $file_count 个文件"
            echo ""
            read -p "是否继续批量清理? (y/n): " confirm_batch
            
            if [[ $confirm_batch =~ ^[Yy]$ ]]; then
                log_step "批量清理中..."
                exiftool -all= -r -overwrite_original "$dir_path"
                log_info "批量清理完成"
            fi
            ;;
            
        6)
            # 查看元数据
            if [ "$has_exiftool" = false ]; then
                log_error "exiftool未安装"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            log_step "查看文件元数据..."
            read -p "文件路径: " file_path
            
            if [ -z "$file_path" ]; then
                log_error "路径不能为空"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -f "$file_path" ]; then
                log_error "文件不存在"
                read -p "按Enter返回..."
                return
            fi
            
            echo ""
            exiftool "$file_path"
            ;;
            
        0)
            return
            ;;
            
        *)
            log_error "无效选项"
            ;;
    esac
    
    echo ""
    read -p "按Enter返回主菜单..."
}

# 选项28: 隐私浏览器启动器
option_privacy_browser() {
    clear
    log_title "══════════════════════════════════════════"
    log_title "  隐私浏览器启动器"
    log_title "══════════════════════════════════════════"
    echo ""
    
    log_step "隐私浏览模式特性："
    echo "  • 使用Firejail沙箱隔离"
    echo "  • 独立的配置文件（与日常分离）"
    echo "  • 自动清理浏览数据"
    echo "  • 防指纹识别配置"
    echo ""
    
    # 子菜单
    echo "请选择操作："
    echo "  [1] 配置并启动Firefox隐私模式"
    echo "  [2] 启动沙箱隔离的Firefox（推荐，默认）"
    echo "  [3] 启动Tor Browser（如已安装）"
    echo "  [4] 配置Firefox隐私增强"
    echo "  [5] 安装Firejail沙箱"
    echo "  [0] 返回主菜单"
    echo ""
    read -p "请选择 [0-5，默认2]: " browser_choice
    browser_choice=${browser_choice:-2}
    
    case $browser_choice in
        1)
            # 配置并启动Firefox隐私模式
            echo ""
            log_step "配置Firefox隐私模式..."
            
            # 检查Firefox
            if ! command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
                log_warn "Firefox未安装"
                read -p "是否安装Firefox ESR? (y/n): " install_ff
                if [[ $install_ff =~ ^[Yy]$ ]]; then
                    apt update
                    apt install -y firefox-esr
                else
                    read -p "按Enter返回..."
                    return
                fi
            fi
            
            # 创建隐私配置文件
            log_step "创建隐私配置..."
            
            firefox_cmd="firefox"
            command -v firefox-esr &>/dev/null && firefox_cmd="firefox-esr"
            
            # 创建配置文件（如果不存在）
            if ! $firefox_cmd -P 隐私模式 --no-remote 2>&1 | grep -q "隐私模式"; then
                log_info "首次运行将创建隐私配置文件"
            fi
            
            # 启动Firefox隐私模式
            log_info "启动Firefox隐私模式..."
            echo ""
            log_warn "使用提示："
            echo "  • 这是独立的Firefox配置文件"
            echo "  • 需要手动安装隐私扩展（见下方）"
            echo "  • 关闭Firefox返回脚本"
            echo ""
            echo "推荐扩展："
            echo "  1. uBlock Origin - 广告拦截"
            echo "  2. Privacy Badger - 反跟踪"
            echo "  3. HTTPS Everywhere - 强制HTTPS"
            echo "  4. NoScript - 禁用JavaScript"
            echo ""
            read -p "按Enter启动Firefox..."
            
            # 检测当前用户和环境
            actual_user=${SUDO_USER:-$USER}
            user_display=${DISPLAY:-:0}
            user_xauth=${XAUTHORITY:-/home/$actual_user/.Xauthority}
            
            echo ""
            log_step "启动Firefox隐私模式..."
            
            # 直接后台启动
            if [ -n "$SUDO_USER" ]; then
                # 通过sudo运行，切换回原用户
                log_info "以用户 $SUDO_USER 身份启动"
                su - $SUDO_USER -c "DISPLAY=$user_display XAUTHORITY=$user_xauth $firefox_cmd -P 隐私模式 --no-remote" > /tmp/firefox-$$.log 2>&1 &
            else
                # 直接运行
                DISPLAY=$user_display $firefox_cmd -P 隐私模式 --no-remote > /tmp/firefox-$$.log 2>&1 &
            fi
            
            # 等待进程启动
            sleep 3
            
            # 检查是否成功启动
            if pgrep -u $actual_user firefox >/dev/null 2>&1; then
                log_info "✓ Firefox已成功启动"
                echo ""
                echo "  运行用户: $actual_user"
                echo "  配置文件: 隐私模式"
                echo "  日志文件: /tmp/firefox-$$.log"
                echo ""
                log_warn "Firefox已在后台运行"
                echo "  • Firefox窗口应该已打开（检查任务栏）"
                echo "  • 等待Firefox关闭后自动清理数据..."
                echo ""
                
                # 直接等待Firefox关闭（不再询问）
                log_step "等待Firefox关闭..."
                while pgrep -u $actual_user firefox >/dev/null 2>&1; do
                    sleep 2
                done
                log_info "✓ Firefox已关闭"
                
                # 自动清理数据（不再询问）
                echo ""
                log_step "自动清理浏览数据..."
                profile_dir=$(find ~/.mozilla/firefox -maxdepth 1 -name "*.隐私模式" 2>/dev/null | head -1)
                
                if [ -n "$profile_dir" ]; then
                    rm -rf "$profile_dir/cache2"/* 2>/dev/null
                    rm -f "$profile_dir/cookies.sqlite" 2>/dev/null
                    rm -f "$profile_dir/places.sqlite" 2>/dev/null
                    rm -f "$profile_dir/formhistory.sqlite" 2>/dev/null
                    rm -rf "$profile_dir/storage"/* 2>/dev/null
                    rm -rf "$profile_dir/sessionstore-backups"/* 2>/dev/null
                    log_info "✓ 浏览数据已清理（历史、Cookies、缓存等）"
                else
                    log_warn "未找到隐私模式配置目录"
                fi
            else
                log_error "Firefox启动可能失败"
                echo ""
                log_step "请检查："
                echo "  1. 查看日志: cat /tmp/firefox-$$.log"
                echo "  2. 检查进程: ps aux | grep firefox"
                echo "  3. 手动运行: firefox -P 隐私模式"
                echo ""
                read -p "按Enter返回..."
            fi
            ;;
            
        2)
            # 使用Firejail启动
            echo ""
            log_step "使用Firejail沙箱启动Firefox..."
            
            if ! command -v firejail &>/dev/null; then
                log_error "Firejail未安装"
                read -p "是否安装Firejail? (y/n): " install_fj
                if [[ $install_fj =~ ^[Yy]$ ]]; then
                    apt update
                    apt install -y firejail
                else
                    read -p "按Enter返回..."
                    return
                fi
            fi
            
            if ! command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
                log_error "Firefox未安装"
                read -p "按Enter返回..."
                return
            fi
            
            firefox_cmd="firefox"
            command -v firefox-esr &>/dev/null && firefox_cmd="firefox-esr"
            
            echo ""
            log_info "Firejail沙箱特性："
            echo "  • 文件系统隔离"
            echo "  • 网络命名空间隔离"
            echo "  • 私有/tmp和/home"
            echo "  • 限制系统调用"
            echo ""
            
            echo "沙箱模式选择："
            echo "  [1] 标准沙箱（有网络）"
            echo "  [2] 私有沙箱（无网络，离线查看）"
            echo "  [3] 私有+网络（推荐，默认）"
            read -p "选择 [1-3，默认3]: " jail_mode
            jail_mode=${jail_mode:-3}
            
            # 检测当前用户和环境
            actual_user=${SUDO_USER:-$USER}
            user_display=${DISPLAY:-:0}
            user_xauth=${XAUTHORITY:-/home/$actual_user/.Xauthority}
            user_home=/home/$actual_user
            
            # 如果是root用户，使用root的home
            [ "$actual_user" = "root" ] && user_home=/root
            
            echo ""
            log_step "环境信息："
            echo "  用户: $actual_user"
            echo "  DISPLAY: $user_display"
            echo "  HOME: $user_home"
            echo ""
            read -p "按Enter启动..."
            
            # 生成启动命令
            case $jail_mode in
                1)
                    jail_cmd="firejail $firefox_cmd"
                    ;;
                2)
                    jail_cmd="firejail --private --net=none $firefox_cmd"
                    ;;
                3|*)
                    jail_cmd="firejail --private $firefox_cmd"
                    ;;
            esac
            
            echo ""
            log_step "准备启动: $jail_cmd"
            echo ""
            
            # 直接在后台启动（不等待）
            log_info "正在启动Firefox沙箱..."
            
            # 以sudo原始用户身份启动
            if [ -n "$SUDO_USER" ]; then
                # 通过sudo运行的，切换回原用户
                su - $SUDO_USER -c "DISPLAY=$user_display XAUTHORITY=$user_xauth $jail_cmd" > /tmp/firefox-$$.log 2>&1 &
            else
                # 直接运行
                $jail_cmd > /tmp/firefox-$$.log 2>&1 &
            fi
            
            fj_pid=$!
            sleep 3
            
            # 检查是否成功启动
            if pgrep -u $actual_user firefox >/dev/null 2>&1; then
                log_info "✓ Firefox沙箱已启动"
                echo ""
                echo "  启动方式: $jail_cmd"
                echo "  运行用户: $actual_user"
                echo "  日志文件: /tmp/firefox-$$.log"
                echo ""
                log_warn "Firefox已在后台运行"
                echo "  • Firefox窗口应该已打开（检查任务栏）"
                echo "  • 等待Firefox关闭后自动清理数据..."
                echo ""
                
                # 直接等待Firefox关闭（不再询问）
                log_step "等待Firefox关闭..."
                while pgrep -u $actual_user firefox >/dev/null 2>&1; do
                    sleep 2
                done
                log_info "✓ Firefox已关闭"
                
                # 自动清理数据（不再询问）
                echo ""
                log_step "自动清理浏览数据..."
                
                if [[ $jail_cmd == *"--private"* ]]; then
                    # 清理Firejail临时数据
                    rm -rf /tmp/firejail.* 2>/dev/null
                    rm -rf /tmp/.firejail-* 2>/dev/null
                    log_info "✓ Firejail临时数据已清理"
                else
                    log_warn "⚠️  标准沙箱模式数据未清理"
                    echo "  数据保存在: ~/.mozilla/firefox/"
                    log_step "建议使用私有模式（选项3）以获得自动清理"
                fi
            else
                log_error "Firefox启动可能失败"
                echo ""
                log_step "故障排查："
                echo "  1. 查看日志: cat /tmp/firefox-$$.log"
                echo "  2. 检查进程: ps aux | grep firefox"
                echo "  3. 手动运行: $jail_cmd"
                echo ""
                echo "常见问题："
                echo "  • 确保没有其他Firefox在运行: pkill firefox"
                echo "  • 检查DISPLAY: echo \$DISPLAY"
                echo "  • 尝试普通模式: firefox &"
            fi
            ;;
            
        3)
            # 启动Tor Browser
            echo ""
            log_step "启动Tor Browser..."
            
            # 查找Tor Browser
            tor_browser_path=""
            
            # 常见位置
            if [ -f ~/tor-browser/Browser/start-tor-browser ]; then
                tor_browser_path=~/tor-browser/Browser/start-tor-browser
            elif [ -f ~/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/start-tor-browser ]; then
                tor_browser_path=~/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/start-tor-browser
            fi
            
            if [ -z "$tor_browser_path" ]; then
                log_error "Tor Browser未找到"
                echo ""
                log_step "安装Tor Browser:"
                echo "  1. 访问 https://www.torproject.org/"
                echo "  2. 下载Tor Browser"
                echo "  3. 解压到用户目录"
                echo ""
                log_step "常见安装位置："
                echo "  ~/tor-browser/Browser/start-tor-browser"
                echo "  ~/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/start-tor-browser"
            else
                # 检测用户
                actual_user=${SUDO_USER:-$USER}
                
                log_info "找到Tor Browser: $tor_browser_path"
                echo ""
                read -p "按Enter启动Tor Browser..."
                
                if [ "$actual_user" = "root" ]; then
                    DISPLAY=:0 $tor_browser_path >/dev/null 2>&1 &
                else
                    sudo -u $actual_user DISPLAY=:0 $tor_browser_path >/dev/null 2>&1 &
                fi
                
                tor_pid=$!
                sleep 2
                
                if ps -p $tor_pid > /dev/null 2>&1; then
                    log_info "✓ Tor Browser已启动 (PID: $tor_pid)"
                    echo ""
                    log_step "Tor Browser运行中..."
                    log_warn "注意：关闭Tor Browser可能需要较长时间"
                else
                    log_warn "Tor Browser可能已启动但进程已分离"
                    log_step "如果没有看到窗口，请检查任务栏"
                fi
            fi
            ;;
            
        4)
            # 配置Firefox隐私增强
            echo ""
            log_step "配置Firefox隐私增强..."
            
            echo ""
            echo "自动配置Firefox隐私设置需要修改prefs.js"
            echo "这将在Firefox配置目录中创建user.js文件"
            echo ""
            read -p "Firefox配置目录（如 ~/.mozilla/firefox/xxxxx.default-esr）: " ff_profile
            
            if [ -z "$ff_profile" ]; then
                log_warn "已取消"
                read -p "按Enter返回..."
                return
            fi
            
            if [ ! -d "$ff_profile" ]; then
                log_error "配置目录不存在"
                read -p "按Enter返回..."
                return
            fi
            
            # 创建user.js
            cat > "$ff_profile/user.js" << 'EOF'
// Firefox 隐私增强配置

// 防指纹识别
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);

// 禁用地理位置
user_pref("geo.enabled", false);
user_pref("geo.wifi.uri", "");

// 禁用WebRTC（防止IP泄露）
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);

// 禁用WebGL（防指纹）
user_pref("webgl.disabled", true);

// 禁用电池API
user_pref("dom.battery.enabled", false);

// 禁用传感器API
user_pref("device.sensors.enabled", false);

// 禁用遥测
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);

// 禁用崩溃报告
user_pref("breakpad.reportURL", "");
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// 禁用Pocket
user_pref("extensions.pocket.enabled", false);

// HTTPS优先
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// 禁用自动填充
user_pref("browser.formfill.enable", false);
user_pref("signon.rememberSignons", false);

// 启用DNT（Do Not Track）
user_pref("privacy.donottrackheader.enabled", true);

// ===== 自动清理配置（关闭时清除数据） =====
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.offlineApps", true);
user_pref("privacy.clearOnShutdown.sessions", true);
user_pref("privacy.clearOnShutdown.siteSettings", false);

// 禁用磁盘缓存（使用内存缓存）
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 65536);

// 禁用会话存储
user_pref("browser.sessionstore.enabled", false);

// 不保存密码
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
EOF
            
            log_info "隐私配置已创建: $ff_profile/user.js"
            echo ""
            log_step "已启用的隐私功能："
            echo "  ✓ 防指纹识别"
            echo "  ✓ 禁用WebRTC（防IP泄露）"
            echo "  ✓ 禁用WebGL"
            echo "  ✓ 禁用遥测"
            echo "  ✓ HTTPS优先"
            echo "  ✓ 关闭时自动清理所有数据 🆕"
            echo "  ✓ 仅使用内存缓存 🆕"
            echo "  ✓ 禁用会话存储 🆕"
            echo ""
            log_step "重启Firefox使配置生效"
            echo ""
            log_info "推荐安装的扩展："
            echo "  1. uBlock Origin"
            echo "  2. Privacy Badger  "
            echo "  3. HTTPS Everywhere"
            echo "  4. NoScript"
            echo "  5. Decentraleyes"
            ;;
            
        5)
            # 安装Firejail
            echo ""
            log_step "安装Firejail沙箱..."
            
            if command -v firejail &>/dev/null; then
                log_warn "Firejail已安装"
                firejail --version
            else
                apt update
                apt install -y firejail
                
                if [ $? -eq 0 ]; then
                    log_info "Firejail安装成功"
                    echo ""
                    echo "使用方法："
                    echo "  firejail firefox          # 基础沙箱"
                    echo "  firejail --private firefox # 私有home"
                    echo "  firejail --net=none firefox # 无网络"
                else
                    log_error "安装失败"
                fi
            fi
            ;;
            
        0)
            return
            ;;
            
        *)
            log_error "无效选项"
            ;;
    esac
    
    echo ""
    read -p "按Enter返回主菜单..."
}

#==============================================================================
# 安全信息展示
#==============================================================================

# 显示安全信息（防渗透检测）
show_security_info() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${YELLOW}⚠️  系统安全信息检查（防渗透检测）${NC}${CYAN}                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 1. 上次登录信息
    echo -e "${BOLD}━━━ [1] 上次登录信息 ━━━${NC}"
    if command -v last >/dev/null 2>&1; then
        echo "最近3次成功登录："
        last -3 -w -a | grep -v "reboot\|wtmp" | head -3
    else
        echo "  未找到last命令"
    fi
    echo ""
    
    # 2. 当前登录会话
    echo -e "${BOLD}━━━ [2] 当前活动会话 ━━━${NC}"
    if command -v w >/dev/null 2>&1; then
        w -h | head -5
    else
        who
    fi
    echo ""
    
    # 3. 最近失败的登录尝试
    echo -e "${BOLD}━━━ [3] 失败登录尝试 ━━━${NC}"
    if [ -f /var/log/auth.log ]; then
        failed_count=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
        echo "  总计失败尝试: $failed_count 次"
        echo "  最近5次失败登录："
        grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 | while read line; do
            echo "    • $line" | cut -c1-100
        done
    elif [ -f /var/log/secure ]; then
        failed_count=$(grep -c "Failed password" /var/log/secure 2>/dev/null || echo "0")
        echo "  总计失败尝试: $failed_count 次"
        echo "  最近5次失败登录："
        grep "Failed password" /var/log/secure 2>/dev/null | tail -5 | while read line; do
            echo "    • $line" | cut -c1-100
        done
    else
        echo "  未找到认证日志"
    fi
    echo ""
    
    # 4. 最近的sudo使用
    echo -e "${BOLD}━━━ [4] 最近sudo使用记录 ━━━${NC}"
    if [ -f /var/log/auth.log ]; then
        sudo_count=$(grep -c "sudo.*COMMAND" /var/log/auth.log 2>/dev/null || echo "0")
        echo "  今日sudo使用: $sudo_count 次"
        echo "  最近3次sudo命令："
        grep "sudo.*COMMAND" /var/log/auth.log 2>/dev/null | tail -3 | while read line; do
            echo "    • $(echo $line | awk '{print $1, $2, $3, $5, $6}' | cut -c1-80)"
        done
    elif [ -f /var/log/secure ]; then
        sudo_count=$(grep -c "sudo.*COMMAND" /var/log/secure 2>/dev/null || echo "0")
        echo "  今日sudo使用: $sudo_count 次"
        echo "  最近3次sudo命令："
        grep "sudo.*COMMAND" /var/log/secure 2>/dev/null | tail -3 | while read line; do
            echo "    • $(echo $line | awk '{print $1, $2, $3, $5, $6}' | cut -c1-80)"
        done
    else
        echo "  未找到sudo日志"
    fi
    echo ""
    
    # 5. 关键文件修改时间
    echo -e "${BOLD}━━━ [5] 关键文件最近修改 ━━━${NC}"
    echo "  /etc/passwd  : $(stat -c '%y' /etc/passwd 2>/dev/null | cut -d. -f1)"
    echo "  /etc/shadow  : $(stat -c '%y' /etc/shadow 2>/dev/null | cut -d. -f1)"
    echo "  /etc/sudoers : $(stat -c '%y' /etc/sudoers 2>/dev/null | cut -d. -f1)"
    echo "  /etc/ssh/sshd_config : $(stat -c '%y' /etc/ssh/sshd_config 2>/dev/null | cut -d. -f1)"
    echo ""
    
    # 6. 最近创建的用户
    echo -e "${BOLD}━━━ [6] 最近创建的用户账户 ━━━${NC}"
    echo "  最近修改的用户（检查/etc/passwd）："
    find /etc/passwd -mtime -7 >/dev/null 2>&1 && echo "    ⚠️  /etc/passwd 在最近7天内被修改" || echo "    ✓ /etc/passwd 无近期修改"
    
    # 显示UID>=1000的普通用户
    echo "  当前普通用户账户："
    awk -F: '$3 >= 1000 && $3 < 65534 {print "    • " $1 " (UID:" $3 ")"}' /etc/passwd | head -5
    echo ""
    
    # 7. 可疑进程检测
    echo -e "${BOLD}━━━ [7] 可疑进程检测 ━━━${NC}"
    
    # 检查监听端口
    suspicious_ports=$(netstat -tlnp 2>/dev/null | grep LISTEN | grep -v "127.0.0.1\|::1" | wc -l)
    echo "  外部监听端口数: $suspicious_ports"
    
    # 检查是否有异常的root进程
    root_procs=$(ps aux | grep "^root" | wc -l)
    echo "  root运行的进程: $root_procs 个"
    
    # 检查可疑的网络连接
    if command -v ss >/dev/null 2>&1; then
        established=$(ss -tn state established 2>/dev/null | wc -l)
        echo "  已建立的TCP连接: $((established - 1)) 个"
    fi
    echo ""
    
    # 8. 系统启动时间
    echo -e "${BOLD}━━━ [8] 系统运行信息 ━━━${NC}"
    echo "  系统启动时间: $(uptime -s 2>/dev/null || who -b | awk '{print $3, $4}')"
    echo "  运行时长: $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
    echo "  当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    
    # 9. 安全提示
    echo -e "${BOLD}${YELLOW}━━━ [9] 安全检查建议 ━━━${NC}"
    echo -e "  ${GREEN}✓${NC} 检查上述信息是否有异常"
    echo -e "  ${GREEN}✓${NC} 确认登录时间、IP地址是否为您本人"
    echo -e "  ${GREEN}✓${NC} 注意失败登录尝试次数和来源"
    echo -e "  ${GREEN}✓${NC} 检查是否有未知的用户账户"
    echo -e "  ${GREEN}✓${NC} 关注关键文件的修改时间"
    echo ""
    
    # 10. 渗透检测提示
    echo -e "${RED}${BOLD}⚠️  可疑迹象（需要警惕）：${NC}"
    echo -e "  • 大量失败登录尝试（暴力破解）"
    echo -e "  • 陌生IP的成功登录"
    echo -e "  • 未知的用户账户"
    echo -e "  • 关键配置文件异常修改"
    echo -e "  • 异常的监听端口"
    echo -e "  • 非预期的系统重启"
    echo ""
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "按Enter继续进入主菜单..."
    clear
}

# 主循环
main() {
    check_root
    
    # 显示安全信息（首次进入时）
    show_security_info
    
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
            24)
                option_diagnose_and_fix
                ;;
            25)
                option_ramdisk_manager
                ;;
            26)
                option_secure_delete
                ;;
            27)
                option_metadata_cleaner
                ;;
            28)
                option_privacy_browser
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

