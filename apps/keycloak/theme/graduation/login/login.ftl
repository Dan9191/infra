<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Войти — База знаний</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap">
    <link rel="stylesheet" href="${url.resourcesPath}/css/graduation.css">
</head>
<body>

<div class="page">
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
</div>

</body>
</html>
