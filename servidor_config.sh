#!/bin/bash

# Função para configurar a data do servidor para o fuso horário de Bahia
configure_date() {
    echo "=== Configurando a data e hora do servidor para o fuso horário da Bahia (America/Bahia) ==="
    
    # Instalar o pacote para fuso horário se necessário
    sudo apt update
    sudo apt install tzdata -y

    # Configurar o fuso horário para America/Bahia
    sudo timedatectl set-timezone America/Bahia
    
    # Sincronizar data e hora com servidores NTP
    sudo apt install ntpdate -y
    sudo ntpdate time.google.com
    
    # Exibir a data e hora atual
    echo "Data e hora configuradas para o fuso horário America/Bahia: $(date)"
}

# Função para configurar o vsftpd
configure_vsftpd() {
    echo "=== Instalando o vsftpd ==="
    sudo apt update
    sudo apt install vsftpd -y

    # Fazer backup do arquivo de configuração original
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    # Configuração do vsftpd para garantir maior segurança
    echo "=== Configurando o vsftpd ==="
    sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
# Configuração básica do vsftpd

# Habilitar log de eventos
xferlog_enable=YES
xferlog_file=/var/log/xferlog
log_ftp_protocol=YES

# Configurações de segurança
anonymous_enable=NO                # Desabilita o login anônimo
local_enable=YES                   # Permite login de usuários locais
write_enable=YES                   # Permite escrita no FTP
local_umask=022                    # Máscara de permissão para arquivos
chroot_local_user=YES              # Enclausura os usuários em seus diretórios home
allow_writeable_chroot=YES         # Permite gravação no diretório chroot

# Configuração SSL/TLS
ssl_enable=YES
ssl_cert_file=/etc/letsencrypt/live/$(hostname)/fullchain.pem
ssl_key_file=/etc/letsencrypt/live/$(hostname)/privkey.pem
ssl_ciphers=HIGH:MEDIUM:!aNULL:!MD5

# Configurações adicionais
pam_service_name=vsftpd
user_sub_token=$USER
local_root=/home/$USER/ftp

# Configuração de limite de conexões
max_clients=10
max_per_ip=3
EOF

    # Reiniciar o serviço do vsftpd
    sudo systemctl restart vsftpd
    sudo systemctl enable vsftpd
}

# Função para configurar o servidor web Nginx
configure_nginx() {
    echo "=== Instalando e configurando o servidor web Nginx ==="
    sudo apt update
    sudo apt install nginx -y

    # Configurar Nginx com SSL (exemplo básico de configuração)
    sudo bash -c 'cat > /etc/nginx/sites-available/default' <<EOF
server {
    listen 80;
    server_name $(hostname);

    # Redireciona todo o tráfego HTTP para HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $(hostname);

    ssl_certificate /etc/letsencrypt/live/$(hostname)/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$(hostname)/privkey.pem;
    ssl_ciphers HIGH:MEDIUM:!aNULL:!MD5;

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

    # Reiniciar o Nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
}

# Função para ajustar configurações de firewall
adjust_firewall() {
    echo "=== Ajustando configurações de firewall ==="

    # Permitir FTP no firewall
    sudo ufw allow 20:21/tcp      # Permitir FTP padrão
    sudo ufw allow 990/tcp         # Permitir FTP sobre SSL (FTPS)
    sudo ufw allow 'Nginx Full'    # Permitir tráfego HTTP e HTTPS para Nginx
    sudo ufw reload

    echo "Firewall configurado para permitir FTP, FTPS e Nginx."
}

# Função para criar um novo usuário FTP
create_ftp_user() {
    echo "=== Criando novo usuário FTP ==="
    read -p "Digite o nome do novo usuário FTP: " ftpuser
    read -sp "Digite a senha para o usuário $ftpuser: " ftppassword
    echo

    # Criar o usuário sem shell de login (evitar login no sistema)
    sudo useradd -m $ftpuser -s /usr/sbin/nologin

    # Definir a senha do usuário
    echo "$ftpuser:$ftppassword" | sudo chpasswd

    # Criar diretório FTP e garantir permissões adequadas
    sudo mkdir -p /home/$ftpuser/ftp
    sudo chown root:root /home/$ftpuser
    sudo chmod 755 /home/$ftpuser
    sudo chown $ftpuser:$ftpuser /home/$ftpuser/ftp
    sudo chmod 755 /home/$ftpuser/ftp

    # Mostrar informações sobre o usuário FTP
    echo "Usuário FTP criado com sucesso!"
    echo "URL de acesso FTP: ftp://$(hostname)/$ftpuser"
    echo "URL de acesso via Web: https://$(hostname)/$ftpuser"
}

# Função para excluir um usuário FTP
delete_ftp_user() {
    echo "=== Excluindo usuário FTP ==="
    read -p "Digite o nome do usuário FTP que deseja excluir: " ftpuser
    sudo userdel -r $ftpuser
    echo "Usuário $ftpuser excluído com sucesso!"
}

# Função para instalar e configurar SSL com Let's Encrypt
install_ssl() {
    echo "=== Instalando e configurando o SSL com Let's Encrypt ==="
    
    # Instalar o Certbot para obter o certificado SSL
    sudo apt install certbot python3-certbot-nginx -y

    # Obter o certificado SSL para o domínio
    read -p "Digite o domínio para gerar o certificado SSL (exemplo: storage.i3host.com.br): " domain
    sudo certbot --nginx -d $domain --non-interactive --agree-tos --email seu-email@dominio.com

    echo "Certificado SSL configurado com sucesso para o domínio $domain!"
}

# Menu principal
while true; do
    echo "===== MENU ====="
    echo "1. Configurar data e hora do servidor"
    echo "2. Configurar vsftpd"
    echo "3. Configurar servidor web Nginx"
    echo "4. Ajustar configurações de firewall"
    echo "5. Criar novo usuário FTP"
    echo "6. Excluir usuário FTP"
    echo "7. Instalar e configurar SSL"
    echo "8. Sair"
    read -p "Escolha uma opção: " option

    case $option in
        1)
            configure_date
            ;;
        2)
            configure_vsftpd
            ;;
        3)
            configure_nginx
            ;;
        4)
            adjust_firewall
            ;;
        5)
            create_ftp_user
            ;;
        6)
            delete_ftp_user
            ;;
        7)
            install_ssl
            ;;
        8)
            echo "Saindo..."
            break
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            ;;
    esac
done
