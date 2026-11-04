# ============================================================================
# 行山腳 HikeHub · 建立 6 個可登入測試帳號（Auth Admin API）
# Project: COMP 7510 Group Project
# ============================================================================
#
# 為什麼需要這支腳本：
#   新版 Supabase 的 GoTrue 不認可用 SQL 直接 INSERT 進 auth.users 的帳號
#   （即便補齊 instance_id / identity / bcrypt，登入仍回 invalid_credentials），
#   必須透過 Auth Admin API 讓 GoTrue 自己建立，才會寫入正確的 Auth 狀態。
#
# 前置：環境變數 SUPABASE_ACCESS_TOKEN = Supabase 帳戶級 Access Token（sbp_ 開頭）
#   取得位置：Supabase 右上角頭像 → Account Settings → Access Tokens → Generate new token
#   用完請至後台 Revoke。此 Token 權限極高，切勿寫入 repo 或 .env。
#
# 用法（在專案根目錄執行）：
#   $env:SUPABASE_ACCESS_TOKEN = 'sbp_xxx'
#   powershell -File supabase/create_auth_users.ps1
#
# 參數可用 -ProjectRef / -Password 覆寫。腳本可重複執行（已存在的帳號會跳過）。

param(
    [string]$ProjectRef = 'khqleyfszhsnavtdtwgn',
    [string]$Password   = 'HikeHub2026!'
)

$ErrorActionPreference = 'Stop'
$token = $env:SUPABASE_ACCESS_TOKEN
if (-not $token) { throw '請先設定環境變數 SUPABASE_ACCESS_TOKEN（sbp_ 開頭的帳戶級 Token）' }

$mgmt = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
$base = "https://$ProjectRef.supabase.co"

# 由 Management API 動態取得 service_role / anon key，避免把金鑰寫死在檔案裡
$keys = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ProjectRef/api-keys" `
                          -Method Get -Headers $mgmt -TimeoutSec 60
$serviceRole = ($keys | Where-Object { $_.name -eq 'service_role' }).api_key
$anon        = ($keys | Where-Object { $_.name -eq 'anon' }).api_key
if (-not $serviceRole -or -not $anon) { throw '無法取得 service_role / anon key' }

$admin = @{ Authorization = "Bearer $serviceRole"; apikey = $serviceRole; 'Content-Type' = 'application/json' }

# 固定 UUID：必須與 seed.sql 的 profiles 及所有貼文/留言/點讚作者一致
$accounts = @(
    @('11111111-1111-4111-8111-111111111101', 'ahon@hikehub.hk'),
    @('11111111-1111-4111-8111-111111111102', 'kaki@hikehub.hk'),
    @('11111111-1111-4111-8111-111111111103', 'fai@hikehub.hk'),
    @('11111111-1111-4111-8111-111111111104', 'yannes@hikehub.hk'),
    @('11111111-1111-4111-8111-111111111105', 'kelvin@hikehub.hk'),
    @('11111111-1111-4111-8111-111111111106', 'mandy@hikehub.hk')
)

Write-Output '--- 建立帳號（Auth Admin API）---'
foreach ($a in $accounts) {
    $body = @{
        id            = $a[0]
        email         = $a[1]
        password      = $Password
        email_confirm = $true
    } | ConvertTo-Json -Compress
    try {
        $r = Invoke-RestMethod -Uri "$base/auth/v1/admin/users" -Method Post `
                               -Headers $admin -Body $body -TimeoutSec 60
        Write-Output ("  OK   {0}  id={1}" -f $r.email, $r.id)
    } catch {
        $detail = $_.ErrorDetails.Message
        if ($detail -match 'already_registered|User already registered|duplicate key') {
            Write-Output ("  SKIP {0}（已存在）" -f $a[1])
        } else {
            Write-Output ("  FAIL {0} : {1} {2}" -f $a[1], $_.Exception.Message, $detail)
        }
    }
}

Write-Output '--- 登入實測 ---'
$allOk = $true
foreach ($a in $accounts) {
    $body = @{ email = $a[1]; password = $Password } | ConvertTo-Json -Compress
    try {
        $r = Invoke-RestMethod -Uri "$base/auth/v1/token?grant_type=password" -Method Post `
             -Headers @{ apikey = $anon; 'Content-Type' = 'application/json' } -Body $body -TimeoutSec 30
        $match = ($r.user.id -eq $a[0])
        Write-Output ("  OK   {0}  uuid_match={1}" -f $a[1], $match)
        if (-not $match) { $allOk = $false }
    } catch {
        Write-Output ("  FAIL {0} : {1}" -f $a[1], $_.ErrorDetails.Message)
        $allOk = $false
    }
}

if ($allOk) { Write-Output 'DONE: 6 個帳號皆可登入，UUID 與 seed.sql 一致。' }
else        { throw '有帳號無法登入，請檢查上方錯誤。' }
