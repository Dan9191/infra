<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Войти — База знаний</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        html, body {
            height: 100%;
        }

        body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px 16px;
            background-color: #f0f4f8;
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
            color: #0f172a;
            -webkit-font-smoothing: antialiased;
        }

        .card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-top: 3px solid #059669;
            border-radius: 12px;
            width: 100%;
            max-width: 420px;
            padding: 36px 32px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1), 0 0 0 1px rgba(5,150,105,0.07);
        }

        .card-header {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 6px;
        }

        .card-header-prompt {
            font-family: 'JetBrains Mono', monospace;
            color: #059669;
            font-size: 1.1rem;
            font-weight: 500;
        }

        .card-header-title {
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.8rem;
            color: #64748b;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }

        .card-subtitle {
            font-size: 1.3rem;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 28px;
            letter-spacing: -0.02em;
        }

        .alert {
            border-radius: 7px;
            padding: 10px 14px;
            font-size: 0.875rem;
            margin-bottom: 20px;
            line-height: 1.4;
        }

        .alert-error, .alert-warning {
            background: #fef2f2;
            border: 1px solid #fca5a5;
            color: #991b1b;
        }

        .alert-success {
            background: #ecfdf5;
            border: 1px solid #a7f3d0;
            color: #065f46;
        }

        .alert-info {
            background: #eff6ff;
            border: 1px solid #bfdbfe;
            color: #1e40af;
        }

        .form-group {
            display: flex;
            flex-direction: column;
            gap: 6px;
            margin-bottom: 18px;
        }

        .form-group label {
            font-size: 0.875rem;
            font-weight: 500;
            color: #0f172a;
        }

        .form-group input {
            border: 1px solid #e2e8f0;
            border-radius: 7px;
            padding: 10px 12px;
            font-family: 'Inter', system-ui, sans-serif;
            font-size: 0.9rem;
            background: white;
            color: #0f172a;
            width: 100%;
            transition: border-color 0.15s, box-shadow 0.15s;
        }

        .form-group input:focus {
            outline: none;
            border-color: #059669;
            box-shadow: 0 0 0 3px rgba(5,150,105,0.15);
        }

        .form-group input.input-error {
            border-color: #fca5a5;
        }

        .form-check {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 22px;
        }

        .form-check input[type="checkbox"] {
            width: 16px;
            height: 16px;
            accent-color: #059669;
            cursor: pointer;
        }

        .form-check label {
            font-size: 0.875rem;
            color: #64748b;
            cursor: pointer;
        }

        .btn-submit {
            width: 100%;
            background: #059669;
            color: white;
            border: 1px solid #059669;
            border-radius: 7px;
            padding: 11px 18px;
            font-family: 'Inter', system-ui, sans-serif;
            font-size: 0.95rem;
            font-weight: 500;
            cursor: pointer;
            transition: background-color 0.15s, border-color 0.15s;
            margin-top: 4px;
        }

        .btn-submit:hover {
            background: #047857;
            border-color: #047857;
        }

        .card-links {
            margin-top: 20px;
            text-align: center;
            font-size: 0.875rem;
        }

        .card-links a {
            color: #059669;
            text-decoration: none;
            font-weight: 500;
        }

        .card-links a:hover {
            color: #047857;
            text-decoration: underline;
        }

        @media (max-width: 480px) {
            .card { padding: 28px 20px; }
        }
    </style>
</head>
<body>

<div class="card">

    <div class="card-header">
        <span class="card-header-prompt">&gt;</span>
        <span class="card-header-title">База знаний</span>
    </div>

    <h1 class="card-subtitle">Войти в аккаунт</h1>

    <#if message?has_content>
    <div class="alert alert-${message.type}">
        ${kcSanitize(message.summary)?no_esc}
    </div>
    </#if>

    <form action="${url.loginAction}" method="post" novalidate>

        <div class="form-group">
            <label for="username">Логин или e-mail</label>
            <input
                type="text"
                id="username"
                name="username"
                value="${(login.username!'')}"
                autofocus
                autocomplete="username"
                class="<#if messagesPerField.existsError('username','password')>input-error</#if>"
            >
        </div>

        <div class="form-group">
            <label for="password">Пароль</label>
            <input
                type="password"
                id="password"
                name="password"
                autocomplete="current-password"
                class="<#if messagesPerField.existsError('username','password')>input-error</#if>"
            >
        </div>

        <#if realm.rememberMe>
        <div class="form-check">
            <input type="checkbox" id="rememberMe" name="rememberMe"
                <#if login.rememberMe??>checked</#if>>
            <label for="rememberMe">Запомнить меня</label>
        </div>
        </#if>

        <input type="hidden" id="id-hidden-input" name="credentialId"
            <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>>

        <button type="submit" class="btn-submit">Войти</button>

    </form>

    <#if realm.resetPasswordAllowed>
    <div class="card-links">
        <a href="${url.loginResetCredentialsUrl}">Забыли пароль?</a>
    </div>
    </#if>

</div>

</body>
</html>
