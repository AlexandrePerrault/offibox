$path = Join-Path (Get-Location) "login-wix.html"
$content = Get-Content $path -Raw -Encoding UTF8
$old = @"
        align-self: stretch;
      }
    }
    .login-col
"@
$new = @"
        align-self: stretch;
      }
      .login-card,
      .login-desc-card {
        min-height: 540px;
      }
    }
    .login-col
"@
$content = $content.Replace($old, $new)
Set-Content $path $content -NoNewline -Encoding UTF8
