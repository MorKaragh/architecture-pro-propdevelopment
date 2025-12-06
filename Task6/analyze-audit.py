#!/usr/bin/env python3
"""
Скрипт для анализа Kubernetes Audit Log
Находит подозрительные события и создает отчет
"""

import json
import sys
from collections import defaultdict
from datetime import datetime

def load_audit_log(filepath):
    """Загружает события из audit.log"""
    events = []
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
                events.append(event)
            except json.JSONDecodeError:
                continue
    return events

def is_suspicious_event(event):
    """Проверяет, является ли событие подозрительным"""
    suspicious = False
    reasons = []
    
    # Пропускаем системные события
    user = event.get('user', {})
    username = user.get('username', '')
    
    # Игнорируем системные пользователи (но не все - некоторые могут быть подозрительными)
    # system:apiserver - точно игнорируем
    if username == 'system:apiserver':
        return False, []
    
    # system:kube-scheduler, system:node - обычно нормальные, но проверяем контекст
    # system:serviceaccount - может быть подозрительным в зависимости от namespace
    
    verb = event.get('verb', '')
    obj_ref = event.get('objectRef', {})
    resource = obj_ref.get('resource', '')
    namespace = obj_ref.get('namespace', '')
    name = obj_ref.get('name', '')
    stage = event.get('stage', '')
    
    # Только завершенные запросы
    if stage != 'ResponseComplete':
        return False, []
    
    # 1. Доступ к secrets (особенно в kube-system)
    if resource == 'secrets' and verb in ['get', 'list']:
        # Игнорируем системные пользователи для secrets
        if not username.startswith('system:'):
            if namespace == 'kube-system' or (not namespace and verb == 'list'):
                suspicious = True
                reasons.append(f"Доступ к secrets в namespace '{namespace or 'cluster-wide'}'")
    
    # 2. Создание privileged pods
    if resource == 'pods' and verb == 'create':
        request_obj = event.get('requestObject', {})
        if request_obj:
            spec = request_obj.get('spec', {})
            containers = spec.get('containers', [])
            for container in containers:
                security_context = container.get('securityContext', {})
                if security_context.get('privileged') is True:
                    suspicious = True
                    reasons.append("Создание privileged pod")
                    break
    
    # 3. Использование exec в подах (особенно в kube-system)
    # Exec может быть через subresource или через requestURI
    request_uri = event.get('requestURI', '')
    subresource = obj_ref.get('subresource', '')
    
    if resource == 'pods' and ('/exec' in request_uri or subresource == 'exec'):
        # Игнорируем системные пользователи
        if not username.startswith('system:'):
            suspicious = True
            reasons.append(f"Использование kubectl exec в поде '{name}' в namespace '{namespace}'")
    
    # 4. Создание RoleBinding с cluster-admin
    if resource == 'rolebindings' and verb == 'create':
        request_obj = event.get('requestObject', {})
        if request_obj:
            role_ref = request_obj.get('roleRef', {})
            if role_ref.get('name') == 'cluster-admin':
                suspicious = True
                reasons.append("Создание RoleBinding с правами cluster-admin")
    
    # 5. Попытки удаления audit-policy.yaml
    if verb == 'delete':
        # Проверяем удаление через разные ресурсы
        if resource in ['configmaps', 'secrets']:
            if 'audit-policy' in name.lower() or 'audit' in name.lower():
                suspicious = True
                reasons.append(f"Попытка удаления файла политики аудита: {name}")
        # Также проверяем через requestURI
        if '/audit-policy' in request_uri.lower() or '/audit' in request_uri.lower():
            suspicious = True
            reasons.append(f"Попытка удаления файла политики аудита через URI: {request_uri}")
    
    # 6. Создание ClusterRoleBinding с cluster-admin
    if resource == 'clusterrolebindings' and verb == 'create':
        request_obj = event.get('requestObject', {})
        if request_obj:
            role_ref = request_obj.get('roleRef', {})
            if role_ref.get('name') == 'cluster-admin':
                suspicious = True
                reasons.append("Создание ClusterRoleBinding с правами cluster-admin")
    
    # 7. Создание подозрительных namespace
    if resource == 'namespaces' and verb == 'create':
        request_obj = event.get('requestObject', {})
        if request_obj:
            ns_name = request_obj.get('metadata', {}).get('name', '')
            if ns_name and ns_name not in ['kube-system', 'kube-public', 'kube-node-lease', 'default']:
                # Проверяем, не является ли это частью атаки
                if 'secure' in ns_name.lower() or 'ops' in ns_name.lower():
                    suspicious = True
                    reasons.append(f"Создание подозрительного namespace: {ns_name}")
    
    # 8. Создание ServiceAccount в подозрительных namespace
    if resource == 'serviceaccounts' and verb == 'create':
        if namespace and namespace not in ['kube-system', 'kube-public', 'kube-node-lease', 'default']:
            suspicious = True
            reasons.append(f"Создание ServiceAccount в нестандартном namespace: {namespace}")
    
    # 9. Создание подозрительных подов
    if resource == 'pods' and verb == 'create':
        request_obj = event.get('requestObject', {})
        if request_obj:
            pod_name = request_obj.get('metadata', {}).get('name', '')
            if pod_name:
                if 'attacker' in pod_name.lower() or 'pwn' in pod_name.lower():
                    suspicious = True
                    reasons.append(f"Создание подозрительного пода: {pod_name}")
    
    return suspicious, reasons

def analyze_audit_log(events):
    """Анализирует события и группирует подозрительные"""
    suspicious_events = []
    events_by_category = defaultdict(list)
    
    for event in events:
        is_susp, reasons = is_suspicious_event(event)
        if is_susp:
            event['_analysis_reasons'] = reasons
            suspicious_events.append(event)
            
            # Группируем по категориям
            for reason in reasons:
                if 'secrets' in reason.lower():
                    events_by_category['secrets_access'].append(event)
                elif 'privileged' in reason.lower():
                    events_by_category['privileged_pods'].append(event)
                elif 'exec' in reason.lower():
                    events_by_category['kubectl_exec'].append(event)
                elif 'rolebinding' in reason.lower() or 'clusterrolebinding' in reason.lower():
                    events_by_category['rbac_escalation'].append(event)
                elif 'audit' in reason.lower():
                    events_by_category['audit_policy_deletion'].append(event)
                elif 'namespace' in reason.lower():
                    events_by_category['suspicious_namespace'].append(event)
                elif 'serviceaccount' in reason.lower():
                    events_by_category['suspicious_serviceaccount'].append(event)
                elif 'pod' in reason.lower() and 'privileged' not in reason.lower():
                    events_by_category['suspicious_pods'].append(event)
    
    return suspicious_events, events_by_category

def format_timestamp(ts):
    """Форматирует timestamp"""
    try:
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        return dt.strftime('%Y-%m-%d %H:%M:%S UTC')
    except:
        return ts

def generate_report(suspicious_events, events_by_category):
    """Генерирует отчет в формате Markdown"""
    report = []
    report.append("# Отчёт по результатам анализа Kubernetes Audit Log\n")
    
    report.append("## Подозрительные события\n\n")
    
    # 1. Доступ к секретам
    report.append("### 1. Доступ к секретам:\n\n")
    secrets_events = events_by_category.get('secrets_access', [])
    if secrets_events:
        unique_secrets = {}
        for event in secrets_events:
            user = event.get('user', {}).get('username', 'unknown')
            namespace = event.get('objectRef', {}).get('namespace', 'cluster-wide')
            timestamp = format_timestamp(event.get('requestReceivedTimestamp', ''))
            key = f"{user}:{namespace}"
            if key not in unique_secrets:
                unique_secrets[key] = {
                    'user': user,
                    'namespace': namespace,
                    'timestamp': timestamp,
                    'event': event
                }
        
        for key, info in unique_secrets.items():
            report.append(f"- **Кто:** {info['user']}\n")
            report.append(f"- **Где:** namespace `{info['namespace']}`\n")
            report.append(f"- **Когда:** {info['timestamp']}\n")
            report.append(f"- **Почему подозрительно:** Доступ к secrets в системном namespace или cluster-wide\n\n")
    else:
        report.append("- Подозрительных обращений к secrets не обнаружено\n\n")
    
    # 2. Привилегированные поды
    report.append("### 2. Привилегированные поды:\n\n")
    privileged_events = events_by_category.get('privileged_pods', [])
    if privileged_events:
        for event in privileged_events:
            user = event.get('user', {}).get('username', 'unknown')
            obj_ref = event.get('objectRef', {})
            namespace = obj_ref.get('namespace', 'default')
            name = obj_ref.get('name', 'unknown')
            timestamp = format_timestamp(event.get('requestReceivedTimestamp', ''))
            report.append(f"- **Кто:** {user}\n")
            report.append(f"- **Под:** `{name}` в namespace `{namespace}`\n")
            report.append(f"- **Когда:** {timestamp}\n")
            report.append(f"- **Комментарий:** Создан pod с привилегированным доступом (privileged: true), что дает доступ к хосту\n\n")
    else:
        report.append("- Привилегированных подов не обнаружено\n\n")
    
    # 3. Использование kubectl exec
    report.append("### 3. Использование kubectl exec в чужом поде:\n\n")
    exec_events = events_by_category.get('kubectl_exec', [])
    if exec_events:
        for event in exec_events:
            user = event.get('user', {}).get('username', 'unknown')
            obj_ref = event.get('objectRef', {})
            namespace = obj_ref.get('namespace', 'default')
            name = obj_ref.get('name', 'unknown')
            timestamp = format_timestamp(event.get('requestReceivedTimestamp', ''))
            report.append(f"- **Кто:** {user}\n")
            report.append(f"- **Что делал:** Выполнил команду в поде `{name}` в namespace `{namespace}`\n")
            report.append(f"- **Когда:** {timestamp}\n\n")
    else:
        # Проверяем exec через другие методы
        exec_found = False
        for event in suspicious_events:
            obj_ref = event.get('objectRef', {})
            if obj_ref.get('subresource') == 'exec':
                exec_found = True
                user = event.get('user', {}).get('username', 'unknown')
                namespace = obj_ref.get('namespace', 'default')
                name = obj_ref.get('name', 'unknown')
                timestamp = format_timestamp(event.get('requestReceivedTimestamp', ''))
                report.append(f"- **Кто:** {user}\n")
                report.append(f"- **Что делал:** Выполнил команду в поде `{name}` в namespace `{namespace}`\n")
                report.append(f"- **Когда:** {timestamp}\n\n")
        if not exec_found:
            report.append("- Использования kubectl exec в чужих подах не обнаружено\n\n")
    
    # 4. Создание RoleBinding с cluster-admin
    report.append("### 4. Создание RoleBinding с правами cluster-admin:\n\n")
    rbac_events = events_by_category.get('rbac_escalation', [])
    if rbac_events:
        for event in rbac_events:
            user = event.get('user', {}).get('username', 'unknown')
            obj_ref = event.get('objectRef', {})
            namespace = obj_ref.get('namespace', '')
            name = obj_ref.get('name', 'unknown')
            timestamp = format_timestamp(event.get('requestReceivedTimestamp', ''))
            request_obj = event.get('requestObject', {})
            subjects = request_obj.get('subjects', [])
            
            report.append(f"- **Кто:** {user}\n")
            report.append(f"- **Что создал:** {'RoleBinding' if namespace else 'ClusterRoleBinding'} `{name}`\n")
            if namespace:
                report.append(f"- **Где:** namespace `{namespace}`\n")
            report.append(f"- **Когда:** {timestamp}\n")
            report.append(f"- **К чему привело:** Предоставлены права cluster-admin субъектам: {', '.join([s.get('name', 'unknown') for s in subjects])}\n\n")
    else:
        report.append("- Создания RoleBinding с правами cluster-admin не обнаружено\n\n")
    
    # 5. Удаление audit-policy.yaml
    report.append("### 5. Удаление audit-policy.yaml:\n\n")
    audit_deletion_events = events_by_category.get('audit_policy_deletion', [])
    if audit_deletion_events:
        for event in audit_deletion_events:
            user = event.get('user', {}).get('username', 'unknown')
            obj_ref = event.get('objectRef', {})
            name = obj_ref.get('name', 'unknown')
            timestamp = format_timestamp(event.get('requestReceivedTimestamp', ''))
            response_status = event.get('responseStatus', {})
            code = response_status.get('code', 0)
            
            report.append(f"- **Кто:** {user}\n")
            report.append(f"- **Что пытался удалить:** {name}\n")
            report.append(f"- **Когда:** {timestamp}\n")
            if code == 200 or code == 201:
                report.append(f"- **Результат:** Успешно удалено\n")
            else:
                report.append(f"- **Результат:** Попытка удаления (код ответа: {code})\n")
            report.append(f"- **Возможные последствия:** Отключение аудита кластера, невозможность отслеживания дальнейших действий злоумышленника\n\n")
    else:
        report.append("- Попыток удаления audit-policy.yaml не обнаружено\n\n")
    
    # Вывод
    report.append("## Вывод\n\n")
    
    total_suspicious = len(suspicious_events)
    if total_suspicious > 0:
        report.append(f"Обнаружено **{total_suspicious}** подозрительных событий.\n\n")
        
        # Анализ компрометации
        compromised = False
        if events_by_category.get('rbac_escalation'):
            compromised = True
            report.append("### Компрометация кластера:\n\n")
            report.append("**КРИТИЧНО:** Обнаружена эскалация привилегий через создание RoleBinding/ClusterRoleBinding с правами cluster-admin. ")
            report.append("Это означает полную компрометацию кластера - злоумышленник получил административные права.\n\n")
        
        if events_by_category.get('privileged_pods'):
            if not compromised:
                report.append("### Компрометация кластера:\n\n")
            compromised = True
            report.append("**КРИТИЧНО:** Обнаружено создание привилегированных подов. ")
            report.append("Такие поды имеют доступ к хосту и могут быть использованы для дальнейшей атаки.\n\n")
        
        if events_by_category.get('audit_policy_deletion'):
            if not compromised:
                report.append("### Компрометация кластера:\n\n")
            compromised = True
            report.append("**КРИТИЧНО:** Обнаружена попытка удаления политики аудита. ")
            report.append("Это попытка скрыть следы атаки и предотвратить дальнейшее логирование.\n\n")
        
        # Ошибки RBAC
        report.append("### Ошибки политики RBAC:\n\n")
        rbac_issues = []
        
        if events_by_category.get('rbac_escalation'):
            rbac_issues.append("- **Отсутствие ограничений на создание RoleBinding с cluster-admin:** Пользователи могут создавать RoleBinding, связывающие ServiceAccount с ClusterRole cluster-admin, что дает полный доступ к кластеру")
        
        if events_by_category.get('secrets_access'):
            rbac_issues.append("- **Слишком широкий доступ к secrets:** Пользователи имеют доступ к secrets в системных namespace (kube-system), что может привести к компрометации системных компонентов")
        
        if events_by_category.get('privileged_pods'):
            rbac_issues.append("- **Отсутствие ограничений на создание privileged pods:** Пользователи могут создавать поды с привилегированным доступом без дополнительных проверок")
        
        if rbac_issues:
            report.append("\n".join(rbac_issues))
        else:
            report.append("Серьезных ошибок в политике RBAC не обнаружено.")
        
    else:
        report.append("Подозрительных событий не обнаружено.\n")
    
    return "\n".join(report)

def main():
    if len(sys.argv) < 2:
        print("Использование: python3 analyze-audit.py <audit.log>")
        sys.exit(1)
    
    audit_log_path = sys.argv[1]
    print(f"Загрузка audit log из {audit_log_path}...")
    events = load_audit_log(audit_log_path)
    print(f"Загружено {len(events)} событий")
    
    print("Анализ событий...")
    suspicious_events, events_by_category = analyze_audit_log(events)
    print(f"Найдено {len(suspicious_events)} подозрительных событий")
    
    # Генерируем отчет
    print("Генерация отчета...")
    report = generate_report(suspicious_events, events_by_category)
    
    # Сохраняем отчет
    with open('analysis.md', 'w', encoding='utf-8') as f:
        f.write(report)
    print("Отчет сохранен в analysis.md")
    
    # Сохраняем подозрительные события в JSON
    # Удаляем временные поля перед сохранением
    for event in suspicious_events:
        if '_analysis_reasons' in event:
            del event['_analysis_reasons']
    
    with open('audit-extract.json', 'w', encoding='utf-8') as f:
        json.dump(suspicious_events, f, indent=2, ensure_ascii=False)
    print("Подозрительные события сохранены в audit-extract.json")
    
    print("\nАнализ завершен!")

if __name__ == '__main__':
    main()

