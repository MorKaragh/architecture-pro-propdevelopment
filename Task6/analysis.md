# Отчёт по результатам анализа Kubernetes Audit Log

## Подозрительные события


### 1. Доступ к секретам:


- **Кто:** kubernetes-admin

- **Где:** namespace `kube-system`

- **Когда:** 2025-12-06 15:38:47 UTC

- **Почему подозрительно:** Доступ к secrets в системном namespace или cluster-wide


- **Кто:** minikube-user

- **Где:** namespace `kube-system`

- **Когда:** 2025-12-06 15:38:51 UTC

- **Почему подозрительно:** Доступ к secrets в системном namespace или cluster-wide


### 2. Привилегированные поды:


- **Кто:** minikube-user

- **Под:** `privileged-pod` в namespace `secure-ops`

- **Когда:** 2025-12-06 15:38:51 UTC

- **Комментарий:** Создан pod с привилегированным доступом (privileged: true), что дает доступ к хосту


- **Кто:** system:serviceaccount:kube-system:daemon-set-controller

- **Под:** `unknown` в namespace `kube-system`

- **Когда:** 2025-12-06 15:38:53 UTC

- **Комментарий:** Создан pod с привилегированным доступом (privileged: true), что дает доступ к хосту


### 3. Использование kubectl exec в чужом поде:


- Использования kubectl exec в чужих подах не обнаружено


### 4. Создание RoleBinding с правами cluster-admin:


- **Кто:** kubernetes-super-admin

- **Что создал:** ClusterRoleBinding `kubeadm:cluster-admins`

- **Когда:** 2025-12-06 15:38:47 UTC

- **К чему привело:** Предоставлены права cluster-admin субъектам: kubeadm:cluster-admins


- **Кто:** minikube

- **Что создал:** ClusterRoleBinding `minikube-rbac`

- **Когда:** 2025-12-06 15:38:48 UTC

- **К чему привело:** Предоставлены права cluster-admin субъектам: default


- **Кто:** minikube-user

- **Что создал:** RoleBinding `escalate-binding`

- **Где:** namespace `secure-ops`

- **Когда:** 2025-12-06 15:38:53 UTC

- **К чему привело:** Предоставлены права cluster-admin субъектам: monitoring


### 5. Удаление audit-policy.yaml:


- Попыток удаления audit-policy.yaml не обнаружено


## Вывод


Обнаружено **11** подозрительных событий.


### Компрометация кластера:


**КРИТИЧНО:** Обнаружена эскалация привилегий через создание RoleBinding/ClusterRoleBinding с правами cluster-admin. 
Это означает полную компрометацию кластера - злоумышленник получил административные права.


**КРИТИЧНО:** Обнаружено создание привилегированных подов. 
Такие поды имеют доступ к хосту и могут быть использованы для дальнейшей атаки.


### Ошибки политики RBAC:


- **Отсутствие ограничений на создание RoleBinding с cluster-admin:** Пользователи могут создавать RoleBinding, связывающие ServiceAccount с ClusterRole cluster-admin, что дает полный доступ к кластеру
- **Слишком широкий доступ к secrets:** Пользователи имеют доступ к secrets в системных namespace (kube-system), что может привести к компрометации системных компонентов
- **Отсутствие ограничений на создание privileged pods:** Пользователи могут создавать поды с привилегированным доступом без дополнительных проверок